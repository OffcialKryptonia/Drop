import { Hono } from "hono";

// Bindings (Hyperdrive, R2, Queues, secrets) are added here as each is created.
type Bindings = {
  ASSETS: Fetcher;
};

const app = new Hono<{ Bindings: Bindings }>();

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

// Any other /api route that does not exist yet returns JSON, never HTML.
app.all("/api/*", (c) =>
  c.json({ message: "Not found", status: 404 }, 404),
);

// Visiting the bare domain sends people to the admin dashboard.
app.get("/", (c) => c.redirect("/admin/", 302));

// Everything else (unknown paths) is a plain 404.
app.notFound((c) => c.text("Not found", 404));

app.onError((err, c) => {
  console.error("Unhandled error", err);
  return c.json({ message: "Internal server error", status: 500 }, 500);
});

export default app;
