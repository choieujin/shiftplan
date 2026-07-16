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
 * 이번 주(월~일) 근무 패턴을 한 줄로 표시한다. 오늘은 테두리로 강조된다.
 */
class ShiftWidgetProvider : HomeWidgetProvider() {

    private val cellIds = intArrayOf(
        R.id.day0_cell, R.id.day1_cell, R.id.day2_cell, R.id.day3_cell,
        R.id.day4_cell, R.id.day5_cell, R.id.day6_cell,
    )
    private val dowIds = intArrayOf(
        R.id.day0_dow, R.id.day1_dow, R.id.day2_dow, R.id.day3_dow,
        R.id.day4_dow, R.id.day5_dow, R.id.day6_dow,
    )
    private val numIds = intArrayOf(
        R.id.day0_num, R.id.day1_num, R.id.day2_num, R.id.day3_num,
        R.id.day4_num, R.id.day5_num, R.id.day6_num,
    )
    private val badgeIds = intArrayOf(
        R.id.day0_badge, R.id.day1_badge, R.id.day2_badge, R.id.day3_badge,
        R.id.day4_badge, R.id.day5_badge, R.id.day6_badge,
    )
    private val defaultDows = arrayOf("월", "화", "수", "목", "금", "토", "일")

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shift_widget)

            for (i in 0 until 7) {
                views.setTextViewText(
                    dowIds[i],
                    widgetData.getString("week_${i}_dow", defaultDows[i]) ?: defaultDows[i],
                )
                views.setTextViewText(
                    numIds[i],
                    widgetData.getString("week_${i}_num", "") ?: "",
                )
                views.setTextViewText(
                    badgeIds[i],
                    widgetData.getString("week_${i}_short", "-") ?: "-",
                )
                views.setInt(
                    badgeIds[i],
                    "setBackgroundColor",
                    parseColor(widgetData.getString("week_${i}_color", null)),
                )
                val isToday =
                    widgetData.getString("week_${i}_today", "false") == "true"
                views.setInt(
                    cellIds[i],
                    "setBackgroundResource",
                    if (isToday) R.drawable.today_bg else 0,
                )
            }

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

    private fun parseColor(hex: String?): Int {
        return try {
            Color.parseColor(hex ?: "#B0BEC5")
        } catch (e: IllegalArgumentException) {
            Color.parseColor("#B0BEC5")
        }
    }
}
