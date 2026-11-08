# Drop

**Mobility, made simpler.**

Drop is a ride-hailing and mobility software project organized as a monorepo. It brings together a Laravel backend and administration interface with separate Flutter applications for riders and drivers.

## Repository structure

| Path | Component | Technology |
|---|---|---|
| `backend-admin/` | Backend services and administration dashboard | Laravel / PHP |
| `apps/drop/` | Unified DROP app: rider by default, switchable driver mode (`lib/driver/`) | Flutter |
| `apps/drop-driver/` | Legacy standalone driver app (archived at slice 8, being replaced by driver mode) | Flutter |

Some imported source directories retain legacy project names. These are implementation-history details and do not change the current product identity: **Drop**.

## Development approach

Work on one component at a time:

1. Review the component's existing documentation and configuration.
2. Install the required toolchain for that component.
3. Configure local environment variables and service credentials.
4. Run the component's available checks and builds.
5. Document any setup changes alongside the code.

## Current project stage

This repository began as an initial source import. Rebranding, configuration cleanup, security review and build verification are tracked as ongoing engineering work. Do not assume every component is production-ready solely because its source is present.

## Security

- Do not commit credentials, private keys, signing files, production database dumps or populated environment files.
- Keep secrets out of Flutter client bundles and public repositories.
- Review authentication, authorization, payment integrations, API permissions and data handling before release.
- Use test credentials and non-production environments for development.

## Contributions

Prefer small, reviewable changes. Include the affected component, validation performed and any required configuration updates in each pull request.

---

Part of the Kryptonia technology portfolio.
