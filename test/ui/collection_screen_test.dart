import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/state/collection_provider.dart';
import 'package:idiom_crossword/src/ui/screens/collection_screen.dart';

Widget _screen(List<CollectionItem> items) => ProviderScope(
  overrides: [
    favoritesProvider.overrideWith((ref) async => items),
    collectionProvider.overrideWith((ref) async => items),
    favoriteIdsProvider.overrideWith((ref) async => <int>{}),
  ],
  child: const MaterialApp(home: CollectionScreen(bannerActive: false)),
);

CollectionItem _item(int id, {String? example}) => CollectionItem(
  id: id,
  word: '成语$id',
  explanation: '成语释义',
  derivation: '成语出处',
  example: example,
  pinyin: 'cheng yu',
  collectedAt: DateTime(2026),
);

void main() {
  testWidgets('例句为空或无时隐藏，有内容时展示', (tester) async {
    await tester.pumpWidget(
      _screen([
        _item(0),
        _item(1, example: ''),
        _item(2, example: '   '),
        _item(3, example: '无'),
        _item(4, example: ' 无 '),
        _item(5, example: '这是例句'),
      ]),
    );
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    await tester.scrollUntilVisible(
      find.text('· 这是例句'),
      100,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.text('· 这是例句'), findsOneWidget);
    for (final text in ['· ', '·    ', '· 无', '·  无 ']) {
      expect(find.text(text), findsNothing);
    }
  });

  for (final tab in ['收藏', '全部']) {
    testWidgets('$tab 翻到下一页和上一页均回到顶部', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _screen(
          List.generate(
            20,
            (id) => _item(
              id,
              example: List.filled(id < 10 ? 2 : 15, '长短不同的例句').join('，'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      for (final next in [true, false]) {
        await tester.scrollUntilVisible(
          find.text(next ? '第 1 / 2 页' : '第 2 / 2 页'),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0),
        );
        final buttons = find.descendant(
          of: list,
          matching: find.byType(IconButton),
        );
        await tester.tap(next ? buttons.last : buttons.first);
        await tester.pumpAndSettle();
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
        // 模拟底部广告出现和关闭带来的可用高度变化。
        await tester.binding.setSurfaceSize(const Size(800, 542));
        await tester.pumpAndSettle();
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
        await tester.binding.setSurfaceSize(null);
        await tester.pumpAndSettle();
        expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
        expect(find.text(next ? '成语10' : '成语0'), findsOneWidget);
      }
    });
  }
}
