import 'dart:async';

import 'package:dirichlet_ads/dirichlet_ads.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/utils/ad_region.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/dirichlet');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late DirichletAds ads;

  setUp(() {
    ads = DirichletAds(channel: channel);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('only mainland system region selects Dirichlet', () {
    expect(usesDirichletForRegion('CN'), isTrue);
    expect(usesDirichletForRegion('cn'), isTrue);
    for (final region in ['HK', 'MO', 'TW', 'US', 'SG', 'zh', '', null]) {
      expect(usesDirichletForRegion(region), isFalse, reason: '$region');
    }
  });

  test('concurrent reward entry points share one native load', () async {
    final loaded = Completer<bool>();
    var requests = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadRewarded') {
        requests++;
        return loaded.future;
      }
      return null;
    });
    final first = ads.loadRewarded();
    final second = ads.loadRewarded();
    loaded.complete(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(requests, 1);
    expect(ads.rewardReady.value, isTrue);
  });

  test('a late load cannot restore an ad after disposal', () async {
    final loaded = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadRewarded') return loaded.future;
      return null;
    });
    final pending = ads.loadRewarded();
    await ads.disposeAds();
    loaded.complete(true);
    expect(await pending, isFalse);
    expect(ads.rewardReady.value, isFalse);
  });

  test('SDK load failure leaves the reward unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'no_fill');
    });
    expect(await ads.loadRewarded(), isFalse);
    expect(ads.rewardReady.value, isFalse);
  });

  for (final outcome in [true, false, 'error']) {
    test(
      'show result $outcome closes once and only true earns a reward',
      () async {
        final result = Completer<bool>();
        final closed = Completer<void>();
        var rewards = 0;
        var shows = 0;
        final events = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'loadRewarded') return true;
          if (call.method == 'showRewarded') {
            shows++;
            if (outcome == 'error') throw PlatformException(code: 'not_ready');
            return result.future;
          }
          return null;
        });
        await ads.loadRewarded();
        expect(
          ads.showRewarded(
            onRewardEarned: (_, _) {
              rewards++;
              events.add('reward');
            },
            onAdClosed: () {
              events.add('closed');
              closed.complete();
            },
          ),
          isTrue,
        );
        expect(ads.rewardReady.value, isFalse);
        expect(
          ads.showRewarded(
            onRewardEarned: (_, _) {
              rewards++;
            },
          ),
          isFalse,
        );
        expect(await ads.loadRewarded(), isFalse);
        if (outcome is bool) result.complete(outcome);
        await closed.future;
        expect(shows, 1);
        expect(rewards, outcome == true ? 1 : 0);
        expect(events, outcome == true ? ['reward', 'closed'] : ['closed']);
      },
    );
  }

  test(
    'disposal suppresses a delayed reward but still releases the caller',
    () async {
      final result = Completer<bool>();
      final closed = Completer<void>();
      var rewards = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'loadRewarded') return true;
        if (call.method == 'showRewarded') return result.future;
        return null;
      });
      await ads.loadRewarded();
      ads.showRewarded(
        onRewardEarned: (_, _) {
          rewards++;
        },
        onAdClosed: closed.complete,
      );
      await ads.disposeAds();
      result.complete(true);
      await closed.future;
      expect(rewards, 0);
    },
  );
}
