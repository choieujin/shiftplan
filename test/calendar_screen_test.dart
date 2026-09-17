import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shiftplan/screens/calendar_screen.dart';
import 'package:shiftplan/services/holiday_service.dart';
import 'package:shiftplan/services/shift_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ko');
  });

  /// 테스트 환경에는 home_widget·광고 플러그인이 없으므로 미지원 플랫폼으로
  /// 바꿔 위젯 동기화와 배너 로드를 건너뛰게 한다.
  Future<T> withoutPlugins<T>(Future<T> Function() action) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      return await action();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// 현재 달력에 그려진 날짜 숫자 중 완전한 빨간색인 것들의 '일' 값.
  /// 이전·다음 달 날짜는 흐리게(투명도 적용) 그려지므로 제외된다.
  Set<int> redDayNumbers(WidgetTester tester) {
    final Set<int> days = {};
    for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
      final int? day = int.tryParse(text.data ?? '');
      if (day == null || day < 1 || day > 31) continue;
      if (text.style?.color == Colors.red) days.add(day);
    }
    return days;
  }

  /// [month]에 속한 날 중 일요일이거나 공휴일인 날의 '일' 값.
  Set<int> expectedRedDays(DateTime month) {
    final Set<int> days = {};
    DateTime d = DateTime(month.year, month.month, 1);
    while (d.month == month.month) {
      if (HolidayService.isRedDay(d)) days.add(d.day);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return days;
  }

  Future<ShiftRepository> loadRepository() => withoutPlugins(() async {
        final repo = ShiftRepository();
        await repo.load();
        return repo;
      });

  Future<void> pumpCalendar(WidgetTester tester, ShiftRepository repo) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await withoutPlugins(() async {
      await tester.pumpWidget(
        MaterialApp(home: CalendarScreen(repository: repo)),
      );
      await tester.pump();
    });
  }

  testWidgets('공휴일·일요일 날짜 숫자는 빨간색으로 표시된다', (tester) async {
    final repo = await loadRepository();
    await pumpCalendar(tester, repo);

    final DateTime now = DateTime.now();
    expect(redDayNumbers(tester), expectedRedDays(now));
    // 이번 달에 빨간 날이 하나도 없는 경우는 없다(일요일이 반드시 있다).
    expect(redDayNumbers(tester), isNotEmpty);
  });

  testWidgets('근무가 배정된 공휴일·일요일도 숫자는 빨간색을 유지한다', (tester) async {
    final repo = await loadRepository();
    // 이번 달 모든 날에 근무를 배정해, 근무색 원이 빨간 숫자를 덮지 않는지 본다.
    final DateTime now = DateTime.now();
    await withoutPlugins(() => repo.applyPattern(
          start: DateTime(now.year, now.month, 1),
          days: 31,
          pattern: ['day'],
        ));

    await pumpCalendar(tester, repo);

    expect(redDayNumbers(tester), expectedRedDays(now));
  });
}
