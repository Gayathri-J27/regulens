# Progress and module status

Status vocabulary: Not started · In progress · Implemented · Integrated · Tested · **Verified** (exercised end to end
through the API and/or the browser against PostgreSQL). "Tested" names the evidence. Honest gaps are marked.

| # | Module | UI | Backend | Database | Integration | Tests | Status |
|---|---|---|---|---|---|---|---|
| 1 | Auth, sessions, lockout, TOTP, password reset, RBAC | Login, demo access, TOTP setup, Settings | `api/auth.py`, `core/security.py`, `core/permissions.py` | users, user_sessions | all routers | integration (lockout, logout, forged token, permission matrix); Playwright | Verified |
| 2 | Region / institution / committee scoping + RLS | — | `core/scope.py` | RLS policies (0002/0003) | every list/detail query | integration (API + raw SQL RLS); benchmark probes | Verified |
| 3 | **Promise Ledger** | Ledger (8 views), obligation detail, create, actions | `services/ledger.py` | obligations, evidence | workflow, EVC, extraction, documents, notifications, escalation, risk, reports | E2E scenario; integration | Verified |
| 4 | **Clock engine** + Why? | Clock strip, explanation, history | `engines/clock_engine.py`, `services/clocks.py` | clocks, clock_events | ledger, workflow, calendars, simulator | 15 unit/property tests; benchmark 100 % agreement | Verified |
| 5 | Rules-as-code, versioning, two-person approval | Admin → Rules, config versions | `services/config.py` | rules, config_versions | deadlines, reminders, escalation, priority, risk, EVC, routes | integration (preview gate, 403 self-approval, citation rule) | Verified |
| 6 | Workflow engine (6 routes), returns, reverts, decisions | Applications list/detail, Workflow queues, route editor | `engines/workflow.py`, `services/workflow.py` | applications, application_events, route_templates | ledger, clocks, EVC, notifications | engine tests; E2E A, D | Verified |
| 7 | Exceptions (withdraw, merge, appeal, legal hold) | Exception dialog | `services/workflow.py` | — | ledger/clocks | integration test (hold → PAUSED_LEGAL_HOLD, lift, appeal, merge, withdraw) | Verified |
| 8 | Rule simulator | Simulator | `services/simulator.py` | — | clock engine on stored histories | integration | Verified |
| 9 | Dashboards & pendency (MV + live) | Overview with 11 filters, 9 charts | `services/intelligence.dashboard` | mv_app_rollup | all modules | integration; Locust | Verified |
| 10 | EVC scheduling & management | EVC queue/detail, panels, exclusions, findings | `engines/evc_ranker.py`, `services/evc.py` | experts, evc_visits, evc_assignments | workflow stage gate, ledger, notifications | engine test; E2E A | Verified |
| 11 | Approval letter → ledger (bounded AI) | Upload, review with source highlight, accept/edit/reject, manual add | `engines/extraction.py`, `engines/ocr.py`, `services/documents.py` | extraction_jobs/items | ledger, notifications | engine tests (hallucination rejection); E2E B | Verified (local extractor); LLM adapter untested live |
| 12 | Process mining | Process mining page | `services/intelligence.process_mining` | application_events | — | E2E G (planted bottlenecks found) | Verified |
| 13 | Breach forecast + capacity | Forecast (risk, capacity) | `engines/risk.py`, `services/intelligence` | risk_scores | notifications (Nudge) | engine test; benchmark; E2E G | Verified |
| 14 | Today's 10 | Today's 10 | `engines/priority.py` | — | ledger, escalation, nudge | engine test; integration ordering; Locust | Verified |
| 15 | Institution portal (Tier 1/2/3), health card | Portal (mobile), magic-link page, assisted handling | `api/routes_core.py` | magic_links, institution_contacts | ledger, documents, notifications | integration (magic link); Playwright upload→verify | Verified |
| 16 | Lease & document validity (OCR) | Documents list/detail with highlights, renewals | `engines/ocr.py`, `services/documents.py` | institutional_documents | ledger, reminders | E2E E | Verified (Tesseract; PaddleOCR optional, not installed) |
| 17 | Notification engine (4 channels, retries, fallback, digest, 4 languages) | Inbox, all messages, delivery log, templates | `services/notifications.py` | notifications, delivery_log, notification_templates | everything | integration (no false delivery); crash test | Verified with dev adapters (no live SMTP/SMS/WhatsApp) |
| 18 | Escalation engine | Escalations, posts/delegations, resolver preview | `engines/escalation_resolver.py`, `services/escalation.py` | escalations, posts, delegations | ledger, notifications, Today's 10 | resolver unit tests; E2E F | Verified |
| 19 | Durable scheduler | (status via actions) | `workers/scheduler.py` | scheduled_actions | reminders, sweeps, audit, MV, digest, OCR, retention | crash-recovery test | Verified |
| 20 | Tamper-evident audit trail | Audit trail, verify, seals, tamper demo | `engines/audit_chain.py`, `services/audit.py` | audit_log (+triggers), audit_seals, audit_demo_log | all writes | property test; DB-trigger test; benchmark | Verified (external anchor = local file) |
| 21 | Reports & exports (14, CSV/PDF) | Reports | `services/reports.py` | — | permissions, audit | integration | Verified |
| 22 | Integration adapters & migration workflow | Admin → Imports | `services/imports.py` | import_batches | ledger/workflow/clocks | integration (preview, dedup, cutover) | Verified (CSV, synthetic); API adapter = stub |
| 23 | Synthetic data generator | Admin → Synthetic data | `services/synthetic.py` | all | — | used by every test run | Verified (20,701 obligations vs 18,000 target) |
| 24 | Benchmark harness | Admin → Benchmark | `services/benchmark.py`, `app.cli benchmark` | benchmark_runs | — | executed | Verified |
| 25 | Impact calculator | Simulator → Impact | `api/routes_intel.impact` | — | — | integration | Verified |
| 26 | Administration console | Admin (9 tabs) | `api/routes_admin.py` | — | — | Playwright (all pages render) | Verified |
| 27 | Localisation & accessibility | Language switch, simple mode | locales en/hi/mr/ta | — | — | component tests | Implemented — translations need native review; no formal a11y audit |
| 28 | Security & privacy (rate limits, signed URLs, malware scan, retention) | — | `core/security.py`, `services/files.py`, scheduler retention | — | — | integration (upload/malware) | Verified with fallback scanner |
| 29 | Deployment (Docker Compose, Makefile) | — | Dockerfiles, compose, nginx | — | — | **not executed** (no Docker daemon) | Implemented, not verified |

## Log

- Phase 1–2: workspace was empty; PostgreSQL 16 initialised locally; models, Alembic migrations, auth/RBAC, audit chain,
  clock engine (+ property tests), rules, workflow, ledger, notifications, escalation, scheduler.
- Phase 3–5: EVC, OCR/extraction, documents, portal, magic links, exceptions, imports.
- Phase 6–7: intelligence, simulator, reports, synthetic generator, benchmark; 65-step scenario passing via API.
- Phase 8: React frontend (27 routes), screenshots reviewed and fixed, Vitest, Playwright, Locust, docs.
