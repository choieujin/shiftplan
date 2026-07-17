import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/shift_type.dart';
import 'holiday_service.dart';

/// 홈 화면 위젯에 표시할 데이터를 저장하고 갱신을 요청한다.
///
/// - Android: `ShiftWidgetProvider` (주간), `MonthWidgetProvider` (월간)
/// - iOS: `ShiftWidget` (WidgetKit)
class WidgetService {
  WidgetService._();

  /// iOS App Group id. Runner + Widget Extension 양쪽에 동일하게 설정해야 한다.
  static const String iosAppGroupId = 'group.com.example.shiftplan';

  /// Android AppWidgetProvider의 클래스명.
  static const String androidWidgetName = 'ShiftWidgetProvider';

  /// Android 월간 위젯 Provider의 클래스명.
  static const String androidMonthWidgetName = 'MonthWidgetProvider';

  /// iOS WidgetKit의 kind 값.
  static const String iosWidgetName = 'ShiftWidget';

  static const List<String> _dowLabels = ['월', '화', '수', '목', '금', '토', '일'];

  /// 홈 위젯 플러그인은 Android/iOS에서만 동작한다.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported) return;
    // 사이드로딩 재서명으로 App Group id가 바뀌었을 수 있으니
    // 네이티브에서 실제 값을 조회한다 (실패 시 기본값).
    String groupId = iosAppGroupId;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final String? actual = await const MethodChannel('shiftplan/app_group')
            .invokeMethod<String>('getAppGroupId');
        if (actual != null && actual.isNotEmpty) groupId = actual;
      } catch (_) {}
    }
    await HomeWidget.setAppGroupId(groupId);
  }

  /// 이번 주(월~일)와 오늘/내일 근무 정보를 위젯 저장소에 기록하고 갱신한다.
  ///
  /// [typeFor]는 반복 패턴 규칙까지 반영된 날짜별 근무 조회 함수다.
  static Future<void> update({
    required ShiftType? Function(DateTime date) typeFor,
  }) async {
    if (!_supported) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    await _writeDay('today', today, typeFor(today));
    await _writeDay(
      'tomorrow',
      today.add(const Duration(days: 1)),
      typeFor(today.add(const Duration(days: 1))),
    );

    // 이번 주 월요일부터 7일.
    final DateTime weekStart =
        today.subtract(Duration(days: today.weekday - DateTime.monday));
    for (int i = 0; i < 7; i++) {
      final DateTime date = weekStart.add(Duration(days: i));
      final ShiftType? type = typeFor(date);
      await HomeWidget.saveWidgetData<String>('week_${i}_dow', _dowLabels[i]);
      await HomeWidget.saveWidgetData<String>('week_${i}_num', '${date.day}');
      await HomeWidget.saveWidgetData<String>(
        'week_${i}_short',
        type?.shortLabel ?? '-',
      );
      await HomeWidget.saveWidgetData<String>('week_${i}_color', _hex(type));
      await HomeWidget.saveWidgetData<String>(
        'week_${i}_today',
        date == today ? 'true' : 'false',
      );
    }

    await _writeMonth(today, typeFor);

    await HomeWidget.saveWidgetData<String>(
      'widget_updated',
      DateFormat('M월 d일 HH:mm 기준').format(now),
    );

    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      iOSName: iosWidgetName,
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await HomeWidget.updateWidget(androidName: androidMonthWidgetName);
    }
  }

  /// 이번 달 달력(월요일 시작, 6주 × 7일 = 42칸)을 JSON 한 덩어리로 저장한다.
  ///
  /// 칸마다 개별 키로 저장하면 200회가 넘는 비동기 쓰기가 발생하므로
  /// 네이티브에서 파싱하도록 JSON 문자열 하나로 넘긴다.
  static Future<void> _writeMonth(
    DateTime today,
    ShiftType? Function(DateTime date) typeFor,
  ) async {
    final DateTime first = DateTime(today.year, today.month, 1);
    // 그리드 시작일: 1일이 속한 주의 월요일.
    final DateTime gridStart =
        first.subtract(Duration(days: first.weekday - DateTime.monday));

    final List<Map<String, dynamic>> days = [];
    for (int i = 0; i < 42; i++) {
      final DateTime date = gridStart.add(Duration(days: i));
      final bool inMonth = date.month == today.month;
      final ShiftType? type = inMonth ? typeFor(date) : null;
      days.add({
        'n': inMonth ? '${date.day}' : '',
        's': type?.shortLabel ?? '',
        'c': type == null ? '' : _hex(type),
        't': inMonth && date == today,
        // 일요일과 공휴일은 날짜를 빨간색으로.
        'h': inMonth &&
            (date.weekday == DateTime.sunday || HolidayService.isHoliday(date)),
      });
    }

    await HomeWidget.saveWidgetData<String>(
      'month_data',
      jsonEncode({
        'title': DateFormat('yyyy년 M월', 'ko').format(today),
        'days': days,
      }),
    );
  }

  static Future<void> _writeDay(
    String prefix,
    DateTime date,
    ShiftType? type,
  ) async {
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_date',
      DateFormat('M/d (E)', 'ko').format(date),
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_name',
      type?.name ?? '없음',
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_short',
      type?.shortLabel ?? '-',
    );
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_time',
      type?.timeRange ?? '',
    );
    await HomeWidget.saveWidgetData<String>('${prefix}_color', _hex(type));
  }

  /// 위젯 네이티브에서 파싱할 수 있는 hex 색상 문자열. 없으면 회색.
  static String _hex(ShiftType? type) {
    final int argb = type?.colorValue ?? 0xFFB0BEC5;
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
