# Test report

Environment: Linux sandbox, 2 vCPU / 7 GB, PostgreSQL 16.15, Python 3.13, Node 22, Tesseract 5.3.4, headless Chromium.
All results below were produced by running the commands shown; nothing is asserted without a run behind it.

## Summary

| Suite | Command | Result |
|---|---|---|
| Clock engine — unit + Hypothesis property tests | `pytest tests/test_clock_engine.py` | **15 passed** (400 random histories compared against an independent day-by-day reference) |
| Pure engines — workflow, escalation resolver, audit chain, priority, risk, EVC ranking, extraction, OCR date logic | `pytest tests/test_engines.py` | **19 passed** (incl. property test: any single altered audit entry is detected at its exact position) |
| API integration on a freshly migrated `regulens_test` DB | `pytest tests/test_integration_api.py` | **15 passed** |
| **Backend total** | `make test-backend` | **49 passed in 35 s** |
| Frontend components | `npx vitest run` | **8 passed** (status badges, acronym labels, DaysLeft, ClockStrip, Login validation/error) |
| Browser E2E (Playwright, Chromium) | `npx playwright test` | **3 passed** — every admin sidebar page renders; portal evidence upload → officer verification → MET; cross-Region URL access blocked |
| PART 29 scenario A–H through the API | `python scripts/e2e_scenario.py` | **65/65 steps passed** — log in [docs/e2e_scenario_log.txt](docs/e2e_scenario_log.txt); also executed inside pytest on the test DB |
| Benchmark harness | `make benchmark` | targets **met** — see below and [docs/benchmark/scorecard.md](docs/benchmark/scorecard.md) |
| Load (Locust) | `make load` | 0 failures; see below |

## Integration tests (what each proves)

- Full PART 29 scenario on a clean database (also the CI-style proof that migrations + seed + synthetic generation work).
- Login lockout after 5 failures (HTTP 423), logout revocation, forged tokens rejected.
- Backend permission enforcement independent of UI (principal → dashboard/audit/rules 403; bureau officer → sweep 403).
- Institution isolation via API **and** PostgreSQL RLS (raw SQL with the scope set sees zero foreign rows).
- `UPDATE`, `DELETE` and `TRUNCATE` on `audit_log` are rejected by the database.
- Scheduler crash recovery: actions crashed mid-run are re-queued after lease expiry — 0 missed, 0 duplicate notifications.
- No notification is `DELIVERED` without a matching DELIVERED delivery-log record; bounced synthetic contacts flagged invalid.
- 14 reports; CSV and PDF exports; exports appear in the audit trail.
- Upload validation (415 for non-PDF/PNG/JPEG by signature) and malware block (EICAR → 422).
- Magic link: scoped to one obligation, single use (410 on reuse), unknown token 404.
- Rule versioning: preview required before approval, author cannot approve (403), second admin can; HANDBOOK_CONFIRMED needs a citation (422).
- Simulator replays stored clocks (deadlines changed + historical back-test).
- Dashboard MV vs live-query paths, process mining, capacity, Today's 10 ordering, impact calculator labelling.
- CSV import: preview counts (1 valid / 2 errors / 1 duplicate), cutover simulation rolls back, commit persists.
- Case exceptions: court hold needs elevated role and the order file, pauses clocks as PAUSED_LEGAL_HOLD, lift resumes; appeal creates a child case; merge de-duplicates; withdrawal cancels obligations; empty reasons refused.

## Benchmark (latest run, 6,000 synthetic applications)

| Criterion | Measurement | Result |
|---|---|---|
| Workflow accuracy | Route rule vs ground truth; detection of 200 planted misroutings; stage validity | 100 % / recall 100 %, precision 100 % / 100 % |
| Alert timeliness | 200 reminders due now → scheduler → dispatcher → delivered | p50 3.3 s, p95 3.3 s (local adapters; SMS receipts arrive on the next pass) |
| Deadline reliability | 1,500 random stored clocks: production engine vs reference; stored due date vs recomputation; missed reminders | 100 % agreement; 100 % match; 0 missed per 100k |
| Scheduler crash recovery | 60 actions, 30 crash mid-run, lease expiry, second worker, replay of completed actions | 0 missed, 0 duplicates |
| Pending-case visibility | Risk recompute for ~5k open obligations; top-10 query; planted late obligations flagged | 1.6 s recompute; 3 ms top-10; 100 % of 300 planted late flagged overdue and HIGH |
| Manual follow-up reduction | Baseline (open × policy follow-ups) vs system-scheduled reminders | baseline 21,648 manual follow-ups; all scheduled by the system (modelled hours: impact calculator) |
| Audit completeness | Creation-audit coverage, clock-event audit coverage, chain verification, tamper detection | 100 %, 100 %, chain OK (~4.2k entries in 0.25 s), tamper detected at the altered entry in 23 ms |
| Permission matrix | 16 role × endpoint probes incl. cross-Region and cross-institution reads | 0 leaks, 0 unexpected results |

Targets: zero missed scheduled actions — **met**; zero duplicate notifications — **met**; zero unauthorised data leaks — **met** (in these tests).

## Performance (Locust, 60 s, API with 4 workers; load generator on the same 2-vCPU host)

| Endpoint | 20 users p50 / p95 | 50 users p50 / p95 |
|---|---|---|
| Dashboard (aggregate) | 82 / **170 ms** | 180 / **480 ms** |
| Dashboard (filtered, live query) | 66 / 130 ms | 150 / 390 ms |
| Ledger list | 47 / 95 ms | 110 / 410 ms |
| Today's 10 | 32 / 91 ms | 60 / 260 ms |
| Upload (validate + checksum + scan + store) | 17 / 120 ms | 39 / 220 ms — **≈144 uploads/min, 0 failures** |

Dashboard p95 < 500 ms: met at 50 users (narrowly) and comfortably at 20. An N+1 query in Today's 10 found by this test
(p95 7.5 s for an account with ~780 escalations) was fixed with a single joined query. Raw CSVs: `docs/load/`.

## Defects found and fixed during testing (selection)

RLS policy cast failing on an empty scope GUC (→ `NULLIF`, migration 0003); two over-short columns (scanner label,
`APPROVED_WITH_CONDITIONS`; migrations 0004–0005); ambiguous routes (`/ledger/{id}/{action}` swallowing `/evidence`;
all numeric path params now use `:int` converters); EVC ranking on institutions without coordinates; relative deadlines
wrongly rejected by the anti-invention check; simulator rule-id bug; risk base saturating so modifiers had no effect;
Today's 10 N+1; portal health card counting AICTE-side work.

## Not covered by automated tests

Docker Compose execution, live ClamAV/MinIO/SMTP/LLM, PaddleOCR, formal accessibility audit, 200k-obligation scale.
See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).
