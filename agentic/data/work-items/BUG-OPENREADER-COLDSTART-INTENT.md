# BUG-OPENREADER-COLDSTART-INTENT: opening a file from another app while OpenReader isn't running crashes (debug)

## Found
2026-10-24, during CR-OWN-ENGINES E1 emulator checks on a Pixel_4a AVD with a debug APK.

## Steps
1. Force-stop the app: `adb shell am force-stop com.chowdhuryelab.openreader`.
2. Send a VIEW intent: `adb shell am start -a android.intent.action.VIEW -d file:///sdcard/Download/qa-text.pdf -t application/pdf -n com.chowdhuryelab.openreader/.MainActivity`.

## Result
A red error screen: `'package:flutter/src/widgets/framework.dart': Failed assertion: line 2170 pos 12: '_elements.contains(element)': is not true.`
- It happens with PDF and with `.xlsx`, so it isn't caused by any one reader or engine.
- With the app already running, the intent is handed to the existing instance instead, and there's no crash.
- Opening the same files from inside the app (Browse) works.

## Not yet known
- The stack trace: logcat didn't show it under the `flutter` tag.
- Whether release builds are affected. In release builds an assertion doesn't fire, but a broken widget tree still could.
- When it started. It might come from the `receive_sharing_intent` path running during the splash → app shell navigation.

## Status
OPEN. It needs triage, and the user decides when to fix it.
