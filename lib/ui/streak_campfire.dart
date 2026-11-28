import 'dart:async';

import 'package:arcadelingo/ui/campfire_stage.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/valley_campfire_painter.dart';
import 'package:flutter/material.dart';

/// One three-second animation on entry or replay. The compact symbol and
/// the panorama share the frame cadence, and only their paint layers tick.
class StreakCampfire extends StatefulWidget {
  const StreakCampfire({
    required this.days,
    required this.tier,
    required this.mood,
    super.key,
    this.size = Size.zero,
    this.child,
    this.landscape = false,
    this.replayToken = 0,
  });

  final int days;
  final FlameTier tier;
  final FlameMood mood;
  final Size size;
  final Widget? child;
  final bool landscape;
  final int replayToken;

  @override
  State<StreakCampfire> createState() => _StreakCampfireState();
}

typedef _ArtKey =
    ({
      CampfireStage stage,
      Brightness brightness,
      bool landscape,
      AssetBundle? bundle,
    });

class _StreakCampfireState extends State<StreakCampfire>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _gain = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    value: 1,
  );
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..addListener(_updateFrame);
  final _frame = ValueNotifier<int>(0);
  late final _paintChanges = Listenable.merge([_frame, _gain]);
  late ImageConfiguration _config;
  late Brightness _brightness;
  _ArtKey? _key;
  ValleyArtwork? _art;
  ValleyArtwork? _previous;
  bool _routeVisible = false;
  bool _reduced = false;
  bool _pendingGain = false;
  bool _canMove = false;
  bool _replayOnLoad = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _config = createLocalImageConfiguration(context);
    _brightness = Theme.of(context).brightness;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _routeVisible =
        TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    _requestArt();
    _syncMotion();
  }

  @override
  void didUpdateWidget(StreakCampfire oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestArt();
    final gained = widget.mood == FlameMood.lit && widget.days > oldWidget.days;
    if (widget.mood != FlameMood.lit) {
      _pendingGain = false;
      _gain.value = 1;
    }
    if (gained) _pendingGain = true;
    _syncMotion(
      replay: widget.replayToken != oldWidget.replayToken,
      start: gained || oldWidget.mood != widget.mood,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncMotion();

  void _syncMotion({bool replay = false, bool start = false}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final allowed = _routeVisible && !_reduced && active && _key != null;
    final revealed = allowed && !_canMove;
    _canMove = allowed;
    if (!allowed) {
      if (_reduced || !active || _key == null) _pendingGain = false;
      _replayOnLoad = false;
      _gain.value = 1;
      _cycle.value = 0;
      if (_art != null && _previous != null) _finishTransition();
      return;
    }
    if (_pendingGain) {
      _pendingGain = false;
      unawaited(_gain.forward(from: 0));
    }
    if (widget.mood == FlameMood.unlit && start && !replay) {
      _replayOnLoad = false;
      _cycle.value = 0;
      if (_art != null && _previous != null) _finishTransition();
    }
    if (replay || ((revealed || start) && widget.mood != FlameMood.unlit)) {
      if (_art == null) {
        _replayOnLoad = true;
      } else {
        unawaited(_cycle.forward(from: 0));
      }
    }
  }

  void _updateFrame() {
    final index = (_cycle.value * ValleyCampfirePainter.frameCount).floor();
    _frame.value = index % ValleyCampfirePainter.frameCount;
    if (index >= ValleyCampfirePainter.transitionFrames && _previous != null) {
      _finishTransition();
    }
  }

  void _finishTransition() {
    final previous = _previous;
    setState(() => _previous = null);
    previous?.dispose();
  }

  void _requestArt() {
    final stage = CampfireStage.forDays(widget.days);
    final key =
        stage == null
            ? null
            : (
              stage: stage,
              brightness: _brightness,
              landscape: widget.landscape,
              bundle: _config.bundle,
            );
    if (key == _key) return;
    final old = _key;
    _key = key;
    final generation = ++_loadGeneration;
    _replayOnLoad = false;
    _cycle.value = 0;
    // A scene stays visible while the next sheet is decoding. Never reuse
    // another course's stage after a reset or a badge as a panorama.
    if (_art != null) {
      _previous?.dispose();
      _previous = _art;
      _art = null;
    }
    if (key == null ||
        old?.landscape != key.landscape ||
        old?.brightness != key.brightness) {
      _previous?.dispose();
      _previous = null;
    }
    if (key == null) return;
    unawaited(_loadArt(key, generation, _config));
  }

  Future<void> _loadArt(
    _ArtKey key,
    int generation,
    ImageConfiguration config,
  ) async {
    final providers = ValleyArtwork.assetsFor(
      key.stage,
      brightness: key.brightness,
      landscape: key.landscape,
    );
    try {
      final images = await Future.wait<ImageInfo>(
        providers.map((provider) => _resolveImage(provider, config)),
        cleanUp: (image) => image.dispose(),
      );
      final art = ValleyArtwork(
        images.first,
        key.landscape ? images.last : null,
      );
      if (!mounted || _loadGeneration != generation) {
        art.dispose();
        return;
      }
      final animate =
          _canMove && (_replayOnLoad || widget.mood != FlameMood.unlit);
      _replayOnLoad = false;
      if (!animate) {
        _previous?.dispose();
        _previous = null;
      }
      setState(() => _art = art);
      if (animate) unawaited(_cycle.forward(from: 0));
    } catch (error, stack) {
      if (!mounted || _loadGeneration != generation) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'streak valley',
          context: ErrorDescription('loading artwork for day ${key.stage.day}'),
        ),
      );
    }
  }

  Future<ImageInfo> _resolveImage(
    ExactAssetImage provider,
    ImageConfiguration config,
  ) {
    final result = Completer<ImageInfo>();
    final stream = provider.resolve(config);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, _) {
        stream.removeListener(listener);
        result.complete(image);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        result.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    return result.future;
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: widget.size,
      painter: ValleyCampfirePainter(
        stage: _key?.stage,
        tier: widget.tier,
        mood: widget.mood,
        scheme: Theme.of(context).colorScheme,
        landscape: widget.landscape,
        artwork: _art,
        previous: _previous,
        frames: _frame,
        accent: _gain,
        repaint: _paintChanges,
      ),
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gain.dispose();
    _cycle.dispose();
    _frame.dispose();
    _previous?.dispose();
    _art?.dispose();
    super.dispose();
  }
}
