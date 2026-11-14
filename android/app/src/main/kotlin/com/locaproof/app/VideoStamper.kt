package com.locaproof.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.Effect
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Video helpers for Dart: size and length, a thumbnail frame, and burning
 * the location stamp into a copy. The original file is only ever read.
 */
@UnstableApi
class VideoStamper(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null

    /** The Dart call and temp file of the stamp in progress, if any. */
    private var pending: MethodChannel.Result? = null
    private var pendingTemp: File? = null

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
        // Nothing is being stamped yet: temp files left by a closed app go.
        io.execute {
            context.cacheDir.listFiles { f -> f.name.startsWith(TEMP_PREFIX) }
                ?.forEach { it.delete() }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> background(result) { info(call.argument<String>("path")!!) }
            "thumbnail" -> background(result) {
                thumbnail(
                    call.argument<String>("path")!!,
                    call.argument<String>("output")!!,
                    call.argument<Number>("atMs")?.toLong() ?: 0L,
                    call.argument<Number>("maxSide")?.toInt() ?: 720,
                )
            }
            "stamp" -> stamp(call, result)
            "cancel" -> {
                // Transformer.cancel() reports nothing, so answer here.
                transformer?.cancel()
                transformer = null
                pendingTemp?.delete()
                pendingTemp = null
                pending?.error("cancelled", "Stamping was cancelled.", null)
                pending = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("video", e.message ?: e.toString(), null) }
            }
        }
    }

    /** Length, size as displayed (rotation applied) and whether it has sound. */
    private fun info(path: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            fun meta(key: Int) = retriever.extractMetadata(key)
            val width = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val height = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val turned = rotation == 90 || rotation == 270
            return mapOf(
                "durationMs" to (meta(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L),
                "width" to if (turned) height else width,
                "height" to if (turned) width else height,
                "rotation" to rotation,
                "hasAudio" to (meta(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"),
            )
        } finally {
            retriever.release()
        }
    }

    /** Writes the frame at [atMs] as a JPEG no larger than [maxSide]. */
    private fun thumbnail(path: String, output: String, atMs: Long, maxSide: Int): Map<String, Int> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val frame = scaledFrame(retriever, atMs * 1000, maxSide)
                ?: throw IllegalStateException("No frame")
            val target = File(output)
            val temp = File("$output.tmp")
            FileOutputStream(temp).use { frame.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            if (!temp.renameTo(target)) throw IllegalStateException("Thumbnail not saved")
            return mapOf("width" to frame.width, "height" to frame.height).also { frame.recycle() }
        } finally {
            retriever.release()
        }
    }

    /** A frame no larger than [maxSide]; scaled by hand before Android 8.1. */
    private fun scaledFrame(retriever: MediaMetadataRetriever, atUs: Long, maxSide: Int): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return retriever.getScaledFrameAtTime(
                atUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                maxSide,
                maxSide,
            ) ?: retriever.getFrameAtTime(0)
        }
        val full = retriever.getFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            ?: retriever.getFrameAtTime(0)
            ?: return null
        val scale = maxSide.toFloat() / maxOf(full.width, full.height)
        if (scale >= 1f) return full
        return Bitmap.createScaledBitmap(
            full,
            (full.width * scale).toInt().coerceAtLeast(1),
            (full.height * scale).toInt().coerceAtLeast(1),
            true,
        ).also { if (it != full) full.recycle() }
    }

    /**
     * Copies `input` to `output` with the stamp drawn on every frame.
     * `frames` are PNGs of the stamp area, each shown from `fromMs` until the
     * next one, at `left`,`top` in a `width` x `height` (as displayed) frame.
     * Progress goes to Dart as "progress" calls.
     */
    private fun stamp(call: MethodCall, result: MethodChannel.Result) {
        if (transformer != null) {
            result.error("busy", "A video is already being stamped.", null)
            return
        }
        val input = call.argument<String>("input")!!
        val output = call.argument<String>("output")!!
        val width = call.argument<Number>("width")!!.toInt()
        val height = call.argument<Number>("height")!!.toInt()
        val frames = (call.argument<List<Map<String, Any>>>("frames") ?: emptyList())
            .map {
                StampFrame(
                    (it["fromMs"] as Number).toLong() * 1000,
                    it["path"] as String,
                    (it["left"] as Number).toInt(),
                    (it["top"] as Number).toInt(),
                )
            }
            .sortedBy { it.fromUs }

        val overlay = StampOverlay(frames, width, height)
        val item = EditedMediaItem.Builder(MediaItem.fromUri(File(input).toURI().toString()))
            .setEffects(
                Effects(
                    ImmutableList.of(),
                    ImmutableList.of<Effect>(OverlayEffect(ImmutableList.of<TextureOverlay>(overlay))),
                ),
            )
            .build()
        // Written in the cache, so a half-made file never shows up as media.
        val temp = File(context.cacheDir, "$TEMP_PREFIX${System.nanoTime()}.mp4")
        temp.delete()
        pending = result
        pendingTemp = temp

        var finished = false
        val progress = ProgressHolder()
        val poll = object : Runnable {
            override fun run() {
                val t = transformer ?: return
                if (finished) return
                if (t.getProgress(progress) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", progress.progress / 100.0)
                }
                main.postDelayed(this, 300)
            }
        }

        fun done(error: String?) {
            finished = true
            transformer = null
            val reply = pending ?: return // Already answered (cancelled).
            pending = null
            pendingTemp = null
            if (error == null && temp.length() > 0 && moveTo(temp, File(output))) {
                reply.success(null)
            } else {
                temp.delete()
                reply.error("stamp", error ?: "The stamped video was not written.", null)
            }
        }

        val t = Transformer.Builder(context)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    done(null)
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    done(exportException.message ?: exportException.errorCodeName)
                }
            })
            .build()
        transformer = t
        try {
            t.start(item, temp.absolutePath)
            main.postDelayed(poll, 300)
        } catch (e: Exception) {
            done(e.message ?: e.toString())
        }
    }

    /**
     * Copied rather than renamed, so Android counts the result as app data
     * like the photos, not as cache.
     */
    private fun moveTo(from: File, to: File): Boolean {
        return try {
            from.copyTo(to, overwrite = true)
            from.delete()
            true
        } catch (e: Exception) {
            false
        }
    }

    private data class StampFrame(val fromUs: Long, val path: String, val left: Int, val top: Int)

    /**
     * A full-frame transparent bitmap with the current stamp drawn in place.
     * Redrawn only when the stamp for the frame's time changes. Media3
     * uploads an overlay only when it gets a different Bitmap object, so two
     * buffers take turns.
     */
    private class StampOverlay(
        private val frames: List<StampFrame>,
        width: Int,
        height: Int,
    ) : BitmapOverlay() {
        private val buffers = Array(2) { Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888) }
        private var current = 0
        private var shown = -2

        override fun getBitmap(presentationTimeUs: Long): Bitmap {
            var index = -1
            for (i in frames.indices) {
                if (frames[i].fromUs <= presentationTimeUs) index = i else break
            }
            if (index != shown) {
                shown = index
                current = 1 - current
                val bitmap = buffers[current]
                bitmap.eraseColor(Color.TRANSPARENT)
                if (index >= 0) {
                    val frame = frames[index]
                    BitmapFactory.decodeFile(frame.path)?.let {
                        Canvas(bitmap).drawBitmap(it, frame.left.toFloat(), frame.top.toFloat(), null)
                        it.recycle()
                    }
                }
            }
            return buffers[current]
        }

        override fun release() {
            super.release()
            buffers.forEach { it.recycle() }
        }
    }

    companion object {
        const val CHANNEL = "com.locaproof.app/video"
        private const val TEMP_PREFIX = "stamp_out_"
    }
}
