import type { Client } from "pg";

// Passwords are hashed and checked INSIDE Postgres (pgcrypto, bcrypt), not in the Worker. bcrypt is
// deliberately slow, and Cloudflare's free plan allows only 10 ms of Worker CPU per request, so doing it in
// JavaScript would need the paid plan. The database does the slow part; the Worker only passes the values on.
// Hashes are standard bcrypt, so the legacy Laravel "$2y$" hashes imported later work unchanged.

const NEW_PASSWORD_COST = 10;

// A valid hash of a random value. When no account matches the email we still run one comparison against it,
// so "unknown email" and "wrong password" take the same time and cannot be told apart by timing.
const DUMMY_HASH = "$2a$12$O1p.W/95GcvNFiUJ08dK2O.cjhYO4namIoDgPszLENdeTOjQWFvx.";

/** PHP writes "$2y$" (and some tools "$2b$"); it is the same algorithm as "$2a$", which pgcrypto reads. */
const normalize = (hash: string) => (/^\$2[yb]\$/.test(hash) ? "$2a$" + hash.slice(4) : hash);

export async function verifyPassword(db: Client, plain: string, hash: string | null): Promise<boolean> {
  const stored = hash ? normalize(hash) : DUMMY_HASH;
  try {
    const r = await db.query("select extensions.crypt($1, $2) = $2 as ok", [plain, stored]);
    return !!hash && r.rows[0].ok === true;
  } catch {
    return false; // malformed hash in the database
  }
}

export async function hashPassword(db: Client, plain: string): Promise<string> {
  const r = await db.query("select extensions.crypt($1, extensions.gen_salt('bf', $2::int)) as h", [plain, NEW_PASSWORD_COST]);
  return r.rows[0].h as string;
}
