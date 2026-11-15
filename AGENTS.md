# Agentic Development Instructions

This file is the canonical repository-level instruction entrypoint for agentic development.

## Core behavior

1. On session start, check for a midflight task before doing anything else (enforced by the `SessionStart` hook, `agentic/kit/runtime/hooks/session_start_check.py`): if `agentic/data/runtime/state/active-task.json` exists, or the run DB has a run with status `RUNNING`/`BLOCKED`, resume it — do not start a new run for that work item. Only start the next work item once nothing is midflight. On a CLI without hook support, run that script yourself as the first action of the session.
2. When compaction is imminent (surfaced by the `PreCompact` hook, `agentic/kit/runtime/hooks/precompact_checkpoint.py`, or on your own judgment if your CLI has no hook support), update every doc this session touched — work-item status, README/AGENTS notes, any tracked plan — before the turn ends, and scope any remaining work down to the smallest subtask that can actually finish rather than starting something large.
3. Treat the current repository as the source project.
4. Use `agentic/data/project-context/` before performing broad discovery.
5. If context is available and sufficiently fresh, reuse it.
6. If context is stale or missing, refresh only the affected module or feature scope.
7. Do not audit the whole repository for every task.
8. Prefer existing implementations, shared components, and established architectural patterns.
9. Never invent missing business rules.
10. Never infer human approval.
11. Route work through the appropriate workflow in `agentic/kit/workflows/`.
12. Use skills under `agentic/kit/skills/` as reusable specialist workflows.
13. Record agent start/end timing and relevant task telemetry through the harness.
14. Preserve traceability from request -> requirements -> design -> tasks -> implementation -> QA -> release.

## Input modes

The system supports both:

- Prompt-first: a developer describes a feature, CR, bug, or hotfix in a prompt.
- Document-first: a developer points to an existing FEATURE.md, CR.md, BUG.md, or HOTFIX.md.

Both modes must normalize into a canonical work item before downstream execution.

## Project types

- Greenfield: use the full feature lifecycle.
- Brownfield/legacy: use context-first, incremental discovery and baseline recovery only where needed.

## Routing authority

The Workflow Orchestrator is the final authority for selecting the next skill based on:
- work type
- workflow stage
- context availability
- impact
- policy
- approvals

## Universal planning rule

Do not decide hierarchy or Sprint Planning from request type alone. For Features, CRs, bugs, hotfixes, and technical changes, classify the minimum useful work level and then choose sprint handling. Full Sprint Planning is conditional. Existing approved tasks should execute without recreating Feature/Epic/Story artifacts or replanning unless impact changes materially.

## Harness runtime

When the reference runtime is enabled, treat workflow state, approvals, policies, context freshness, capability limits, checkpoints, and task timing as deterministic harness responsibilities. Do not substitute model judgment for these controls.


<!-- agentic-kit:start -->
# Agentic kit workflow

Use `agentic/README.md` and `agentic/kit/workflows/routing.md` for lifecycle routing.
Load relevant `agentic/data/project-context/` before discovering affected code.
Reuse existing patterns and refresh only stale context needed for the request.
Classify the minimum useful work hierarchy; sprint planning is conditional.
Preserve traceability from the request through requirements, implementation, QA,
and release evidence. Generated artifacts and host work items belong under
`agentic/data/`; reusable skills, templates, and runtime belong under `agentic/kit/`.
Never infer missing business rules or human approval.

Instruction mode guides agent behavior. In local-harness mode, use the runtime
task protocol and verify installation with its `doctor` command. Before starting
new work, run `python3 agentic/kit/runtime/hooks/session_start_check.py` when the
agent platform has no SessionStart hook. Resume midflight work before starting
another run. Unknown or damaged state requires explicit recovery.

Record execution timing through the harness. Before compaction, checkpoint
active work and update affected task/context documents with remaining work.
<!-- agentic-kit:end -->

# OpenReader & universal_document_viewer development guidelines

Applies to every analysis, implementation, refactor, test and release across the **OpenReader** app and the **universal_document_viewer** Flutter package ("the Kit").

## 1. Feature ownership: decide before implementing

Put a feature in the **Kit** when it provides generic document viewing, is reusable by other Flutter apps, improves the package's core capabilities, and needs no OpenReader-specific logic.

Put it in **OpenReader** when it is specific to the product experience, app-level business logic or workflow, OpenReader UI/navigation/state, or has no meaningful value to other Kit users.

Not every document feature belongs in the Kit. When it could go either way, keep it in OpenReader.

## 2. Public package stability

The Kit is a public pub.dev package. Before changing it:

- Review its public APIs and their usage; preserve backward compatibility; avoid breaking changes.
- Avoid new dependencies; keep APIs generic, configurable and reusable.
- Never add OpenReader-specific logic, assumptions or workarounds.
- Consider regressions for existing consumers; follow Flutter/Dart package conventions.
- Add or update tests; update docs and examples when public APIs change.

## 3. Local repository setup

Keep both repositories as **siblings** under one root (`openreader/` and `universal_document_viewer/`). If the Kit is not cloned, clone it into OpenReader's parent directory, never inside OpenReader. Reuse an existing clone; verify both repos are on the intended branches before changing anything.

## 4. Development dependency

Develop against the local Kit with a path dependency, kept in the git-ignored `pubspec_overrides.yaml` (`universal_document_viewer: path: ../universal_document_viewer`). Use it only for development and testing; never commit or release it; track which unpublished Kit changes OpenReader depends on.

## 5. Release dependency rules

OpenReader releases **always** use the published pub.dev version of the Kit.

1. Never release with a local path dependency or an unpublished Git commit/branch.
2. If a needed Kit feature is unpublished, stop and wait for the Kit release. Do not copy Kit code into the app or add temporary workarounds.
3. Verify the required Kit version is on pub.dev, update OpenReader's constraint, run `flutter pub get`, and confirm `pubspec.yaml` and `pubspec.lock` hold the release configuration.
4. Run tests and release checks before releasing.

Sequence: implement Kit feature -> test Kit alone -> integrate and test locally with OpenReader -> publish Kit -> verify it is on pub.dev -> update OpenReader to it -> test -> release OpenReader.

## 6. Analysis before changes

Inspect the structure and relevant code, check whether the functionality already exists, identify which repo owns the feature, review existing UI/UX, and list regression and compatibility risks. Do not assume a feature is missing, add needless architecture, or duplicate implementations.

## 7. Implementation and testing

Follow existing architecture and conventions; prefer small focused changes; avoid needless abstractions and dependencies; preserve UI/UX unless a redesign is requested; keep the Kit free of app code; document public APIs; add meaningful tests; test in isolation and through OpenReader; check for regressions. Change the Kit from OpenReader work only when the functionality genuinely belongs there.

## 8. Final verification

Before calling a task done, confirm: ownership was evaluated; changes are in the right repo; existing behaviour is preserved; no unnecessary Kit breaking changes; public APIs stay generic; tests pass; OpenReader integration works; no unintended dependency/config changes; the release dependency is the published version; any new Kit version is actually published before an OpenReader release.

## 9. Principles

Analyze first. Protect the Kit. Keep responsibilities separate. Develop locally with sibling clones. Release only against published packages. Wait for publication when needed. Never compromise stability with temporary release workarounds.
