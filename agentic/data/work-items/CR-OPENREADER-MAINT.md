# CR-OPENREADER-MAINT: repository hygiene and README accuracy

## Status
**Backlog.** Created 2026-11-13 from a feature/gap audit of the repo against README.md. Not started, no run, no technical plan.

## Request (user, 2026-11-13)
"add these next work list" — the four quick wins identified in the audit:
add a LICENSE, remove unused dependencies, add a CI job for `flutter analyze` + `flutter test`, fix stale README lines.

## Scope

### 1. Add a LICENSE file
- README.md:179 and the website call the project "open source", but no licence file exists.
- Pick the licence with the maintainer (MIT or Apache-2.0 fits the deps; `universal_document_viewer` is MIT).
- Add it, then update the Licence section in README.md to state the grant.
- Note: GitHub Releases/publishing depend on this being real.

### 2. Remove unused dependencies
Audit found these in pubspec.yaml with no matching usage in lib/ (verify each with grep before removing):
`geolocator`, `mobile_scanner`, `home_widget`, `workmanager`, `timezone`, `flutter_timezone`, `fl_chart`, `cached_network_image`, `lottie`, `shimmer`, `any_image_view`, `pinput`, `smart_auth`.
- Keep anything actually wired (e.g. `flutter_udid`/`device_info_plus`/`package_info_plus` if the update service uses them).
- Re-run `flutter analyze` and `flutter test` after each batch of removals.
- Cuts build size and attack surface; a reader app needs no location/QR/background-job packages.

### 3. Add CI job
- `.github/workflows/release.yml` exists (README:247 claiming ".github absent" is stale), but no test/analyze CI.
- New workflow (e.g. `.github/workflows/ci.yml`): on PR + push to main, run `flutter pub get`, `flutter analyze` (0 errors/warnings), `flutter test`.
- Runs on ubuntu-latest; optionally cache pub.

### 4. Fix stale README lines
- README:191: says push notifications via firebase_core/firebase_messaging with a TODO in `lib/app/flavours/app_flavour.dart` — no firebase in code or pubspec, no TODO in lib/. Delete the line.
- README:247: says "No CI configuration yet (`.github` absent)" — `.github/workflows/release.yml` exists. Rewrite once item 3 lands ("CI runs analyze+test on every PR").
- While editing, keep the Installation section in step with `release.yml` per README:175.

## Out of scope
- Legacy .doc/.xls/.ppt support (CR-LEGACY-OFFICE).
- Code signing, iOS build, PPT layout fidelity, on-device UAT (separate work items).

## Next step
Run intake, then execute as one small maintenance run (items are independent; 1 and 4 first, then 2, then 3).
