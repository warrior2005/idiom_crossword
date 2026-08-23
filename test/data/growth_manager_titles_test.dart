import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';

void main() {
  test('Lv.7 至 Lv.9 的科举称号顺序正确', () {
    expect(GrowthManager.titleForLevel(7), '贡士');
    expect(GrowthManager.titleForLevel(8), '会元');
    expect(GrowthManager.titleForLevel(9), '进士');
  });
}
