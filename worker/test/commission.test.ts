// Commission wallet logic against a LOCAL/test database. Run: DATABASE_URL=... npx tsx test/commission.test.ts
import pg from "pg";
import { computeCommission, driverEligibility, settleDriverForRide } from "../src/lib/commission";
import { InsufficientFunds, postToWallet } from "../src/lib/wallet";

const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
await db.connect();
let fails = 0;
const ok = (n: string, c: boolean, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const s = Math.random().toString(36).slice(2, 8);

// --- pure maths ---
ok("15% of 2000 = 300", computeCommission({ commission_type: "percentage", admin_commission: 15 }, 2000) === "300.00");
ok("rounds to kobo", computeCommission({ commission_type: "percentage", admin_commission: 12.5 }, 333.33) === "41.67");
ok("fixed 200", computeCommission({ commission_type: "fixed", admin_commission: 200 }, 2000) === "200.00");
ok("fixed never above fare", computeCommission({ commission_type: "fixed", admin_commission: 500 }, 300) === "300.00");
ok("zero rate = zero", computeCommission({ commission_type: "percentage", admin_commission: 0 }, 2000) === "0.00");
ok("zero fare = zero", computeCommission({ commission_type: "percentage", admin_commission: 15 }, 0) === "0.00");

// --- wallet effects ---
const mk = async (type: string) => (await db.query(
  "insert into app.users (first_name,last_name,display_name,email,username,password_hash,login_type,user_type,status) values ('T','T','T',$1,$2,'x','app',$3,'active') returning id",
  [`${type}${s}@x.com`, `${type}${s}`, type])).rows[0].id as number;
const driver = await mk("driver"), rider = await mk("rider");
const region = (await db.query("insert into app.regions (name, distance_unit, timezone, status) values ($1,'km','Africa/Lagos',true) returning id", ["R" + s])).rows[0].id;
const svc = (await db.query("insert into app.services (name, region_id, capacity, base_fare, commission_type, admin_commission, payment_method, status) values ('T',$1,4,0,'percentage',15,'cash_wallet',true) returning id", [region])).rows[0].id;
const bal = async (u: number) => Number((await db.query("select coalesce((select balance from app.wallets where user_id=$1),0) b", [u])).rows[0].b);
const tx = async (fn: () => Promise<unknown>) => { await db.query("begin"); try { const r = await fn(); await db.query("commit"); return r; } catch (e) { await db.query("rollback"); throw e; } };

try {
  await tx(() => postToWallet(db, { userId: driver, direction: "credit", amount: "100.00", kind: "topup", idempotencyKey: `t:${s}:1` }));
  ok("driver topped up to 100", (await bal(driver)) === 100);

  const r1: any = await tx(() => settleDriverForRide(db, { id: 9100 + 1, driverId: driver, serviceId: svc, fare: 2000, paymentType: "cash" }));
  ok("cash trip takes 300 commission (balance can go negative)", r1.posted && (await bal(driver)) === -200, JSON.stringify(r1));
  const r2: any = await tx(() => settleDriverForRide(db, { id: 9100 + 1, driverId: driver, serviceId: svc, fare: 2000, paymentType: "cash" }));
  ok("same ride settled twice changes nothing", !r2.posted && (await bal(driver)) === -200);

  ok("below minimum 0: not eligible", (await driverEligibility(db, driver, svc)).eligible === false);
  await tx(() => postToWallet(db, { userId: driver, direction: "credit", amount: "500.00", kind: "topup", idempotencyKey: `t:${s}:2` }));
  ok("after topping up: eligible", (await driverEligibility(db, driver, svc)).eligible === true);
  await db.query("update app.services set min_wallet_balance = 1000 where id = $1", [svc]);
  ok("ride type minimum overrides global", (await driverEligibility(db, driver, svc)).eligible === false);

  const r3: any = await tx(() => settleDriverForRide(db, { id: 9100 + 2, driverId: driver, serviceId: svc, fare: 1000, paymentType: "wallet" }));
  ok("wallet trip credits fare minus commission (850)", r3.posted && (await bal(driver)) === 300 + 850, JSON.stringify(r3));

  // riders are protected
  let blocked = false;
  try { await tx(() => postToWallet(db, { userId: rider, direction: "debit", amount: "10.00", kind: "ride_payment", idempotencyKey: `t:${s}:3` })); } catch (e) { blocked = e instanceof InsufficientFunds; }
  ok("rider cannot spend money they do not have", blocked && (await bal(rider)) === 0);
  let refused = false;
  try { await tx(() => postToWallet(db, { userId: rider, direction: "debit", amount: "10.00", kind: "adjustment", allowNegative: true, idempotencyKey: `t:${s}:4` })); } catch { refused = true; }
  ok("negative balance refused for riders", refused && (await bal(rider)) === 0);
  let dbGuard = false;
  try { await db.query("insert into app.wallets (user_id, balance) values ($1, -5)", [rider]); } catch { dbGuard = true; }
  ok("database itself refuses a negative rider wallet", dbGuard);
} finally {
  await db.query("delete from app.wallet_ledger where user_id in ($1,$2)", [driver, rider]);
  await db.query("delete from app.wallets where user_id in ($1,$2)", [driver, rider]);
  await db.query("delete from app.services where id=$1", [svc]);
  await db.query("delete from app.regions where id=$1", [region]);
  await db.query("delete from app.users where id in ($1,$2)", [driver, rider]);
  await db.end();
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED"); process.exit(fails ? 1 : 0);
