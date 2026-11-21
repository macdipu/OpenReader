package com.chowdhuryelab.openreader

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Entry point for documents opened from other apps ("Open with", share sheets,
 * Messenger/Gmail/WhatsApp/Drive, file managers, backup folders).
 *
 * Why this exists at all: `receive_sharing_intent` cannot classify an
 * `ACTION_VIEW`/`ACTION_SEND` intent that carries no MIME type - which is what
 * Messenger and several social apps send. It reports the `content://` URI as a
 * plain URL (or drops the intent entirely for `ACTION_SEND`), and Dart cannot
 * read a `content://` URI anyway (`File(...)` has no content resolver). So
 * those opens used to end in "OpenReader doesn't support this file type".
 *
 * This activity now owns Android intent intake:
 *  - [materialize] asks the content resolver for the MIME type and display
 *    name, copies the stream into the app cache under a real extension, and
 *    returns a path Dart can read.
 *  - The [EventChannel] hands those documents to Dart, including an intent
 *    that arrived before Flutter was ready (flushed on first listen).
 *  - iOS keeps using the plugin; this class is Android-only.
 *
 * Everything logs under tag `OpenReaderIntent`:
 * `adb logcat -s OpenReaderIntent`.
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var pendingUri: String? = null
    private var lastDeliveredUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        logIntent("onCreate", intent)
        super.onCreate(savedInstanceState)
        capturePending(intent)
    }

    override fun onNewIntent(intent: Intent) {
        logIntent("onNewIntent", intent)
        super.onNewIntent(intent)
        capturePending(intent)
        deliverPending()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Device facts Dart cannot read without a plugin: the Android SDK level (file access rules differ
        // from API 30).
        MethodChannel(messenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(android.os.Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    // A document shared while the app was starting up.
                    deliverPending()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    /** Remembers the document URI of an intent we can turn into a file. */
    private fun capturePending(incoming: Intent?) {
        val uri = incomingUri(incoming) ?: return
        pendingUri = uri
        Log.i(TAG, "captured document uri=$uri")
    }

    private fun incomingUri(intent: Intent?): String? {
        if (intent == null) return null
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.dataString?.let { return it }
            Intent.ACTION_SEND -> {
                val uri: Uri? = if (android.os.Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                return uri?.toString()
            }

            Intent.ACTION_SEND_MULTIPLE -> {
                val uris: List<Uri>? = if (android.os.Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                return uris?.firstOrNull()?.toString()
            }
        }
        return null
    }

    /** Materializes the pending URI and pushes it to Dart, once per intent. */
    private fun deliverPending() {
        val sink = eventSink ?: return
        val uri = pendingUri ?: return
        pendingUri = null
        if (uri == lastDeliveredUri) return
        lastDeliveredUri = uri

        io.execute {
            val payload = try {
                materialize(uri)
            } catch (t: Throwable) {
                Log.w(TAG, "materialize failed uri=$uri: $t")
                null
            }
            mainHandler.post {
                if (payload != null) {
                    Log.i(TAG, "delivering document path=${payload["path"]} mime=${payload["mimeType"]}")
                    sink.success(payload)
                } else {
                    Log.w(TAG, "document not readable: $uri")
                    sink.error("unreadable", "Could not read $uri", null)
                }
            }
        }
    }

    private fun materialize(uriString: String): Map<String, Any?>? {
        val uri = Uri.parse(uriString)

        // Already a real file path (file:// from an older app, backup folder
        // scan, or a picker that hands over a path).
        if (uri.scheme == null || uri.scheme == "file") {
            val path = uri.path ?: return null
            val file = File(path)
            if (!file.exists()) return null
            val mime = contentResolver.getType(uri) ?: mimeFromName(file.name)
            Log.i(TAG, "materialize file uri=$uriString -> path=$path mime=$mime")
            return mapOf("path" to path, "mimeType" to mime, "displayName" to file.name)
        }

        if (uri.scheme != "content") return null

        val mime = contentResolver.getType(uri)
        val displayName = queryDisplayName(uri) ?: uri.lastPathSegment
        val name = safeFileName(displayName, mime)
        val dir = File(cacheDir, INCOMING_DIR).apply { mkdirs() }

        // The copy is keyed by the source uri, so two different documents that share a file
        // name never collide. It is reused only when its size AND the provider's modified time both
        // match the source (the copy's own lastModified is set to the source's). A provider that
        // reports no size or no modified time gets a fresh copy every time: size alone is never trusted.
        // Known trade-off: a provider that mints a new uri for each open produces a new cached copy
        // per open (pruneOldFiles bounds the cache).
        val sourceSize = querySize(uri)
        val sourceModified = queryLastModified(uri)
        val key = Integer.toHexString(uriString.hashCode())
        val target = File(dir, "${key}_$name")
        val reusable = target.exists() && target.length() > 0 && sourceSize > 0 && target.length() == sourceSize &&
            sourceModified > 0 && target.lastModified() == sourceModified
        if (!reusable) {
            val stream = contentResolver.openInputStream(uri) ?: return null
            val partial = File(dir, "${key}_$name.part")
            stream.use { input -> partial.outputStream().use { output -> input.copyTo(output) } }
            if (partial.length() == 0L) {
                partial.delete()
                return null
            }
            if (!partial.renameTo(target)) {
                partial.copyTo(target, overwrite = true)
                partial.delete()
            }
            if (sourceModified > 0) target.setLastModified(sourceModified)
        }

        pruneOldFiles(dir, keep = target)
        Log.i(TAG, "materialize content uri=$uriString -> path=${target.absolutePath} mime=$mime name=$name")
        return mapOf("path" to target.absolutePath, "mimeType" to mime, "displayName" to displayName)
    }

    /** The provider's modified time in ms ("last_modified" column), or -1 when it offers none. */
    private fun queryLastModified(uri: Uri): Long {
        return try {
            contentResolver.query(uri, arrayOf("last_modified"), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else -1L
            } ?: -1L
        } catch (t: Throwable) {
            -1L
        }
    }

    private fun querySize(uri: Uri): Long {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else -1L
            } ?: -1L
        } catch (t: Throwable) {
            Log.w(TAG, "size query failed for $uri: $t")
            -1L
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (t: Throwable) {
            Log.w(TAG, "display name query failed for $uri: $t")
            null
        }
    }

    /**
     * Gives the cache copy the original name when the provider supplies one,
     * otherwise derives an extension from the MIME type so the resolver can
     * still classify the document.
     */
    private fun safeFileName(displayName: String?, mime: String?): String {
        val cleaned = displayName
            ?.substringBefore('?')
            ?.substringAfterLast('/')
            ?.replace(Regex("[^A-Za-z0-9._ -]"), "_")
            ?.trim()
            ?.take(80)
            ?.takeIf { it.isNotEmpty() }

        if (cleaned != null) {
            val extension = cleaned.substringAfterLast('.', "")
            if (extension.length in 1..10) return cleaned
        }

        val extension = mime
            ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?: "bin"
        val base = cleaned?.removeSuffix(".") ?: "shared_${System.currentTimeMillis()}"
        return "$base.$extension"
    }

    private fun mimeFromName(name: String): String? {
        val extension = name.substringAfterLast('.', "")
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
    }

    /** Shared documents are transient; drop copies the user isn't reading. */
    /** Deletes old copies except [keep] (its mtime mirrors the source's, so it may look old). */
    private fun pruneOldFiles(dir: File, keep: File) {
        val cutoff = System.currentTimeMillis() - PRUNE_AFTER_MS
        dir.listFiles()?.forEach { file ->
            if (file != keep && file.lastModified() < cutoff) file.delete()
        }
    }

    private fun logIntent(source: String, incoming: Intent?) {
        if (incoming == null) {
            Log.i(TAG, "$source intent=<null>")
            return
        }
        val extraKeys = incoming.extras?.keySet()?.joinToString(",") ?: ""
        Log.i(
            TAG,
            "$source action=${incoming.action} type=${incoming.type} " +
                "data=${incoming.dataString} flags=0x${incoming.flags.toString(16)} " +
                "extras=[$extraKeys]",
        )
    }

    private companion object {
        const val TAG = "OpenReaderIntent"
        const val DEVICE_CHANNEL = "openreader/device"
        const val EVENTS_CHANNEL = "openreader/incoming_intent/events"
        const val INCOMING_DIR = "incoming"
        const val PRUNE_AFTER_MS = 7L * 24 * 60 * 60 * 1000
    }
}
