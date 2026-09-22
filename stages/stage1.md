# Stage 1 — Repo Scaffolding & Tooling

> **Status:** 🟨 In progress
> **Started:** Sep 2026 · **Completed:** —
> **Implements:** `doc/12-ai-dev-guide.md` Phase 0

---

## 1. Objective

Create the empty-but-runnable skeleton of the whole system so that every later stage has a home: version control, the two Flutter apps, the Next.js console, the Supabase project structure, CI, and lint/test tooling. Nothing business-logic-related happens here — only structure that compiles and passes CI.

## 2. Prerequisites

- [x] Planning docs complete (`doc/00`–`doc/12`, `backend/backend_plan.md`)
- [ ] **Founder:** GitHub account + empty repo created (or local-only git for now)
- [ ] **Founder:** Supabase account + 1 project created (free tier, region: Mumbai ap-south-1 if available)
- [ ] **Founder:** Flutter SDK installed locally (AI provides install instructions)
- [ ] **Founder:** Node.js LTS installed locally

## 3. Task checklist

### 3.1 Repository & hygiene
- [x] `stages/` folder with stage files (this folder)
- [x] Root `AGENTS.md` (exists)
- [ ] `README.md` at root — project one-liner, folder map, how to run each app
- [ ] `git init` + `.gitignore` (Flutter, Node, Supabase, IDE, OS files)
- [ ] Initial commit

### 3.2 Flutter apps (buyer + vendor)
- [ ] Scaffold `apps/buyer` (Flutter, package name `com.plateshare.buyer`)
- [ ] Scaffold `apps/vendor` (Flutter, package name `com.plateshare.vendor`)
- [ ] Shared lint rules (`analysis_options.yaml` with `flutter_lints`)
- [ ] Both apps: `flutter analyze` clean, `flutter test` passes (default widget test ok to start)
- [ ] Minimal app shell: themed splash → placeholder home with app name + version
- [ ] Add dependencies (declared now, used later): `supabase_flutter`, `flutter_riverpod`, `mobile_scanner`, `google_maps_flutter`, `flutter_local_notifications` (buyer), `intl`
- [ ] `lib/core/` folders: `theme/`, `router/`, `config/` (env via `--dart-define`)

### 3.3 Web console
- [ ] Scaffold `console/` (Next.js + TypeScript + Tailwind)
- [ ] ESLint + Prettier config; `npm run lint`, `npx tsc --noEmit`, `npm run build` all clean
- [ ] Minimal page shell: login placeholder + empty dashboard route
- [ ] Add deps (used later): `@supabase/supabase-js`, `shadcn/ui` primitives

### 3.4 Supabase project structure
- [ ] `supabase/` initialized via CLI (`config.toml` committed)
- [ ] `supabase/migrations/` empty folder (Stage 2 fills it)
- [ ] `supabase/functions/` empty folder (Stage 7 fills it)
- [ ] `supabase/seed.sql` placeholder

### 3.5 CI
- [ ] `.github/workflows/ci.yml`:
  - job 1: Flutter matrix (`flutter analyze` + `flutter test` for both apps)
  - job 2: console (`npm ci`, lint, typecheck, build)
  - job 3 (manual dispatch only): build release APK artifact
- [ ] CI badge in root `README.md`

## 4. Deliverables

```
PlateShare/
├── AGENTS.md, README.md, .gitignore
├── apps/buyer/        (Flutter, analyze+test green)
├── apps/vendor/       (Flutter, analyze+test green)
├── console/           (Next.js, lint+typecheck+build green)
├── supabase/          (CLI-initialized, empty migrations/functions)
├── .github/workflows/ci.yml
├── stages/            (this journal)
├── doc/, backend/     (existing specs)
```

## 5. Acceptance criteria (founder-verifiable)

1. `flutter analyze` and `flutter test` exit clean in **both** `apps/buyer` and `apps/vendor` (AI runs and shows output).
2. In `console/`: `npm run lint`, `npx tsc --noEmit`, `npm run build` all exit clean.
3. Both Flutter apps launch on an emulator/device and show a themed placeholder screen.
4. CI passes on the first push to GitHub (or, if working locally-only, all local commands green).
5. No secrets anywhere in the repo (AI confirms; keys go in `--dart-define`/env only).

## 6. Founder manual steps

| # | Step | Notes |
|---|---|---|
| 1 | Install Flutter SDK + Android Studio (emulator) | AI gives step-by-step for Windows |
| 2 | Install Node.js LTS | one installer |
| 3 | Create Supabase project (free tier) | choose Mumbai region; note URL + anon key → give to AI to store in local env files (never committed) |
| 4 | Create GitHub repo + push (optional at this stage) | can stay local until Stage 2 |

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| 1 | Two separate Flutter apps (not one app with role switch) | single app with role-based UI vs two apps | Founder (per doc plan) | Sep 2026 |
| 2 | Riverpod for state management | bloc / provider / riverpod | Founder (doc plan: AI-writability) | Sep 2026 |
| 3 | Env config via `--dart-define`, no flavors in Stage 1 | flavors vs dart-define | Founder | Sep 2026 |

## 8. Status & dates

- Planning: done (this file).
- Execution: **in progress** — see checklist ticks above.
- Blockers: none (founder manual steps 1–3 pending).
