import 'package:flutter_test/flutter_test.dart';
import 'package:shiftplan/services/holiday_service.dart';

void main() {
  group('고정 공휴일', () {
    test('신정/삼일절/현충일/광복절 등을 인식한다', () {
      expect(HolidayService.holidayName(DateTime(2026, 1, 1)), '신정');
      expect(HolidayService.holidayName(DateTime(2026, 3, 1)), '삼일절');
      expect(HolidayService.holidayName(DateTime(2026, 6, 6)), '현충일');
      expect(HolidayService.holidayName(DateTime(2026, 8, 15)), '광복절');
      expect(HolidayService.holidayName(DateTime(2026, 10, 3)), '개천절');
      expect(HolidayService.holidayName(DateTime(2026, 10, 9)), '한글날');
      expect(HolidayService.holidayName(DateTime(2026, 12, 25)), '기독탄신일');
      expect(HolidayService.isHoliday(DateTime(2026, 7, 15)), isFalse);
    });
  });

  group('음력 공휴일', () {
    test('2025년 설날 연휴는 1/28~1/30', () {
      expect(HolidayService.holidayName(DateTime(2025, 1, 28)), '설날 연휴');
      expect(HolidayService.holidayName(DateTime(2025, 1, 29)), '설날');
      expect(HolidayService.holidayName(DateTime(2025, 1, 30)), '설날 연휴');
    });

    test('2025년 추석은 10/6, 연휴는 10/5~10/7', () {
      expect(HolidayService.holidayName(DateTime(2025, 10, 5)), '추석 연휴');
      expect(HolidayService.holidayName(DateTime(2025, 10, 6)), '추석');
      expect(HolidayService.holidayName(DateTime(2025, 10, 7)), '추석 연휴');
    });

    test('2026년 설날은 2/17', () {
      expect(HolidayService.holidayName(DateTime(2026, 2, 17)), '설날');
    });
  });

  group('대체공휴일', () {
    test('2026년 삼일절(일요일) → 3/2 대체공휴일', () {
      expect(DateTime(2026, 3, 1).weekday, DateTime.sunday);
      expect(HolidayService.holidayName(DateTime(2026, 3, 2)), '대체공휴일');
    });

    test('2026년 광복절(토요일) → 8/17(월) 대체공휴일', () {
      expect(DateTime(2026, 8, 15).weekday, DateTime.saturday);
      expect(HolidayService.holidayName(DateTime(2026, 8, 17)), '대체공휴일');
    });

    test('2025년 어린이날과 부처님오신날이 겹쳐 5/6 대체공휴일', () {
      expect(HolidayService.holidayName(DateTime(2025, 5, 5)), isNotNull);
      expect(HolidayService.holidayName(DateTime(2025, 5, 6)), '대체공휴일');
    });

    test('2025년 추석 연휴가 일요일과 겹쳐 10/8 대체공휴일', () {
      expect(DateTime(2025, 10, 5).weekday, DateTime.sunday);
      expect(HolidayService.holidayName(DateTime(2025, 10, 8)), '대체공휴일');
    });

    test('현충일은 주말과 겹쳐도 대체공휴일이 없다', () {
      expect(DateTime(2026, 6, 6).weekday, DateTime.saturday);
      expect(HolidayService.isHoliday(DateTime(2026, 6, 8)), isFalse);
    });
  });
}
