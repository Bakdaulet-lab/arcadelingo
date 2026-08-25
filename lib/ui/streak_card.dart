/// Стрик-карточка: пламя, растущее с серией, и полоса недели под ним.
///
/// Всё, что здесь есть, — краска. Что рисовать, решили `streak_flame.dart` и
/// `week_strip.dart`; числа пришли из `SPEC.md`, раздел «Стрик-карточка».
///
/// Пламя рисуется, а не лежит картинкой: ступеней четыре, настроений три, и
/// на каждую плотность экрана понадобилось бы по файлу — дюжина PNG,
/// замораживающих палитру в пикселях (разбор в SPEC).
library;

import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_flame.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

/// Диаметр кружка дня, dp.
const double weekDotSize = 30;

/// Зазор между кружками, dp.
const double weekDotGap = 8;

/// Толщина кольца «сегодня», dp.
const double weekTodayRing = 2;

/// Прозрачность будущих дней.
const double weekFutureAlpha = 0.4;

/// Карточка серии на домашнем экране.
class StreakCard extends StatelessWidget {
  const StreakCard({required this.ritual, super.key, this.week});

  final StreakView ritual;

  /// Семь дней недели; null — журнал ещё читается. Место под полосу при этом
  /// уже занято, чтобы карточка не прыгала, когда данные приедут.
  final List<WeekDay>? week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tier = flameTier(ritual.days);
    final mood = flameMood(ritual);
    final caption = ritualStreakLabel(ritual);

    return Container(
      key: streakCardKey,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Экранному диктору цифра в пламени ничего не говорит: он читает
          // подпись целиком, а не картинку под ней.
          Semantics(
            label: ritual.days == 0 ? 'Серии нет' : streakLabel(ritual.days),
            excludeSemantics: true,
            child: _Flame(tier: tier, mood: mood, days: ritual.days),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              key: streakCaptionKey,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: weekDotSize + weekTodayRing * 2,
            child:
                week == null
                    ? const SizedBox.shrink()
                    : _WeekStrip(days: week!),
          ),
        ],
      ),
    );
  }
}

/// Ключ карточки: тест ищет по нему то, что не опознать по тексту.
const Key streakCardKey = Key('app.streak_card');

/// Ключ подписи под пламенем.
const Key streakCaptionKey = Key('app.streak');

/// Ключ полосы недели.
const Key weekStripKey = Key('app.week');

class _Flame extends StatelessWidget {
  const _Flame({required this.tier, required this.mood, required this.days});

  final FlameTier tier;
  final FlameMood mood;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = flameHeights[tier]!;
    final digitSize = flameDigitSizes[tier];
    final halo = tier == FlameTier.inferno;
    // Ореол шире самого пламени, поэтому под него отводится место: иначе он
    // обрежется рамкой карточки, и «максимум» стал бы похож на «большое».
    final boxHeight = halo ? height * flameHaloRadius : height;

    return SizedBox(
      height: boxHeight,
      width: boxHeight,
      child: CustomPaint(
        painter: FlamePainter(tier: tier, mood: mood, scheme: scheme),
        child:
            digitSize == null
                ? null
                : Align(
                  // Ядро пламени — в нижней трети (SPEC: центр градиента на
                  // 0.72 высоты). Число сидит там же: оно вырезано из
                  // пламени, а не положено сверху.
                  alignment: const Alignment(0, 0.44),
                  child: Text(
                    '$days',
                    key: flameDigitKey,
                    style: withWeight(
                      TextStyle(fontSize: digitSize, height: 1),
                      FontWeight.bold,
                    ).copyWith(color: flameDigitColor(scheme, mood)),
                  ),
                ),
      ),
    );
  }
}

/// Ключ числа дней внутри пламени.
const Key flameDigitKey = Key('app.flame_digit');

/// Кисть пламени. Публичная ради голденов и виджет-тестов: они проверяют,
/// что размер и настроение доехали до краски.
class FlamePainter extends CustomPainter {
  const FlamePainter({
    required this.tier,
    required this.mood,
    required this.scheme,
  });

  final FlameTier tier;
  final FlameMood mood;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final height = flameHeights[tier]!;
    final width = height * flameAspect;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;
    final rect = Rect.fromLTWH(left, top, width, height);

    if (tier == FlameTier.inferno) {
      final centre = Offset(size.width / 2, top + height * 0.72);
      final radius = height * flameHaloRadius / 2;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              scheme.tertiary.withValues(alpha: flameHaloAlpha),
              scheme.tertiary.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    final path = flamePath(rect);
    if (mood == FlameMood.unlit) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = scheme.outline,
      );
      return;
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.44),
          radius: 0.75,
          colors: [
            scheme.primary,
            scheme.tertiary,
            flameEdgeColor(scheme, mood),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(FlamePainter old) =>
      old.tier != tier || old.mood != mood || old.scheme != scheme;
}

/// Контур пламени в прямоугольнике [rect].
///
/// Отдельной функцией, потому что форма — тоже решение: узкий кончик,
/// раздутые бока и круглое основание отличают пламя от листа.
Path flamePath(Rect rect) {
  final w = rect.width;
  final h = rect.height;
  final cx = rect.left + w / 2;
  return Path()
    ..moveTo(cx, rect.top)
    ..quadraticBezierTo(
      rect.left + w * 0.98,
      rect.top + h * 0.42,
      rect.left + w * 0.80,
      rect.top + h * 0.74,
    )
    ..quadraticBezierTo(
      rect.left + w * 0.70,
      rect.top + h * 0.98,
      cx,
      rect.top + h,
    )
    ..quadraticBezierTo(
      rect.left + w * 0.30,
      rect.top + h * 0.98,
      rect.left + w * 0.20,
      rect.top + h * 0.74,
    )
    ..quadraticBezierTo(rect.left + w * 0.02, rect.top + h * 0.42, cx, rect.top)
    ..close();
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    // Крупный системный шрифт полосу не ломает: она уменьшается целиком.
    // Кружки при этом остаются кружками — их размер задан в dp, а не текстом.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        key: weekStripKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, day) in days.indexed) ...[
            if (index > 0) const SizedBox(width: weekDotGap),
            _WeekDot(day: day),
          ],
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final future = day.state == WeekDayState.future;
    final fill = switch (day.state) {
      WeekDayState.played => scheme.primaryContainer,
      _ => scheme.surfaceContainerHighest,
    };

    return Semantics(
      label: '${day.letter}: ${weekDayDescription(day)}',
      excludeSemantics: true,
      child: Container(
        width: weekDotSize,
        height: weekDotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: future ? fill.withValues(alpha: weekFutureAlpha) : fill,
          border:
              day.isToday
                  ? Border.all(color: scheme.primary, width: weekTodayRing)
                  : null,
        ),
        alignment: Alignment.center,
        child: switch (day.state) {
          WeekDayState.played => Icon(
            Icons.check,
            size: 16,
            color: scheme.primary,
          ),
          WeekDayState.frozen => Icon(
            Icons.shield,
            size: 15,
            color: scheme.tertiary,
          ),
          _ => Text(
            day.letter,
            style: textTheme.bodySmall?.copyWith(
              color:
                  future
                      ? scheme.onSurfaceVariant.withValues(
                        alpha: weekFutureAlpha,
                      )
                      : scheme.onSurfaceVariant,
            ),
          ),
        },
      ),
    );
  }
}

/// Что случилось с днём — словами, для экранного диктора.
String weekDayDescription(WeekDay day) => switch (day.state) {
  WeekDayState.played => 'сыграно',
  WeekDayState.frozen => 'заморозка',
  WeekDayState.missed => 'пропущено',
  WeekDayState.pending => 'сегодня, ещё не сыграно',
  WeekDayState.future => 'ещё не наступил',
};
