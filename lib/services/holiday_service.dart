import 'package:klc/klc.dart' as klc;

import '../models/shift_assignment.dart';

/// 대한민국 법정 공휴일 계산.
///
/// 고정 공휴일과 음력 공휴일(설날·부처님오신날·추석)을 계산하고,
/// 대체공휴일 규정(관공서의 공휴일에 관한 규정 제3조)을 적용한다.
/// 임시공휴일·선거일은 포함하지 않는다.
class HolidayService {
  HolidayService._();

  // 연도별 계산 결과 캐시. dateKey('yyyy-MM-dd') -> 공휴일 이름.
  static final Map<int, Map<String, String>> _cache = {};

  /// 토·일요일과 겹치면 대체공휴일이 생기는 공휴일. (2021.8. 개정 기준)
  static const Set<String> _substitutable = {
    '삼일절',
    '어린이날',
    '부처님오신날',
    '광복절',
    '개천절',
    '한글날',
    '기독탄신일',
  };

  static bool isHoliday(DateTime date) => holidayName(date) != null;

  /// [date]가 공휴일이면 이름을, 아니면 null을 반환한다.
  static String? holidayName(DateTime date) {
    if (date.year < 1900 || date.year > 2049) return null;
    final Map<String, String> holidays =
        _cache.putIfAbsent(date.year, () => _compute(date.year));
    return holidays[ShiftAssignment.keyFor(date)];
  }

  static DateTime _lunarToSolar(int lunarYear, int month, int day) {
    klc.setLunarDate(lunarYear, month, day, false);
    return DateTime(klc.getSolarYear(), klc.getSolarMonth(), klc.getSolarDay());
  }

  static Map<String, String> _compute(int year) {
    final Map<String, String> holidays = {};
    // 같은 날 두 공휴일이 겹친 경우(예: 2025년 어린이날+부처님오신날).
    final Set<String> collided = {};

    void add(DateTime date, String name) {
      final String key = ShiftAssignment.keyFor(date);
      if (holidays.containsKey(key)) {
        collided.add(name);
      } else {
        holidays[key] = name;
      }
    }

    final DateTime seollal = _lunarToSolar(year, 1, 1);
    final DateTime buddha = _lunarToSolar(year, 4, 8);
    final DateTime chuseok = _lunarToSolar(year, 8, 15);

    add(DateTime(year, 1, 1), '신정');
    add(seollal.subtract(const Duration(days: 1)), '설날 연휴');
    add(seollal, '설날');
    add(seollal.add(const Duration(days: 1)), '설날 연휴');
    add(DateTime(year, 3, 1), '삼일절');
    add(DateTime(year, 5, 5), '어린이날');
    add(buddha, '부처님오신날');
    add(DateTime(year, 6, 6), '현충일');
    add(DateTime(year, 8, 15), '광복절');
    add(chuseok.subtract(const Duration(days: 1)), '추석 연휴');
    add(chuseok, '추석');
    add(chuseok.add(const Duration(days: 1)), '추석 연휴');
    add(DateTime(year, 10, 3), '개천절');
    add(DateTime(year, 10, 9), '한글날');
    add(DateTime(year, 12, 25), '기독탄신일');

    // 공휴일(일요일 포함)이 아닌 다음 날을 찾는다.
    DateTime nextFreeDay(DateTime from) {
      DateTime d = from.add(const Duration(days: 1));
      while (d.weekday == DateTime.sunday ||
          holidays.containsKey(ShiftAssignment.keyFor(d))) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    // 설·추석 연휴: 일요일과 겹치면 연휴 다음 날이 대체공휴일.
    for (final DateTime mid in [seollal, chuseok]) {
      final bool overlapsSunday = [
        mid.subtract(const Duration(days: 1)),
        mid,
        mid.add(const Duration(days: 1)),
      ].any((d) => d.weekday == DateTime.sunday);
      if (overlapsSunday) {
        final String key = ShiftAssignment.keyFor(
            nextFreeDay(mid.add(const Duration(days: 1))));
        holidays[key] = '대체공휴일';
      }
    }

    // 토·일요일(또는 다른 공휴일)과 겹친 공휴일의 대체공휴일.
    final List<MapEntry<DateTime, String>> singles = [
      MapEntry(DateTime(year, 3, 1), '삼일절'),
      MapEntry(DateTime(year, 5, 5), '어린이날'),
      MapEntry(buddha, '부처님오신날'),
      MapEntry(DateTime(year, 8, 15), '광복절'),
      MapEntry(DateTime(year, 10, 3), '개천절'),
      MapEntry(DateTime(year, 10, 9), '한글날'),
      MapEntry(DateTime(year, 12, 25), '기독탄신일'),
    ];
    for (final entry in singles) {
      final String name = entry.value;
      if (!_substitutable.contains(name)) continue;
      // 부처님오신날·기독탄신일은 2023년, 나머지 국경일은 2021년부터 적용.
      final int since =
          (name == '부처님오신날' || name == '기독탄신일') ? 2023 : 2021;
      if (year < since) continue;
      final DateTime date = entry.key;
      final bool onWeekend = date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;
      if (onWeekend || collided.contains(name)) {
        holidays[ShiftAssignment.keyFor(nextFreeDay(date))] = '대체공휴일';
      }
    }

    return holidays;
  }
}
