package com.rafaabou.eszero_hero

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews

class EszeroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "eszero_widget_prefs"
        private const val KEY_DUE_COUNT = "due_count"
        private const val KEY_STREAK = "streak"
        private const val KEY_LESSONS = "lessons_completed"

        @JvmStatic
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val dueCount = prefs.getInt(KEY_DUE_COUNT, 0)
            val streak = prefs.getInt(KEY_STREAK, 0)
            val lessons = prefs.getInt(KEY_LESSONS, 0)

            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setTextViewText(R.id.widget_due_count, dueCount.toString())
            views.setTextViewText(R.id.widget_streak, streak.toString())
            views.setTextViewText(R.id.widget_lessons, "$lessons/72")

            // Set click listener on due count to open flashcards
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "OPEN_FLASHCARDS"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_due_count, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        @JvmStatic
        fun updateFromFlutter(context: Context, dueCount: Int, streak: Int, lessons: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putInt(KEY_DUE_COUNT, dueCount)
                .putInt(KEY_STREAK, streak)
                .putInt(KEY_LESSONS, lessons)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, EszeroWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
}