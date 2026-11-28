import 'package:arcadelingo/domain/kitchen/kitchen_shift.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/features/games/order_kitchen/kitchen_counter_scene.dart';
import 'package:arcadelingo/features/games/order_kitchen/kitchen_ingredient_icon.dart';
import 'package:arcadelingo/features/games/order_kitchen/order_kitchen_strings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_answer_feedback.dart';
import 'package:arcadelingo/ui/arcade_press_feedback.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

class OrderKitchenGame extends StatefulWidget {
  const OrderKitchenGame({
    required this.course,
    required this.seed,
    required this.onExit,
    this.onShiftComplete,
    this.onReplay,
    super.key,
  });

  final StudyCourse course;
  final int seed;
  final VoidCallback onExit;
  final VoidCallback? onShiftComplete;
  final VoidCallback? onReplay;

  @override
  State<OrderKitchenGame> createState() => _OrderKitchenGameState();
}

class _OrderKitchenGameState extends State<OrderKitchenGame> {
  final _scroll = ScrollController();
  late int _seed;
  late List<KitchenOrder> _orders;
  int _index = 0;
  int _firstTry = 0;
  Set<KitchenIngredient> _selected = {};
  bool _served = false;
  bool _showMistake = false;
  bool _hadMistake = false;

  @override
  void initState() {
    super.initState();
    _startShift(widget.seed);
  }

  @override
  void didUpdateWidget(OrderKitchenGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.course.id != widget.course.id) {
      _startShift(widget.seed);
      _scrollToTicket();
    }
  }

  void _startShift(int seed) {
    _seed = seed;
    _orders = kitchenOrdersFor(
      course: widget.course,
      level: CefrLevel.a1,
      seed: seed,
    );
    _index = 0;
    _firstTry = 0;
    _resetCup();
  }

  void _resetCup() {
    _selected = {};
    _showMistake = false;
    _hadMistake = false;
    _served = false;
  }

  void _toggle(KitchenIngredient ingredient) {
    if (_served) return;
    setState(() {
      final next = {..._selected};
      if (!next.remove(ingredient)) next.add(ingredient);
      _selected = next;
      _showMistake = _showMistake && !_orders[_index].matches(next);
    });
  }

  void _serve() {
    if (_served || _selected.isEmpty || _index >= _orders.length) return;
    final correct = _orders[_index].matches(_selected);
    setState(() {
      _served = correct;
      _showMistake = !correct;
      if (!correct) _hadMistake = true;
      if (correct && !_hadMistake) _firstTry++;
    });
    if (correct && _index + 1 == _orders.length) widget.onShiftComplete?.call();
  }

  void _scrollToTicket() {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (!_served) return;
    _scrollToTicket();
    setState(() {
      _index++;
      _resetCup();
    });
  }

  void _replay() {
    setState(() => _startShift(_seed + 1));
    _scrollToTicket();
    widget.onReplay?.call();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final course = widget.course;
    final done = _index == _orders.length && _orders.isNotEmpty;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final paper = theme.brightness == Brightness.light;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('kitchen.exit'),
          onPressed: widget.onExit,
        ),
        title: Text(
          s.orderKitchen,
          style: withWeight(theme.textTheme.titleMedium!, FontWeight.w700),
        ),
        titleSpacing: 0,
        backgroundColor: theme.colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          if (scale <= 1.4)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Semantics(
                label: '${s.courseName(course)}, A1',
                excludeSemantics: true,
                child: DefaultTextStyle(
                  style: withWeight(
                    theme.textTheme.labelSmall!,
                    FontWeight.w600,
                  ).copyWith(color: theme.colorScheme.onSurfaceVariant),
                  child: Row(
                    children: [
                      Text(course.translationLanguage.toUpperCase()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text('${course.studyLanguage.toUpperCase()} · A1'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child:
                _orders.isEmpty
                    ? Text(s.unavailable, textAlign: TextAlign.center)
                    : done
                    ? SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: _ShiftSummary(
                        score: _firstTry,
                        total: _orders.length,
                        lastDrink: _orders.last.ingredients,
                        onReplay: _replay,
                        onExit: widget.onExit,
                      ),
                    )
                    : Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _Ticket(
                                    index: _index,
                                    total: _orders.length,
                                    reduced: reduced,
                                    phrase: _orders[_index].phrase(
                                      course.studyLanguage,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  KitchenCounterScene(
                                    selected: _selected,
                                    guestIndex: _index,
                                    served: _served,
                                    mistake: _showMistake,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    s.ingredients,
                                    style: withWeight(
                                      theme.textTheme.titleMedium!,
                                      FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final minWidth =
                                          92 * scale.clamp(1.0, 4.0);
                                      final shelfColumns =
                                          constraints.maxWidth < 390 &&
                                                  MediaQuery.sizeOf(
                                                        context,
                                                      ).height >=
                                                      700
                                              ? 2
                                              : 3;
                                      final columns = ((constraints.maxWidth +
                                                  8) /
                                              (minWidth + 8))
                                          .floor()
                                          .clamp(1, shelfColumns);
                                      final width =
                                          (constraints.maxWidth -
                                              8 * (columns - 1)) /
                                          columns;
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (final item
                                              in KitchenIngredient.values)
                                            SizedBox(
                                              width: width,
                                              child: _IngredientButton(
                                                item: item,
                                                label: item.label(
                                                  course.translationLanguage,
                                                ),
                                                selected: _selected.contains(
                                                  item,
                                                ),
                                                onTap:
                                                    _served
                                                        ? null
                                                        : () => _toggle(item),
                                                reduced: reduced,
                                                paper: paper,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _ServiceBar(
                          order: _orders[_index],
                          selected: _selected,
                          language: course.translationLanguage,
                          served: _served,
                          mistake: _showMistake,
                          last: _index + 1 == _orders.length,
                          reduced: reduced,
                          onNext: _next,
                          onServe: _serve,
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.index,
    required this.total,
    required this.phrase,
    required this.reduced,
  });
  final int index;
  final int total;
  final String phrase;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final paper = theme.brightness == Brightness.light;
    final ink = paper ? const Color(0xFF442E21) : const Color(0xFFFFEDDB);
    final accent = paper ? const Color(0xFF93472A) : const Color(0xFFFFBE85);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paper ? const Color(0xFFFFFAEE) : const Color(0xFF302630),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: paper ? colors.outlineVariant : const Color(0xFF59434A),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: accent, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.strings.ticket(index + 1, total),
                    style: withWeight(
                      theme.textTheme.labelMedium!,
                      FontWeight.w700,
                    ).copyWith(color: accent),
                  ),
                ),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var i = 0; i < total; i++)
                        Container(
                          width: i == index ? 12 : 5,
                          height: 5,
                          margin: const EdgeInsetsDirectional.only(start: 4),
                          decoration: BoxDecoration(
                            color:
                                i <= index ? accent : ink.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            AnimatedSwitcher(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 210),
              switchInCurve: Curves.easeOutCubic,
              layoutBuilder:
                  (current, outgoing) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...outgoing, if (current != null) current],
                  ),
              child: Semantics(
                liveRegion: true,
                key: ValueKey(index),
                child: Text(
                  phrase,
                  key: const ValueKey('kitchen.order'),
                  style: withWeight(
                    theme.textTheme.headlineSmall!,
                    FontWeight.w600,
                  ).copyWith(color: ink, height: 1.18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientButton extends StatelessWidget {
  const _IngredientButton({
    required this.item,
    required this.label,
    required this.selected,
    required this.reduced,
    required this.paper,
    required this.onTap,
  });
  final KitchenIngredient item;
  final String label;
  final bool selected;
  final bool reduced;
  final bool paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: ArcadePressFeedback(
        enabled: onTap != null,
        builder:
            (states) => AnimatedContainer(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color:
                    selected
                        ? colors.primaryContainer
                        : (paper
                            ? colors.surfaceContainerLow
                            : colors.surfaceContainerHighest),
                borderRadius: shape.borderRadius,
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey('kitchen.ingredient.${item.name}'),
                  customBorder: shape,
                  statesController: states,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KitchenIngredientIcon(item),
                            if (selected)
                              PositionedDirectional(
                                end: -13,
                                top: -1,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: withWeight(
                            theme.textTheme.labelLarge!,
                            FontWeight.w600,
                          ).copyWith(
                            color:
                                selected
                                    ? colors.onPrimaryContainer
                                    : colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _ServiceBar extends StatelessWidget {
  const _ServiceBar({
    required this.order,
    required this.selected,
    required this.language,
    required this.served,
    required this.mistake,
    required this.last,
    required this.reduced,
    required this.onNext,
    required this.onServe,
  });
  final KitchenOrder order;
  final Set<KitchenIngredient> selected;
  final String language;
  final bool served;
  final bool mistake;
  final bool last;
  final bool reduced;
  final VoidCallback onNext;
  final VoidCallback onServe;

  String _names(Iterable<KitchenIngredient> items) =>
      items.map((i) => i.label(language)).join(', ');

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final missing = order.ingredients.difference(selected);
    final extra = selected.difference(order.ingredients);
    final details = [
      if (served) order.phrase(language),
      if (mistake && missing.isNotEmpty) '${s.addItems}: ${_names(missing)}',
      if (mistake && extra.isNotEmpty) '${s.removeItems}: ${_names(extra)}',
    ];
    final accent = served ? colors.primary : colors.tertiary;
    final feedback =
        served || mistake
            ? ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .22,
              ),
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  key: const ValueKey('kitchen.feedback'),
                  child: ArcadeAnswerFeedback(
                    correct: served,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              served
                                  ? Icons.check_circle_rounded
                                  : Icons.tune_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  served ? s.servedDrink : s.adjustDrink,
                                  style: withWeight(
                                    theme.textTheme.labelLarge!,
                                    FontWeight.w700,
                                  ),
                                ),
                                for (final line in details)
                                  Text(line, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            : const SizedBox(width: double.infinity);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reduced)
              feedback
            else
              AnimatedSize(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: feedback,
              ),
            FilledButton.icon(
              key: ValueKey(served ? 'kitchen.next' : 'kitchen.serve'),
              onPressed:
                  served
                      ? onNext
                      : selected.isNotEmpty
                      ? onServe
                      : null,
              icon: Icon(
                served
                    ? Icons.arrow_forward_rounded
                    : Icons.room_service_rounded,
              ),
              label: Text(
                served ? (last ? s.finishShift : s.nextGuest) : s.serveDrink,
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftSummary extends StatelessWidget {
  const _ShiftSummary({
    required this.score,
    required this.lastDrink,
    required this.total,
    required this.onReplay,
    required this.onExit,
  });
  final int score;
  final Set<KitchenIngredient> lastDrink;
  final int total;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KitchenCounterScene(
          selected: lastDrink,
          guestIndex: total - 1,
          served: true,
          mistake: false,
        ),
        const SizedBox(height: 20),
        Text(
          s.shiftDone,
          textAlign: TextAlign.center,
          style: withWeight(theme.textTheme.headlineMedium!, FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Text(
          '$score/$total',
          key: const ValueKey('kitchen.first-try'),
          textAlign: TextAlign.center,
          style: withWeight(
            theme.textTheme.displayMedium!,
            FontWeight.bold,
          ).copyWith(color: theme.colorScheme.primary),
        ),
        Text(
          s.firstTry,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('kitchen.replay'),
          onPressed: onReplay,
          icon: const Icon(Icons.replay_rounded),
          label: Text(s.anotherShift),
        ),
        TextButton(onPressed: onExit, child: Text(s.exit)),
      ],
    );
  }
}
