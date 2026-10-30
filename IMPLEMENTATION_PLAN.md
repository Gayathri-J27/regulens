# Implementation plan

Followed in the order of PART 33; every phase ended with something runnable before the next began.

## Decisions taken up front

- **Modular monolith**, one PostgreSQL database; pure, database-free engines (`app/engines`) separated from
  orchestration services (`app/services`) so the deterministic logic is unit- and property-testable.
- **History, not state, is the source of truth** for deadlines (`clock_events`), workflow (`application_events`) and
  audit (`audit_log`); current values are derived caches.
- **Every external dependency gets a local adapter that says what it is**: dev mailbox, SMS log, WhatsApp preview,
  local malware signatures, rule-based extractor, Tesseract — each labelled in data and UI.
- **No invented regulation**: all values are configurable parameters; nothing is labelled handbook-confirmed.
- Synchronous FastAPI endpoints (thread pool) with short transactions; scheduler in-process for development and as a
  separate worker for deployment (safe to scale out).

## Phases

1. **Foundation** — config, DB, models (38 tables), Alembic 0001–0002 (triggers, RLS, partial indexes, MV), sessions,
   lockout, TOTP, permission matrix, scope helpers, hash-chained audit service.
2. **Core engines** — clock engine with two implementations + Hypothesis tests; rules/config versioning; route state
   machine (6 routes); Promise Ledger; `explain()`.
3. **Primary workflow** — registration, route rule, stage clocks, return/resubmit ownership hand-over, reverts with
   policies, decisions (Competent Authority only), assignment.
4. **Approval & compliance** — secure uploads (signature, checksum, scan, signed URLs), PDF text/OCR, bounded
   extraction with source verification, officer review → ledger, institution portal, evidence + receipts, magic links,
   assisted handling.
5. **Time & communication** — durable scheduler, reminders, notifications (retries, fallback, digest, 4 languages),
   documents/OCR validity, EVC (ranking, scheduling, findings), escalation resolver, calendars + recomputation, exceptions.
6. **Intelligence** — dashboards (MV/live), Today's 10, breach forecast, capacity, process mining, rule simulator.
7. **Reliability & reporting** — seals/anchor/verification jobs, crash recovery, 14 reports (CSV/PDF), import
   adapters + cutover simulation, synthetic generator with planted faults, benchmark harness, impact calculator.
8. **Verification** — API scenario (65 steps), integration tests on a clean DB, React UI for all modules, screenshot
   review, Vitest, Playwright, Locust, documentation.
