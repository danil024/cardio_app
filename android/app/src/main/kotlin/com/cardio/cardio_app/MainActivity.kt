package com.cardio.cardio_app

import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val mediaChannel = "cardio_app/media_control"

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
    }

    private fun dispatchMediaKey(keyCode: Int) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        audioManager.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))
    }
}
