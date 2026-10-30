# API documentation

ReguLens AI exposes a REST API (FastAPI). The live, interactive OpenAPI UI is served at **`/docs`** (Swagger) and **`/redoc`** when the API runs; the full machine-readable contract is in [`docs/openapi.json`](docs/openapi.json).

## Conventions

- **Auth:** `POST /api/auth/login` returns an opaque session token; send `Authorization: Bearer <token>`. Sessions are server-side (revocable), expire after 8 h or 60 min idle. Officers may enable TOTP (`/api/auth/totp/*`).
- **Authorisation:** every endpoint checks a named permission (see `backend/app/core/permissions.py`, also rendered in Administration → Roles). Row scope (Region / institution / committee assignment) is applied in queries, and PostgreSQL row-level security isolates institution users. Forbidden = `403`; rows hidden by RLS = `404`.
- **Errors:** `{"detail": "…"}` with 401/403/404/409 (state conflict)/410 (expired or used link)/413/415/422 (validation, with the reason)/423 (locked)/429 (rate limit).
- **Pagination:** `?page=1&page_size=25` → `{total, page, page_size, pages, items}`.
- **Tracing:** every response carries `X-Request-ID`; the same id is stored on audit entries as `correlation_id`.
- **Files:** uploads are multipart; downloads use short-lived HMAC-signed URLs (`/api/files/{id}/download?u=&exp=&sig=`).
- **Integration stub:** `POST /api/admin/integration/v1/{entity}` accepts canonical JSON records and stages them exactly like CSV; contract at `GET /api/admin/integration/openapi.json`. Not connected to any AICTE system.

## Auth

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/auth/demo-accounts` | Role-appropriate demo access for the login page (only in non-production environments). |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/logout` | Logout |
| GET | `/api/auth/me` | Me |
| POST | `/api/auth/password-reset/confirm` | Reset Confirm |
| POST | `/api/auth/password-reset/request` | Reset Request |
| POST | `/api/auth/totp/disable` | Totp Disable |
| POST | `/api/auth/totp/enable` | Totp Enable |
| POST | `/api/auth/totp/setup` | Totp Setup |
| POST | `/api/auth/totp/verify` | Totp Verify |

## Core

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/applications` | List Applications |
| POST | `/api/applications` | Create Application |
| GET | `/api/applications/{aid}` | Get Application |
| POST | `/api/applications/{aid}/assign` | Assign App |
| POST | `/api/applications/{aid}/complete-stage` | Complete Stage |
| POST | `/api/applications/{aid}/decide` | Decide |
| POST | `/api/applications/{aid}/exception` | Record Exception |
| POST | `/api/applications/{aid}/resubmit` | Resubmit |
| POST | `/api/applications/{aid}/return` | Return App |
| POST | `/api/applications/{aid}/revert` | Revert |
| GET | `/api/clocks/{cid}/explain` | Clock Explain |
| POST | `/api/evidence/{eid}/review` | Review Evidence |
| POST | `/api/files` | Upload File |
| GET | `/api/files/{fid}/download` | Download |
| GET | `/api/files/{fid}/link` | File Link |
| GET | `/api/institutions` | List Institutions |
| POST | `/api/institutions` | Create Institution |
| GET | `/api/institutions/{iid}` | Get Institution |
| POST | `/api/institutions/{iid}/contacts` | Add Contact |
| PATCH | `/api/institutions/{iid}/contacts/{cid}` | Update Contact |
| GET | `/api/ledger` | List Ledger |
| POST | `/api/ledger` | Create Ledger |
| GET | `/api/ledger/export` | Export Ledger |
| GET | `/api/ledger/{oid}` | Get Ledger |
| PATCH | `/api/ledger/{oid}` | Edit Ledger |
| POST | `/api/ledger/{oid}/assisted` | Ledger Assisted |
| POST | `/api/ledger/{oid}/do/{action}` | Ledger Action |
| POST | `/api/ledger/{oid}/evidence` | Submit Evidence |
| GET | `/api/m/{token}` | Magic Open |
| POST | `/api/m/{token}/acknowledge` | Magic Ack |
| POST | `/api/m/{token}/evidence` | Magic Evidence |
| GET | `/api/meta` | Meta |
| GET | `/api/portal/summary` | Portal Summary |

## Operations

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/documents` | Doc List |
| POST | `/api/documents` | Doc Upload |
| GET | `/api/documents/{did}` | Doc Get |
| POST | `/api/documents/{did}/confirm` | Doc Confirm |
| GET | `/api/escalations` | Esc List |
| POST | `/api/escalations/run-sweep` | Esc Sweep |
| POST | `/api/escalations/{eid}` | Esc Act |
| GET | `/api/evc/visits` | Evc List |
| GET | `/api/evc/visits/{vid}` | Evc Get |
| POST | `/api/evc/visits/{vid}/confirm-findings` | Evc Confirm |
| POST | `/api/evc/visits/{vid}/delay` | Evc Delay |
| POST | `/api/evc/visits/{vid}/propose` | Evc Propose |
| POST | `/api/evc/visits/{vid}/report` | Evc Report |
| POST | `/api/evc/visits/{vid}/schedule` | Evc Schedule |
| POST | `/api/evc/visits/{vid}/visited` | Evc Visited |
| GET | `/api/experts` | Experts |
| POST | `/api/experts` | Add Expert |
| PATCH | `/api/experts/{eid}` | Update Expert |
| POST | `/api/extraction/items/{iid}/review` | Extraction Review |
| POST | `/api/extraction/jobs` | Extraction Upload |
| GET | `/api/extraction/jobs` | Extraction Jobs |
| GET | `/api/extraction/jobs/{jid}` | Extraction Job |
| POST | `/api/extraction/jobs/{jid}/items` | Extraction Manual |
| GET | `/api/notifications` | My Notifications |
| GET | `/api/notifications/all` | All Notifications |
| POST | `/api/notifications/dispatch` | Dispatch Now |
| POST | `/api/notifications/read-all` | Read All |
| POST | `/api/notifications/webhook/{provider}` | Delivery-receipt webhook (provider DLR). Authenticated here; production would verify the provider signature. |
| GET | `/api/notifications/{nid}/deliveries` | Deliveries |
| POST | `/api/notifications/{nid}/read` | Mark Read |

## Intelligence

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/capacity` | Capacity |
| GET | `/api/dashboard` | Dashboard |
| GET | `/api/forecast` | Forecast |
| POST | `/api/forecast/recompute` | Forecast Recompute |
| POST | `/api/impact` | Transparent model — every output is a formula of the stated inputs (modelled estimate, not measured AICTE results). |
| GET | `/api/process-mining` | Process Mining |
| GET | `/api/reports` | Report Catalog |
| GET | `/api/reports/{name}` | Report |
| POST | `/api/simulator/run` | Sim Run |
| GET | `/api/today` | Today |

## Admin

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/admin/audit` | Audit List |
| POST | `/api/admin/audit/seal` | Audit Seal |
| POST | `/api/admin/audit/tamper-demo` | Audit Tamper |
| POST | `/api/admin/audit/try-modify/{aid}` | Shows the production table refuses modification (database trigger). Nothing is changed. |
| POST | `/api/admin/audit/verify` | Audit Verify |
| POST | `/api/admin/benchmark/run` | Bench Run |
| GET | `/api/admin/benchmark/runs` | Bench Runs |
| GET | `/api/admin/calendars` | Calendars |
| POST | `/api/admin/calendars/{cid}/holidays` | Add Holiday |
| DELETE | `/api/admin/calendars/{cid}/holidays/{hid}` | Del Holiday |
| GET | `/api/admin/config-versions` | Config Versions |
| POST | `/api/admin/delegations` | Add Delegation |
| POST | `/api/admin/delegations/{did}/revoke` | Revoke Delegation |
| GET | `/api/admin/imports` | Import History |
| POST | `/api/admin/imports/csv` | Import Csv |
| GET | `/api/admin/imports/template/{entity}` | Import Template |
| POST | `/api/admin/imports/{bid}/commit` | Import Commit |
| GET | `/api/admin/integration/openapi.json` | Import Contract |
| POST | `/api/admin/integration/v1/{entity}` | Import Api |
| GET | `/api/admin/posts` | Posts |
| POST | `/api/admin/posts/{pid}/vacate` | Vacate |
| GET | `/api/admin/resolve-escalation/{post_id}` | Resolve Preview |
| GET | `/api/admin/roles` | Roles |
| GET | `/api/admin/routes` | Routes |
| POST | `/api/admin/routes` | Route New Version |
| GET | `/api/admin/rules` | Rules |
| POST | `/api/admin/rules` | Rule Draft |
| PATCH | `/api/admin/rules/{rid}` | Rule Edit |
| POST | `/api/admin/rules/{rid}/active` | Rule Active |
| POST | `/api/admin/rules/{rid}/approve` | Rule Approve |
| POST | `/api/admin/rules/{rid}/preview` | Rule Preview |
| POST | `/api/admin/synthetic/regenerate` | Synth Regen |
| GET | `/api/admin/synthetic/status` | Synth Status |
| GET | `/api/admin/templates` | Templates |
| POST | `/api/admin/templates` | Template Version |
| GET | `/api/admin/users` | Users |
| POST | `/api/admin/users` | Create User |
| PATCH | `/api/admin/users/{uid}` | Patch User |

_122 operations, generated from the running application._
