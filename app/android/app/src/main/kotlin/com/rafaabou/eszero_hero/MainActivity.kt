package com.rafaabou.eszero_hero

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rafaabou.eszero_hero/widget"
    private val EXACT_ALARM_REQUEST_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestExactAlarmPermission()
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

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:$packageName")
                startActivityForResult(intent, EXACT_ALARM_REQUEST_CODE)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == EXACT_ALARM_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
                if (alarmManager.canScheduleExactAlarms()) {
                    NotificationService.updateFromFlutter(this, 0, 0, 0)
                }
            }
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