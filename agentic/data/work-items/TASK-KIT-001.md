# TASK-KIT-001: Strengthen the kit and add device preview

## Request and scope

User requests: “add some skill for emulator, simulator run for in device preview” and “Specialist skill, Runtime enforcement, Documentation and adoption updates these”. This follows the kit audit's findings about generic skill bodies, unguarded transitions, non-atomic checkpoints, and misleading eval passes.

Classification: technical change, TASK_ONLY, NO_REPLAN. The task is local implementation and validation; it does not authorize deployment or invent human approval records.

## Requirements and evidence

| ID | Acceptance criterion | Implementation / verification |
|---|---|---|
| KIT-01 | Android/iOS previews use explicit targets, launch checks, screenshots, visual inspection, and partial/blocker reporting | [Device skill](../../skills/device-preview-agent/SKILL.md), linked command references; skill/link/registry validation |
| KIT-02 | Specialists have distinct procedures, deliverables, and readiness boundaries | [Catalog](../../SKILL-CATALOG.md), [handoff contract](../../skills/RESULT-CONTRACT.md); structural and skill validation |
| KIT-03 | Unknown/skip transitions, missing evidence/gates, terminal execution, and stale context are denied | [Orchestrator](../../runtime/python/agentic_runtime/orchestrator.py); [tests](../../kit/runtime/tests/test_runtime.py) `test_order_and_evidence_are_required`, `test_stale_and_deleted_context_rejected`, `test_rejection_and_revocation_prevent_implementation` (verified passing via `validate-kit.sh` on 2026-09-18) |
| KIT-04 | Run, checkpoint, and audit changes roll back together on persistence failure | [Store](../../runtime/python/agentic_runtime/store.py); [test](../../kit/runtime/tests/test_runtime.py) `test_checkpoint_failure_rolls_back_run_audit_and_timing` (verified passing via `validate-kit.sh` on 2026-09-18) |
| KIT-05 | Trusted adapter/tool execution checks pins, capabilities, retries, time/call budgets, cancellation, and idempotency; dry runs suppress declared effects | [Runtime guide](../../runtime/README.md); [tests](../../kit/runtime/tests/test_runtime.py) `test_dry_run_suppresses_gateway_and_denies_native_effects`, `test_retry_deadline_and_tool_budget`, `test_cancellation_rejects_late_result`, `test_idempotency_and_failed_effect_replay`, `test_config_and_skill_pins_reject_changes` (verified passing via `validate-kit.sh` on 2026-09-18) |
| KIT-06 | Evaluations compare real outputs and fail on wrong/empty/unknown cases | DONE (2026-09-18) — [eval runner](../../kit/runtime/python/agentic_runtime/evals.py), `eval-check` CLI command ([runtime guide](../../kit/runtime/README.md#evaluations)); [tests](../../kit/runtime/tests/test_evals.py) `test_wrong_status_fails`, `test_empty_evidence_on_ready_fails`, `test_unknown_status_fails`, `test_missing_actual_output_fails_rather_than_being_skipped`, plus `test_suite_distinguishes_good_from_bad_output_for_the_same_case` guarding against exactly the "misleading eval pass" failure mode this task's own request named (verified passing via `validate-kit.sh`, 42/42 tests) |
| KIT-07 | Adoption, upgrade, local trust boundary, limitations, and a runnable example are documented | [Adoption](../../ADOPTION.md), [demo](../../examples/runtime-demo.py), validation script and CI workflow |

## Design boundaries

Use the existing Python standard-library runtime, with per-run persistence as plain JSON files (`agentic/kit/runtime/python/agentic_runtime/store.py` — deliberately not SQLite, per commit `fcb5aab`). Add coarse ordered routes and a cooperative trusted-adapter API, with transactional local state. Do not introduce a model provider, cloud service, deployment path, automatic human identity, or simulated claims of real device testing. The result contract validates shape and presence of evidence; semantic coverage remains a reviewer/orchestrator responsibility.

## Validation and handoff

Run `sh agentic/kit/scripts/validate-kit.sh` for structure, the isolated synthetic demo, and the behavioral test suite (42 tests across `test_runtime.py`, `test_adoption.py`, `test_delivery.py`, `test_production.py`, `test_hooks.py`, `test_evals.py` — passing on 2026-09-18; this corrects an earlier, inaccurate note in this file that the suite had been removed). The KIT-06 eval runner (`agentic_runtime/evals.py`, `eval-check` CLI command) was added on 2026-09-18 to close a gap this file previously and correctly flagged as genuinely missing. Device command references are checked against official Android/Flutter guidance and installed Xcode command help; actual mobile-app execution is outside this kit-only change. Hosted CI has not been run locally.

Task timing is recorded through RuntimeStore in a task-local temporary database. No production release is part of this work item.
