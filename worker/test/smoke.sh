#!/usr/bin/env bash
# End-to-end smoke test of the auth endpoints against a running `wrangler dev`.
# Usage: BASE=http://127.0.0.1:8787 bash test/smoke.sh
set -u
BASE=${BASE:-http://127.0.0.1:8787}
fail=0
check() { # name, expected substring, actual
  if [[ "$3" == *"$2"* ]]; then echo "PASS  $1"; else echo "FAIL  $1  (wanted: $2)  got: $3"; fail=1; fi
}
j() { curl -s -H 'content-type: application/json' "$@"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
S=$RANDOM$RANDOM

check "health" '"ok":true' "$(j $BASE/api/health)"
check "db health" '"ok":true' "$(j $BASE/api/health/db)"

R=$(j -X POST $BASE/api/register -d "{\"first_name\":\"Ada\",\"last_name\":\"Obi\",\"email\":\"ada$S@x.com\",\"username\":\"ada$S\",\"password\":\"secret123\",\"user_type\":\"rider\"}")
check "register passenger" 'Passenger has been saved successfully' "$R"
TOKEN=$(echo "$R" | sed -n 's/.*"api_token":"\([^"]*\)".*/\1/p')
check "register returns token" '|' "$TOKEN"

check "register admin blocked" 'selected user type is invalid' "$(j -X POST $BASE/api/register -d "{\"first_name\":\"E\",\"last_name\":\"V\",\"email\":\"e$S@x.com\",\"username\":\"e$S\",\"password\":\"secret123\",\"user_type\":\"admin\"}")"
check "duplicate email" 'email has already been taken' "$(j -X POST $BASE/api/register -d "{\"first_name\":\"Ada\",\"last_name\":\"Obi\",\"email\":\"ada$S@x.com\",\"username\":\"other$S\",\"password\":\"secret123\"}")"
check "short password" 'at least 8' "$(j -X POST $BASE/api/register -d "{\"first_name\":\"A\",\"last_name\":\"B\",\"email\":\"s$S@x.com\",\"username\":\"s$S\",\"password\":\"x\"}")"
D=$(j -X POST $BASE/api/register -d "{\"first_name\":\"Dan\",\"last_name\":\"D\",\"email\":\"dan$S@x.com\",\"username\":\"dan$S\",\"password\":\"secret123\",\"user_type\":\"driver\",\"status\":\"active\"}")
check "driver forced pending" '"status":"pending"' "$D"

check "login ok" '"status":true' "$(j -X POST $BASE/api/login -d "{\"email\":\"ada$S@x.com\",\"password\":\"secret123\",\"user_type\":\"rider\"}")"
check "login wrong password" '"status":false' "$(j -X POST $BASE/api/login -d "{\"email\":\"ada$S@x.com\",\"password\":\"nope\"}")"
check "login unknown email" 'do not match our records' "$(j -X POST $BASE/api/login -d '{"email":"nobody@x.com","password":"secret123"}')"
check "driver pending blocked on login_api" 'not active' "$(j -X POST $BASE/api/login -d "{\"email\":\"dan$S@x.com\",\"password\":\"secret123\",\"login_api\":true}")"

if [[ -n "${LEGACY_EMAIL:-}" ]]; then
  s=$(date +%s%N)
  check "legacy \$2y\$12 hash login" '"status":true' "$(j -X POST $BASE/api/login -d "{\"email\":\"$LEGACY_EMAIL\",\"password\":\"legacy-pass-1\"}")"
  echo "      legacy login took $(( ($(date +%s%N)-s)/1000000 )) ms"
fi

check "user-detail no token" '"unauthenticated"' "$(j $BASE/api/user-detail)"
check "user-detail bad token" '"unauthenticated"' "$(j -H 'Authorization: Bearer 1|abcdefghijklmnopqrstuvwxyzabcdefghijklmn' $BASE/api/user-detail)"
UD=$(j -H "Authorization: Bearer $TOKEN" $BASE/api/user-detail)
check "user-detail self" "ada$S@x.com" "$UD"
check "user-detail no password leak" 'ok' "$([[ "$UD" != *password* && "$UD" != *otp_hash* ]] && echo ok)"
check "user-detail unknown id" 'User not found' "$(j -H "Authorization: Bearer $TOKEN" "$BASE/api/user-detail?id=999999999")"
DID=$(echo "$D" | sed -n 's/.*"id":\([0-9]*\),"first_name":"Dan".*/\1/p')
OTHER=$(j -H "Authorization: Bearer $TOKEN" "$BASE/api/user-detail?id=$DID")
check "other user sees public view only" 'ok' "$([[ "$OTHER" == *username* && "$OTHER" != *dan$S@x.com* ]] && echo ok)"

check "logout" 'Logout successfully' "$(j -H "Authorization: Bearer $TOKEN" $BASE/api/logout)"
check "token revoked after logout" '401' "$(code -H "Authorization: Bearer $TOKEN" $BASE/api/user-detail)"
[[ $fail == 0 ]] && echo "ALL PASSED" || { echo "SOME FAILED"; exit 1; }
