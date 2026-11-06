import type { Client } from "pg";
import { decryptValue } from "./crypto";

export type GatewayConfig = { enabled: boolean; isTest: boolean; creds: Record<string, string> };

/** Reads one gateway's saved credentials for its CURRENT mode (test or live), decrypted. Server-side only. */
export async function loadGateway(db: Client, type: string, encryptionKey: string | undefined): Promise<GatewayConfig | null> {
  const g = (await db.query("select status, is_test from app.payment_gateways where type = $1", [type])).rows[0];
  if (!g) return null;
  const rows = (await db.query("select field, value_enc from app.gateway_credentials where gateway_type = $1 and mode = $2", [type, g.is_test ? "test" : "live"])).rows;
  const creds: Record<string, string> = {};
  for (const r of rows) creds[r.field] = await decryptValue(r.value_enc, encryptionKey);
  return { enabled: g.status, isTest: g.is_test, creds };
}

/** Webhook secrets for both modes, so a sandbox or live event verifies whichever mode is switched on. */
export async function loadSecrets(db: Client, type: string, field: string, encryptionKey: string | undefined): Promise<string[]> {
  const rows = (await db.query("select value_enc from app.gateway_credentials where gateway_type = $1 and field = $2", [type, field])).rows;
  const out: string[] = [];
  for (const r of rows) out.push(await decryptValue(r.value_enc, encryptionKey));
  return out;
}
