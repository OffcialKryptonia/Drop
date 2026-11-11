import { Hono } from "hono";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";

export const adminBankRoutes = new Hono<AppEnv>();

adminBankRoutes.get("/admin/banks", ...guard("bank list"), async (c) =>
  c.json({ data: (await c.get("db").query("select id, code, name, kind, logo_url, active from app.banks order by name")).rows }));

const KINDS = ["bank", "mfb", "mmo"];

adminBankRoutes.post("/admin/banks", ...guard("bank edit"), async (c) => {
  const b = await readBody(c);
  const code = String(b.code ?? "").trim(), name = String(b.name ?? "").trim();
  const kind = KINDS.includes(String(b.kind)) ? String(b.kind) : "bank";
  if (!code || !name) return validationFailed(c, { name: ["Bank name and code are required."] });
  const logo = String(b.logo_url ?? "").trim() || null;
  const r = await c.get("db").query(
    "insert into app.banks (code, name, kind, logo_url) values ($1,$2,$3,$4) on conflict (code) do nothing returning id", [code, name, kind, logo]);
  if (!r.rowCount) return validationFailed(c, { code: ["A bank with this code already exists."] });
  return c.json({ message: "Bank added" });
});

adminBankRoutes.put("/admin/banks/:id", ...guard("bank edit"), async (c) => {
  const b = await readBody(c);
  const sets: string[] = [], args: unknown[] = [c.req.param("id")];
  const add = (col: string, v: unknown) => { args.push(v); sets.push(`${col} = $${args.length}`); };
  if (typeof b.name === "string" && b.name.trim()) add("name", b.name.trim());
  if (typeof b.code === "string" && b.code.trim()) add("code", b.code.trim());
  if (KINDS.includes(String(b.kind))) add("kind", String(b.kind));
  if (b.logo_url !== undefined) add("logo_url", String(b.logo_url ?? "").trim() || null);
  if (typeof b.active === "boolean") add("active", b.active);
  if (!sets.length) return c.json({ message: "Nothing to change" });
  try {
    await c.get("db").query(`update app.banks set ${sets.join(", ")}, updated_at = now() where id = $1`, args);
  } catch {
    return validationFailed(c, { code: ["Another bank already uses this code."] });
  }
  return c.json({ message: "Saved" });
});

/** Fills in logos and fixes names from a public Nigerian bank list. Matches by code. */
adminBankRoutes.post("/admin/banks/sync-logos", ...guard("bank edit"), async (c) => {
  let list: { code?: string; name?: string; logo?: string }[];
  try {
    const res = await fetch("https://nigerianbanks.xyz");
    list = (await res.json()) as typeof list;
    if (!Array.isArray(list)) throw new Error("bad list");
  } catch {
    return c.json({ message: "Could not reach the public bank list. Try again later." }, 502);
  }
  let updated = 0;
  for (const b of list) {
    if (!b.code || !b.logo) continue;
    const r = await c.get("db").query("update app.banks set logo_url = $2, updated_at = now() where code = $1 and (logo_url is null or logo_url <> $2)", [b.code, b.logo]);
    updated += r.rowCount ?? 0;
  }
  return c.json({ message: `Updated logos for ${updated} bank${updated === 1 ? "" : "s"}.` });
});
