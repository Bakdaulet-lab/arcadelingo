import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'space_flight.dart';
import 'space_paint.dart';

class SpaceField extends StatefulWidget {
  const SpaceField({
    super.key,
    required this.flight,
    required this.labels,
    required this.playing,
    required this.reducedMotion,
    required this.onEvent,
    required this.onPause,
    required this.semanticsLabel,
  });

  final SpaceFlight flight;
  final List<String> labels;
  final bool playing;
  final bool reducedMotion;
  final ValueChanged<FlightEvent> onEvent;
  final VoidCallback onPause;
  final String semanticsLabel;

  @override
  State<SpaceField> createState() => SpaceFieldState();
}

class SpaceFieldState extends State<SpaceField>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _paint = ValueNotifier(0);
  Duration? _previous;
  int? _pointer;
  Offset _lastPoint = Offset.zero;
  bool _buttonFire = false;
  final _keys = <LogicalKeyboardKey>{};
  bool _foreground = true;
  bool _visible = true;
  bool _interrupted = false;
  bool _pauseQueued = false;
  SpaceLabels? _layout;
  SpaceDrone? _sizedDrone;
  ImageStream? _stream;
  ImageInfo? _sheet;
  late final _imageListener = ImageStreamListener(_onImage);

  bool get _active =>
      widget.playing && _foreground && _visible && !_interrupted;
  bool get _trigger =>
      _buttonFire ||
      _pointer != null ||
      _keys.contains(LogicalKeyboardKey.space);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addEarlyKeyEventHandler(_key);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _visible;
    _visible =
        TickerMode.of(context) && (ModalRoute.isCurrentOf(context) ?? true);
    if (wasVisible && !_visible && _ticker.isActive) _interrupt();
    final day = Theme.of(context).brightness == Brightness.light;
    final image = ExactAssetImage(
      'assets/images/space_word/${day ? 'day' : 'night'}.webp',
      bundle: rootBundle,
    ).resolve(createLocalImageConfiguration(context));
    if (image.key != _stream?.key) {
      _stream?.removeListener(_imageListener);
      _sheet?.dispose();
      _sheet = null;
      _stream = image..addListener(_imageListener);
    }
    _updateClock();
  }

  void _onImage(ImageInfo image, bool synchronous) {
    _sheet?.dispose();
    _sheet = image;
    if (!synchronous && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SpaceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flight != widget.flight || !widget.playing) {
      oldWidget.flight.stopInput();
      clearInput();
      _interrupted = false;
    }
    _updateClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _ticker.isActive) _interrupt();
    _updateClock();
  }

  void _interrupt() {
    _interrupted = true;
    clearInput();
    if (_pauseQueued) return;
    _pauseQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pauseQueued = false;
      if (mounted && _interrupted && widget.playing) widget.onPause();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _updateClock() {
    if (_active && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    } else if (!_active && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (!_active || previous == null) return;
    final event = widget.flight.advance(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
      firing: _trigger,
    );
    // Transform updates and shot particles do not rebuild the HUD or labels.
    _paint.value++;
    if (event != null) widget.onEvent(event);
  }

  void clearInput() {
    _pointer = null;
    _buttonFire = false;
    _keys.clear();
    widget.flight.stopInput();
  }

  void fire(bool held) {
    if (held && !_active) return;
    if (held && !_buttonFire) widget.flight.shoot();
    _buttonFire = held;
  }

  static final _pilotGestures = <Type, GestureRecognizerFactory>{
    EagerGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
          () => EagerGestureRecognizer(
            allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
          ),
          (_) {},
        ),
  };

  static final _directions = <LogicalKeyboardKey, Offset>{
    LogicalKeyboardKey.arrowLeft: const Offset(-1, 0),
    LogicalKeyboardKey.keyA: const Offset(-1, 0),
    LogicalKeyboardKey.arrowRight: const Offset(1, 0),
    LogicalKeyboardKey.keyD: const Offset(1, 0),
    LogicalKeyboardKey.arrowUp: const Offset(0, -1),
    LogicalKeyboardKey.keyW: const Offset(0, -1),
    LogicalKeyboardKey.arrowDown: const Offset(0, 1),
    LogicalKeyboardKey.keyS: const Offset(0, 1),
  };

  KeyEventResult _key(KeyEvent event) {
    if (!_active) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _interrupt();
      _updateClock();
      return KeyEventResult.handled;
    }
    if (!_directions.containsKey(key) && key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) {
      _keys.remove(key);
    } else if (_keys.add(key) && key == LogicalKeyboardKey.space) {
      widget.flight.shoot();
    }
    widget.flight.steer(
      _keys.fold(
        Offset.zero,
        (sum, k) => sum + (_directions[k] ?? Offset.zero),
      ),
    );
    return KeyEventResult.handled;
  }

  Offset _toWorld(Offset local) {
    final size = context.size!;
    return Offset(
      local.dx * SpaceFlight.worldSize.width / size.width,
      local.dy * SpaceFlight.worldSize.height / size.height,
    );
  }

  void _down(PointerDownEvent event) {
    if (!_active || _pointer != null || event.buttons != kPrimaryButton) return;
    _pointer = event.pointer;
    _lastPoint = _toWorld(event.localPosition);
    widget.flight.moveTo(widget.flight.ship);
    widget.flight.shoot();
  }

  void _move(PointerMoveEvent event) {
    if (!_active || event.pointer != _pointer) return;
    final current = _toWorld(event.localPosition);
    widget.flight.dragBy((current - _lastPoint) * 1.08);
    _lastPoint = current;
  }

  void _lift(PointerEvent event) {
    if (event.pointer == _pointer) _pointer = null;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_key);
    WidgetsBinding.instance.removeObserver(this);
    _stream?.removeListener(_imageListener);
    _sheet?.dispose();
    _layout?.dispose();
    _ticker.dispose();
    _paint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = theme.brightness == Brightness.light;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final style = theme.textTheme.titleMedium!.copyWith(
      color: day ? const Color(0xFF392D30) : const Color(0xFFFFF3DF),
      fontWeight: FontWeight.w600,
      height: 1.12,
    );
    final ui.Image? image = _sheet?.image;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final previous = _layout;
        if (previous == null ||
            previous.size != size ||
            previous.scaler != scaler ||
            previous.direction != direction ||
            previous.locale != locale ||
            previous.style != style ||
            !listEquals(previous.words, widget.labels)) {
          previous?.dispose();
          _layout = SpaceLabels(
            widget.labels,
            size,
            scaler,
            direction,
            locale,
            style,
          );
          _sizedDrone = null;
        }
        final first = widget.flight.drones.firstOrNull;
        if (first != null && _sizedDrone != first) {
          widget.flight.setDroneSizes(_layout!.hitSizes);
          _sizedDrone = first;
        }
        return RawGestureDetector(
          gestures: _active ? _pilotGestures : const {},
          excludeFromSemantics: true,
          child: Semantics(
            image: true,
            label: widget.semanticsLabel,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _lift,
              onPointerCancel: _lift,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(painter: SpaceBackdrop(image, day)),
                    ),
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: SpaceSprites(
                          flight: widget.flight,
                          sheet: image,
                          labels: _layout!,
                          day: day,
                          reduced: widget.reducedMotion,
                          repaint: _paint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
