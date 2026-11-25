import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each earned day shows the latest unlocked Pixel Valley stage', () {
    const thresholds = [
      1,
      2,
      3,
      4,
      5,
      7,
      10,
      14,
      21,
      28,
      35,
      42,
      49,
      60,
      75,
      90,
      92,
      94,
      96,
      98,
      100,
    ];
    expect(CampfireStage.values.map((stage) => stage.day), thresholds);
    expect(CampfireStage.forDays(-1), isNull);
    expect(CampfireStage.forDays(0), isNull);
    for (var i = 0; i < thresholds.length; i++) {
      final start = thresholds[i];
      final until = i + 1 < thresholds.length ? thresholds[i + 1] : 367;
      for (var day = start; day < until; day++) {
        expect(CampfireStage.forDays(day)?.day, start, reason: 'day $day');
      }
    }
    expect(CampfireStage.forDays(10000)?.day, 100);
  });
}
