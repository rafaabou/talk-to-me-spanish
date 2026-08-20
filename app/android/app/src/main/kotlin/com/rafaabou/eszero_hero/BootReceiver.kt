package com.rafaabou.eszero_hero

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
            val dailyHour = prefs.getInt("daily_hour", 19)
            val streakHour = prefs.getInt("streak_hour", 20)

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

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
                if (this.before(java.util.Calendar.getInstance())) {
                    this.add(java.util.Calendar.DAY_OF_MONTH, 1)
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
                if (this.before(java.util.Calendar.getInstance())) {
                    this.add(java.util.Calendar.DAY_OF_MONTH, 1)
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