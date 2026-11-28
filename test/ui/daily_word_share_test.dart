import 'package:arcadelingo/ui/daily_word_share.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('arcadelingo/daily_word_share');
  const grid = 'ArcadeLingo · A1\n🟨⬜🟩\n🟩🟩🟩';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'passes only the supplied grid to the $platform system share sheet',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        MethodCall? sent;
        messenger.setMockMethodCallHandler(channel, (call) async {
          sent = call;
          return true;
        });
        expect(await shareDailyWordResult(grid), DailyWordShareOutcome.opened);
        expect(sent!.method, 'shareText');
        expect(sent!.arguments, grid);
      },
    );
  }
  test(
    'copies the grid if a native sheet cannot open and reports clipboard failure',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        expect(call.method, 'Clipboard.setData');
        copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      expect(await shareDailyWordResult(grid), DailyWordShareOutcome.copied);
      expect(copied, grid);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async {
        throw PlatformException(code: 'clipboard-unavailable');
      });
      expect(await shareDailyWordResult(grid), DailyWordShareOutcome.failed);
    },
  );
}
