import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shiftplan/screens/pattern_screen.dart';
import 'package:shiftplan/services/shift_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ko');
  });

  /// 테스트 환경에는 home_widget 플러그인이 없으므로 [action] 동안만
  /// 미지원 플랫폼으로 바꿔 위젯 동기화를 건너뛰게 한다.
  Future<T> withoutHomeWidget<T>(Future<T> Function() action) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      return await action();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<ShiftRepository> loadRepository() => withoutHomeWidget(() async {
        final repo = ShiftRepository();
        await repo.load();
        return repo;
      });

  test('applyPattern은 시작일부터 패턴을 반복 적용한다', () async {
    final repo = await loadRepository();

    // 주주야비휴 (5일 주기) 를 10일간 적용.
    await withoutHomeWidget(() => repo.applyPattern(
          start: DateTime(2026, 7, 1),
          days: 10,
          pattern: ['day', 'day', 'night', 'rest', 'off'],
        ));

    expect(repo.typeForDate(DateTime(2026, 7, 1))?.id, 'day');
    expect(repo.typeForDate(DateTime(2026, 7, 2))?.id, 'day');
    expect(repo.typeForDate(DateTime(2026, 7, 3))?.id, 'night');
    expect(repo.typeForDate(DateTime(2026, 7, 4))?.id, 'rest');
    expect(repo.typeForDate(DateTime(2026, 7, 5))?.id, 'off');
    // 두 번째 주기.
    expect(repo.typeForDate(DateTime(2026, 7, 6))?.id, 'day');
    expect(repo.typeForDate(DateTime(2026, 7, 10))?.id, 'off');
    // 적용 범위 밖.
    expect(repo.typeForDate(DateTime(2026, 7, 11)), isNull);
  });

  test('days가 null이면 무제한 규칙으로 저장되어 먼 미래에도 적용된다', () async {
    final repo = await loadRepository();

    await withoutHomeWidget(() => repo.applyPattern(
          start: DateTime(2026, 7, 1),
          pattern: ['day', 'day', 'night', 'rest', 'off'],
        ));

    expect(repo.hasPatternRule, isTrue);
    expect(repo.typeForDate(DateTime(2026, 7, 3))?.id, 'night');
    // 5일 주기 유지: 2030-07-01 은 시작 후 1461일 = 5*292+1 → 'day'(2번째 칸).
    expect(repo.typeForDate(DateTime(2030, 7, 1))?.id, 'day');
    // 시작일 이전에는 적용되지 않는다.
    expect(repo.typeForDate(DateTime(2026, 6, 30)), isNull);
  });

  test('무제한 규칙 위에 개별 배정과 비움이 우선한다', () async {
    final repo = await loadRepository();

    await withoutHomeWidget(() async {
      await repo.applyPattern(
        start: DateTime(2026, 7, 1),
        pattern: ['day', 'night'],
      );
      // 규칙상 'day'인 날을 'off'로 덮어쓰기.
      await repo.assign(DateTime(2026, 7, 3), 'off');
      // 규칙상 'night'인 날을 명시적으로 비우기.
      await repo.assign(DateTime(2026, 7, 4), null);
    });

    expect(repo.typeForDate(DateTime(2026, 7, 3))?.id, 'off');
    expect(repo.typeForDate(DateTime(2026, 7, 4)), isNull);
    // 다른 날짜는 규칙 그대로.
    expect(repo.typeForDate(DateTime(2026, 7, 5))?.id, 'day');
  });

  test('규칙을 해제하면 패턴 배정이 사라지고 저장소에서도 지워진다', () async {
    final repo = await loadRepository();

    await withoutHomeWidget(() async {
      await repo.applyPattern(
        start: DateTime(2026, 7, 1),
        pattern: ['day', 'night'],
      );
      await repo.clearPatternRule();
    });

    expect(repo.hasPatternRule, isFalse);
    expect(repo.typeForDate(DateTime(2026, 7, 1)), isNull);

    // 다시 로드해도 규칙이 없다.
    final reloaded = await loadRepository();
    expect(reloaded.hasPatternRule, isFalse);
  });

  test('무제한 규칙은 다시 로드해도 유지된다', () async {
    final repo = await loadRepository();
    await withoutHomeWidget(() => repo.applyPattern(
          start: DateTime(2026, 7, 1),
          pattern: ['day', 'night'],
        ));

    final reloaded = await loadRepository();
    expect(reloaded.hasPatternRule, isTrue);
    expect(reloaded.typeForDate(DateTime(2026, 7, 2))?.id, 'night');
  });

  testWidgets('패턴 텍스트 "주주야비휴" 입력 시 5일 주기로 파싱된다', (tester) async {
    final repo = await loadRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PatternScreen(repository: repo, startDate: DateTime(2026, 7, 1)),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, '패턴 입력'),
      '주주야비휴',
    );
    await tester.pump();

    expect(find.text('5일 주기로 반복'), findsOneWidget);
  });

  testWidgets('없는 근무 라벨 입력 시 오류를 표시한다', (tester) async {
    final repo = await loadRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PatternScreen(repository: repo, startDate: DateTime(2026, 7, 1)),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '패턴 입력'), '주멍');
    await tester.pump();

    expect(find.textContaining('해당하는 근무 유형이 없습니다'), findsOneWidget);
  });
}
