# Demo walkthrough (about 20 minutes)

Start the stack (README §6), open http://localhost:5173. Every demo password is `Demo@1234`; the login page lists the
accounts — click one to fill the form. Fictional files for uploads are in `demo_docs/`.

The whole journey can also be run headless in one command, printing each of the 64 scenario steps:
`python scripts/e2e_scenario.py` (sample output: [docs/e2e_scenario_log.txt](docs/e2e_scenario_log.txt)).

## 1. The regional picture — `ro.south@regulens.demo`
1. **Overview**: Southern Region KPIs, stage pendency, deadlines by week, missed-deadline trend, officer workload. Note the
   caption: figures come from the materialised view or a live query. Change a filter (e.g. Status = Returned) — the
   source switches to *live query*.
2. **Today's 10**: ranked actions with *why* and *next action*; the formula and weights are shown underneath. Click **Nudge now**.

## 2. Application workflow (Scenario A)
1. **Applications → Register application** → Kaveri Institute, type *Increase in intake*, route *By rule* → the route
   rule assigns *Scrutiny + EVC*. Assign to Meera Pillai.
2. Sign in as `bureau@regulens.demo`, open the application: **Complete Scrutiny** without remarks is refused (required field).
   Use **Return to institution** with a reason: the stage clock pauses (*waiting on institution*) and an institution-side clock starts.
3. Sign in as `principal@kaveri-demo.in` → **Applications** → open it → **Resubmit application**. Back as the officer,
   open the stage obligation: the **clock strip** shows the hatched institution pause, and **Why this date?** explains it.
4. Complete scrutiny (with remarks) → the EVC visit is queued automatically.

## 3. EVC (Scenario A, steps 7–9)
`ro.south` → **EVC management** → the new visit → pick a weekday → **Rank eligible experts**: three panels with
scores and coverage; the right column lists every excluded expert and why (including the declared conflict of interest
for Dr. Sujatha Rao). **Approve panel and schedule**. Record the visit, upload a report with a finding and proposed
undertaking, then **Confirm → create undertaking** — it appears in the Promise Ledger.

## 4. Decision (human only)
Complete the EVC stage; the application waits for a decision. `ro.south` cannot decide (button absent; API returns 403).
Sign in as `authority@regulens.demo` → **Record decision** → *Approved with conditions* + note.

## 5. Approval letter → ledger (Scenario B)
`ro.south` → **Undertakings** → choose Kaveri → upload `demo_docs/approval_letter_scanned.pdf` (a skewed, noisy scan).
The review screen states the extractor honestly (*LOCAL_RULE_BASED (no LLM)* without an API key), shows each proposal
with its quoted source sentence (click a card to highlight it in the letter text), resolved deadlines, and one undertaking
with **no stated deadline** — the system will not invent one; set the date and accept. Accepted items become ledger
obligations with running clocks and notify the institution.

## 6. Institution compliance (Scenario C)
`principal@kaveri-demo.in` → **My institution**: health card, open requirements. **Acknowledge**, then **Upload
evidence** (`demo_docs/evidence_fire_noc.pdf`) → receipt number. Settings → *Simple language* enlarges text and simplifies
portal wording; switch language to தமிழ் or हिन्दी. Back as `ro.south`, the evidence notification is in the inbox;
**Verify** (or reject — a reason is mandatory) → obligation MET, clock stopped.

## 7. Deadline engine (Scenario D)
`admin@regulens.demo` → **Administration → Holiday calendars → AICTE Southern Region** → add a holiday before a
running due date. The toast reports how many clocks were recomputed and moved. Open an affected obligation: the new due
date, the holiday listed in **Why this date?**, and the clock history.

## 8. Document validity (Scenario E)
`ro.south` → **Document validity** → upload `demo_docs/lease_deed_scan.png` (rotated, noisy). The detail page shows
the scan with the detected date boxed, OCR confidence, deskew angle and agreement source; the expiry is **not** recorded
until the officer confirms or corrects it. Confirm → a lease-renewal obligation with advance reminders (90/60/30/7 days).
Then **Submit renewed document** with `lease_deed_renewal.png` and confirm → the old renewal obligation closes.

## 9. Notifications and escalation (Scenario F)
**Promise Ledger → New obligation**, start date 45 days ago, budget 30 → overdue. **Escalations → Run escalation sweep
now** (as admin). Sign in as `dd.south@regulens.demo`: the escalation is on *Escalations* and in *Today's 10*. The
resolution path (holder / delegate / nearest Region / next level) is stored. **Notifications → All messages** (admin or
regional officer): delivery states, retries, bounces to `.invalid` contacts and their SMS fallbacks, delivery log per message.
**Administration → Posts and delegations → Vacate** a post and ask *Who receives escalations?* to see the nearest-Region fallback.

## 10. Intelligence (Scenario G)
- **Process mining**: findings computed from the event log — the planted bottlenecks appear (Eastern Region EVC and
  Northern Region re-scrutiny ≈ 1.7× the cross-Region median), loop-back heat map, deficiency reasons, variants vs prescribed routes.
- **Breach forecast**: miss probability, top three reasons, sample size and segment, suggested reminder date; **Nudge now**.
  *Capacity* tab: 4-week due load and reassignment *suggestions* (never applied automatically).
- **Rule simulator** (admin): try `deadline.SCRUTINY_COMPLETION` with `{"budget_days": 10}` → deadlines changed,
  new breaches, back-test, workload shift. *Impact calculator* tab: low/base/high scenarios, clearly labelled as modelled.
- **Administration → Rules**: create a new version → *Preview impact* → the author cannot approve; sign in as
  `admin2@regulens.demo` to approve. The configuration version increments; existing cases keep theirs.

## 11. Security and audit (Scenario H)
1. As `ro.west@regulens.demo`, paste the URL of a Southern Region application → *Not permitted*.
2. `auditor@regulens.demo` → **Audit trail** → **Verify chain** (entries checked, signed daily heads). Click an entry for
   before/after JSON and hashes. **Try to edit a production entry** → blocked by the database trigger.
   **Run tamper demonstration** → isolated 20-entry chain intact, one entry silently altered, verification fails at exactly that entry.

## 12. Reports and benchmark
**Reports**: 14 reports with filters; CSV/PDF export (logged). **Administration → Synthetic data and benchmark** →
**Run benchmark** for the six-criteria scorecard.
