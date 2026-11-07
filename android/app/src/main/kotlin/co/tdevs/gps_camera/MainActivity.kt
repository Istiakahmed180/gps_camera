package co.tdevs.gps_camera

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.KeyEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** The Dart call waiting for a document picker, if any. */
    private var pending: MethodChannel.Result? = null
    private var pendingBackup: File? = null

    /** Set by Dart while the camera screen is open. */
    private var volumeShutter = false
    private var volumeChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPdf" -> result.success(openPdf(call.argument<String>("path")))
                    "mapKey" -> result.success(mapKey())
                    "galleryAvailable" -> result.success(galleryAvailable())
                    "saveToGallery" -> background(result) {
                        saveToGallery(
                            call.argument<String>("path"),
                            call.argument<String>("name"),
                            call.argument<Number>("takenAt")?.toLong(),
                        )
                    }
                    "saveBackup" -> saveBackup(call.argument<String>("path"), result)
                    "pickBackup" -> pickBackup(result)
                    "pickImage" -> pickImage(result)
                    "pendingImage" -> result.success(pendingImage())
                    else -> result.notImplemented()
                }
            }
        volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
            .apply {
                setMethodCallHandler { call, result ->
                    if (call.method == "setEnabled") {
                        volumeShutter = call.arguments == true
                        result.success(null)
                    } else {
                        result.notImplemented()
                    }
                }
            }
    }

    /** Handled before Flutter sees the key, so volume does not change. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeShutter && isVolumeKey(event.keyCode)) {
            // One photo per press, not one per auto-repeat.
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                volumeChannel?.invokeMethod("pressed", null)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun isVolumeKey(keyCode: Int) =
        keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try {
                work()
            } catch (e: Exception) {
                "failed"
            }
            main.post { result.success(value) }
        }
    }

    /**
     * Opens a report PDF in another app. Only `.pdf` files inside
     * GPSCamera/Reports are accepted. The file is copied into a dedicated
     * cache folder that is the only location the FileProvider exposes.
     */
    private fun openPdf(path: String?): String {
        if (path == null) return "invalid"
        val source = File(path).canonicalFile
        val reports = File(appRoot(), "Reports").canonicalFile
        if (source.parentFile != reports || !source.name.endsWith(".pdf")) return "invalid"
        if (!source.isFile) return "missing"

        val outDir = File(cacheDir, "open_reports").apply { mkdirs() }
        outDir.listFiles()?.forEach { it.delete() }
        val copy = File(outDir, source.name)
        source.copyTo(copy, overwrite = true)

        val uri = FileProvider.getUriForFile(this, "$packageName.reports", copy)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/pdf")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            startActivity(Intent.createChooser(intent, "Open report"))
            "opened"
        } catch (e: ActivityNotFoundException) {
            "noApp"
        }
    }

    /** The Geoapify key provided at build time, or null. */
    private fun mapKey(): String? {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString("co.tdevs.gps_camera.GEOAPIFY_API_KEY")
            ?.takeIf { it.isNotBlank() }
    }

    /** `<app documents>/GPSCamera`, the folder path_provider reports to Dart. */
    private fun appRoot(): File =
        File(getDir("flutter", Context.MODE_PRIVATE), "GPSCamera").canonicalFile

    /**
     * MediaStore lets an app add photos to shared storage without any
     * permission from Android 10 on. Older versions would need storage
     * permission, which this app does not request.
     */
    private fun galleryAvailable(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    /**
     * Copies a JPEG from GPSCamera/Photos or GPSCamera/Watermarked into
     * Pictures/GPS Camera. The app's own file is only read. A gallery photo
     * with the same name that this app added earlier is left as it is.
     */
    private fun saveToGallery(path: String?, name: String?, takenAt: Long?): String {
        if (!galleryAvailable()) return "unsupported"
        if (path == null || name == null || !SAFE_NAME.matches(name)) return "invalid"
        val source = File(path).canonicalFile
        val folder = source.parentFile ?: return "invalid"
        if (folder.parentFile != appRoot() || folder.name !in GALLERY_SOURCES ||
            !source.name.endsWith(".jpg")
        ) return "invalid"
        if (!source.isFile) return "missing"

        val resolver = contentResolver
        val images = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        resolver.query(
            images,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=?",
            arrayOf(name, "$GALLERY_DIR/"),
            null,
        )?.use { if (it.moveToFirst()) return "exists" }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, GALLERY_DIR)
            put(MediaStore.Images.Media.DATE_TAKEN, takenAt ?: source.lastModified())
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(images, values) ?: return "failed"
        return try {
            val out = resolver.openOutputStream(uri) ?: throw IOException("No stream")
            out.use { stream -> source.inputStream().use { it.copyTo(stream) } }
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
                null,
                null,
            )
            "saved"
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            "failed"
        }
    }

    /** Folder the Dart side builds backups in and copies picked ones to. */
    private fun backupCache(): File = File(cacheDir, "backups").canonicalFile

    /** Lets the user choose where to save a finished backup ZIP. */
    private fun saveBackup(path: String?, result: MethodChannel.Result) {
        if (pending != null) return result.success("busy")
        val source = path?.let { File(it).canonicalFile }
        if (source == null || source.parentFile != backupCache() ||
            !source.name.endsWith(".zip") || !source.isFile
        ) return result.success("invalid")

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/zip")
            .putExtra(Intent.EXTRA_TITLE, source.name)
        start(intent, REQUEST_SAVE, result) { pendingBackup = source }
    }

    /** Lets the user choose a backup ZIP; Dart gets a private copy's path. */
    private fun pickBackup(result: MethodChannel.Result) {
        if (pending != null) return result.error("busy", "A picker is already open", null)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"),
            )
        start(intent, REQUEST_PICK, result) {}
    }

    private fun pickedDir(): File = File(cacheDir, "picked").apply { mkdirs() }

    private fun copyPickedImage(uri: android.net.Uri, target: File) {
        val input = contentResolver.openInputStream(uri) ?: throw IOException("No stream")
        input.use { stream -> target.outputStream().use { stream.copyTo(it) } }
    }

    /** An image picked just before Android restarted the app, or null. */
    private fun pendingImage(): String? =
        File(pickedDir(), "pending_image").takeIf { it.isFile }?.path

    /** Lets the user choose an image (the watermark logo). */
    private fun pickImage(result: MethodChannel.Result) {
        if (pending != null) return result.error("busy", "A picker is already open", null)
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("image/*")
        start(intent, REQUEST_IMAGE, result) {}
    }

    private fun start(
        intent: Intent,
        request: Int,
        result: MethodChannel.Result,
        onStarted: () -> Unit,
    ) {
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, request)
            pending = result
            onStarted()
        } catch (e: ActivityNotFoundException) {
            result.success(if (request == REQUEST_SAVE) "noApp" else null)
        }
    }

    @Deprecated("FlutterActivity has no activity-result registry")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_PICK &&
            requestCode != REQUEST_IMAGE
        ) return
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        val result = pending
        if (result == null) {
            // Android stopped the app while the picker was open, so no Dart
            // call is waiting. Keep a chosen image for Dart to collect.
            if (requestCode == REQUEST_IMAGE && uri != null) {
                io.execute {
                    try {
                        copyPickedImage(uri, File(pickedDir(), "pending_image"))
                    } catch (e: Exception) {
                        // Nothing to recover; the user can pick again.
                    }
                }
            }
            return
        }
        pending = null

        if (requestCode == REQUEST_SAVE) {
            val source = pendingBackup
            pendingBackup = null
            if (uri == null || source == null) return result.success("cancelled")
            background(result) {
                // "wt" truncates an existing file; some providers only know "w".
                val out = try {
                    contentResolver.openOutputStream(uri, "wt")
                } catch (e: Exception) {
                    contentResolver.openOutputStream(uri, "w")
                } ?: throw IOException("No stream")
                out.use { stream -> source.inputStream().use { it.copyTo(stream) } }
                "saved"
            }
        } else if (requestCode == REQUEST_IMAGE) {
            if (uri == null) return result.success(null)
            background(result) {
                val target = File(pickedDir(), "image")
                copyPickedImage(uri, target)
                target.path
            }
        } else {
            if (uri == null) return result.success(null)
            background(result) {
                val target = File(backupCache().apply { mkdirs() }, "restore.zip")
                val input = contentResolver.openInputStream(uri) ?: throw IOException("No stream")
                input.use { stream -> target.outputStream().use { stream.copyTo(it) } }
                target.path
            }
        }
    }

    companion object {
        private const val CHANNEL = "co.tdevs.gps_camera/native"
        private const val VOLUME_CHANNEL = "co.tdevs.gps_camera/volume"
        private const val GALLERY_DIR = "Pictures/GPS Camera"
        private val GALLERY_SOURCES = setOf("Photos", "Watermarked")
        private val SAFE_NAME = Regex("[A-Za-z0-9_.-]{1,120}\\.jpg")
        private const val REQUEST_SAVE = 4101
        private const val REQUEST_PICK = 4102
        private const val REQUEST_IMAGE = 4103
    }
}
