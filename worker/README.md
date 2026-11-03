# Drop Worker (Cloudflare)

The new Drop backend: a Cloudflare Worker (Hono, TypeScript) that serves the REST
API under `/api/*` and the admin dashboard under `/admin/`.

See `../docs/cloudflare-backend-plan.md` for the full architecture and rollout.

## Layout

| Path | Purpose |
|---|---|
| `src/index.ts` | Worker entry point and API routes |
| `public/admin/` | Admin dashboard (static files, served at `/admin/`) |
| `wrangler.jsonc` | Worker config. `name` must equal the Worker name in the Cloudflare dashboard (`drop`) |

## Cloudflare dashboard build settings (Workers Builds)

| Setting | Value |
|---|---|
| Git repository | `OffcialKryptonia/Drop` |
| Production branch | `main` |
| Root directory | `/worker` |
| Build command | *(none)* |
| Deploy command | `npx wrangler deploy` |

Secrets and keys are added in the dashboard under the Worker's
**Settings → Variables and secrets**. Never commit them. For local development put
them in `worker/.dev.vars` (git-ignored).

## Local development

```bash
cd worker
npm install
npm run dev        # http://127.0.0.1:8787
npm run typecheck
```

Endpoints today: `GET /api/health`, `GET /admin/`.
