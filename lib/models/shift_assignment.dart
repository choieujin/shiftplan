import 'package:intl/intl.dart';

/// 특정 날짜에 배정된 근무. 저장 시 날짜는 'yyyy-MM-dd' 키로 사용된다.
class ShiftAssignment {
  ShiftAssignment({required this.date, required this.shiftTypeId});

  final DateTime date;
  final String shiftTypeId;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');

  /// 시/분/초를 제거한 날짜 키 문자열.
  static String keyFor(DateTime date) =>
      _fmt.format(DateTime(date.year, date.month, date.day));

  String get key => keyFor(date);
}
