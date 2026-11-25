import 'dart:math' as math;

import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

import 'word_mahjong_board.dart';

abstract final class WordMahjongKeys {
  static const field = Key('mahjong.field');
  static const hint = Key('mahjong.hint');
  static const summary = Key('mahjong.summary');
  static Key tile(int index) => ValueKey('mahjong.tile.$index');
}

class WordMahjongField extends StatelessWidget {
  const WordMahjongField({
    required this.board,
    required this.onTap,
    required this.enabled,
    this.wordLanguage,
    this.translationLanguage,
    this.selected,
    this.mismatch,
    this.highlight,
    super.key,
  });

  final WordMahjongBoard board;
  final ValueChanged<MahjongTile> onTap;
  final bool enabled;
  final String? wordLanguage;
  final String? translationLanguage;
  final MahjongTile? selected;
  final MahjongTile? mismatch;
  final MahjongPair? highlight;

  static const _gap = 9.0;
  static const _rise = 10.0;
  static const _shift = 4.0;
  static const _glyphPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final style = withWeight(
      Theme.of(context).textTheme.bodyMedium!,
      FontWeight.w700,
    ).copyWith(height: 1.14);
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 190);
    return ArcadePanel(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 350 ? 4 : 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              1 + board.tiles.map((tile) => tile.column).reduce(math.max);
          final scaler = MediaQuery.textScalerOf(context);
          final paletteHeight = scaler.scale(10) + 8;
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: scaler,
          );
          final (tiles, height) = _arrange(
            style,
            painter,
            constraints.maxWidth - _shift,
            columns,
            paletteHeight,
          );
          painter.dispose();
          return Center(
            child: SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: Stack(
                key: ObjectKey(board),
                children: [
                  for (final tile in board.tiles)
                    Positioned.fromRect(
                      rect: tiles[(tile.row, tile.column)]!.shift(
                        Offset(tile.layer * _shift, -tile.layer * _rise),
                      ),
                      child: IgnorePointer(
                        ignoring: !board.contains(tile),
                        child: _buildTile(context, tile, style, duration),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  (Map<(int, int), Rect>, double) _arrange(
    TextStyle style,
    TextPainter painter,
    double width,
    int columns,
    double paletteHeight,
  ) {
    final cellWidth = (width - _gap * (columns - 1)) / columns;
    final rows = <int, Map<int, List<MahjongTile>>>{};
    for (final tile in board.tiles) {
      final row = rows.putIfAbsent(tile.row, () => {});
      row.putIfAbsent(tile.column, () => []).add(tile);
    }

    final placements = <(int, int), Rect>{};
    var top = _rise;
    for (final row in rows.entries) {
      final shelf = <(int, double)>[];
      var usedWidth = 0.0;
      var shelfHeight = 78.0;

      void placeShelf() {
        var left = (width - usedWidth) / 2;
        for (final (column, tileWidth) in shelf) {
          placements[(row.key, column)] = Rect.fromLTWH(
            left,
            top,
            tileWidth,
            shelfHeight,
          );
          left += tileWidth + _gap;
        }
        top += shelfHeight + _gap + _rise;
        shelf.clear();
        usedWidth = 0;
        shelfHeight = 78;
      }

      // A slot's width includes every layer even after it is removed. The
      // tiles never shift because another pair was picked or uncovered.
      for (final entry in row.value.entries) {
        var tileWidth = cellWidth;
        for (final tile in entry.value) {
          painter
            ..text = TextSpan(text: tile.label, style: style)
            ..layout();
          tileWidth = math.max(
            tileWidth,
            painter.minIntrinsicWidth.ceilToDouble() + 2 * _glyphPadding + 2,
          );
        }
        tileWidth = math.min(tileWidth, width);
        if (shelf.isNotEmpty && usedWidth + _gap + tileWidth > width + .001) {
          placeShelf();
        }
        for (final tile in entry.value) {
          painter
            ..text = TextSpan(text: tile.label, style: style)
            ..layout(maxWidth: math.max(1, tileWidth - 2 * _glyphPadding));
          shelfHeight = math.max(
            shelfHeight,
            painter.height.ceilToDouble() + paletteHeight + 21,
          );
        }
        usedWidth += tileWidth + (shelf.isEmpty ? 0 : _gap);
        shelf.add((entry.key, tileWidth));
      }
      placeShelf();
    }
    return (placements, top - _gap - _rise + 4);
  }

  Widget _buildTile(
    BuildContext context,
    MahjongTile tile,
    TextStyle style,
    Duration duration,
  ) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    final visible = board.contains(tile);
    // Keep the face of a removed pair readable throughout its fade.
    final free = !visible || board.isFree(tile);
    final covered = board.isCovered(tile);
    final pressed = selected == tile;
    final guided = tile == highlight?.word || tile == highlight?.translation;
    final wrong = mismatch == tile;
    final canTap = visible && free && enabled;
    final accent = tile.isTranslation ? colors.tertiary : colors.primary;
    final border =
        wrong
            ? colors.error
            : pressed || guided
            ? accent
            : Color.lerp(colors.outlineVariant, accent, free ? .45 : .12)!;
    final face =
        Color.lerp(
          colors.surfaceContainerLowest,
          wrong ? colors.error : accent,
          pressed || guided || wrong
              ? .17
              : free
              ? .07
              : .03,
        )!;
    final foreground = free ? colors.onSurface : colors.onSurfaceVariant;
    final radius = BorderRadius.circular(12);
    final language =
        (tile.isTranslation ? translationLanguage : wordLanguage)
            ?.toUpperCase();
    final spokenLabel =
        tile.isTranslation ? strings.mahjongTranslation : strings.mahjongWord;
    return ExcludeSemantics(
      excluding: !visible || covered,
      child: Semantics(
        key: WordMahjongKeys.tile(tile.index),
        label: '${tile.label}, $spokenLabel',
        button: true,
        enabled: canTap,
        selected: pressed || guided,
        onTap: canTap ? () => onTap(tile) : null,
        excludeSemantics: true,
        child: TweenAnimationBuilder<double>(
          // A selected tile lifts while its tap target stays in its slot.
          tween: Tween(end: pressed && duration != Duration.zero ? -3.5 : 0),
          builder:
              (context, lift, child) => Transform.translate(
                offset: Offset(0, lift),
                transformHitTests: false,
                child: child,
              ),
          curve: Curves.easeOutCubic,
          duration: duration,
          child: AnimatedScale(
            scale: visible ? 1 : .84,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: duration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(color: border, offset: const Offset(0, 3)),
                    if (guided)
                      BoxShadow(
                        color: accent.withValues(alpha: .5),
                        blurRadius: 12,
                      ),
                  ],
                ),
                child: Material(
                  color: face,
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
                    side: BorderSide(
                      color: border,
                      width: pressed || guided || wrong ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canTap ? () => onTap(tile) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _glyphPadding,
                        vertical: 7,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 4,
                        children: [
                          if (!free)
                            Icon(
                              Icons.lock_outline_rounded,
                              color: foreground,
                              size: 14,
                            )
                          else if (language == null)
                            Icon(
                              tile.isTranslation
                                  ? Icons.translate_rounded
                                  : Icons.school_outlined,
                              color: accent,
                              size: 14,
                            )
                          else
                            Text(
                              language,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .7,
                              ),
                            ),
                          if (!covered)
                            Text(
                              tile.label,
                              style: style.copyWith(color: foreground),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
