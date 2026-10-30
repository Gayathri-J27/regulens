# Architecture

ReguLens AI is a **modular monolith**: one FastAPI process (plus optional scheduler workers) over one PostgreSQL
database. Modules share tables and services, never copies of data — an obligation created anywhere appears at once in
the ledger, the institution portal, Today's 10, notifications, escalation, the forecast, reports and the audit trail.

```
            React PWA (Vite) ── /api ──►  FastAPI  ─┬─ api/            routers (auth, core, operations, intelligence, admin)
                                                    ├─ core/           config, db, security (sessions, TOTP, rate limit, signed URLs),
                                                    │                  permissions (role→permission matrix), scope (Region/institution/RLS)
                                                    ├─ engines/        PURE, unit-tested: clock_engine, workflow, escalation_resolver,
                                                    │                  audit_chain, risk, priority, evc_ranker, extraction, ocr
                                                    ├─ services/       DB-aware orchestration: ledger, workflow, clocks, notifications,
                                                    │                  escalation, evc, documents, intelligence, simulator, reports,
                                                    │                  imports, synthetic, benchmark, audit, config, seed
                                                    └─ workers/        durable scheduler (thread in API or `app.cli worker`)
                                                              │
                                PostgreSQL 16 ◄───────────────┘  (JSONB rules, RLS, append-only audit triggers, MV, partial indexes)
                                File store: local dir or MinIO/S3 (SSE)      Malware: clamd INSTREAM or labelled local fallback
                                Audit anchor: append-only file (dev) / object-locked bucket (Compose)
```

## Core principles and where they are enforced

| Principle | Mechanism |
|---|---|
| AI assists, never decides | `engines/extraction.py` only produces proposals; `validate_and_verify` rejects schema failures, quotes not found verbatim in the document, and dates absent from the quoted sentence. Only `review_item(accept)` creates obligations. Decisions require `workflow.decide` (Competent Authority only) and a note. |
| Deterministic deadlines | `engines/clock_engine.py` — no DB, no LLM. Due dates are always re-derived from `clock_events` (`services/clocks.recompute`); stored `due_date` is a cache. |
| Explainable | `clock_engine.explain()` templates; EVC ranking returns per-expert reasons; risk returns top-3 reasons with effect sizes; process-mining insights are filled from SQL aggregates; priority shows its formula. |
| Configurable & versioned | `rules` (DRAFT→PREVIEWED→APPROVED→EFFECTIVE, two-person), `route_templates` (versioned JSON state machines), `config_versions` pinned per application. |
| Traceable | `services/audit.audit()` on every state change; hash chain + DB triggers + signed daily heads + external anchor; request `X-Request-ID` stored as `correlation_id`. |

## Clock engine (PART 7)

Semantics (also in the module docstring and enforced by tests): instants are converted to Asia/Kolkata dates; a clock
started on S consumes the countable dates after S; a date counts only if no pause is active at its start, so a pause on P
still counts P and a resume on R does not count R. Countable = every date (CALENDAR) or non-weekend, non-holiday
dates of the union of the AICTE national, Regional-office and institution-State calendars (WORKING).
`due = walk_forward(segment_start, budget − consumed_so_far, calendar)` over the running segments since the last reset.

- Pause kinds nest (INSTITUTION, AICTE, LEGAL_HOLD, SOURCE); state reports the strongest active pause.
- EXTEND adds budget; REVERT applies RESUME (keep accrued), RESTART (original budget, extensions dropped) or
  RESET_TO_STAGE_BUDGET (stage budget + extensions).
- STOP_MET / STOP_WAIVED freeze consumption; `met_on_time` compares with the due date.
- Two independent implementations — interval arithmetic (`compute`, production) and a day-by-day simulation
  (`compute_naive`) — are compared by 400-example Hypothesis tests and by the benchmark on 1,500 stored clocks (100 % agreement).
- Holiday edits call `recompute_for_calendar` (every running clock using that calendar; GIN-indexed).

**Ownership of delay:** returning an application pauses the AICTE stage clock (`PAUSE INSTITUTION`) and starts a
separate institution-side `DEFICIENCY_RESPONSE` obligation/clock. Resubmission stops that clock (met) and applies a
`REVERT` with the route's policy to the AICTE clock — waiting time is never charged to the officer.

## Workflow engine (PART 6)

Routes are data: `{stages[], revert_policy, revert_targets}`; each stage has budget, day mode, responsible role,
required fields, required facts (`evc_report`), returnability and `resubmit_to` (SCRUTINY → RESCRUTINY). The pure
`engines/workflow.py` plans transitions and raises on invalid ones; `services/workflow.py` executes them (closing and
opening stage obligations/clocks, queueing EVC, notifications, events, audit). Route assignment is the
`route.assignment` rule; explicit deviations are recorded and flagged as route mismatches. Exceptions: withdraw
(cancel obligations, stop clocks), merge (re-parent / de-duplicate), appeal (child case, parent clocks on LEGAL_HOLD),
court hold (requires the order file) and lift.

## Notification engine (PART 17)

`notifications` rows are created with an idempotency key `(template, entity, recipient, channel, suffix)` and
`ON CONFLICT DO NOTHING`, so any replay is harmless. The dispatcher claims due rows with `SKIP LOCKED`. Channel adapters:
in-app (delivered on write), email (SMTP → SENT only, no false "delivered"; dev mailbox capture → DELIVERED to the dev
mailbox), SMS (dev log → SENT, then a simulated delivery receipt; a provider webhook endpoint applies real receipts),
WhatsApp (preview only → SENT). Transient failures retry after 1 m, 10 m, 1 h, 6 h then FAILED + one fallback hop;
bounces mark the contact invalid, alert the Regional desk officer and fall back. Non-urgent mail for digest institutions
is held and combined into one daily digest. Templates are versioned per language and rendered from stored text.

## Escalation (PART 18)

Daily sweep: days overdue → level from `escalation.timeline`; level *n* targets the post *n* steps above the assigned post.
`engines/escalation_resolver.resolve` (pure) walks: active delegate → active holder → same-level post in the nearest
Region (haversine) → next level → UNROUTABLE (administrators alerted). Resolution happens at execution time, so
transfers, vacancies and leave are honoured automatically; the full path is stored on each escalation.

## Durable scheduler

`scheduled_actions(idempotency_key unique, status, run_at, lease_expires_at)`. Each tick: materialise periodic actions
with period keys (`sweep:escalation:2026-10-30`, `audit_verify:2026103014`, …), re-queue RUNNING actions whose lease
expired (crashed worker), claim due PENDING actions with `FOR UPDATE SKIP LOCKED`, run each in its own transaction.
Reminders are keyed by (obligation, due date, offset) and skip themselves if the obligation closed or was re-dated.
Benchmarked with a controlled crash: 30 of 60 actions crashed mid-run → 0 missed, 0 duplicate notifications.

## Intelligence

- **Dashboard:** application counts from `mv_app_rollup` when filters allow, otherwise live queries (source is shown).
- **Today's 10:** one joined query; `priority = w1·urgency + w2·tier + w3·statutory + w4·ageing`, urgency bounded for
  zero/negative days; overrides recorded with a reason.
- **Breach forecast:** empirical survival of `duration / budget` among closed obligations per (type, Region, tier);
  conditional miss probability `S(1)/S(elapsed)`; shrinkage `p = (n·p_seg + k·p_parent)/(n+k)`; `INSUFFICIENT_DATA`
  below `min_samples` globally; explicit odds modifiers with reported effects; clamped to 1–99 %.
- **Process mining:** variants from `STAGE_ENTER` sequences vs the prescribed path, loop matrix from
  RETURNED/REVERTED/RESUBMITTED, stage durations, Region medians (bottleneck if > 1.3× the cross-Region median), delay
  beyond budget.
- **Rule simulator:** replays stored clock histories through the production engine with the proposed budget
  (+ historical back-test, 14-day workload, escalation re-levelling, route-rule changes).

## Security model

Opaque server-side sessions (bcrypt passwords, 5-failure lockout, idle + absolute expiry, optional TOTP for officers,
login/reset/magic-link rate limits). Every endpoint declares a permission; row scope by Region/institution/committee
assignment in queries; PostgreSQL RLS (FORCE) on the four institution-scoped tables using a per-connection GUC that is
reset when the connection returns to the pool. Uploads: signature-based type check, size limit, SHA-256, malware scan,
randomised storage keys, HMAC-signed short-lived download URLs, `nosniff`. Magic links: 256-bit token stored hashed,
single-obligation scope, single use, 7-day expiry, rate-limited. Security headers and CSP on API responses; exports are
audited. Details, DPDP alignment and the breach-response procedure: [docs/SECURITY_AND_PRIVACY.md](docs/SECURITY_AND_PRIVACY.md).

## Deployment

Compose: `db`, `minio` (+ `minio-init` creating an object-locked `regulens-audit-anchor` bucket), `clamav`, `api`
(runs `alembic upgrade head`, 4 workers, scheduler off), `worker` (scheduler), `web` (nginx serving the PWA, proxying
`/api`, HSTS). TLS terminates at the ingress/load balancer; encryption at rest via encrypted volumes/managed Postgres
and S3 server-side encryption (the S3 adapter sets `ServerSideEncryption=AES256`).
