package com.rafaabou.eszero_hero

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rafaabou.eszero_hero/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleOpenFlashcardsIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOpenFlashcardsIntent(intent)
    }

    private fun handleOpenFlashcardsIntent(intent: Intent?) {
        if (intent?.action == "OPEN_FLASHCARDS") {
            // Send message to Flutter to navigate to flashcards
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
                .invokeMethod("navigateToFlashcards", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val dueCount = call.argument<Int>("dueCount") ?: 0
                val streak = call.argument<Int>("streak") ?: 0
                val lessons = call.argument<Int>("lessonsCompleted") ?: 0
                EszeroWidgetProvider.updateFromFlutter(this, dueCount, streak, lessons)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
