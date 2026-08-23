import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/banner_ad_view.dart';

void main() {
  test('横幅广告重试延迟逐次增加并在 1 分钟封顶', () {
    expect(bannerAdRetryDelay(0), const Duration(seconds: 15));
    expect(bannerAdRetryDelay(1), const Duration(seconds: 30));
    expect(bannerAdRetryDelay(2), const Duration(minutes: 1));
    expect(bannerAdRetryDelay(10), const Duration(minutes: 1));
  });
}
