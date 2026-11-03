#!/usr/bin/env bash
# Drop: dump the LIVE legacy MySQL database for migration to Supabase Postgres.
#
# Run this ON THE OLD SERVER (or any machine that can reach the old MySQL).
# It is read-only: it only runs SELECTs and a consistent snapshot dump.
#
# Usage:
#   bash dump-live-mysql.sh <db_name> <db_user> [db_host] [db_port]
# Example:
#   bash dump-live-mysql.sh texiapp root 127.0.0.1 3306
#
# You will be prompted for the MySQL password (it is never put on the command line).
#
# Output (in ./drop-dump-<timestamp>/):
#   drop-live.sql.gz      full data + structure (consistent snapshot, InnoDB)
#   reconciliation.txt    per-table row counts + wallet/payment totals, used to prove
#                         the import is exact
#   drop-live.sql.gz.sha256
#
# NEVER commit these files to git. They contain personal data and password hashes.
# Not included on purpose: payment_gateways rows (they hold live gateway secret keys;
# those keys must be rotated and re-entered in the new system), failed_jobs, jobs,
# password_resets.

set -euo pipefail

DB="${1:?usage: $0 <db_name> <db_user> [db_host] [db_port]}"
USER_="${2:?usage: $0 <db_name> <db_user> [db_host] [db_port]}"
HOST="${3:-127.0.0.1}"
PORT="${4:-3306}"

command -v mysqldump >/dev/null 2>&1 || { echo "mysqldump not found. Install mysql-client or mariadb-client first."; exit 1; }
command -v mysql >/dev/null 2>&1 || { echo "mysql client not found."; exit 1; }

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="./drop-dump-${STAMP}"
mkdir -p "$OUT"
chmod 700 "$OUT"

read -r -s -p "MySQL password for ${USER_}@${HOST}: " MYSQL_PWD_INPUT
echo
export MYSQL_PWD="$MYSQL_PWD_INPUT"
unset MYSQL_PWD_INPUT

MYSQL_ARGS=(--host="$HOST" --port="$PORT" --user="$USER_")

echo "[1/4] Testing connection..."
mysql "${MYSQL_ARGS[@]}" -N -e "SELECT CONCAT('connected to ', VERSION(), ' / db ', DATABASE())" "$DB"

SKIP_DATA=(payment_gateways failed_jobs jobs password_resets)
IGNORE_ARGS=()
for t in "${SKIP_DATA[@]}"; do IGNORE_ARGS+=(--ignore-table="${DB}.${t}"); done

# Oracle MySQL and MariaDB ship different mysqldump options. Only pass the ones
# this mysqldump actually supports.
DUMP_HELP="$(mysqldump --help 2>/dev/null || true)"
COMPAT_ARGS=()
if grep -q -- '--set-gtid-purged' <<<"$DUMP_HELP"; then COMPAT_ARGS+=(--set-gtid-purged=OFF); fi
if grep -q -- '--no-tablespaces' <<<"$DUMP_HELP"; then COMPAT_ARGS+=(--no-tablespaces); fi
echo "mysqldump: $(mysqldump --version)"

echo "[2/4] Dumping data + structure (consistent snapshot, no table locks)..."
{
  mysqldump "${MYSQL_ARGS[@]}" \
    --single-transaction --quick --routines --triggers --events \
    --hex-blob --default-character-set=utf8mb4 \
    "${COMPAT_ARGS[@]}" \
    "${IGNORE_ARGS[@]}" "$DB"
  # structure only for the skipped tables, so the schema is complete
  mysqldump "${MYSQL_ARGS[@]}" \
    --no-data --skip-triggers \
    "${COMPAT_ARGS[@]}" \
    "$DB" "${SKIP_DATA[@]}"
} | gzip -9 > "${OUT}/drop-live.sql.gz"

# Sanity check: a failed dump must not leave a "successful" tiny file behind.
SIZE=$(wc -c < "${OUT}/drop-live.sql.gz")
if [ "$SIZE" -lt 2000 ]; then
  echo "ERROR: dump is suspiciously small (${SIZE} bytes). Aborting."
  exit 1
fi

echo "[3/4] Writing reconciliation report..."
{
  echo "Drop legacy DB reconciliation"
  echo "database: ${DB}   taken (UTC): ${STAMP}"
  echo
  echo "== row counts per table =="
  mysql "${MYSQL_ARGS[@]}" -N "$DB" -e "SELECT table_name FROM information_schema.tables WHERE table_schema='${DB}' AND table_type='BASE TABLE' ORDER BY 1" |
  while read -r t; do
    printf '%-32s %s\n' "$t" "$(mysql "${MYSQL_ARGS[@]}" -N "$DB" -e "SELECT COUNT(*) FROM \`$t\`")"
  done
  echo
  echo "== money totals (exact check values) =="
  mysql "${MYSQL_ARGS[@]}" -t "$DB" -e "
    SELECT 'wallets' AS src, COUNT(*) AS n,
           ROUND(SUM(total_amount),2) AS total_amount,
           ROUND(SUM(online_received),2) AS online_received,
           ROUND(SUM(collected_cash),2) AS collected_cash,
           ROUND(SUM(manual_received),2) AS manual_received,
           ROUND(SUM(total_withdrawn),2) AS total_withdrawn
    FROM wallets;
    SELECT 'payments' AS src, COUNT(*) AS n,
           ROUND(SUM(total_amount),2) AS total_amount,
           ROUND(SUM(admin_commission),2) AS admin_commission,
           ROUND(SUM(driver_fee),2) AS driver_fee,
           ROUND(SUM(driver_tips),2) AS driver_tips
    FROM payments;
    SELECT 'wallet_histories' AS src, COUNT(*) AS n, ROUND(SUM(amount),2) AS amount_sum
    FROM wallet_histories;
    SELECT 'users by type' AS src, user_type, COUNT(*) AS n FROM users GROUP BY user_type;
    SELECT 'rides by status' AS src, status, COUNT(*) AS n FROM ride_requests GROUP BY status;
  "
} > "${OUT}/reconciliation.txt"

echo "[4/4] Checksum..."
( cd "$OUT" && sha256sum drop-live.sql.gz > drop-live.sql.gz.sha256 )
unset MYSQL_PWD

echo
echo "Done. Files in: ${OUT}"
ls -lh "$OUT"
echo
echo "Next: send drop-live.sql.gz and reconciliation.txt through a private channel."
echo "Do NOT email them or put them in GitHub."
