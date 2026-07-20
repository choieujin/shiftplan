package com.choieujin.shiftplan

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * 한 달 전체를 보여주는 홈 화면 위젯.
 *
 * 실행 시점의 실제 날짜로 이번 달 그리드를 계산하므로, 앱을 열지 않아도
 * 자정마다 예약된 알람으로 스스로 갱신된다.
 */
class MonthWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ShiftDayData.ACTION_MIDNIGHT) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, MonthWidgetProvider::class.java),
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
        val month = today.get(Calendar.MONTH)

        // 이번 달 1일이 속한 주의 월요일부터 42칸.
        val gridStart = (today.clone() as Calendar).apply {
            set(Calendar.DAY_OF_MONTH, 1)
            val dow = get(Calendar.DAY_OF_WEEK)
            val diff = if (dow == Calendar.SUNDAY) 6 else dow - Calendar.MONDAY
            add(Calendar.DAY_OF_MONTH, -diff)
        }
        val title = "${today.get(Calendar.YEAR)}년 ${month + 1}월"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.month_widget)
            views.setTextViewText(R.id.month_title, title)
            views.setTextViewText(
                R.id.month_updated,
                widgetData.getString("widget_updated", "") ?: "",
            )

            // 42칸을 채우면서 각 주에 이번 달 날짜가 있는지 기록한다.
            val rowHasDay = BooleanArray(6)
            for (i in 0 until 42) {
                val date = (gridStart.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_MONTH, i)
                }
                val inMonth = date.get(Calendar.MONTH) == month
                val key = ShiftDayData.keyFor(date)
                val short = if (inMonth) data.shortFor(key) else null

                if (inMonth) rowHasDay[i / 7] = true

                if (inMonth) {
                    views.setTextViewText(numIds[i], "${date.get(Calendar.DAY_OF_MONTH)}")
                    views.setTextColor(
                        numIds[i],
                        if (data.isHoliday(key)) HOLIDAY_COLOR else DEFAULT_NUM_COLOR,
                    )
                } else {
                    views.setTextViewText(numIds[i], "")
                }

                if (short == null) {
                    views.setViewVisibility(badgeIds[i], View.INVISIBLE)
                    views.setViewVisibility(dotIds[i], View.INVISIBLE)
                } else {
                    views.setViewVisibility(badgeIds[i], View.VISIBLE)
                    views.setViewVisibility(dotIds[i], View.VISIBLE)
                    views.setTextViewText(badgeIds[i], short)
                    views.setInt(dotIds[i], "setColorFilter", data.colorFor(key))
                }

                views.setInt(
                    cellIds[i],
                    "setBackgroundResource",
                    if (inMonth && key == todayKey) R.drawable.today_bg else 0,
                )
            }

            // 이번 달 날짜가 없는 주(마지막 줄)는 숨겨 빈 공간을 없앤다.
            for (r in 0 until 6) {
                views.setViewVisibility(
                    rowIds[r],
                    if (rowHasDay[r]) View.VISIBLE else View.GONE,
                )
            }

            views.setOnClickPendingIntent(
                R.id.month_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        ShiftDayData.scheduleMidnight(context, MonthWidgetProvider::class.java)
    }

    private companion object {
        val HOLIDAY_COLOR = android.graphics.Color.parseColor("#D32F2F")
        val DEFAULT_NUM_COLOR = android.graphics.Color.parseColor("#AA000000")

        val rowIds = intArrayOf(
            R.id.m_row0, R.id.m_row1, R.id.m_row2,
            R.id.m_row3, R.id.m_row4, R.id.m_row5,
        )
        val cellIds = intArrayOf(
            R.id.m0_cell, R.id.m1_cell, R.id.m2_cell, R.id.m3_cell, R.id.m4_cell,
            R.id.m5_cell, R.id.m6_cell, R.id.m7_cell, R.id.m8_cell, R.id.m9_cell,
            R.id.m10_cell, R.id.m11_cell, R.id.m12_cell, R.id.m13_cell,
            R.id.m14_cell, R.id.m15_cell, R.id.m16_cell, R.id.m17_cell,
            R.id.m18_cell, R.id.m19_cell, R.id.m20_cell, R.id.m21_cell,
            R.id.m22_cell, R.id.m23_cell, R.id.m24_cell, R.id.m25_cell,
            R.id.m26_cell, R.id.m27_cell, R.id.m28_cell, R.id.m29_cell,
            R.id.m30_cell, R.id.m31_cell, R.id.m32_cell, R.id.m33_cell,
            R.id.m34_cell, R.id.m35_cell, R.id.m36_cell, R.id.m37_cell,
            R.id.m38_cell, R.id.m39_cell, R.id.m40_cell, R.id.m41_cell,
        )
        val numIds = intArrayOf(
            R.id.m0_num, R.id.m1_num, R.id.m2_num, R.id.m3_num, R.id.m4_num,
            R.id.m5_num, R.id.m6_num, R.id.m7_num, R.id.m8_num, R.id.m9_num,
            R.id.m10_num, R.id.m11_num, R.id.m12_num, R.id.m13_num, R.id.m14_num,
            R.id.m15_num, R.id.m16_num, R.id.m17_num, R.id.m18_num, R.id.m19_num,
            R.id.m20_num, R.id.m21_num, R.id.m22_num, R.id.m23_num, R.id.m24_num,
            R.id.m25_num, R.id.m26_num, R.id.m27_num, R.id.m28_num, R.id.m29_num,
            R.id.m30_num, R.id.m31_num, R.id.m32_num, R.id.m33_num, R.id.m34_num,
            R.id.m35_num, R.id.m36_num, R.id.m37_num, R.id.m38_num, R.id.m39_num,
            R.id.m40_num, R.id.m41_num,
        )
        val dotIds = intArrayOf(
            R.id.m0_dot, R.id.m1_dot, R.id.m2_dot, R.id.m3_dot, R.id.m4_dot,
            R.id.m5_dot, R.id.m6_dot, R.id.m7_dot, R.id.m8_dot, R.id.m9_dot,
            R.id.m10_dot, R.id.m11_dot, R.id.m12_dot, R.id.m13_dot, R.id.m14_dot,
            R.id.m15_dot, R.id.m16_dot, R.id.m17_dot, R.id.m18_dot, R.id.m19_dot,
            R.id.m20_dot, R.id.m21_dot, R.id.m22_dot, R.id.m23_dot, R.id.m24_dot,
            R.id.m25_dot, R.id.m26_dot, R.id.m27_dot, R.id.m28_dot, R.id.m29_dot,
            R.id.m30_dot, R.id.m31_dot, R.id.m32_dot, R.id.m33_dot, R.id.m34_dot,
            R.id.m35_dot, R.id.m36_dot, R.id.m37_dot, R.id.m38_dot, R.id.m39_dot,
            R.id.m40_dot, R.id.m41_dot,
        )
        val badgeIds = intArrayOf(
            R.id.m0_badge, R.id.m1_badge, R.id.m2_badge, R.id.m3_badge,
            R.id.m4_badge, R.id.m5_badge, R.id.m6_badge, R.id.m7_badge,
            R.id.m8_badge, R.id.m9_badge, R.id.m10_badge, R.id.m11_badge,
            R.id.m12_badge, R.id.m13_badge, R.id.m14_badge, R.id.m15_badge,
            R.id.m16_badge, R.id.m17_badge, R.id.m18_badge, R.id.m19_badge,
            R.id.m20_badge, R.id.m21_badge, R.id.m22_badge, R.id.m23_badge,
            R.id.m24_badge, R.id.m25_badge, R.id.m26_badge, R.id.m27_badge,
            R.id.m28_badge, R.id.m29_badge, R.id.m30_badge, R.id.m31_badge,
            R.id.m32_badge, R.id.m33_badge, R.id.m34_badge, R.id.m35_badge,
            R.id.m36_badge, R.id.m37_badge, R.id.m38_badge, R.id.m39_badge,
            R.id.m40_badge, R.id.m41_badge,
        )
    }
}
