# ReguLens AI — Evidence-Driven Regulatory Intelligence for AICTE

A working, locally runnable prototype that tracks AICTE approval workflows, post-approval undertakings, EVC visits,
institutional compliance and document validity in one **Promise Ledger**, with deterministic deadline clocks, a
notification and escalation engine, analytics, and a tamper-evident audit trail.

> **Prototype.** Not connected to AICTE production systems. All institutions, people and documents are fictional and
> flagged *synthetic*. AI only *proposes* (approval-letter extraction); routing, deadlines, reminders and escalation are
> deterministic; statutory decisions are recorded only by the competent authority.

| | |
|---|---|
| Backend | Python 3.12+, FastAPI, SQLAlchemy 2, Alembic, PostgreSQL 16 (JSONB, RLS, materialised view) |
| Frontend | React 19, TypeScript, Vite, Tailwind, TanStack Query, React Hook Form + Zod, Recharts, i18next (en/hi/mr/ta), PWA |
| Documents | PyMuPDF, OpenCV (deskew/denoise), Tesseract (PaddleOCR optional), ClamAV (local fallback scanner) |
| Scheduling | PostgreSQL-backed durable queue (`FOR UPDATE SKIP LOCKED`, leases, idempotency keys) |
| Tests | Pytest + Hypothesis (49), Vitest + Testing Library (8), Playwright (3), 65-step API scenario, Locust |

Documentation: [Architecture](ARCHITECTURE.md) · [API](API_DOCUMENTATION.md) · [Database](DATABASE_SCHEMA.md) ·
[Demo guide](DEMO_GUIDE.md) · [Test report](TEST_REPORT.md) · [Known limitations](KNOWN_LIMITATIONS.md) ·
[Progress / module status](PROGRESS.md) · [Implementation plan](IMPLEMENTATION_PLAN.md) · [Security & privacy](docs/SECURITY_AND_PRIVACY.md) ·
[Benchmark scorecard](docs/benchmark/scorecard.md) · [Screenshots](docs/screenshots/)

---

## 1. Prerequisites

Native: Python ≥ 3.12, Node ≥ 20, PostgreSQL 16, Tesseract 5 (`apt install tesseract-ocr`). Optional: ClamAV (`clamd`),
MinIO, PaddleOCR. Or Docker with Compose v2 for the containerised stack.

## 2. Installation (native)

```bash
cp .env.example .env                      # edit secrets; defaults work for local development
createuser -s regulens -P                 # password: regulens (or change DATABASE_URL)
createdb -O regulens regulens && createdb -O regulens regulens_test
make install                              # pip install -r backend/requirements-dev.txt; npm ci
```

## 3. Environment variables

All settings live in `.env` (see [`.env.example`](.env.example), every variable is commented). The important ones:
`DATABASE_URL`, `SECRET_KEY`, `AUDIT_SIGNING_KEY` (signs daily audit heads — keep separate), `STORAGE_BACKEND`
(`local`|`s3`), `CLAMD_HOST` (empty = labelled local scanner), `LLM_PROVIDER` + `ANTHROPIC_API_KEY` (empty = local
rule-based extractor, labelled as such), `SMTP_HOST` (empty = development mailbox), `RUN_SCHEDULER`.

## 4. Database setup and migrations

```bash
make migrate        # alembic upgrade head  (0001 schema · 0002 audit triggers, RLS, partial indexes, MV · 0003–0005 fixes)
```

## 5. Seed data

```bash
make bootstrap      # Regions, calendars, posts, rules, routes, templates, demo accounts (idempotent)
make synthetic      # 2,000 institutions · 6,000 applications · ~20.7k obligations · 120 officers (seed 20261030) + sweeps
python3 scripts/make_demo_docs.py   # fictional approval letters (digital + scanned) and lease scans in demo_docs/
```

## 6. Start the application

```bash
make api            # API on :8000 with the in-process scheduler   (OpenAPI UI: http://localhost:8000/docs)
make web            # UI on http://localhost:5173  (proxies /api to :8000)
# optional separate worker(s): make worker   — safe to run several
```

Docker alternative: `make up` → UI on http://localhost:8080 (Postgres, MinIO with object-locked audit bucket, ClamAV,
API, worker, nginx). *The Compose file was written for this prototype but could not be executed in the build sandbox
(no Docker daemon) — see KNOWN_LIMITATIONS.*

## 7. Demo credentials

Password for every demo account: **`Demo@1234`** (the login page lists them; click one to fill the form).

| Role | Email |
|---|---|
| Super Administrator | superadmin@regulens.demo |
| AICTE Administrator (and second approver) | admin@regulens.demo · admin2@regulens.demo |
| Regional Officer — Southern Region desk / Deputy Director / Head | ro.south@ · dd.south@ · head.south@regulens.demo |
| Regional Officer — Western Region | ro.west@regulens.demo |
| Bureau Officer | bureau@regulens.demo |
| Committee Member (EVC expert) | committee@regulens.demo |
| Competent Authority | authority@regulens.demo |
| Audit Officer | auditor@regulens.demo |
| Institution Principal / Compliance (Kaveri, SR) | principal@kaveri-demo.in · compliance@kaveri-demo.in |
| Institution Principal (Sahyadri, WR) | principal@sahyadri-demo.in |

Synthetic officers use `syn.officerNNN@regulens.synthetic` / `Synthetic@1234`.

## 8. Running tests

```bash
make test-backend   # 49 tests: clock-engine unit + Hypothesis property tests, engine tests, API integration on regulens_test
make test-frontend  # Vitest component tests
make e2e            # 65-step PART 29 scenario against a running API (prints every step)
make e2e-browser    # Playwright (needs `npx vite preview` on :4173 and the API on :8000)
make load           # Locust: 50 users, 60 s
```

## 9. Running the benchmark

```bash
make benchmark      # writes docs/benchmark/scorecard.json and scorecard.md; also runnable from Administration → Benchmark
```

## 10. Resetting synthetic demo data

- **Synthetic only (keeps real/demo records):** Administration → *Synthetic data and benchmark* → type the confirmation
  phrase, or `cd backend && python -m app.cli synthetic`. Only `SYN-*` institutions and synthetic officers/experts are removed.
- **Full rebuild (destructive, asks for confirmation):** `make reset-demo`.

## Repository layout

```
backend/app/{api,core,engines,models,services,workers}  backend/migrations  backend/tests
frontend/src/{components,layouts,pages,hooks,services,locales}  frontend/e2e
scripts/ (e2e scenario, demo documents, locust, dev server)   infra/ (nginx, audit anchor)   docs/ (benchmark, screenshots, openapi)
```
