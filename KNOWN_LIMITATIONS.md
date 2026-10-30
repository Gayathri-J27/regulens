# Known limitations

Stated plainly so nothing in the prototype is mistaken for a capability it does not have.

## Not executed / not connected in this build environment

| Item | Status |
|---|---|
| Docker Compose stack | Dockerfiles, `docker-compose.yml` and nginx config are written, but the build sandbox has **no Docker daemon**, so the containerised stack was **not run**. Everything was built and tested natively (PostgreSQL 16, Python 3.13, Node 22). |
| AICTE systems | No connection. CSV and synthetic adapters work; the API adapter is a documented, testable **stub** (`/api/admin/integration/v1/{entity}`). |
| LLM extraction | No API key was available. Extraction ran with the **local rule-based extractor** (labelled `LOCAL_RULE_BASED (no LLM)` in the UI and audit). The Anthropic adapter is implemented but **untested against the live API**. Validation gates apply to both. |
| PaddleOCR | Not installed (large download). **Tesseract** (after OpenCV deskew/denoise) is the primary engine. "Engine agreement" therefore uses the PDF text layer when present, otherwise a **second Tesseract pass with different page segmentation** — labelled as "same engine" in the OCR result. Install PaddleOCR to get true two-engine agreement (auto-detected). |
| ClamAV | Not available. Uploads are scanned by a clearly labelled **local signature fallback** (EICAR + active-PDF heuristics). Set `CLAMD_HOST` to use clamd (`INSTREAM`); the Compose file includes a ClamAV service. |
| MinIO / S3 | The S3 adapter (with server-side encryption) is implemented but was **not exercised**; tests used local storage. |
| Email / SMS / WhatsApp | Development adapters: email captured in a dev mailbox (`delivery_log`), SMS hand-off logged with a **simulated delivery receipt**, WhatsApp preview only (stays SENT). SMTP sending is implemented but untested here. |
| External audit trust anchor | Daily signed heads are appended to a local append-only file (`infra/audit-anchor/daily-heads.jsonl`). Compose creates an object-locked MinIO bucket, but **writing anchors to it is not implemented** — the file anchor is a development stand-in. |
| TLS | Configured at the ingress (nginx sends HSTS); not exercised locally. |
| Real browser fonts | Google Fonts were blocked in the sandbox; screenshots show system fallback fonts. |

## Regulatory content

- **No rule is marked HANDBOOK_CONFIRMED.** APH clause/page references were not verified, so every deadline, reminder offset,
  escalation timeline and route budget is an administrator-configurable default, labelled `CONFIGURABLE_PARAMETER`.
- **Holiday calendars are illustrative** (national, eight Regional offices, seven States) and must be replaced with
  official gazette lists.
- Routes and application-type mappings are plausible defaults, not taken from the APH.

## Language and accessibility

- Hindi, Marathi and Tamil notification templates and UI strings were **drafted by the developer (AI-assisted), not by
  native speakers**; they are stored as fixed versioned text (never machine-translated at send time) and flagged
  `DRAFT_REQUIRES_HUMAN_REVIEW`.
- Translation covers navigation, common controls and the institution portal; officer screens are largely English.
- WCAG 2.1 AA was the design target (keyboard focus, labels, text+glyph status badges, reduced motion), but **no formal
  audit** (axe, screen reader) was run.

## Scale and performance

- Measured on a shared 2-vCPU sandbox with the load generator on the same machine (see TEST_REPORT): dashboard p95
  **480 ms at 50 concurrent users** (target < 500 ms met narrowly), 170 ms at 20 users; uploads ~144/min.
- The dataset was ~20.7k obligations / 6k applications. The design target (200k obligations, 1,000 concurrent users) is
  supported by indexes, MV aggregates and stateless API workers but **was not load-tested at that size**.
- Rate limiting is per API process (in memory); behind several replicas it should move to Redis or the gateway.

## Functional simplifications

- Synthetic generator: 20,701 obligations versus the 18,000 target (stage-history obligations dominate); all planted
  faults match exactly (300 / 200 / 150).
- Process-mining "delay beyond budget" converts working-day budgets to calendar days with a 1.4 factor (approximation).
- Risk model is an empirical-CDF model with stated modifiers; it has not been calibrated against real AICTE history,
  and the impact calculator therefore **does not claim** a deadline-miss reduction.
- The officer review UI shows the PDF in the browser's viewer; sentence highlighting is on the extracted text panel,
  not drawn on the PDF page (OCR word boxes are drawn on image scans of documents).
- Bearer tokens live in `sessionStorage` (no cookies → CSRF not applicable); XSS risk is mitigated by React escaping and
  API CSP, but an httpOnly-cookie session would be stronger for production.
- Retention purge covers sessions, delivery logs and notifications; the audit log is never purged by the application
  (archival per `audit_years` is an operational procedure).
- Integration tests and the E2E scenario create additional synthetic-labelled institutions on each run; use
  `make reset-demo` for a clean demo database.
