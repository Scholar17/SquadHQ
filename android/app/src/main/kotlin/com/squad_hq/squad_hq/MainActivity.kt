package com.squad_hq.squad_hq

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerClipboardImage(flutterEngine)
    }

    /// "Paste copied photo" (lib/core/clipboard/clipboard_image_io.dart):
    /// the copied image as a JPEG, fitted within maxWidth × maxHeight, or
    /// null if nothing copied is an image. Same as iOS's AppDelegate.swift.
    private fun registerClipboardImage(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "squad_hq/clipboard_image")
        channel.setMethodCallHandler { call, result ->
            if (call.method != "readImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val maxWidth = call.argument<Int>("maxWidth") ?: 1280
            val maxHeight = call.argument<Int>("maxHeight") ?: Int.MAX_VALUE
            val quality = call.argument<Int>("quality") ?: 80
            // Read while the app has focus (Android 10+ allows it only then),
            // decode off the main thread.
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val uri = clipboard.primaryClip
                ?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)
                ?.uri
            if (uri == null) {
                result.success(null)
                return@setMethodCallHandler
            }
            val main = Handler(Looper.getMainLooper())
            thread {
                val jpeg = try {
                    readJpeg(uri, maxWidth, maxHeight, quality)
                } catch (e: Exception) {
                    null
                }
                main.post { result.success(jpeg) }
            }
        }
    }

    private fun readJpeg(uri: android.net.Uri, maxWidth: Int, maxHeight: Int, quality: Int): ByteArray? {
        val type = contentResolver.getType(uri)
        if (type != null && !type.startsWith("image/")) return null
        // Size first, then decode at roughly the target size to save memory.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val fit = min(maxWidth.toDouble() / bounds.outWidth, maxHeight.toDouble() / bounds.outHeight)
        var sample = 1
        while (sample * 2 * fit <= 1) sample *= 2
        val decoded = contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val scale = min(1.0, min(maxWidth.toDouble() / decoded.width, maxHeight.toDouble() / decoded.height))
        val width = max(1, (decoded.width * scale).roundToInt())
        val height = max(1, (decoded.height * scale).roundToInt())
        // Onto white, so a transparent PNG doesn't turn black as a JPEG.
        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(output).apply {
            drawColor(Color.WHITE)
            drawBitmap(decoded, null, Rect(0, 0, width, height), null)
        }
        decoded.recycle()
        val bytes = ByteArrayOutputStream()
        output.compress(Bitmap.CompressFormat.JPEG, quality, bytes)
        output.recycle()
        return bytes.toByteArray()
    }
}
