# ReguLens AI — developer commands (native Postgres or `make up` for Docker Compose)
PY ?= python3
.PHONY: install migrate bootstrap synthetic reset-demo dev api web worker test test-backend test-frontend e2e e2e-browser benchmark load screenshots up down

install:            ## install backend + frontend dependencies
	pip install -r backend/requirements-dev.txt
	cd frontend && npm ci
migrate:            ## apply database migrations
	cd backend && alembic upgrade head
bootstrap:          ## reference data + demo accounts
	cd backend && $(PY) -m app.cli bootstrap
synthetic:          ## regenerate bulk synthetic data (fixed seed) and run sweeps
	cd backend && $(PY) -m app.cli synthetic && $(PY) -m app.cli sweep
reset-demo:         ## DESTRUCTIVE: drop and rebuild the whole local database
	@read -p "Drop the local regulens database? [y/N] " a && [ "$$a" = y ]
	cd backend && $(PY) -c "from sqlalchemy import create_engine,text;from app.core.config import settings;e=create_engine(settings.database_url);c=e.connect();c.execute(text('DROP SCHEMA public CASCADE; CREATE SCHEMA public'));c.commit()"
	$(MAKE) migrate bootstrap synthetic
	$(PY) scripts/make_demo_docs.py
api:                ## API with in-process scheduler on :8000
	cd backend && uvicorn app.main:app --reload --port 8000
worker:             ## standalone scheduler worker
	cd backend && $(PY) -m app.cli worker
web:                ## frontend dev server on :5173 (proxies /api)
	cd frontend && npm run dev
test: test-backend test-frontend
test-backend:       ## unit + property + integration (uses database regulens_test)
	cd backend && $(PY) -m pytest -q
test-frontend:
	cd frontend && npx vitest run
e2e:                ## 65-step end-to-end scenario against a running API
	$(PY) scripts/e2e_scenario.py http://localhost:8000
e2e-browser:        ## Playwright browser tests against the built frontend (vite preview on :4173)
	cd frontend && npx playwright test
benchmark:          ## six-criteria scorecard -> docs/benchmark/scorecard.{json,md}
	cd backend && RUN_SCHEDULER=0 $(PY) -m app.cli benchmark
load:               ## 60 s Locust run, 50 users
	locust -f scripts/locustfile.py --headless -u 50 -r 10 -t 60s --host http://localhost:8000 --csv .run/load
screenshots:
	cd frontend && node e2e/screens.mjs http://localhost:4173 ../docs/screenshots
up:                 ## Docker Compose stack (Postgres, MinIO, ClamAV, API, worker, web on :8080)
	docker compose up --build -d && docker compose exec api python -m app.cli synthetic && docker compose exec api python -m app.cli sweep
down:
	docker compose down
