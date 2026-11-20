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
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              1 + board.tiles.map((tile) => tile.column).reduce(math.max);
          final rows = 1 + board.tiles.map((tile) => tile.row).reduce(math.max);
          final width =
              (constraints.maxWidth - _gap * (columns - 1) - _shift) / columns;
          final fieldWidth = width * columns + _gap * (columns - 1) + _shift;
          final heights = List.filled(rows, 78.0);
          final tops = List.filled(rows, _rise);
          final scaler = MediaQuery.textScalerOf(context);
          final paletteHeight = scaler.scale(10) + 8;
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: scaler,
          );
          for (final tile in board.tiles) {
            painter.text = TextSpan(text: tile.label, style: style);
            painter.layout(maxWidth: math.max(1, width - 16));
            heights[tile.row] = math.max(
              heights[tile.row],
              painter.height.ceilToDouble() + paletteHeight + 21,
            );
          }
          painter.dispose();
          for (var row = 1; row < rows; row++) {
            tops[row] = tops[row - 1] + heights[row - 1] + _gap + _rise;
          }
          return Center(
            child: SizedBox(
              width: fieldWidth,
              height: tops.last + heights.last + 4,
              child: Stack(
                key: ObjectKey(board),
                children: [
                  for (final tile in board.tiles)
                    Positioned(
                      left: tile.column * (width + _gap) + tile.layer * _shift,
                      top: tops[tile.row] - tile.layer * _rise,
                      width: width,
                      height: heights[tile.row],
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

  Widget _buildTile(
    BuildContext context,
    MahjongTile tile,
    TextStyle style,
    Duration duration,
  ) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    final free = board.isFree(tile);
    final covered = board.isCovered(tile);
    final visible = board.contains(tile);
    final pressed = selected == tile;
    final guided = tile == highlight?.word || tile == highlight?.translation;
    final wrong = mismatch == tile;
    final canTap = free && enabled;
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
                      horizontal: 8,
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
    );
  }
}
