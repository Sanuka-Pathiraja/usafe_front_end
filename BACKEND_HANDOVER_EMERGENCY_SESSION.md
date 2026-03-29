# Backend Handover – Emergency Session Persistence

**Date:** 2026-03-23
**Prepared by:** Frontend team
**Context:** The Flutter frontend now calls two new/updated endpoints to track the full lifecycle of an emergency session. The backend must persist this data in Supabase.

---

## 1. Supabase – New Table Required

Create a new table `emergency_sessions` in Supabase with the following schema:

```sql
create table public.emergency_sessions (
  id                       uuid primary key default gen_random_uuid(),
  session_id               text not null unique,          -- matches the id returned by POST /emergency/start
  user_id                  uuid references auth.users(id),
  status                   text not null default 'ACTIVE', -- ACTIVE | COMPLETED | FAILED | CANCELLED
  trigger_source           text,                           -- optional: 'in-app', 'widget', 'notification'
  user_name                text,
  latitude                 double precision,
  longitude                double precision,
  approximate_address      text,
  someone_answered         boolean default false,
  emergency_services_called boolean default false,
  contacts_messaged        boolean default false,
  failed_step_title        text,
  failed_step_reason       text,
  cancellation_message     text,
  started_at               timestamptz not null default now(),
  finished_at              timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- Index for fast lookups by session_id
create index on public.emergency_sessions (session_id);

-- Index for lookups by user
create index on public.emergency_sessions (user_id);

-- RLS: only the owning user can read their own sessions
alter table public.emergency_sessions enable row level security;

create policy "Users can read own sessions"
  on public.emergency_sessions for select
  using (auth.uid() = user_id);

create policy "Service role can insert/update"
  on public.emergency_sessions for all
  using (true)
  with check (true);
```

---

## 2. Endpoint Changes

### 2a. `POST /emergency/start`  ← already exists, needs DB write added

**Current behaviour:** Sends messages to contacts, returns a `sessionId`.
**Required change:** After creating the in-memory session, **insert a row** into `emergency_sessions`:

```
session_id               = <newly generated sessionId>
user_id                  = <from JWT>
status                   = 'ACTIVE'
user_name                = body.userName         (optional)
latitude                 = body.latitude         (optional)
longitude                = body.longitude        (optional)
approximate_address      = body.approximateAddress (optional)
started_at               = now()
```

**Request body (already sent by frontend):**
```json
{
  "userName": "Jane Doe",
  "latitude": 6.9271,
  "longitude": 79.8612,
  "approximateAddress": "Galle Road, Colombo 3, Western Province, Sri Lanka"
}
```

**Response (no change needed):**
```json
{
  "sessionId": "<uuid>",
  "messagingSuccessful": true,
  "message": "..."
}
```

---

### 2b. `POST /emergency/:sessionId/cancel`  ← already exists, needs DB update added

**Current behaviour:** Marks the session as cancelled in memory.
**Required change:** Update the `emergency_sessions` row:

```
status            = 'CANCELLED'
cancellation_message = body.message  (if present)
finished_at       = now()
updated_at        = now()
```

No request body change needed – the frontend already calls this endpoint as-is.

---

### 2c. `POST /emergency/:sessionId/finish`  ← **NEW endpoint**

**Purpose:** Called by the frontend when the emergency process ends with outcome `COMPLETED` or `FAILED` (cancellation is handled separately by `/cancel`).

**Authentication:** Bearer token (same as all other emergency endpoints).

**Request body:**
```json
{
  "status": "COMPLETED",           // "COMPLETED" or "FAILED"
  "someoneAnswered": true,
  "emergencyServicesCalled": false,
  "contactsMessaged": true,
  "failedStepTitle": null,          // present only when status = "FAILED"
  "failedStepReason": null          // present only when status = "FAILED"
}
```

**Required action:** Upsert (or update) the `emergency_sessions` row matching `:sessionId`:

```
status                    = body.status
someone_answered          = body.someoneAnswered
emergency_services_called = body.emergencyServicesCalled
contacts_messaged         = body.contactsMessaged
failed_step_title         = body.failedStepTitle   (nullable)
failed_step_reason        = body.failedStepReason  (nullable)
finished_at               = now()
updated_at                = now()
```

**Success response (200):**
```json
{ "ok": true, "message": "Session status updated." }
```

**Error responses:**
| Code | Condition |
|------|-----------|
| 401  | Missing or invalid token |
| 404  | `sessionId` not found |
| 400  | Invalid `status` value |

---

## 3. Summary of Frontend Calls and Timing

| Frontend event | Endpoint called | Expected DB change |
|---|---|---|
| Timer fires → process screen opens → messaging step starts | `POST /emergency/start` | INSERT row with status `ACTIVE` |
| User taps "Stop Emergency" | `POST /emergency/:id/cancel` | UPDATE status → `CANCELLED`, set `finished_at` |
| All steps complete normally | `POST /emergency/:id/finish` body `status=COMPLETED` | UPDATE status → `COMPLETED`, set outcome fields + `finished_at` |
| A critical step throws an unrecoverable error | `POST /emergency/:id/finish` body `status=FAILED` | UPDATE status → `FAILED`, set `failedStepTitle`, `failedStepReason`, `finished_at` |

---

## 4. Notes

- The `/finish` endpoint should be **idempotent** – if it is called twice (e.g. due to a retry), it should simply overwrite with the same data rather than error.
- The frontend makes the `/finish` call in a best-effort fire-and-forget pattern. If it fails, the session row may remain as `ACTIVE` indefinitely. Consider adding a background job that marks sessions older than N hours as `TIMED_OUT` if they never received a finish/cancel call.
- The `session_id` stored in Supabase is the same string returned in the `sessionId` field of the `/emergency/start` response. The frontend stores this and uses it for all subsequent calls.
- Guest-mode sessions (no JWT) never reach the authenticated endpoints, so no row is created for them.
