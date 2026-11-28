import 'package:arcadelingo/ui/campfire_painter.dart';
import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A decoded sheet plus the static scenery behind it. The widget owns these
/// image handles. The painter only selects a rectangle for the current frame.
class ValleyArtwork {
  ValleyArtwork(this.sheet, this.plate);

  final ImageInfo sheet;
  final ImageInfo? plate;

  static List<ExactAssetImage> assetsFor(
    CampfireStage stage, {
    required Brightness brightness,
    required bool landscape,
  }) {
    final dir = 'assets/streak_valley/${brightness.name}';
    final day = stage.day;
    if (!landscape) return [ExactAssetImage('$dir/badge_$day.webp')];
    final area = switch (day) {
      < 7 => 1,
      <= 28 => 7,
      35 => 35,
      < 60 => 42,
      < 90 => 60,
      < 100 => 90,
      _ => 100,
    };
    return [
      ExactAssetImage('$dir/scene_$day.webp'),
      ExactAssetImage('$dir/land_$area.webp'),
    ];
  }

  void dispose() {
    sheet.dispose();
    plate?.dispose();
  }
}

class ValleyCampfirePainter extends FlamePainter {
  ValleyCampfirePainter({
    required this.stage,
    required this.landscape,
    required this.artwork,
    required this.previous,
    required this.frames,
    required this.accent,
    required this.repaint,
    required super.tier,
    required super.mood,
    required super.scheme,
  });

  static const frameCount = 72;
  static const transitionFrames = 5;
  static const _columns = 8;
  static const _rows = frameCount ~/ _columns;
  final CampfireStage? stage;
  final bool landscape;
  final ValleyArtwork? artwork;
  final ValleyArtwork? previous;
  final ValueListenable<int> frames;
  final Animation<double> accent;
  final Listenable repaint;

  int get frame => frames.value;
  bool get hasArtwork => artwork != null;

  @override
  double get intensity {
    final t = accent.value;
    return t <= .3
        ? Curves.easeOutCubic.transform(t / .3)
        : 1 - Curves.easeInOut.transform((t - .3) / .7);
  }

  @override
  void addListener(VoidCallback listener) => repaint.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      repaint.removeListener(listener);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final art = artwork ?? previous;
    if (art == null) {
      if (stage == null && !landscape) super.paint(canvas, size);
      return;
    }
    const panorama = Size(240, 100);
    final dest = Alignment.center.inscribe(
      applyBoxFit(
        BoxFit.contain,
        landscape ? panorama : const Size.square(72),
        size,
      ).destination,
      Offset.zero & size,
    );
    // The sheets contain whole, hand-pixelled frames. Filtering between them
    // would draw the edges of the neighbouring cell along the silhouette.
    final paint = Paint()..filterQuality = FilterQuality.none;
    final from = previous;
    if (artwork != null && from != null && frame < transitionFrames) {
      final progress = Curves.easeOut.transform(frame / transitionFrames);
      _draw(canvas, from, 0, dest, paint, landscape ? 1 : 1 - progress);
      _draw(canvas, art, frame, dest, paint, progress);
    } else {
      _draw(canvas, art, frame, dest, paint, 1);
    }
  }

  void _draw(
    Canvas canvas,
    ValleyArtwork art,
    int index,
    Rect dest,
    Paint paint,
    double opacity,
  ) {
    paint.color = Colors.white.withValues(alpha: opacity);
    paint.colorFilter = null;
    final plate = art.plate?.image;
    if (plate != null) {
      canvas.drawImageRect(
        plate,
        Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble()),
        dest,
        paint,
      );
    }
    final sheet = art.sheet.image;
    final width = sheet.width / _columns;
    final height = sheet.height / _rows;
    final src = Rect.fromLTWH(
      (index % _columns) * width,
      (index ~/ _columns) * height,
      width,
      height,
    );
    paint.colorFilter = switch (mood) {
      FlameMood.unlit => ColorFilter.mode(
        scheme.surface.withValues(alpha: .42),
        BlendMode.srcATop,
      ),
      FlameMood.atRisk => const ColorFilter.mode(
        Color(0x48B72E43),
        BlendMode.srcATop,
      ),
      FlameMood.lit when intensity > 0 => ColorFilter.mode(
        const Color(0xFFFFDE98).withValues(alpha: intensity * .24),
        BlendMode.srcATop,
      ),
      FlameMood.lit => null,
    };
    canvas.drawImageRect(sheet, src, dest, paint);
  }

  @override
  bool shouldRepaint(ValleyCampfirePainter old) =>
      old.stage != stage ||
      old.landscape != landscape ||
      old.artwork != artwork ||
      old.previous != previous ||
      old.mood != mood ||
      old.tier != tier ||
      old.scheme != scheme ||
      old.repaint != repaint;
}
