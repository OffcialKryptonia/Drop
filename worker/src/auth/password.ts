import bcrypt from "bcryptjs";

// New passwords use bcrypt cost 10 (about 70 ms of compute). Imported legacy hashes are
// Laravel's cost 12 ("$2y$12$...", about 300 ms); they verify as they are.
const NEW_PASSWORD_COST = 10;

// A valid hash of a random value. When no account matches the email we still run one
// comparison against it, so "unknown email" and "wrong password" take the same time and
// cannot be told apart by timing.
const DUMMY_HASH = "$2b$12$O1p.W/95GcvNFiUJ08dK2O.cjhYO4namIoDgPszLENdeTOjQWFvx.";

/** PHP writes "$2y$"; it is the same algorithm as "$2b$", which bcryptjs always accepts. */
const normalize = (hash: string) => (hash.startsWith("$2y$") ? "$2b$" + hash.slice(4) : hash);

export async function verifyPassword(plain: string, hash: string | null): Promise<boolean> {
  if (!hash) {
    await bcrypt.compare(plain, DUMMY_HASH);
    return false;
  }
  try {
    return await bcrypt.compare(plain, normalize(hash));
  } catch {
    return false; // malformed hash in the database
  }
}

export function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, NEW_PASSWORD_COST);
}
