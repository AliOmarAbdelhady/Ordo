# Ordo — Coding Agent Instructions

You are helping build **Ordo**, a time-first group coordination app.

## Product identity
Ordo is **not** a chat clone. It is a shared-life coordination system centered on daily, weekly, and monthly **timelines**, privacy-controlled **availability**, group **tasks**, **reminders**, and realtime **chat**.

The four pillars (everything else supports these):
1. **Timeline** — daily, weekly, monthly.
2. **Groups** — shared spaces, not just chats.
3. **Availability** — find empty slots quickly.
4. **Privacy** — share busy time without exposing personal details.

## Stack (as implemented in this repo)
- **Backend:** NestJS (modular monolith) + Prisma ORM + PostgreSQL.
- **Mobile app:** Flutter (Material 3) + Riverpod (state) + go_router (routing) + Dio (HTTP) + flutter_secure_storage (token storage) + socket_io_client (realtime). Runs on Android, iOS, Linux desktop, and web. (The plan called for Flutter mobile-first; that is what was built. The backend is a plain REST + Socket.IO API, so a future web/native client is additive.)
- **Realtime:** NestJS WebSocket gateway (Socket.IO), in-memory adapter for the MVP (Redis adapter is the scale-up path).
- **Auth:** JWT access (15m) + rotating refresh (60d) tokens, stored hashed; bcryptjs password hashing.
- **Reminders:** lightweight in-process scheduler for MVP (BullMQ + Redis is the production path).

## Monorepo layout
```
ordo/
  apps/
    api/     # NestJS backend
    mobile/  # Flutter app — lib/ has core/, features/, models/, shared/
  packages/  # empty for now (no shared package yet)
```

## Non-negotiable architecture rules
1. Start as a **modular monolith**, not microservices.
2. **Never bypass authorization checks.** Every resource endpoint enforces object-level authorization (the requesting user must be a member of the owning group / the owner of the owning self-space).
3. **Timeline privacy is core:** `PRIVATE | BUSY_ONLY | TITLE_ONLY | FULL`. The backend must redact details server-side based on the viewer's relationship to the block, never trust the client.
4. **Use UTC internally**, display in the user's timezone.
5. Use **UUIDs** as public identifiers — never expose sequential IDs.
6. Every screen must have loading / empty / error states where relevant.
7. Most common actions must take **no more than two taps**.
8. Keep chat **secondary** to timeline and coordination.

## Conventions
- Backend modules: `controller -> service -> prisma`. Gateways call services.
- DTOs use `class-validator`. Controllers are thin.
- The mobile app keeps its own Dart models in `lib/models/` mirroring the API shapes; there is no shared package yet.
- Mobile feature folders under `lib/features/` mirror the pillars: `auth`, `today`, `timeline`, `groups`, `tasks`, `todos`, `chat`, `availability`, `inbox`, `profile`, plus `shell` (bottom-nav app shell). Shared widgets/format live in `lib/shared/`; cross-cutting wiring (api, auth, providers, realtime, router, theme) lives in `lib/core/`.

## Local dev
- Postgres is local — the connection string lives in `apps/api/.env` (copy it from `apps/api/.env.example` and set your local password).
- `pnpm install`, then `pnpm db:migrate` and `pnpm db:seed` to bootstrap data.
- Backend: `pnpm dev:api` → `http://localhost:4000/api`.
- Mobile: `cd apps/mobile && flutter pub get`, then `flutter run` (picks a connected device; on Chrome, Linux desktop, or the Android emulator it targets `localhost:4000`; on a **physical device** pass `--dart-define=ORDO_API_URL=http://<your-LAN-IP>:4000`). See `lib/core/config.dart`.
- Demo login: `ali@ordo.app` / `password123`.
