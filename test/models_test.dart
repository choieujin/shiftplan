import 'package:flutter_test/flutter_test.dart';
import 'package:shiftplan/models/shift_assignment.dart';
import 'package:shiftplan/models/shift_type.dart';

void main() {
  group('ShiftAssignment.keyFor', () {
    test('시/분/초를 무시하고 동일한 키를 만든다', () {
      final a = ShiftAssignment.keyFor(DateTime(2026, 7, 15, 9, 30));
      final b = ShiftAssignment.keyFor(DateTime(2026, 7, 15, 23, 59));
      expect(a, b);
      expect(a, '2026-07-15');
    });

    test('한 자리 월/일을 0으로 채운다', () {
      expect(ShiftAssignment.keyFor(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('ShiftType JSON', () {
    test('직렬화 후 역직렬화하면 값이 유지된다', () {
      final type = ShiftType(
        id: 'night',
        name: '야간',
        shortLabel: '야',
        colorValue: 0xFF1565C0,
        startTime: '23:00',
        endTime: '07:00',
      );
      final restored = ShiftType.fromJson(type.toJson());
      expect(restored.id, type.id);
      expect(restored.name, type.name);
      expect(restored.shortLabel, type.shortLabel);
      expect(restored.colorValue, type.colorValue);
      expect(restored.startTime, type.startTime);
      expect(restored.endTime, type.endTime);
      expect(restored.timeRange, '23:00 ~ 07:00');
    });

    test('시간이 없으면 timeRange는 빈 문자열', () {
      final off = ShiftType(
        id: 'off',
        name: '휴무',
        shortLabel: '휴',
        colorValue: 0xFF9E9E9E,
      );
      expect(off.timeRange, '');
    });
  });

  group('defaults', () {
    test('기본 근무 유형 4종을 제공한다', () {
      final defaults = ShiftType.defaults();
      expect(defaults.length, 4);
      expect(defaults.map((e) => e.id), containsAll(['day', 'evening', 'night', 'off']));
    });
  });
}
