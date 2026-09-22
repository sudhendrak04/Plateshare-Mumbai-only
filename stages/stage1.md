# Stage 1 — Repo Scaffolding & Tooling

> **Status:** ✅ Complete (one deferred founder verification)
> **Started:** Sep 2026 · **Completed:** Sep 2026
> **Implements:** `doc/12-ai-dev-guide.md` Phase 0

---

## 1. Objective

Create the empty-but-runnable skeleton of the whole system so that every later stage has a home: version control, the two Flutter apps, the Next.js console, the Supabase project structure, CI, and lint/test tooling. Nothing business-logic-related happens here — only structure that compiles and passes CI.

## 2. Prerequisites

- [x] Planning docs complete (`doc/00`–`doc/12`, `backend/backend_plan.md`)
- [x] Toolchain installed by AI (Flutter 3.47.5, JDK 17, Android SDK 36, Supabase CLI 2.117.0; Git + Node 24 already present)
- [ ] **Founder:** Supabase account + 1 project created (free tier, region Mumbai ap-south-1 if available) — keys still needed for later stages
- [ ] **Founder:** optional GitHub repo + push (local-only git works for now)

## 3. Task checklist

### 3.1 Repository & hygiene
- [x] `stages/` folder with stage files (this folder)
- [x] Root `AGENTS.md` (exists)
- [x] `README.md` at root — project one-liner, folder map, how to run each app
- [x] `git init` + `.gitignore` + `.gitattributes` (line-ending hygiene)
- [x] Initial commit (`190821d`)

### 3.2 Flutter apps (buyer + vendor)
- [x] Scaffold `apps/buyer` (Flutter 3.47.5, `com.plateshare.buyer`)
- [x] Scaffold `apps/vendor` (Flutter 3.47.5, `com.plateshare.vendor`)
- [x] Lint rules (template `analysis_options.yaml` with `flutter_lints`; analyze → 0 issues)
- [x] Both apps: `flutter analyze` clean (exit 0), `flutter test` passes
- [x] Minimal app shell: themed placeholder home with app name + version (`--dart-define` APP_VERSION)
- [x] Dependencies added: `supabase_flutter`, `flutter_riverpod`, `mobile_scanner`, `google_maps_flutter`, `flutter_local_notifications` (buyer), `intl`
- [x] `lib/core/` folders: `theme/app_theme.dart`, `config/env.dart` (env via `--dart-define`); `router/` deferred to app stages
- [x] Debug APK builds for **both** apps (proves Android toolchain: Gradle + JDK + SDK 36)

### 3.3 Web console
- [x] Scaffold `console/` (Next.js 15 + TypeScript + Tailwind, App Router)
- [x] ESLint (template) + Prettier added; `npm run lint`, `npx tsc --noEmit`, `npm run build` all exit 0
- [x] Minimal page shell (create-next-app default page; login/dashboard arrive in Stage 4)
- [x] Deps: `@supabase/supabase-js` added; `shadcn/ui` init deferred → Stage 4 (needs Tailwind wiring decisions)

### 3.4 Supabase project structure
- [x] `supabase/` initialized via CLI 2.117.0 (`config.toml` committed)
- [x] `supabase/migrations/` empty folder
- [x] `supabase/functions/` empty folder
- [x] `supabase/seed.sql` placeholder

### 3.5 CI
- [x] `.github/workflows/ci.yml`: Flutter analyze+test matrix (buyer/vendor) · console lint/typecheck/build · manual-dispatch APK job
- [ ] CI badge in root README — deferred until GitHub remote exists

## 4. Deliverables

```
PlateShare/
├── AGENTS.md, README.md, .gitignore, .gitattributes
├── apps/buyer/        (analyze 0 issues, test pass, debug APK built)
├── apps/vendor/       (analyze 0 issues, test pass, debug APK built)
├── console/           (lint/tsc/build all exit 0, prettier configured)
├── supabase/          (CLI 2.117.0 init; config.toml, empty migrations/functions, seed placeholder)
├── .github/workflows/ci.yml
├── stages/            (this journal)
├── doc/, backend/     (specs)
```

## 5. Acceptance criteria

1. ✅ `flutter analyze` + `flutter test` clean in both apps (0 issues; all tests passed).
2. ✅ Console: lint, typecheck, build all exit 0.
3. ⏸️ **Deferred:** emulator/device launch — no Android emulator installed by design (device verification is cheaper); debug APKs were built for both apps as the compile-level proof. Founder: `flutter install` on a phone, or set up an emulator later — the placeholder shell renders in `flutter test` as smoke proof.
4. ✅/⏸️ CI defined and committed; will verify on first push (local runs all green).
5. ✅ No secrets in repo (env read via `--dart-define` only; `.env*` gitignored).

## 6. Founder manual steps (remaining)

| # | Step | Notes |
|---|---|---|
| 1 | Create Supabase project (free tier) | Mumbai region; hand AI the URL + anon key (stored locally only) |
| 2 | Optional: create GitHub repo + push | enables hosted CI + backup |
| 3 | Optional: install APK on Android phone | `apps/*/build/app/outputs/flutter-apk/app-debug.apk` |

## 7. Decision log

| # | Decision | Options considered | Approved by | Date |
|---|---|---|---|---|
| 1 | Two separate Flutter apps (not one app with role switch) | single app with role-based UI vs two apps | Founder (per doc plan) | Sep 2026 |
| 2 | Riverpod for state management | bloc / provider / riverpod | Founder (doc plan: AI-writability) | Sep 2026 |
| 3 | Env config via `--dart-define`, no flavors in Stage 1 | flavors vs dart-define | Founder | Sep 2026 |
| 4 | Console folder kept as `console/` despite Node refusing the name | rename folder vs rename package | AI (trivial, forced) — scaffolded `admin-console`, renamed to `console/`, package name `plateshare-console` | Sep 2026 |
| 5 | `kotlin.incremental=false` in both apps | disable incremental Kotlin vs move project path (has spaces → Kotlin cache bug) | AI (build-config fix, reversible) | Sep 2026 |
| 6 | Core library desugaring enabled (buyer) | required by `flutter_local_notifications` | AI (build-config fix) | Sep 2026 |
| 7 | Emulator verification deferred to physical-device check | install emulator (2.5 GB+) vs founder device | AI (pragmatic; APK build proves compile) | Sep 2026 |
| 8 | shadcn/ui init deferred to Stage 4 | init now vs with actual console screens | AI (avoid unused scaffolding) | Sep 2026 |

## 8. Status & dates

- Planning: done.
- Execution: done Sep 2026. Commits: `190821d` (+ follow-up scaffold commit).
- Open item: founder device check (criterion 3) — non-blocking; Stage 2 can start.
- Blockers: none.
