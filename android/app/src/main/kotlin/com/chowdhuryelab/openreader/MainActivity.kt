package com.chowdhuryelab.openreader

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Android has no API to set a default app for documents; "Always" in the open-with
        // chooser does it per file type. This just opens the closest settings screen.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openreader/default_app")
            .setMethodCallHandler { call, result ->
                if (call.method != "openDefaultAppSettings") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val candidates = listOf(
                    Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS),
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
                )
                val opened = candidates.any { intent ->
                    try {
                        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        true
                    } catch (_: Exception) {
                        false
                    }
                }
                result.success(opened)
            }
    }
}
