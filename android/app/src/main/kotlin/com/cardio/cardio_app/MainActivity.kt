package com.cardio.cardio_app

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.KeyEvent
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.system.exitProcess

class MainActivity: FlutterActivity() {
    private val mediaChannel = "cardio_app/media_control"
    private val appControlChannel = "cardio_app/app_control"
    private val mediaExportChannel = "cardio_app/media_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "previous" -> {
                        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                        result.success(null)
                    }
                    "playPause" -> {
                        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                        result.success(null)
                    }
                    "play" -> {
                        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PLAY)
                        result.success(null)
                    }
                    "pause" -> {
                        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_PAUSE)
                        result.success(null)
                    }
                    "next" -> {
                        dispatchMediaKey(KeyEvent.KEYCODE_MEDIA_NEXT)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appControlChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "forceExit" -> {
                        finishAffinity()
                        result.success(null)
                        exitProcess(0)
                    }
                    "minimizeApp" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaExportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePngToGallery" -> {
                        try {
                            val args = call.arguments as? Map<*, *>
                            val bytes = args?.get("bytes") as? ByteArray
                            val fileName = args?.get("fileName") as? String
                            val albumName = (args?.get("albumName") as? String) ?: "CardioApp Export"
                            if (bytes == null || fileName.isNullOrBlank()) {
                                result.error("invalid_args", "Missing PNG bytes or fileName", null)
                                return@setMethodCallHandler
                            }
                            val savedPath = savePngToGallery(bytes, fileName, albumName)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun dispatchMediaKey(keyCode: Int) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }

    private fun savePngToGallery(bytes: ByteArray, fileName: String, albumName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativePath = "${Environment.DIRECTORY_PICTURES}/$albumName"
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri: Uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Cannot create MediaStore record")
            resolver.openOutputStream(uri).use { output ->
                if (output == null) {
                    throw IllegalStateException("Cannot open output stream")
                }
                output.write(bytes)
                output.flush()
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }

        val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        val albumDir = File(picturesDir, albumName)
        if (!albumDir.exists()) {
            albumDir.mkdirs()
        }
        val file = File(albumDir, fileName)
        FileOutputStream(file).use { output: OutputStream ->
            output.write(bytes)
            output.flush()
        }
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(file.absolutePath),
            arrayOf("image/png"),
            null
        )
        return file.absolutePath
    }
}
