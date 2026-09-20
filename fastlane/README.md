# Fastlane metadata

Used by the `Upload to Google Play` step in `.github/workflows/release.yml`
(`fastlane supply --metadata_path fastlane/metadata/android`). Only runs when
the `PLAY_SERVICE_ACCOUNT_JSON` secret is set; otherwise this step is skipped.

Before the first Play Store submission:

1. Fill in `en-US/short_description.txt` and `en-US/full_description.txt`
   (placeholders currently, marked `TODO`).
2. Add at least 2 phone screenshots under
   `en-US/images/phoneScreenshots/` and a feature graphic under
   `en-US/images/featureGraphic.png` — required by Play for a new app's
   first listing. Not scaffolded here since they need real app screenshots.
3. Add an app icon at `en-US/images/icon.png` (512x512) if not already set
   in the Play Console.

See the [fastlane supply metadata docs](https://docs.fastlane.tools/actions/supply/#metadata-structure)
for the full directory layout.
