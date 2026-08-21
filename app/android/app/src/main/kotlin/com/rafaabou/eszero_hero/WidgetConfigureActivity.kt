package com.rafaabou.eszero_hero

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews

class WidgetConfigureActivity : Activity() {

    companion object {
        private const val PREFS_NAME = "eszero_widget_prefs"
        private const val KEY_DUE_COUNT = "due_count"
        private const val KEY_STREAK = "streak"
        private const val KEY_LESSONS = "lessons_completed"
    }

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Set initial values
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dueCount = prefs.getInt(KEY_DUE_COUNT, 0)
        val streak = prefs.getInt(KEY_STREAK, 0)
        val lessons = prefs.getInt(KEY_LESSONS, 0)

        val views = RemoteViews(packageName, R.layout.widget_layout)
        views.setTextViewText(R.id.widget_due_count, dueCount.toString())
        views.setTextViewText(R.id.widget_streak, streak.toString())
        views.setTextViewText(R.id.widget_lessons, "$lessons/72")

        val manager = AppWidgetManager.getInstance(this)
        manager.updateAppWidget(appWidgetId, views)

        val result = Intent()
        result.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, result)
        finish()
    }
}