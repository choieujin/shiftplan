package com.example.shiftplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 홈 화면 위젯. Flutter( home_widget )가 저장한 SharedPreferences 데이터를 읽어
 * 오늘/내일 근무를 표시한다.
 */
class ShiftWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shift_widget)

            bindDay(
                views,
                prefix = "today",
                widgetData = widgetData,
                dateViewId = R.id.today_date,
                badgeViewId = R.id.today_badge,
                nameViewId = R.id.today_name,
                timeViewId = R.id.today_time,
            )
            bindDay(
                views,
                prefix = "tomorrow",
                widgetData = widgetData,
                dateViewId = R.id.tomorrow_date,
                badgeViewId = R.id.tomorrow_badge,
                nameViewId = R.id.tomorrow_name,
                timeViewId = R.id.tomorrow_time,
            )

            views.setTextViewText(
                R.id.updated,
                widgetData.getString("widget_updated", "") ?: "",
            )

            // 위젯을 누르면 앱이 열린다.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindDay(
        views: RemoteViews,
        prefix: String,
        widgetData: SharedPreferences,
        dateViewId: Int,
        badgeViewId: Int,
        nameViewId: Int,
        timeViewId: Int,
    ) {
        val date = widgetData.getString("${prefix}_date", "") ?: ""
        val name = widgetData.getString("${prefix}_name", "없음") ?: "없음"
        val short = widgetData.getString("${prefix}_short", "-") ?: "-"
        val time = widgetData.getString("${prefix}_time", "") ?: ""
        val colorHex = widgetData.getString("${prefix}_color", "#B0BEC5") ?: "#B0BEC5"

        views.setTextViewText(dateViewId, date)
        views.setTextViewText(badgeViewId, short)
        views.setTextViewText(nameViewId, name)
        views.setTextViewText(timeViewId, time)

        val color = try {
            Color.parseColor(colorHex)
        } catch (e: IllegalArgumentException) {
            Color.parseColor("#B0BEC5")
        }
        views.setInt(badgeViewId, "setBackgroundColor", color)
    }
}
