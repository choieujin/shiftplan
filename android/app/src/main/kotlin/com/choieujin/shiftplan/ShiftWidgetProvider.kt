package com.choieujin.shiftplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * 이번 주(월~일) 근무를 한 줄로 보여주는 홈 화면 위젯.
 *
 * 실행 시점의 실제 날짜로 "이번 주"를 계산하므로, 앱을 열지 않아도
 * 자정마다 예약된 알람으로 스스로 갱신된다.
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
    private val memoIds = intArrayOf(
        R.id.day0_memo, R.id.day1_memo, R.id.day2_memo, R.id.day3_memo,
        R.id.day4_memo, R.id.day5_memo, R.id.day6_memo,
    )
    private val defaultDows = arrayOf("월", "화", "수", "목", "금", "토", "일")

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // 자정 알람: 위젯을 다시 그리도록 강제 갱신한다.
        if (intent.action == ShiftDayData.ACTION_MIDNIGHT) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, ShiftWidgetProvider::class.java),
            )
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val data = ShiftDayData(widgetData)

        val today = ShiftDayData.startOfToday()
        val todayKey = ShiftDayData.keyFor(today)
        // 이번 주 월요일.
        val monday = (today.clone() as Calendar).apply {
            val dow = get(Calendar.DAY_OF_WEEK) // 일=1..토=7
            val diff = if (dow == Calendar.SUNDAY) 6 else dow - Calendar.MONDAY
            add(Calendar.DAY_OF_MONTH, -diff)
        }

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.shift_widget)

            for (i in 0 until 7) {
                val date = (monday.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_MONTH, i)
                }
                val key = ShiftDayData.keyFor(date)

                views.setTextViewText(dowIds[i], defaultDows[i])
                views.setTextViewText(numIds[i], "${date.get(Calendar.DAY_OF_MONTH)}")
                views.setTextViewText(badgeIds[i], data.shortFor(key) ?: "-")
                views.setInt(badgeIds[i], "setBackgroundColor", data.colorFor(key))
                views.setViewVisibility(
                    memoIds[i],
                    if (data.hasMemo(key)) android.view.View.VISIBLE
                    else android.view.View.INVISIBLE,
                )
                views.setInt(
                    cellIds[i],
                    "setBackgroundResource",
                    if (key == todayKey) R.drawable.today_bg else 0,
                )
            }

            views.setTextViewText(
                R.id.updated,
                widgetData.getString("widget_updated", "") ?: "",
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        ShiftDayData.scheduleMidnight(context, ShiftWidgetProvider::class.java)
    }
}
