# Ordo

> A time-first group coordination app. Organize your day, week, and month with yourself **and** your groups — shared timelines, privacy-controlled availability, tasks, reminders, realtime chat, and an empty-slot finder — in one place.

Ordo is **not** a chat clone. It's a shared-life coordination system built around four pillars:

1. **Timeline** — daily, weekly, monthly, for yourself and each group.
2. **Groups** — structured spaces (timeline, tasks, chat, members), not just chats.
3. **Availability** — find when everyone is free, ranked.
4. **Privacy** — share *busy* time without exposing personal details.

---

## Status — what's implemented

This repo contains a **working, end-to-end MVP** covering all four pillars.

### Backend — `apps/api` (NestJS modular monolith)
- **Auth**: email/password register & login, JWT access (15m) + rotating refresh (60d) tokens stored hashed, device sessions, secure password hashing (bcryptjs), transparent refresh-on-401.
- **Groups**: create from templates (Family / University / Gym / Friends / Work / Project / Travel / Custom), roles (Owner/Admin/Moderator/Member/Guest), RBAC permissions, invite codes, join, pin, leave with ownership transfer.
- **Timeline**: self + group timelines, day/week/month ranges, RFC-5545-style recurrence expansion, conflict-relevant flexibility, **privacy-controlled sync** of a self block to multiple groups at different visibility levels.
- **Privacy engine** (server-side redaction): `PRIVATE | BUSY_ONLY | TITLE_ONLY | FULL`. The server decides what each viewer may see — clients never receive private details for blocks they don't own. (e.g. your *"Doctor appointment"* shows as **Busy** to your Family group.)
- **Availability**: empty-slot finder algorithm — gathers each member's busy intervals across self + all groups, expands recurrence, merges, then 15-min grid search with scoring (availability ratio, preferred time window, comfort hours) → ranked slots.
- **Tasks**: assignees, status, priority, due dates, comments, role-aware permissions.
- **To-dos**: fast self/group lists with tabs.
- **Chat**: realtime group chat over Socket.IO — messages, replies, reactions, @mentions (with notifications), edit/delete, typing, read tracking.
- **Notifications + Reminders**: in-app notifications + a reminder scheduler that fires for upcoming timeline blocks.
- PostgreSQL via Prisma, UUIDs everywhere, object-level authorization on every resource, global validation pipe, consistent error envelope.

### Mobile — `apps/mobile` (Flutter)
- Material 3 design system encoding the plan's shadcn/Tailwind-inspired tokens (spacing, radius, light/dark, and a per-user/per-group **accent** that recolors the whole app).
- Secure token storage (flutter_secure_storage) + auto refresh.
- Riverpod state, go_router with a stateful bottom-nav shell + quick-action command menu.
- Today dashboard, self timeline (Day/Week/Month), groups + create-from-template flow, group home with internal tabs (home/timeline/tasks/members), privacy-aware group timeline, add-block sheet with the sync/privacy editor, empty-slot finder, tasks + to-dos, realtime chat, inbox, profile & settings.

> **Note on stack:** the original plan called for Flutter (mobile-first). We built exactly that. The backend is identical to what a web client would consume, so a future web app is additive.

---

## Quick start

### Prerequisites
- Node 20+, pnpm
- PostgreSQL (running locally on :5432)
- Flutter 3.41+ / Dart 3.11+

### 1. Database
The app uses your local Postgres. Create the DB once:
```bash
PGPASSWORD=Ali_2792005 psql -h localhost -U postgres -d postgres -c "CREATE DATABASE ordo;"
PGPASSWORD=Ali_2792005 psql -h localhost -U postgres -d ordo -c "CREATE EXTENSION IF NOT EXISTS citext; CREATE EXTENSION IF NOT EXISTS pgcrypto;"
```
(DBeaver connects with user `postgres`, password `Ali_2792005`, database `ordo`.)

### 2. Backend
```bash
pnpm install
pnpm db:migrate     # prisma migrate dev
pnpm db:seed        # demo data
pnpm dev:api        # http://localhost:4000/api
```
Seed creates demo users; log in with **`ali@ordo.app` / `password123`**.

### 3. Mobile
```bash
pnpm mobile:get     # flutter pub get
pnpm mobile:run     # flutter run  (pick a device)
```
- **Android emulator**: the app auto-targets `http://10.0.2.2:4000`.
- **iOS simulator / desktop / flutter web**: targets `http://localhost:4000`.
- **Physical device**: pass your host LAN IP:
  ```bash
  cd apps/mobile && flutter run --dart-define=ORDO_API_URL=http://192.168.x.x:4000
  ```

> Building an **APK** requires the Android SDK; an **IPA** requires macOS + Xcode. The same Dart code compiles for all of Android, iOS, web, and desktop.

---

## Architecture

```
ordo/
  apps/
    api/      NestJS backend (Prisma + PostgreSQL)
    mobile/   Flutter app (Riverpod + go_router)
  CLAUDE.md
```

Backend layering per module: `controller → service → prisma`. Realtime gateway reuses services. See the root `CLAUDE.md` and `apps/mobile/lib/` for the feature layout.

### Non-negotiable rules (see CLAUDE.md)
1. Modular monolith first.
2. Never bypass authorization — every endpoint enforces object-level auth.
3. Timeline privacy is core and enforced server-side.
4. UTC internally, display in the user's timezone.

---

## What's intentionally out of this build (MVP scope)
Google Calendar sync, AI assistant, location sharing, file/media storage, polls, admin dashboard, and the Next.js admin-web — all designed for in the plan, deferred to v1.5/v2. The architecture leaves clean seams for them.
