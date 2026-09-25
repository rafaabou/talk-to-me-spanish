package com.rafaabou.eszero_hero

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NotificationService : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var notificationManager: NotificationManager? = null
    private var alarmManager: AlarmManager? = null
    private val CHANNEL_ID_DAILY = "daily_review"
    private val CHANNEL_ID_STREAK = "streak_nudge"
    private val CHANNEL_ID_REVIEW = "review_notification"
    private val PREFS_NAME = "notification_prefs"
    private val KEY_DAILY_HOUR = "daily_hour"
    private val KEY_STREAK_HOUR = "streak_hour"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.rafaabou.eszero_hero/notification")
        channel?.setMethodCallHandler(this)
        context = binding.applicationContext
        notificationManager = context?.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager?
        alarmManager = context?.getSystemService(Context.ALARM_SERVICE) as AlarmManager?
        createNotificationChannels()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val dailyChannel = NotificationChannel(
                CHANNEL_ID_DAILY,
                "Repaso diario",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Recordatorio diario de repaso SRS"
            }
            val streakChannel = NotificationChannel(
                CHANNEL_ID_STREAK,
                "Racha de días",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Aviso para no perder la racha"
            }
            val reviewChannel = NotificationChannel(
                CHANNEL_ID_REVIEW,
                "Notificación de repaso",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificación de palabras para repasar"
            }
            notificationManager?.createNotificationChannels(listOf(dailyChannel, streakChannel, reviewChannel))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                createNotificationChannels()
                result.success(true)
            }
            "scheduleDailyReviewReminder" -> {
                val hour = call.argument<Int>("hour") ?: 19
                scheduleDailyReview(hour)
                result.success(true)
            }
            "scheduleStreakNudge" -> {
                val hour = call.argument<Int>("hour") ?: 20
                scheduleStreakNudge(hour)
                result.success(true)
            }
            "updateReviewNotification" -> {
                val dueCount = call.argument<Int>("dueCount") ?: 0
                showReviewNotification(dueCount)
                result.success(true)
            }
            "cancelAll" -> {
                cancelAllNotifications()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleDailyReview(hour: Int) {
        val ctx = context ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(KEY_DAILY_HOUR, hour).apply()

        val intent = Intent(ctx, NotificationReceiver::class.java).apply {
            action = "DAILY_REVIEW"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            ctx, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            if (before(java.util.Calendar.getInstance())) {
                add(java.util.Calendar.DAY_OF_MONTH, 1)
            }
        }

        alarmManager?.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    private fun scheduleStreakNudge(hour: Int) {
        val ctx = context ?: return
        val prefs = ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putInt(KEY_STREAK_HOUR, hour).apply()

        val intent = Intent(ctx, NotificationReceiver::class.java).apply {
            action = "STREAK_NUDGE"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            ctx, 2, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            if (before(java.util.Calendar.getInstance())) {
                add(java.util.Calendar.DAY_OF_MONTH, 1)
            }
        }

        alarmManager?.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    private fun showReviewNotification(dueCount: Int) {
        val ctx = context ?: return
        if (dueCount == 0) {
            notificationManager?.cancel(3)
            return
        }

        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            ctx, 3, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(ctx, CHANNEL_ID_REVIEW)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Palabras para repasar: $dueCount")
            .setContentText("Toca para empezar el repaso SRS.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager?.notify(3, notification)
    }

    private fun cancelAllNotifications() {
        notificationManager?.cancelAll()
        val ctx = context ?: return
        alarmManager?.cancel(
            PendingIntent.getBroadcast(ctx, 1, Intent(ctx, NotificationReceiver::class.java), PendingIntent.FLAG_IMMUTABLE)
        )
        alarmManager?.cancel(
            PendingIntent.getBroadcast(ctx, 2, Intent(ctx, NotificationReceiver::class.java), PendingIntent.FLAG_IMMUTABLE)
        )
    }

    companion object {
        @JvmStatic
        fun updateFromFlutter(context: Context, dueCount: Int, streak: Int, lessons: Int) {
            val prefs = context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
            val dailyHour = prefs.getInt("daily_hour", 19)
            val streakHour = prefs.getInt("streak_hour", 20)

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

            // Reschedule daily review
            val dailyIntent = Intent(context, NotificationReceiver::class.java).apply {
                action = "DAILY_REVIEW"
            }
            val dailyPendingIntent = PendingIntent.getBroadcast(
                context, 1, dailyIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val dailyCalendar = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, dailyHour)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                if (before(java.util.Calendar.getInstance())) {
                    add(java.util.Calendar.DAY_OF_MONTH, 1)
                }
            }

            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                dailyCalendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                dailyPendingIntent
            )

            // Reschedule streak nudge
            val streakIntent = Intent(context, NotificationReceiver::class.java).apply {
                action = "STREAK_NUDGE"
            }
            val streakPendingIntent = PendingIntent.getBroadcast(
                context, 2, streakIntent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val streakCalendar = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, streakHour)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                if (before(java.util.Calendar.getInstance())) {
                    add(java.util.Calendar.DAY_OF_MONTH, 1)
                }
            }

            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                streakCalendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                streakPendingIntent
            )
        }
    }
}