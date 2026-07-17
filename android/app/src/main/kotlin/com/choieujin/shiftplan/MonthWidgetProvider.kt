package com.choieujin.shiftplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * 한 달 전체를 보여주는 홈 화면 위젯.
 *
 * Flutter가 `month_data` 키에 저장한 JSON(제목 + 42칸)을 파싱해 표시한다.
 * 칸마다 개별 키를 두면 쓰기 횟수가 200회를 넘기 때문에 JSON 한 덩어리로 받는다.
 */
class MonthWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val raw = widgetData.getString("month_data", null)
        val root = try {
            if (raw.isNullOrEmpty()) null else JSONObject(raw)
        } catch (e: org.json.JSONException) {
            null
        }
        val days = root?.optJSONArray("days")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.month_widget)

            views.setTextViewText(R.id.month_title, root?.optString("title") ?: "")
            views.setTextViewText(
                R.id.month_updated,
                widgetData.getString("widget_updated", "") ?: "",
            )

            for (i in 0 until 42) {
                val numId = numIds[i]
                val badgeId = badgeIds[i]
                val cell = days?.optJSONObject(i)

                val num = cell?.optString("n") ?: ""
                val short = cell?.optString("s") ?: ""
                val isToday = cell?.optBoolean("t") ?: false
                val isHoliday = cell?.optBoolean("h") ?: false

                views.setTextViewText(numId, num)
                views.setTextColor(
                    numId,
                    if (isHoliday) HOLIDAY_COLOR else DEFAULT_NUM_COLOR,
                )

                if (short.isEmpty()) {
                    // 근무가 없는 날(또는 이번 달이 아닌 칸)은 배지를 감춘다.
                    views.setViewVisibility(badgeId, View.INVISIBLE)
                } else {
                    views.setViewVisibility(badgeId, View.VISIBLE)
                    views.setTextViewText(badgeId, short)
                    views.setInt(
                        badgeId,
                        "setBackgroundColor",
                        parseColor(cell?.optString("c")),
                    )
                }

                views.setInt(
                    cellIds[i],
                    "setBackgroundResource",
                    if (isToday) R.drawable.today_bg else 0,
                )
            }

            views.setOnClickPendingIntent(
                R.id.month_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseColor(hex: String?): Int {
        return try {
            if (hex.isNullOrEmpty()) FALLBACK_COLOR else Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            FALLBACK_COLOR
        }
    }

    private companion object {
        val HOLIDAY_COLOR = Color.parseColor("#D32F2F")
        val DEFAULT_NUM_COLOR = Color.parseColor("#AA000000")
        val FALLBACK_COLOR = Color.parseColor("#B0BEC5")

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
