# Ordo — Coding Agent Instructions

You are helping build **Ordo**, a time-first group coordination app.

## Product identity
Ordo is **not** a chat clone. It is a shared-life coordination system centered on daily, weekly, and monthly **timelines**, privacy-controlled **availability**, group **tasks**, **reminders**, **chat**, **files**, and AI scheduling support.

The four pillars (everything else supports these):
1. **Timeline** — daily, weekly, monthly.
2. **Groups** — shared spaces, not just chats.
3. **Availability** — find empty slots quickly.
4. **Privacy** — share busy time without exposing personal details.

## Stack (as implemented in this repo)
- **Backend:** NestJS (modular monolith) + Prisma ORM + PostgreSQL.
- **Frontend:** Next.js (App Router) + shadcn/ui + Tailwind + TanStack Query + Socket.IO client. (The original plan specified Flutter; a web app was chosen for best-in-class UI/UX and verifiability. The backend is identical to what a Flutter client would consume.)
- **Realtime:** NestJS WebSocket gateway (Socket.IO), in-memory adapter for the MVP (Redis adapter is the scale-up path).
- **Auth:** JWT access + refresh tokens, bcrypt hashing.
- **Reminders:** lightweight in-process scheduler for MVP (BullMQ + Redis is the production path).

## Monorepo layout
```
ordo/
  apps/
    api/   # NestJS backend
    web/   # Next.js frontend
  packages/
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
- Shared types live close to the feature; the web app duplicates lightweight TS types (no shared package yet).
- Frontend feature folders mirror the plan (today, groups, timeline, tasks, todos, chat, etc.).

## Local dev
- Postgres is local: `postgresql://postgres:Ali_2792005@localhost:5432/ordo` (see `apps/api/.env`).
- `pnpm db:migrate` then `pnpm db:seed` to bootstrap data.
- `pnpm dev:api` (port 4000) and `pnpm dev:web` (port 3000).
