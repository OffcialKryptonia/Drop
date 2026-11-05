/** AES-256-GCM for gateway credentials, keyed from the Worker secret SETTINGS_ENCRYPTION_KEY. */

const b64 = {
  enc: (buf: ArrayBuffer | Uint8Array) => btoa(String.fromCharCode(...new Uint8Array(buf))),
  dec: (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0)),
};

/**
 * The secret is any long random phrase (at least 32 characters) chosen by the owner; the AES key is
 * SHA-256 of it. Changing the phrase makes previously saved credentials unreadable (re-enter them).
 */
async function importKey(secret: string | undefined): Promise<CryptoKey> {
  if (!secret || secret.length < 32) throw new Error("SETTINGS_ENCRYPTION_KEY must be set (32+ characters)");
  const raw = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encryptValue(plain: string, secret: string | undefined): Promise<string> {
  const key = await importKey(secret);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plain));
  return `${b64.enc(iv)}:${b64.enc(ct)}`;
}

export async function decryptValue(stored: string, secret: string | undefined): Promise<string> {
  const key = await importKey(secret);
  const [iv, ct] = stored.split(":");
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: b64.dec(iv) }, key, b64.dec(ct));
  return new TextDecoder().decode(pt);
}
