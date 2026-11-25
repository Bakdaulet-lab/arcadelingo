import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _render(FlameTier tier, {double intensity = 0}) async {
  final recorder = ui.PictureRecorder();
  FlamePainter(
    tier: tier,
    mood: FlameMood.lit,
    scheme: wordarcadeColors,
    intensity: intensity,
  ).paint(ui.Canvas(recorder), const ui.Size.square(200));
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the campfire grows above a stationary stack of crossed logs', () async {
    final spark = await _render(FlameTier.spark);
    final blaze = await _render(FlameTier.blaze);
    final leap = await _render(FlameTier.blaze, intensity: 1);
    int alpha(Uint8List rgba, int x, int y) => rgba[(y * 200 + x) * 4 + 3];

    expect(alpha(spark, 110, 32), 0);
    expect(alpha(blaze, 110, 32), 255);
    expect(alpha(blaze, 44, 173), 255);
    expect(alpha(blaze, 146, 176), 255);
    const logsStart = 164 * 200 * 4;
    expect(spark.sublist(logsStart), blaze.sublist(logsStart));
    expect(leap.sublist(logsStart), blaze.sublist(logsStart));
    expect(leap.sublist(0, logsStart), isNot(blaze.sublist(0, logsStart)));
  });
}
