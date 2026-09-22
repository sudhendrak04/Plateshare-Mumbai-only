# Plate Share — surplus-food marketplace (Mumbai)

Mystery-box marketplace: Mumbai restaurants/cafés/bakeries sell unsold surplus food at 30–50% off for self-pickup near closing. Unsold boxes can be donated to verified NGOs. Pickup only — no delivery.

**Status:** Stage 1 (scaffolding) — see `stages/README.md`.

## Folder map

```
doc/                  Product & architecture specifications (source of truth)
stages/               Build journal — one .md per stage
apps/buyer/           Flutter app for buyers (students, professionals)
apps/vendor/          Flutter app for restaurants/cafés/bakeries
console/              Next.js admin + NGO web console
supabase/             Database migrations, Edge Functions, seed data
.github/workflows/    CI (analyze/test/build)
```

## Running locally

| App | Directory | Command |
|---|---|---|
| Buyer app | `apps/buyer` | `flutter run` |
| Vendor app | `apps/vendor/` | `flutter run` |
| Console | `console/` | `npm run dev` |
| Supabase stack | root | `supabase start` (requires Docker) |

## CI

Every push/PR: Flutter analyze+test (both apps) and console lint/typecheck/build. APK builds are manual (`workflow_dispatch`).

Secrets live in Supabase dashboard / GitHub encrypted secrets — never in this repo.
