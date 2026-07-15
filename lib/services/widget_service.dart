import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/shift_assignment.dart';
import '../models/shift_type.dart';

/// 홈 화면 위젯에 표시할 데이터를 저장하고 갱신을 요청한다.
///
/// - Android: `ShiftWidgetProvider` (AppWidget)
/// - iOS: `ShiftWidget` (WidgetKit)
class WidgetService {
  WidgetService._();

  /// iOS App Group id. Runner + Widget Extension 양쪽에 동일하게 설정해야 한다.
  static const String iosAppGroupId = 'group.com.example.shiftplan';

  /// Android AppWidgetProvider의 클래스명.
  static const String androidWidgetName = 'ShiftWidgetProvider';

  /// iOS WidgetKit의 kind 값.
  static const String iosWidgetName = 'ShiftWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(iosAppGroupId);
  }

  /// 오늘/내일 근무 정보를 위젯 저장소에 기록하고 위젯을 갱신한다.
  static Future<void> update({
    required Map<String, String> assignments,
    required Map<String, ShiftType> typesById,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    await _writeDay('today', today, assignments, typesById);
    await _writeDay('tomorrow', tomorrow, assignments, typesById);

    await HomeWidget.saveWidgetData<String>(
      'widget_updated',
      DateFormat('M월 d일 HH:mm 기준').format(now),
    );

    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      iOSName: iosWidgetName,
    );
  }

  static Future<void> _writeDay(
    String prefix,
    DateTime date,
    Map<String, String> assignments,
    Map<String, ShiftType> typesById,
  ) async {
    final String? typeId = assignments[ShiftAssignment.keyFor(date)];
    final ShiftType? type = typeId == null ? null : typesById[typeId];

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
    // 위젯 네이티브에서 파싱할 수 있도록 색상을 hex 문자열로 저장.
    final int argb = type?.colorValue ?? 0xFFB0BEC5;
    await HomeWidget.saveWidgetData<String>(
      '${prefix}_color',
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    );
  }
}
