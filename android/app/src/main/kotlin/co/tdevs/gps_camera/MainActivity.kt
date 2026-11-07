package co.tdevs.gps_camera

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openPdf" -> result.success(openPdf(call.argument<String>("path")))
                    "mapKey" -> result.success(mapKey())
                    else -> result.notImplemented()
                }
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
        val reports = File(getDir("flutter", Context.MODE_PRIVATE), "GPSCamera/Reports")
            .canonicalFile
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

    companion object {
        private const val CHANNEL = "co.tdevs.gps_camera/native"
    }
}
