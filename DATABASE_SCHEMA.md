# Database schema

PostgreSQL 16, managed by Alembic (`backend/migrations`, revisions 0001–0005). Tables below are generated from the SQLAlchemy models.

## Integrity features (migrations 0002/0003)

- `audit_log` and `audit_seals`: `BEFORE UPDATE OR DELETE` and `BEFORE TRUNCATE` triggers raise `audit_log is append-only`; `UPDATE/DELETE/TRUNCATE` revoked from PUBLIC.
- Row-level security (FORCE) on `obligations`, `evidence`, `institutional_documents`, `applications`: when `app.scope_institution` is set (institution users), only that institution's rows are visible or writable.
- Partial indexes on open work: `ix_obligations_open_due`, `ix_obl_open_assignee`, `ix_obl_open_inst`, `ix_sched_pending`, `ix_notif_queued`; GIN index on `clocks.calendar_ids`.
- Materialised view `mv_app_rollup` (+ `mv_refresh_log`) for dashboard aggregates, refreshed `CONCURRENTLY` by the scheduler every `dashboard.refresh.refresh_minutes`.
- Unique idempotency keys on `notifications` and `scheduled_actions`; unique `(clock_id, seq)` on `clock_events`; unique `(rule_key, version)` on `rules`.

## Core relationships

```
institutions ─┬─ applications ─┬─ application_events (movement log → process mining)
              │                └─ evc_visits ── evc_assignments ── experts
              ├─ obligations (Promise Ledger) ── clocks ── clock_events (deadline history)
              │        ├─ evidence ── files
              │        ├─ escalations ── posts / delegations / users
              │        └─ risk_scores
              ├─ institutional_documents (validity) ── files
              └─ institution_contacts ── notifications ── delivery_log
rules (versioned) ── config_versions (pinned by applications)   route_templates (versioned state machines)
audit_log (hash chain) ── audit_seals (signed daily heads) ── external anchor file;  audit_demo_log (isolated tamper demo)
```

## `audit_demo_log`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| ts | DATETIME | no |  |
| actor_id | INTEGER | yes |  |
| actor_role | VARCHAR(40) | yes |  |
| action | VARCHAR(60) | no |  |
| entity_type | VARCHAR(40) | no |  |
| entity_id | VARCHAR(60) | yes |  |
| before | JSONB | yes |  |
| after | JSONB | yes |  |
| reason | TEXT | yes |  |
| correlation_id | VARCHAR(64) | yes |  |
| prev_hash | VARCHAR(64) | no |  |
| hash | VARCHAR(64) | no |  |

## `audit_log`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| ts | DATETIME | no | indexed |
| actor_id | INTEGER | yes | indexed |
| actor_role | VARCHAR(40) | yes |  |
| action | VARCHAR(60) | no | indexed |
| entity_type | VARCHAR(40) | no | indexed |
| entity_id | VARCHAR(60) | yes | indexed |
| before | JSONB | yes |  |
| after | JSONB | yes |  |
| reason | TEXT | yes |  |
| correlation_id | VARCHAR(64) | yes |  |
| prev_hash | VARCHAR(64) | no |  |
| hash | VARCHAR(64) | no | unique |

## `audit_seals`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| day | DATE | no | unique |
| first_audit_id | BIGINT | no |  |
| last_audit_id | BIGINT | no |  |
| entry_count | INTEGER | no |  |
| head_hash | VARCHAR(64) | no |  |
| signature | VARCHAR(128) | no |  |
| anchored | BOOLEAN | no |  |
| created_at | DATETIME | no |  |

## `benchmark_runs`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| ran_at | DATETIME | no |  |
| scorecard | JSONB | no |  |

## `config_versions`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| created_at | DATETIME | no |  |
| reason | VARCHAR(200) | no |  |
| rule_ids | JSONB | no |  |

## `holiday_calendars`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| code | VARCHAR(40) | no | unique |
| name | VARCHAR(160) | no |  |
| scope | VARCHAR(20) | no |  |
| state | VARCHAR(60) | yes |  |
| weekend_days | JSONB | no |  |
| version | INTEGER | no |  |

## `notification_templates`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| key | VARCHAR(60) | no | indexed |
| language | VARCHAR(5) | no |  |
| version | INTEGER | no |  |
| subject | VARCHAR(240) | no |  |
| body | TEXT | no |  |
| is_active | BOOLEAN | no |  |
| translation_source | VARCHAR(40) | no |  |

## `route_templates`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| code | VARCHAR(40) | no | indexed |
| version | INTEGER | no |  |
| name | VARCHAR(160) | no |  |
| description | TEXT | no |  |
| definition | JSONB | no |  |
| source_type | VARCHAR(30) | no |  |
| is_active | BOOLEAN | no |  |
| created_at | DATETIME | no |  |

## `scheduled_actions`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| idempotency_key | VARCHAR(160) | no | unique |
| action_type | VARCHAR(40) | no | indexed |
| entity_type | VARCHAR(30) | yes |  |
| entity_id | INTEGER | yes |  |
| payload | JSONB | no |  |
| run_at | DATETIME | no | indexed |
| status | VARCHAR(12) | no | indexed |
| attempts | INTEGER | no |  |
| locked_by | VARCHAR(60) | yes |  |
| lease_expires_at | DATETIME | yes |  |
| last_error | TEXT | yes |  |
| done_at | DATETIME | yes |  |
| created_at | DATETIME | no |  |

## `holidays`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| calendar_id | INTEGER | no | indexed → holiday_calendars.id |
| day | DATE | no |  |
| name | VARCHAR(160) | no |  |

## `regions`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| code | VARCHAR(16) | no | unique |
| name | VARCHAR(120) | no |  |
| hq_city | VARCHAR(80) | no |  |
| lat | FLOAT | no |  |
| lon | FLOAT | no |  |
| states | JSONB | no |  |
| holiday_calendar_id | INTEGER | yes | → holiday_calendars.id |

## `institutions`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| aicte_id | VARCHAR(40) | no | unique indexed |
| name | VARCHAR(240) | no | indexed |
| region_id | INTEGER | no | indexed → regions.id |
| state | VARCHAR(60) | no | indexed |
| district | VARCHAR(80) | yes |  |
| tier | INTEGER | no |  |
| address | TEXT | yes |  |
| lat | FLOAT | yes |  |
| lon | FLOAT | yes |  |
| preferred_language | VARCHAR(5) | no |  |
| digest_enabled | BOOLEAN | no |  |
| responsiveness | FLOAT | no |  |
| is_synthetic | BOOLEAN | no | indexed |
| created_at | DATETIME | no |  |

## `posts`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| code | VARCHAR(40) | no | unique |
| title | VARCHAR(160) | no |  |
| level | INTEGER | no |  |
| region_id | INTEGER | yes | → regions.id |
| parent_post_id | INTEGER | yes | → posts.id |
| holder_user_id | INTEGER | yes | → users.id |
| is_synthetic | BOOLEAN | no |  |

## `users`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| email | VARCHAR(200) | no | unique indexed |
| full_name | VARCHAR(160) | no |  |
| password_hash | VARCHAR(200) | no |  |
| role | VARCHAR(40) | no | indexed |
| region_id | INTEGER | yes | → regions.id |
| institution_id | INTEGER | yes | → institutions.id |
| post_id | INTEGER | yes | → posts.id |
| phone | VARCHAR(32) | yes |  |
| preferred_language | VARCHAR(5) | no |  |
| totp_secret | VARCHAR(64) | yes |  |
| totp_enabled | BOOLEAN | no |  |
| failed_logins | INTEGER | no |  |
| locked_until | DATETIME | yes |  |
| is_active | BOOLEAN | no |  |
| is_synthetic | BOOLEAN | no |  |
| reset_token_hash | VARCHAR(128) | yes |  |
| reset_token_expires | DATETIME | yes |  |
| created_at | DATETIME | no |  |

## `applications`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| app_no | VARCHAR(40) | no | unique indexed |
| institution_id | INTEGER | no | indexed → institutions.id |
| application_type | VARCHAR(60) | no | indexed |
| academic_year | VARCHAR(10) | no |  |
| route_template_id | INTEGER | no | → route_templates.id |
| route_code | VARCHAR(40) | no | indexed |
| current_stage | VARCHAR(40) | no | indexed |
| status | VARCHAR(20) | no | indexed |
| assigned_officer_id | INTEGER | yes | indexed → users.id |
| stage_entered_at | DATETIME | no |  |
| stage_clock_id | INTEGER | yes | → clocks.id |
| institution_clock_id | INTEGER | yes | → clocks.id |
| parent_application_id | INTEGER | yes | → applications.id |
| merged_into_id | INTEGER | yes | → applications.id |
| config_version_id | INTEGER | yes | → config_versions.id |
| priority | VARCHAR(10) | no |  |
| decision | VARCHAR(40) | yes |  |
| decision_by | INTEGER | yes | → users.id |
| decision_at | DATETIME | yes |  |
| decision_note | TEXT | yes |  |
| ground_truth_route | VARCHAR(40) | yes |  |
| is_synthetic | BOOLEAN | no | indexed |
| created_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no | indexed |
| updated_at | DATETIME | no |  |

## `audit_verifications`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| ran_at | DATETIME | no |  |
| trigger | VARCHAR(20) | no |  |
| target | VARCHAR(20) | no |  |
| ok | BOOLEAN | no |  |
| checked | INTEGER | no |  |
| first_broken_id | BIGINT | yes |  |
| detail | TEXT | yes |  |
| seals_checked | INTEGER | no |  |
| duration_ms | FLOAT | no |  |
| run_by | INTEGER | yes | → users.id |

## `delegations`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| post_id | INTEGER | no | indexed → posts.id |
| delegate_user_id | INTEGER | no | → users.id |
| starts_on | DATE | no |  |
| ends_on | DATE | no |  |
| reason | VARCHAR(200) | no |  |
| created_by | INTEGER | yes | → users.id |
| revoked | BOOLEAN | no |  |

## `experts`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| name | VARCHAR(160) | no |  |
| expertise | JSONB | no |  |
| region_id | INTEGER | no | → regions.id |
| city | VARCHAR(80) | no |  |
| lat | FLOAT | no |  |
| lon | FLOAT | no |  |
| monthly_cap | INTEGER | no |  |
| unavailable_dates | JSONB | no |  |
| coi_institution_ids | JSONB | no |  |
| user_id | INTEGER | yes | → users.id |
| is_active | BOOLEAN | no |  |
| is_synthetic | BOOLEAN | no |  |

## `files`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| storage_key | VARCHAR(300) | no | unique |
| filename | VARCHAR(240) | no |  |
| mime | VARCHAR(80) | no |  |
| size | INTEGER | no |  |
| sha256 | VARCHAR(64) | no | indexed |
| scan_status | VARCHAR(20) | no |  |
| scan_engine | VARCHAR(160) | no |  |
| institution_id | INTEGER | yes | indexed → institutions.id |
| uploaded_by | INTEGER | yes | → users.id |
| purpose | VARCHAR(40) | no |  |
| created_at | DATETIME | no |  |

## `import_batches`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| adapter | VARCHAR(20) | no |  |
| entity | VARCHAR(30) | no |  |
| filename | VARCHAR(240) | yes |  |
| status | VARCHAR(20) | no |  |
| staged_rows | JSONB | no |  |
| errors | JSONB | no |  |
| duplicates | JSONB | no |  |
| counts | JSONB | no |  |
| dry_run | BOOLEAN | no |  |
| created_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |
| committed_at | DATETIME | yes |  |

## `institution_contacts`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| institution_id | INTEGER | no | indexed → institutions.id |
| role | VARCHAR(30) | no |  |
| name | VARCHAR(160) | no |  |
| email | VARCHAR(200) | yes |  |
| phone | VARCHAR(32) | yes |  |
| verified | BOOLEAN | no |  |
| invalid | BOOLEAN | no |  |
| invalid_reason | VARCHAR(200) | yes |  |
| user_id | INTEGER | yes | → users.id |

## `rules`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| rule_key | VARCHAR(80) | no | indexed |
| version | INTEGER | no |  |
| name | VARCHAR(200) | no |  |
| description | TEXT | no |  |
| rule_type | VARCHAR(40) | no |  |
| condition | JSONB | no |  |
| action | JSONB | no |  |
| params | JSONB | no |  |
| effective_from | DATE | yes |  |
| effective_to | DATE | yes |  |
| source_type | VARCHAR(30) | no |  |
| aph_edition | VARCHAR(40) | yes |  |
| section | VARCHAR(40) | yes |  |
| page | VARCHAR(20) | yes |  |
| citation | TEXT | yes |  |
| status | VARCHAR(20) | no | indexed |
| is_active | BOOLEAN | no |  |
| impact_preview | JSONB | yes |  |
| created_by | INTEGER | yes | → users.id |
| approved_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |
| approved_at | DATETIME | yes |  |

## `user_sessions`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| token_hash | VARCHAR(128) | no | unique indexed |
| user_id | INTEGER | no | indexed → users.id |
| created_at | DATETIME | no |  |
| last_seen_at | DATETIME | no |  |
| expires_at | DATETIME | no |  |
| revoked | BOOLEAN | no |  |
| mfa_passed | BOOLEAN | no |  |
| ip | VARCHAR(64) | yes |  |

## `application_events`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| application_id | INTEGER | no | indexed → applications.id |
| event_type | VARCHAR(30) | no | indexed |
| from_stage | VARCHAR(40) | yes |  |
| to_stage | VARCHAR(40) | yes |  |
| actor_id | INTEGER | yes | → users.id |
| reason | TEXT | yes |  |
| reason_code | VARCHAR(40) | yes | indexed |
| payload | JSONB | no |  |
| at | DATETIME | no | indexed |

## `clocks`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| owner_side | VARCHAR(12) | no |  |
| label | VARCHAR(160) | no |  |
| budget_days | INTEGER | no |  |
| day_mode | VARCHAR(10) | no |  |
| calendar_ids | JSONB | no |  |
| revert_policy | VARCHAR(30) | no |  |
| state | VARCHAR(24) | no | indexed |
| started_at | DATETIME | no |  |
| due_date | DATE | yes | indexed |
| source_rule_id | INTEGER | yes | → rules.id |
| application_id | INTEGER | yes | indexed → applications.id |
| computed_at | DATETIME | yes |  |

## `extraction_jobs`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| file_id | INTEGER | no | → files.id |
| application_id | INTEGER | yes | → applications.id |
| institution_id | INTEGER | no | indexed → institutions.id |
| letter_date | DATE | yes |  |
| text_method | VARCHAR(120) | no |  |
| extractor | VARCHAR(60) | no |  |
| status | VARCHAR(20) | no |  |
| full_text | TEXT | no |  |
| rejected_count | INTEGER | no |  |
| log | JSONB | no |  |
| created_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |

## `notifications`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| idempotency_key | VARCHAR(160) | no | unique |
| recipient_user_id | INTEGER | yes | indexed → users.id |
| recipient_contact_id | INTEGER | yes | → institution_contacts.id |
| institution_id | INTEGER | yes | indexed → institutions.id |
| channel | VARCHAR(12) | no |  |
| address | VARCHAR(200) | yes |  |
| template_key | VARCHAR(60) | no | indexed |
| template_version | INTEGER | no |  |
| language | VARCHAR(5) | no |  |
| subject | VARCHAR(240) | no |  |
| body | TEXT | no |  |
| status | VARCHAR(12) | no | indexed |
| attempts | INTEGER | no |  |
| next_attempt_at | DATETIME | yes | indexed |
| entity_type | VARCHAR(30) | yes |  |
| entity_id | INTEGER | yes |  |
| provider | VARCHAR(40) | yes |  |
| error | TEXT | yes |  |
| fallback_of_id | BIGINT | yes |  |
| created_at | DATETIME | no | indexed |
| sent_at | DATETIME | yes |  |
| delivered_at | DATETIME | yes |  |
| read_at | DATETIME | yes |  |
| is_synthetic | BOOLEAN | no |  |

## `clock_events`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| clock_id | INTEGER | no | indexed → clocks.id |
| seq | INTEGER | no |  |
| kind | VARCHAR(20) | no |  |
| pause_kind | VARCHAR(24) | yes |  |
| at | DATETIME | no |  |
| days | INTEGER | yes |  |
| policy | VARCHAR(30) | yes |  |
| actor_id | INTEGER | yes | → users.id |
| reason | TEXT | yes |  |

## `delivery_log`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | BIGINT | no | PK |
| notification_id | BIGINT | no | indexed → notifications.id |
| channel | VARCHAR(12) | no |  |
| provider | VARCHAR(40) | no |  |
| address | VARCHAR(200) | yes |  |
| payload | JSONB | no |  |
| outcome | VARCHAR(20) | no |  |
| at | DATETIME | no |  |

## `obligations`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| obl_no | VARCHAR(40) | no | unique indexed |
| institution_id | INTEGER | no | indexed → institutions.id |
| application_id | INTEGER | yes | indexed → applications.id |
| obligation_type | VARCHAR(40) | no | indexed |
| title | VARCHAR(300) | no |  |
| description | TEXT | no |  |
| responsible_role | VARCHAR(40) | no |  |
| responsible_party | VARCHAR(12) | no |  |
| assigned_user_id | INTEGER | yes | indexed → users.id |
| assigned_post_id | INTEGER | yes | → posts.id |
| source_event | VARCHAR(60) | no |  |
| source_rule_id | INTEGER | yes | → rules.id |
| source_document_id | INTEGER | yes | → files.id |
| source_text | TEXT | yes |  |
| evidence_requirements | JSONB | no |  |
| start_date | DATE | no |  |
| due_date | DATE | yes | indexed |
| clock_id | INTEGER | yes | → clocks.id |
| state | VARCHAR(20) | no | indexed |
| priority | VARCHAR(10) | no |  |
| priority_override | FLOAT | yes |  |
| priority_override_reason | TEXT | yes |  |
| statutory_flag | BOOLEAN | no |  |
| verification_status | VARCHAR(30) | no |  |
| escalation_level | INTEGER | no |  |
| acknowledged_at | DATETIME | yes |  |
| completed_at | DATETIME | yes |  |
| closure_note | TEXT | yes |  |
| closed_by | INTEGER | yes | → users.id |
| merged_into_id | INTEGER | yes | → obligations.id |
| is_synthetic | BOOLEAN | no | indexed |
| created_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |
| updated_at | DATETIME | no |  |

## `escalations`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| obligation_id | INTEGER | no | indexed → obligations.id |
| level | INTEGER | no |  |
| previous_recipient_id | INTEGER | yes | → users.id |
| new_recipient_id | INTEGER | yes | indexed → users.id |
| target_post_id | INTEGER | yes | → posts.id |
| resolution_path | JSONB | no |  |
| reason | TEXT | no |  |
| status | VARCHAR(20) | no | indexed |
| notification_id | BIGINT | yes |  |
| triggered_at | DATETIME | no |  |
| closed_at | DATETIME | yes |  |
| closure_note | TEXT | yes |  |

## `evc_visits`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| application_id | INTEGER | no | indexed → applications.id |
| institution_id | INTEGER | no | indexed → institutions.id |
| status | VARCHAR(20) | no | indexed |
| required_expertise | JSONB | no |  |
| proposal | JSONB | yes |  |
| panel_expert_ids | JSONB | no |  |
| proposed_date | DATE | yes |  |
| scheduled_date | DATE | yes |  |
| visited_at | DATETIME | yes |  |
| report_file_id | INTEGER | yes | → files.id |
| report_received_at | DATETIME | yes |  |
| findings | JSONB | no |  |
| override_reason | TEXT | yes |  |
| delayed_reason | TEXT | yes |  |
| schedule_obligation_id | INTEGER | yes | → obligations.id |
| report_obligation_id | INTEGER | yes | → obligations.id |
| reschedule_count | INTEGER | no |  |
| is_synthetic | BOOLEAN | no |  |
| created_at | DATETIME | no |  |

## `evidence`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| receipt_no | VARCHAR(40) | no | unique |
| obligation_id | INTEGER | no | indexed → obligations.id |
| institution_id | INTEGER | no | indexed → institutions.id |
| file_id | INTEGER | yes | → files.id |
| channel | VARCHAR(20) | no |  |
| note | TEXT | yes |  |
| status | VARCHAR(40) | no |  |
| ocr_status | VARCHAR(20) | no |  |
| ocr_text | TEXT | yes |  |
| submitted_by | INTEGER | yes | → users.id |
| submitted_at | DATETIME | no |  |
| reviewed_by | INTEGER | yes | → users.id |
| reviewed_at | DATETIME | yes |  |
| review_reason | TEXT | yes |  |

## `extraction_items`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| job_id | INTEGER | no | indexed → extraction_jobs.id |
| kind | VARCHAR(30) | no |  |
| title | VARCHAR(300) | no |  |
| description | TEXT | no |  |
| source_sentence | TEXT | no |  |
| source_offset | INTEGER | yes |  |
| due_text | VARCHAR(120) | yes |  |
| due_date | DATE | yes |  |
| responsible_role | VARCHAR(40) | no |  |
| evidence_requirement | TEXT | yes |  |
| obligation_type | VARCHAR(40) | no |  |
| confidence | FLOAT | no |  |
| status | VARCHAR(20) | no |  |
| edited | BOOLEAN | no |  |
| obligation_id | INTEGER | yes | → obligations.id |
| reviewed_by | INTEGER | yes | → users.id |
| reject_reason | TEXT | yes |  |

## `institutional_documents`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| institution_id | INTEGER | no | indexed → institutions.id |
| doc_type | VARCHAR(60) | no |  |
| issue_date | DATE | yes |  |
| expiry_date | DATE | yes | indexed |
| file_id | INTEGER | yes | → files.id |
| ocr_text | TEXT | yes |  |
| ocr_result | JSONB | yes |  |
| extraction_confidence | FLOAT | yes |  |
| ocr_status | VARCHAR(40) | no |  |
| verification_status | VARCHAR(20) | no |  |
| verified_by | INTEGER | yes | → users.id |
| verified_at | DATETIME | yes |  |
| obligation_id | INTEGER | yes | → obligations.id |
| previous_document_id | INTEGER | yes | → institutional_documents.id |
| is_current | BOOLEAN | no |  |
| is_synthetic | BOOLEAN | no |  |
| uploaded_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |

## `magic_links`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| token_hash | VARCHAR(128) | no | unique |
| obligation_id | INTEGER | no | → obligations.id |
| contact_id | INTEGER | yes | → institution_contacts.id |
| expires_at | DATETIME | no |  |
| used_at | DATETIME | yes |  |
| opened_count | INTEGER | no |  |
| created_by | INTEGER | yes | → users.id |
| created_at | DATETIME | no |  |

## `risk_scores`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| obligation_id | INTEGER | no | PK → obligations.id |
| probability | FLOAT | yes |  |
| level | VARCHAR(20) | no |  |
| reasons | JSONB | no |  |
| sample_size | INTEGER | no |  |
| segment | VARCHAR(120) | no |  |
| suggested_reminder | DATE | yes |  |
| computed_at | DATETIME | no |  |

## `evc_assignments`

| Column | Type | Null | Key / FK |
|---|---|---|---|
| id | INTEGER | no | PK |
| visit_id | INTEGER | no | indexed → evc_visits.id |
| expert_id | INTEGER | no | indexed → experts.id |
| visit_date | DATE | no | indexed |
| active | BOOLEAN | no |  |

