import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/utils/lunar_calendar.dart';

void main() {
  group('solarToLunar', () {
    // 农历新年（正月初一）各年验证
    const cny = <int, (int, int)>{
      2000: (2, 5),
      2020: (1, 25),
      2021: (2, 12),
      2022: (2, 1),
      2023: (1, 22),
      2024: (2, 10),
      2025: (1, 29),
      2026: (2, 17),
      2030: (2, 3),
      2034: (2, 19),
    };
    cny.forEach((year, md) {
      test('$year 年正月初一', () {
        final l = solarToLunar(DateTime(year, md.$1, md.$2));
        expect(l.month, 1);
        expect(l.day, 1);
        expect(l.isLeap, isFalse);
        expect(l.monthName, '正月');
        expect(l.dayName, '初一');
      });
    });

    test('2023 闰二月', () {
      final l = solarToLunar(DateTime(2023, 3, 22));
      expect(l.month, 2);
      expect(l.day, 1);
      expect(l.isLeap, isTrue);
      expect(l.monthName, '闰二月');
    });

    test('2024-03-10 为二月初一', () {
      final l = solarToLunar(DateTime(2024, 3, 10));
      expect(l.month, 2);
      expect(l.day, 1);
    });

    test('农历日名', () {
      expect(solarToLunar(DateTime(2026, 8, 6)).dayName, '廿四');
      expect(solarToLunar(DateTime(2026, 8, 6)).monthName, '六月');
    });
  });

  group('currentSolarTerm', () {
    test('2026 大暑后、立秋前为大暑', () {
      expect(currentSolarTerm(DateTime(2026, 8, 6)), '大暑');
    });
    test('谷雨当天为谷雨', () {
      expect(currentSolarTerm(DateTime(2026, 4, 20)), '谷雨');
    });
    test('冬至当天为冬至', () {
      expect(currentSolarTerm(DateTime(2026, 12, 22)), '冬至');
    });
  });
}
