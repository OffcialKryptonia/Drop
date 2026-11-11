import { Hono } from "hono";
import type { AppEnv, Bindings } from "./env";
import { connectDb } from "./db";
import { authRoutes } from "./routes/auth";
import { legacyRoutes } from "./routes/legacy";
import { bankRoutes } from "./routes/banks";
import { adminBankRoutes } from "./routes/admin-banks";
import { userRoutes } from "./routes/users";
import { adminRoutes } from "./routes/admin";
import { adminCatalogRoutes } from "./routes/admin-catalog";
import { walletRoutes } from "./routes/wallet";
import { adminWalletRoutes } from "./routes/admin-wallets";
import { mapRoutes } from "./routes/maps";
import { modeRoutes } from "./routes/mode";
import { driverOnlineRoutes } from "./routes/driver-online";
import { rideRoutes } from "./routes/rides";
import { driverRideRoutes } from "./routes/driver-rides";
import { sweepRides } from "./lib/ride-sweep";
import { driverApplicationRoutes } from "./routes/driver-application";
import { adminDriverApplicationRoutes } from "./routes/admin-driver-applications";

const app = new Hono<AppEnv>();

// Liveness check. Used by uptime monitors and the /admin page.
// (Workers freeze the clock outside a request, so time is read per request.)
app.get("/api/health", (c) =>
  c.json({
    ok: true,
    service: "drop-api",
    version: "0.1.0",
    time: new Date().toISOString(),
  }),
);

// Deep check: opens a real database connection through Hyperdrive.
app.get("/api/health/db", async (c) => {
  try {
    const db = await connectDb(c.env.HYPERDRIVE.connectionString);
    try {
      const r = await db.query("select 1 as ok, (select count(*)::int from app.regions) as regions");
      return c.json({ ok: r.rows[0].ok === 1, regions: r.rows[0].regions });
    } finally {
      c.executionCtx.waitUntil(db.end().catch(() => undefined));
    }
  } catch (err) {
    console.error("db health failed", err);
    return c.json({ ok: false, message: "Database unreachable" }, 503);
  }
});

app.route("/api", authRoutes);
app.route("/api", userRoutes);
app.route("/api", adminRoutes);
app.route("/api", adminCatalogRoutes);
app.route("/api", walletRoutes);
app.route("/api", adminWalletRoutes);
app.route("/api", mapRoutes);
app.route("/api", modeRoutes);
app.route("/api", driverOnlineRoutes);
app.route("/api", rideRoutes);
app.route("/api", driverRideRoutes);
app.route("/api", driverApplicationRoutes);
app.route("/api", adminDriverApplicationRoutes);
app.route("/api", legacyRoutes);
app.route("/api", bankRoutes);
app.route("/api", adminBankRoutes);

// Any other /api route that does not exist yet returns JSON, never HTML.
app.all("/api/*", (c) =>
  c.json({ message: "Not found", status: 404 }, 404),
);

// Visiting the bare domain sends people to the admin dashboard.

// Everything else (unknown paths) is a plain 404.
app.notFound((c) => c.text("Not found", 404));

app.onError((err, c) => {
  console.error("Unhandled error", err);
  return c.json({ message: "Internal server error", status: 500 }, 500);
});

export default {
  fetch: app.fetch,
  /** Every minute: expire unaccepted ride requests and take silent drivers offline. */
  async scheduled(_event: ScheduledController, env: Bindings, ctx: ExecutionContext) {
    ctx.waitUntil(
      (async () => {
        const db = await connectDb(env.HYPERDRIVE.connectionString);
        try {
          console.log("ride sweep", JSON.stringify(await sweepRides(db)));
        } finally {
          await db.end();
        }
      })(),
    );
  },
} satisfies ExportedHandler<Bindings>;
