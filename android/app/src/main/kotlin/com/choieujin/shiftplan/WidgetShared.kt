package com.choieujin.shiftplan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.text.format.DateFormat
import java.util.Calendar
import org.json.JSONObject

/**
 * Flutter가 `day_data`에 저장한 dateKey→{s,c,h} 맵을 읽어
 * 위젯이 실행 시점의 실제 날짜로 근무를 조회하게 한다.
 *
 * 위젯이 스스로 "오늘"을 계산하므로 앱을 열지 않아도 자정이 지나면 갱신된다.
 */
class ShiftDayData(prefs: SharedPreferences) {
    private val days: JSONObject = try {
        val raw = prefs.getString("day_data", null)
        if (raw.isNullOrEmpty()) JSONObject() else JSONObject(raw)
    } catch (e: org.json.JSONException) {
        JSONObject()
    }

    /** dateKey('yyyy-MM-dd')의 근무 라벨. 없으면 null. */
    fun shortFor(key: String): String? =
        days.optJSONObject(key)?.optString("s")?.takeIf { it.isNotEmpty() }

    /** dateKey의 근무 색상(int). 근무가 없으면 회색. */
    fun colorFor(key: String): Int {
        val hex = days.optJSONObject(key)?.optString("c")
        return try {
            if (hex.isNullOrEmpty()) FALLBACK else Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            FALLBACK
        }
    }

    /** dateKey가 일요일 또는 공휴일인지. */
    fun isHoliday(key: String): Boolean =
        days.optJSONObject(key)?.optInt("h", 0) == 1

    companion object {
        val FALLBACK: Int = Color.parseColor("#B0BEC5")

        /** 자정 기준 오늘 0시. */
        fun startOfToday(): Calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        fun keyFor(cal: Calendar): String {
            val y = cal.get(Calendar.YEAR)
            val m = cal.get(Calendar.MONTH) + 1
            val d = cal.get(Calendar.DAY_OF_MONTH)
            return "%04d-%02d-%02d".format(y, m, d)
        }

        /** 갱신 시각 표시용 문자열. */
        fun updatedLabel(context: Context): String {
            val now = Calendar.getInstance()
            val fmt = if (DateFormat.is24HourFormat(context)) "M월 d일 HH:mm 기준"
            else "M월 d일 a h:mm 기준"
            return DateFormat.format(fmt, now).toString()
        }

        /**
         * 다음 자정에 위젯을 갱신하도록 알람을 예약한다.
         * onUpdate마다 재예약해 알람이 유지되게 한다.
         */
        fun scheduleMidnight(context: Context, providerClass: Class<*>) {
            val next = startOfToday().apply { add(Calendar.DAY_OF_MONTH, 1) }
            val intent = Intent(context, providerClass).apply {
                action = ACTION_MIDNIGHT
            }
            val pi = PendingIntent.getBroadcast(
                context,
                providerClass.name.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            // 정확 알람 권한(Android 12+)이 필요 없는 비정확 알람. 자정 근처에 울린다.
            am.setAndAllowWhileIdle(
                AlarmManager.RTC,
                next.timeInMillis,
                pi,
            )
        }

        const val ACTION_MIDNIGHT = "com.choieujin.shiftplan.MIDNIGHT_UPDATE"
    }
}
