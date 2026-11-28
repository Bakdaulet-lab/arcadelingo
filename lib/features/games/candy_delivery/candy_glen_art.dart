import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The original glade illustration. Each theme packs the backdrop and both
/// poses of all three rabbits into one offline image, so shuffling lanes or
/// delivering a candy can reuse the same decoded pixels immediately.
class CandyGlenArt extends StatefulWidget {
  const CandyGlenArt({
    super.key,
    required this.day,
    required this.rabbits,
    required this.happyLane,
  });

  final bool day;
  final List<int> rabbits;
  final int? happyLane;

  static ExactAssetImage imageFor(bool day) => ExactAssetImage(
    'assets/images/candy_delivery/${day ? 'day' : 'night'}.webp',
    bundle: rootBundle,
  );

  @override
  State<CandyGlenArt> createState() => _CandyGlenArtState();
}

class _CandyGlenArtState extends State<CandyGlenArt> {
  ImageInfo? _sheet;
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CandyGlenArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _resolve();
  }

  void _resolve() {
    final next = CandyGlenArt.imageFor(
      widget.day,
    ).resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _sheet?.dispose();
    _sheet = null;
    _stream = next;
    next.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronous) {
    _sheet?.dispose();
    if (synchronous) {
      _sheet = info;
    } else {
      setState(() => _sheet = info);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _sheet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ColoredBox(
      color: widget.day ? const Color(0xFFF6D7AA) : const Color(0xFF252B52),
      child: CustomPaint(
        size: const Size(360, 292),
        painter: _GlenPainter(_sheet?.image, widget.rabbits, widget.happyLane),
      ),
    ),
  );
}

class _GlenPainter extends CustomPainter {
  const _GlenPainter(this.sheet, this.rabbits, this.happyLane);

  final ui.Image? sheet;
  final List<int> rabbits;
  final int? happyLane;

  static const _scene = Size(360, 292);
  static const _sprite = Size(120, 88);
  static const _anchor = Offset(60, 54);
  static const _lanes = [64.0, 180.0, 296.0];

  @override
  void paint(Canvas canvas, Size size) {
    final image = sheet;
    if (image == null || size.isEmpty) return;
    final density = image.width / _scene.width;
    final widthScale = size.width / _scene.width;
    final paint = Paint()..filterQuality = FilterQuality.low;
    // On taller phones trim the sides of the landscape, keeping the sun and
    // moon round. Lane positions still follow the physics coordinate system.
    final crop = Alignment.center.inscribe(
      applyBoxFit(BoxFit.cover, _scene, size).source * density,
      Offset.zero & (_scene * density),
    );
    canvas.drawImageRect(image, crop, Offset.zero & size, paint);
    for (var lane = 0; lane < _lanes.length; lane++) {
      final rabbit = rabbits[lane];
      final cell = Offset(
        rabbit * _sprite.width,
        _scene.height + (lane == happyLane ? _sprite.height : 0),
      );
      final center = Offset(
        _lanes[lane] * widthScale,
        (rabbit == 1 ? 241 : 239) * size.height / _scene.height,
      );
      canvas.drawImageRect(
        image,
        (cell * density) & (_sprite * density),
        (center - _anchor * widthScale) & (_sprite * widthScale),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GlenPainter oldDelegate) =>
      oldDelegate.sheet != sheet ||
      oldDelegate.happyLane != happyLane ||
      !listEquals(oldDelegate.rabbits, rabbits);
}
