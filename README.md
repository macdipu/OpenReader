# OpenReader

A privacy-first, fully offline Android document reader built with Flutter. OpenReader lets users discover, open, read, search, and navigate documents stored locally on their device — no accounts, no cloud upload, no server dependency.

**Supported formats:** PDF, DOC/DOCX, XLS/XLSX, CSV, TXT. (PPT/PPTX has no reader yet — blocked on an open product decision, see `agentic/data/project-context/features/FEATURE-OPENREADER-P3`.)

---

## Features

- **Readers:** PDF (page-based), Word (paginated/flow), Excel/CSV (spreadsheet grid), plain text
- **File discovery:** on-device document scanner, Recents, Favorites, Search
- **Sharing:** Share, File Info, Open With, and Open From Other Apps (receive shared/opened files from other apps)
- **Offline-first:** all reading happens on-device; local SQLite index for recents/favorites

Reference: `lib/features/` (`pdf_reader`, `word_reader`, `excel_reader`, `csv_reader`, `text_reader`, `files`, `recents`, `favorites`, `search`, `settings`, `onboarding`, `home`).

---

## Tech Stack

- **Framework:** Flutter (SDK `>=3.2.3 <4.0.0`)
- **State management:** GetX
- **Architecture:** Clean Architecture (presentation / domain / data per feature)
- **HTTP:** dio
- **Local storage:** sqflite (document index), shared_preferences, flutter_secure_storage
- **Document rendering:** pdfrx (PDF), docx_file_viewer/docx_creator (Word), excel_plus (Excel/CSV)
- **File integration:** open_filex (Open With), receive_sharing_intent (Open From Other Apps)
- **Push notifications:** firebase_core / firebase_messaging (currently disabled — see `TODO` in `lib/app/flavours/app_flavour.dart`)

---

## Environment Setup

Copy `env_example` to `.env` and fill in values:

```bash
cp env_example .env
```

Config is injected at **compile time** via `--dart-define-from-file`, read through `String.fromEnvironment`/`bool.fromEnvironment` in `AppConfig` — not bundled as a readable asset:

```bash
flutter run --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
```

`.env` is git-ignored and never packaged into the build output, so secrets never land in the binary.

---

## Getting Started

1. **Clone the repository**
2. **Install dependencies:** `flutter pub get`
3. **Set up `.env`** (see Environment Setup above)
4. **Run the app:** `flutter run --dart-define-from-file=.env`
5. **Run tests:** `flutter test`

---

## Project Structure

```
lib/
├── app/                  ← App bootstrap, flavours, top-level view
├── core/                 ← Shared data/domain/presentation (http client, widgets, controllers)
├── features/             ← One folder per feature (pdf_reader, word_reader, excel_reader, csv_reader,
│                            text_reader, files, home, recents, favorites, search, settings,
│                            onboarding, splash, file_information)
├── services/             ← Platform integration (Open With, Open From Other Apps, push notifications)
├── res/                  ← Routes, strings, themes
└── main.dart
```

Each feature follows Clean Architecture layering:

```
features/<feature_name>/
├── data/         ← repo_impl, models
├── domain/       ← entity, repo interface, usecase
└── presentation/ ← controller, screens, bindings
```

---

## Feature Generator

New feature scaffolding (folders, entity, repo, controller, bindings, routes wiring) can be generated with:

```bash
dart generate_feature.dart <feature_name>
```

This generates the Clean Architecture + GetX skeleton for a new feature; you then wire up the entity fields, API/response mapping, HTTP endpoint, and routes for the new feature. Use `lib/features/pdf_reader/` or `lib/features/text_reader/` as a reference for a complete, wired-up feature.

---

## Testing & Quality

- `flutter analyze` — 0 errors/warnings (informational lints only)
- `flutter test` — unit/widget coverage across services, repositories, controllers, and widgets (see `test/`)
- No CI configuration yet (`.github` absent) — checks are run locally/manually

Known gaps: PowerPoint has no reader (open product question); no Android SDK/emulator available in this dev environment, so native rendering, real intent delivery (Open From Other Apps), and physical-device UAT remain to be verified on-device.

---

## Documentation

Project context, requirements, architecture, and task tracking live under `agentic/`:

- `agentic/data/project-context/features/OpenReader_BRD_v1.0.md` — business requirements
- `agentic/data/project-context/features/FEATURE-OPENREADER-P1..P5/` — per-phase SRS, architecture, and tasks
- `agentic/README.md` and `AGENTS.md` — agentic workflow entrypoint for this repo

---

## Docker Development (Run everything in containers)

You can run and test the app entirely inside Docker. This is the recommended way to ensure everyone on the team has the same SDKs, toolchains and emulator behaviour.

Quick start (emulator-in-container)

1. Build images and start services (emulator + flutter):

   ./scripts/start.sh

2. (If needed) force adb connect:

   ./scripts/start.sh connect

Troubleshooting: "No physical devices found" and connection errors

- If you see a message like "No physical devices found. Attempting to connect to emulator at :5555" or "no host in ':5555'", it means the start script could not determine the emulator container IP. Try:

  - Run: ./scripts/start.sh connect
  - If that still shows no devices, exec into the flutter container and try connecting to the emulator service name (Docker internal DNS):

    docker compose exec -u developer -T flutter bash -lc "/opt/android-sdk/platform-tools/adb connect emulator:5555 && /opt/android-sdk/platform-tools/adb devices -l"

  - Or get the emulator container IP and connect directly (replace <ip>):

    EMU_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose ps -q emulator))
    docker compose exec -u developer -T flutter bash -lc "/opt/android-sdk/platform-tools/adb connect ${EMU_IP}:5555 && /opt/android-sdk/platform-tools/adb devices -l"

  - If you plan to access adb from your local machine, create an SSH tunnel from your laptop to the server to forward port 5555 (recommended) instead of opening ports in the server firewall.

3. Exec into flutter container and run the app:

   ./scripts/start.sh shell
   # inside container
   flutter pub get
   flutter devices
   flutter run -d <device-id>

Alternatively use the convenience script to connect adb from the flutter container to the emulator container:

    ./scripts/start.sh connect

Or to connect host adb to the emulator (requires adb on host):

    ./scripts/start.sh connect host

Run a single flutter command from the host (convenience via Makefile):

  make flutter run -d <device-id>

Makefile targets (shortcuts):

- make up         # build + start (same as ./scripts/start.sh up)
- make connect    # connect flutter adb to emulator
- make shell      # open shell into flutter container
- make flutter ...# run flutter <args> inside the container
- make down       # stop and remove containers
- make logs       # follow emulator logs

Additional Makefile helpers:

- make ensure-perms     # ensure repo helper scripts are executable
- make recreate-volumes # remove compose volumes and restart emulator (repopulates SDK bundle)
- make reset-volumes    # alias for recreate-volumes
- make devcontainer     # start VS Code devcontainer via devcontainer CLI (if .devcontainer exists)
- make emulator-container   # start the emulator via the repo scripts in container mode (EMULATOR_MODE=container)
- make emulator-host-connect # connect the flutter container to a host-running emulator (EMULATOR_MODE=host)

Emulator Modes

- container: runs the emulator fully inside Docker. Reliable on Linux with KVM (x86_64), and supported on Apple Silicon (ARM64). On macOS Intel/Windows, uses x86_64 emulation (slower but works).
- host: run the Android emulator on your host (Android Studio or sdk/emulator) and connect the Flutter container to it via adb (adb connect localhost:5555).
- auto (default): the start script detects the host OS/arch and chooses container mode where supported, else host mode.

You can override with EMULATOR_MODE=container|host|auto when running scripts/start.sh or `make up`.

### macOS Apple Silicon (M1/M2/M3) Setup

The setup automatically detects Apple Silicon (ARM64) and uses the ARM64 Android emulator in container mode.

1. Ensure ARM64 emulator binaries are available (copy `linux/emulator/` from cryze repo or build them) into `docker/emulator/` directory.

2. Run in container mode (detected automatically):

   ```bash
   make up
   ```

3. Connect and run Flutter:

   ```bash
   make connect
   make flutter devices
   make flutter run -d emulator-5554
   ```

**Multi-OS Support:** The setup automatically detects the host architecture:
- **ARM64 (Apple Silicon):** Uses ARM64 emulator in container mode
- **x86_64 (Intel Macs, Linux, Windows):** Uses x86_64 emulator in container mode (requires KVM on Linux for best performance) or falls back to host mode

For graphical interaction, use scrcpy with the VNC port (5900) or connect to the emulator via ADB.

### Use a physical Android device (Linux USB passthrough)

1. Start with the usb override (Linux only):

   docker compose -f docker-compose.yml -f docker-compose.override.usb.yml up --build -d

2. Then run the normal start and connect commands (start.sh will still help):

    ./scripts/start.sh
    ./scripts/start.sh connect

### Host emulator (macOS/Windows)

- Start the emulator on your host (Android Studio or command line) and then connect the flutter container to the host adb:

  docker compose exec flutter bash -lc "/opt/android-sdk/platform-tools/adb connect host.docker.internal:5555"

### Stopping everything

  docker compose down

### Alternative: use a prebuilt android-build-box image for one-off commands

If you prefer not to build the images in this repo you can use the community image `mingc/android-build-box` to run one-off commands against the project folder (example below runs tests):

  docker run --rm -v "$(pwd)":/project -w /project -e ANDROID_SDK_ROOT=/opt/android-sdk mingc/android-build-box:latest bash -lc "flutter pub get && flutter test"

### docker-compose (no custom Dockerfiles)

1. Start stack (emulator + flutter + scrcpy-web):

   make up

2. Open a shell inside the flutter container:

   make shell

3. Run flutter commands from host via Makefile:

   make flutter devices
   make flutter run -d emulator

4. Open scrcpy-web (VNC-like web UI) in your browser at:

   http://localhost:8080

Notes:

- The compose stack uses the public image mingc/android-build-box for both the emulator (android) and the flutter dev container (flutter). No custom image is built.
- scrcpy-web connects to the adb server exported by the android service. If scrcpy-web doesn't show the device, exec into the scrcpy-web container and ensure it can reach adb at android:5037.
- To stop everything: `make down`.

Port collisions and multi-arch images

- If port 8080 is already used on the host, the compose `up` will fail. You can change the host port for scrcpy-web with an environment variable when running compose, for example:

  SCRCPY_WEB_PORT=8081 make up

- The scrcpy-web image used must match your host architecture. The compose file uses a multi-arch-friendly image by default; if you still see platform mismatch messages, select a scrcpy-web image that matches your host (search Docker Hub for `scrcpy-web` and pick an image with the appropriate platform support).

### VS Code devcontainer

- Open the repository in VS Code and use the Remote - Containers (Dev Containers) extension to reopen in container. The .devcontainer/devcontainer.json targets the `flutter` service.

More commands and troubleshooting are available in `docker/README.md` — it contains detailed platform-specific instructions and examples.

---

## Additional Resources

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [GetX Documentation](https://pub.dev/packages/get)
- [Dartz for Functional Programming](https://pub.dev/packages/dartz)

---

## Contributing

1. Check `agentic/data/project-context/` for current requirements/architecture before making changes
2. Follow the established Clean Architecture + GetX patterns (use `generate_feature.dart` for new features)
3. Run `flutter analyze` and `flutter test` before submitting
4. Submit your PR
