import type { Client } from "pg";

/**
 * Same scheme as Laravel Sanctum, so tokens issued by the old backend keep working after
 * the cutover: the client holds "<id>|<40 random chars>", the database holds only
 * sha256(<40 random chars>).
 */

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** 40 random letters/digits, unbiased (bytes >= 248 are discarded so every char is equally likely). */
function randomSecret(length = 40): string {
  let out = "";
  while (out.length < length) {
    for (const byte of crypto.getRandomValues(new Uint8Array(length))) {
      if (byte < 248 && out.length < length) out += ALPHABET[byte % ALPHABET.length];
    }
  }
  return out;
}

export async function createToken(db: Client, userId: number, name = "auth_token"): Promise<string> {
  const secret = randomSecret();
  const result = await db.query(
    "insert into app.api_tokens (user_id, name, token_hash) values ($1, $2, $3) returning id",
    [userId, name, await sha256Hex(secret)],
  );
  return `${result.rows[0].id}|${secret}`;
}

/** Splits "<id>|<secret>"; returns null when the shape is wrong. */
export function parseBearer(header: string | undefined): { id: number; secret: string } | null {
  const match = /^Bearer\s+(\d{1,15})\|([A-Za-z0-9]{40})$/.exec(header ?? "");
  return match ? { id: Number(match[1]), secret: match[2] } : null;
}
