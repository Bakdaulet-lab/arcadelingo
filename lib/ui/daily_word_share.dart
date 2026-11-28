import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DailyWordShareOutcome { opened, copied, failed }

const _channel = MethodChannel('arcadelingo/daily_word_share');

Future<DailyWordShareOutcome> shareDailyWordResult(String grid) async {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      if (await _channel.invokeMethod<bool>('shareText', grid) == true) {
        return DailyWordShareOutcome.opened;
      }
    } on PlatformException {
      // Fall back if the system cannot present the sheet.
    } on MissingPluginException {
      // Embedders without the share handler can still copy text.
    }
  }
  try {
    await Clipboard.setData(ClipboardData(text: grid));
    return DailyWordShareOutcome.copied;
  } on PlatformException {
    return DailyWordShareOutcome.failed;
  } on MissingPluginException {
    return DailyWordShareOutcome.failed;
  }
}
