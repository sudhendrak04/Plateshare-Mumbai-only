# 06 — Tech Stack Recommendation

**Decision context:** 2-person team, zero dev experience, all code AI-written, Mumbai launch, must scale later in stages. Optimize for: (a) AI writes it extremely well, (b) minimum infrastructure to operate, (c) no dead-ends.

## 1. Final stack table

| Layer | Choice | Why (for THIS team) |
|---|---|---|
| **Mobile** | **Flutter 3.x** (single codebase, Android-first) | AI generates Dart/Flutter with very high reliability; huge doc corpus; one codebase for future iOS; camera/QR/map plugins mature (`mobile_scanner`, `google_maps_flutter`) |
| **Backend platform** | **Supabase** (Postgres 15 + PostGIS, Auth, Edge Functions, Realtime, Storage, pg_cron) | Removes ~70% of backend ops a 2-person team would drown in: no API server to deploy, no Redis to run, no cron workers, no auth server. Postgres functions handle transactional logic (AI writes SQL excellently). Scales to thousands of DAU before any migration |
| **Database** | **PostgreSQL + PostGIS** (via Supabase) | Geo-radius queries (`ST_DWithin`), ACID inventory, one database to learn. No separate cache in v1 |
| **Maps / geo** | **Google Maps SDK + Places** (Flutter plugin); MapmyIndia as cost fallback later | Best Indian POI coverage; swap path documented |
| **Payments** | **Razorpay** (Standard PG + Route for vendor payouts; UPI-first) | India standard; 0% platform-fee offer for first 90 days/₹5L; Route handles commission splitting; best-documented API for AI-generated integration |
| **Push notifications** | **FCM** + `flutter_local_notifications` | Free, standard |
| **SMS / OTP** | **MSG91** (via Supabase Auth phone provider) | Cheap (~₹0.15–0.20/SMS), DLT-registered templates required |
| **WhatsApp (vendor comms)** | **WhatsApp Business API** (Meta Cloud API, free service conversations) | v1.1 — vendors live on WhatsApp; highest open rates |
| **Web console (Admin/NGO)** | **Next.js + Tailwind + shadcn/ui on Vercel** | AI generates this stack flawlessly; free hosting |
| **File storage** | **Supabase Storage** (v1) → Cloudflare R2 if egress costs matter | Zero-config start |
| **Hosting/region** | Supabase **Mumbai region (ap-south-1)**; Vercel global edge | Indian latency for DB + API |
| **Version control / CI** | **GitHub** + Actions (analyze + test + APK artifact) | Free; AI can write the 30-line workflow |
| **Analytics** | **PostHog** (cloud free tier) + Metabase on a read replica later | Funnel + retention from day 1 |
| **Error tracking** | **Sentry** (Flutter + Next.js, free tier) | Non-negotiable when devs can't debug alone |

## 2. Explicitly rejected alternatives (and why)

| Rejected | Reason |
|---|---|
| React Native / Expo | Fine stack, but Flutter's widget model produces more deterministic AI output; fewer version-churn breakages |
| Custom NestJS/FastAPI server | Adds deploy, containers, Redis, cron worker ops — too much surface for 2 non-devs. (Documented as the scaling path in `04-architecture.md` §9) |
| MongoDB | No PostGIS equivalent; transactions weaker; relational domain (orders/payments) fits SQL |
| Firebase-only (no SQL) | Firestore geo + transactions + reporting for GST = pain; Postgres is the right call |
| Native Android (Kotlin) | 2× the work for v1; revisit only if deep hardware needs appear |
| Cashfree / PhonePe PG | Viable Razorpay alternatives; Razorpay Route + docs edge wins for now |

## 3. Monthly cost projection (Mumbai v1, worst case)

| Item | Cost/month |
|---|---|
| Supabase Pro (2 projects: staging+prod) | ~$50 (₹4,200) |
| Vercel (hobby) | ₹0 |
| Razorpay | 2%+GST per txn (0% first 90 days) |
| MSG91 (OTP + alerts, ~10k SMS) | ~₹2,000 |
| FCM | ₹0 |
| Google Maps (free tier covers ≤ ~5k map loads/mo at launch) | ₹0 → budget ₹5–10k later |
| Sentry + PostHog free tiers | ₹0 |
| Play Store developer account | $25 once |
| **Total burn (tech)** | **≈ ₹6,500–15,000/month** |

This excludes founder time and any field ops — the real costs are human, not infra.

## 4. What "scalable in stages" concretely means here

| Stage | Trigger | Action |
|---|---|---|
| 1 (now) | Mumbai launch | Supabase monolith, 2 Flutter apps, 1 web console |
| 2 | > 500 orders/day or feed p95 > 300 ms | Add Redis cache for feed; move webhook handling to dedicated service |
| 3 | Multi-city | `city_id` column (already in schema from day 1), cluster-based ops |
| 4 | > 10k DAU / team grows | Extract NestJS/FastAPI core behind same Postgres; read replica + Metabase |
| 5 | iOS + WhatsApp bot listing | Flutter iOS target; WhatsApp Cloud API listing bot |
