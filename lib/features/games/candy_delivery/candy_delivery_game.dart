import 'package:arcadelingo/domain/candy_delivery/candy_orders.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'candy_field.dart';

enum _Delivery { ready, flying, delivered, wrongRabbit, grass }

class CandyDeliveryGame extends StatefulWidget {
  const CandyDeliveryGame({
    required this.course,
    required this.level,
    required this.seed,
    required this.onExit,
    this.onComplete,
    this.onReplay,
    super.key,
  });

  final StudyCourse course;
  final CefrLevel level;
  final int seed;
  final VoidCallback onExit;
  final VoidCallback? onComplete;
  final VoidCallback? onReplay;

  @override
  State<CandyDeliveryGame> createState() => _CandyDeliveryGameState();
}

class _CandyDeliveryGameState extends State<CandyDeliveryGame> {
  late int _seed;
  late List<CandyOrder> _orders;
  int _index = 0;
  int _aim = 0;
  bool _showTranslation = false;
  _Delivery _delivery = _Delivery.ready;
  GlobalKey<CandyFieldState> _field = GlobalKey<CandyFieldState>();

  @override
  void initState() {
    super.initState();
    _start(widget.seed);
  }

  @override
  void didUpdateWidget(CandyDeliveryGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.level != widget.level ||
        oldWidget.course.id != widget.course.id ||
        oldWidget.course.studyLanguage != widget.course.studyLanguage ||
        oldWidget.course.translationLanguage !=
            widget.course.translationLanguage) {
      _start(widget.seed);
    }
  }

  void _start(int seed) {
    _seed = seed;
    _orders = candyOrdersFor(
      course: widget.course,
      level: widget.level,
      seed: seed,
    );
    _index = 0;
    _showTranslation = false;
    _resetField();
  }

  void _resetField() {
    _field = GlobalKey<CandyFieldState>();
    _delivery = _Delivery.ready;
    _aim = 0;
  }

  void _land(int? lane) {
    if (_delivery != _Delivery.flying) return;
    final order = _orders[_index];
    setState(() {
      _delivery =
          lane == null
              ? _Delivery.grass
              : order.rabbits[lane] == order.target
              ? _Delivery.delivered
              : _Delivery.wrongRabbit;
    });
    if (_delivery == _Delivery.delivered && _index == _orders.length - 1) {
      widget.onComplete?.call();
    }
  }

  void _advance() {
    if (_delivery != _Delivery.delivered) return;
    if (_index == _orders.length - 1) {
      setState(() => _start(_seed + 1));
      widget.onReplay?.call();
    } else {
      setState(() {
        _index++;
        _showTranslation = false;
        _resetField();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final day = theme.brightness == Brightness.light;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final order = _orders.isEmpty ? null : _orders[_index];
    final levelName = widget.level.name.toUpperCase();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onExit),
        titleSpacing: 0,
        title: Text(
          s.candyDelivery,
          style: withWeight(theme.textTheme.titleMedium!, FontWeight.w700),
        ),
        actions: [
          if (!largeText)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Semantics(
                label: '${s.courseName(widget.course)}, $levelName',
                excludeSemantics: true,
                child: DefaultTextStyle(
                  style: withWeight(
                    theme.textTheme.labelSmall!,
                    FontWeight.w600,
                  ).copyWith(color: colors.onSurfaceVariant),
                  child: Row(
                    children: [
                      Text(widget.course.translationLanguage.toUpperCase()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${widget.course.studyLanguage.toUpperCase()} · $levelName',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: const Alignment(0, -.55),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child:
                order == null
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        s.candyUnavailable,
                        textAlign: TextAlign.center,
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OrderTicket(
                            order: order,
                            index: _index,
                            total: _orders.length,
                            showTranslation: _showTranslation,
                            day: day,
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder:
                                (context, bounds) => CandyField(
                                  key: _field,
                                  aspectRatio:
                                      largeText || viewportHeight < 640
                                          ? 360 / 292
                                          : (bounds.maxWidth /
                                                  (viewportHeight * .52))
                                              .clamp(.92, 360 / 292)
                                              .toDouble(),
                                  rabbits: order.rabbits,
                                  aim: _aim,
                                  targetLane: order.rabbits.indexOf(
                                    order.target,
                                  ),
                                  reducedMotion: reduced,
                                  semanticsLabel: [
                                    for (final (i, rabbit)
                                        in order.rabbits.indexed)
                                      '${s.candyLane(i)} — ${s.candyRabbit(rabbit)}',
                                  ].join('. '),
                                  onCut:
                                      () => setState(
                                        () => _delivery = _Delivery.flying,
                                      ),
                                  onLand: _land,
                                ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                            child: Semantics(
                              liveRegion: true,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    switch (_delivery) {
                                      _Delivery.delivered =>
                                        Icons.check_circle_outline_rounded,
                                      _Delivery.grass ||
                                      _Delivery
                                          .wrongRabbit => Icons.replay_rounded,
                                      _Delivery.ready || _Delivery.flying =>
                                        Icons.auto_awesome_rounded,
                                    },
                                    size: 18,
                                    color:
                                        _delivery == _Delivery.delivered
                                            ? colors.primary
                                            : colors.tertiary,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      switch (_delivery) {
                                        _Delivery.ready =>
                                          reduced ? s.candyAim : s.candySwipe,
                                        _Delivery.flying => s.candyFlying,
                                        _Delivery.delivered => s.candyDelivered,
                                        _Delivery.wrongRabbit =>
                                          s.candyOtherRabbit,
                                        _Delivery.grass => s.candyInGrass,
                                      },
                                      key: const Key('candy.status'),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (reduced && _delivery == _Delivery.ready)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 6,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    ChoiceChip(
                                      key: Key('candy.aim.$i'),
                                      label: Text(s.candyLane(i)),
                                      selected: _aim == i - 1,
                                      onSelected:
                                          (_) => setState(() => _aim = i - 1),
                                    ),
                                ],
                              ),
                            ),
                          _Actions(
                            delivery: _delivery,
                            last: _index == _orders.length - 1,
                            stacked: largeText,
                            showTranslation: _showTranslation,
                            onTranslate:
                                () => setState(
                                  () => _showTranslation = !_showTranslation,
                                ),
                            onCut: () => _field.currentState?.cut(),
                            onNext: _advance,
                            onRetry: () => setState(_resetField),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _OrderTicket extends StatelessWidget {
  const _OrderTicket({
    required this.order,
    required this.index,
    required this.total,
    required this.showTranslation,
    required this.day,
  });
  final CandyOrder order;
  final int index, total;
  final bool showTranslation, day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final tag = day ? const Color(0xff925137) : const Color(0xffedbfa2);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: day ? const Color(0xfffffaf0) : const Color(0xff302a38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 17, color: tag),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.strings.candyOrderNumber(index + 1, total),
                    style: withWeight(
                      theme.textTheme.labelMedium!,
                      FontWeight.w700,
                    ).copyWith(color: tag),
                  ),
                ),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < total; i++)
                        Container(
                          width: i == index ? 14 : 5,
                          height: 5,
                          margin: const EdgeInsetsDirectional.only(start: 4),
                          decoration: BoxDecoration(
                            color:
                                i <= index ? tag : tag.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Semantics(
              liveRegion: true,
              child: Text(
                order.phrase,
                key: const Key('candy.phrase'),
                style: withWeight(
                  theme.textTheme.headlineSmall!,
                  FontWeight.w600,
                ).copyWith(
                  fontFamily: warmPaperFont,
                  height: 1.18,
                  color:
                      day ? const Color(0xff443023) : const Color(0xfffff0dc),
                ),
              ),
            ),
            if (showTranslation)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    order.translation,
                    key: const Key('candy.translation'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.delivery,
    required this.last,
    required this.stacked,
    required this.showTranslation,
    required this.onTranslate,
    required this.onCut,
    required this.onNext,
    required this.onRetry,
  });
  final _Delivery delivery;
  final bool last, stacked, showTranslation;
  final VoidCallback onTranslate, onCut, onNext, onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final hint = Semantics(
      toggled: showTranslation,
      child: OutlinedButton.icon(
        key: const Key('candy.hint'),
        onPressed: onTranslate,
        icon: const Icon(Icons.translate_rounded, size: 18),
        label: Text(s.dailyWordClue, textAlign: TextAlign.center),
      ),
    );
    final (id, label, icon, action) = switch (delivery) {
      _Delivery.ready => ('cut', s.candyCut, Icons.content_cut_rounded, onCut),
      _Delivery.flying => ('cut', s.candyCut, Icons.content_cut_rounded, null),
      _Delivery.delivered => (
        last ? 'replay' : 'next',
        last ? s.playAgain : s.candyNext,
        last ? Icons.replay_rounded : Icons.arrow_forward_rounded,
        onNext,
      ),
      _Delivery.wrongRabbit ||
      _Delivery.grass => ('retry', s.candyRetry, Icons.replay_rounded, onRetry),
    };
    final primary = FilledButton.icon(
      key: Key('candy.$id'),
      onPressed: action,
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
    );
    return stacked
        ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hint, const SizedBox(height: 6), primary],
        )
        : Row(
          children: [
            Expanded(flex: 4, child: hint),
            const SizedBox(width: 8),
            Expanded(flex: 6, child: primary),
          ],
        );
  }
}
