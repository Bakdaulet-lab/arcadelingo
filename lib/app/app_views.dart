/// Экраны хоста: «Играть» и два экрана ошибок.
///
/// Как и `falling_words_views.dart`, здесь нет ни состояния, ни хранилища:
/// всё, что видно, приходит параметрами. Причина ошибки — обычная строка,
/// а не `Failure`: экрану нужен текст, разбирать `Result` — работа хоста.
///
/// Экранов ошибки два, а не один с флагом, потому что различаются они не
/// оформлением, а тем, что человек может сделать. Битое состояние сбросить
/// можно — и решает это он, а не код (0.6). Битый сид — дефект сборки:
/// сбрасывать нечего, и кнопки здесь не будет.
library;

import 'package:arcadelingo/app/game_selector.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
import 'package:arcadelingo/ui/arcade_status_layout.dart';
import 'package:arcadelingo/ui/home_ritual_card.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

export 'game_selector.dart' show GameSelector;

/// Ключи экранов хоста. Тест ищет по ним то, что не опознать по тексту:
/// какой именно экран показан и есть ли на нём кнопка сброса.
abstract final class AppKeys {
  /// Кнопка «Играть». Она же признак того, что показан домашний экран.
  static const Key play = Key('app.play');

  static const Key learn = Key('app.learn');

  static const Key gameSelector = Key('app.game_selector');

  static const Key levelSelector = Key('app.level_selector');

  static const Key stateError = Key('app.state_error');

  static const Key seedError = Key('app.seed_error');

  /// «Сбросить прогресс» — только на экране ошибки состояния.
  static const Key reset = Key('app.reset');

  /// Вход на «Настройки» с домашнего экрана.
  static const Key settings = Key('app.settings');
  static const Key course = Key('app.course');

  /// Вход на «Прогресс» с домашнего экрана.
  ///
  /// Здесь же, где «Источники»: домашний экран открывают, когда не играют, и
  /// оба этих экрана — про «посмотреть», а не про «сыграть».
  static const Key progress = Key('app.progress');

  /// Вход на «Источники» с домашнего экрана.
  ///
  /// Домашний, а не конец партии: на итогах кнопка конкурировала бы с «Ещё
  /// раз» и «Выйти», ради которых экран и существует. Плюс домашний экран
  /// не входит ни в один из восьми голденов.
  static const Key sources = Key('app.sources');

  /// Сам экран «Источники».
  static const Key sourcesView = Key('app.sources_view');

  /// «Полные тексты лицензий» → штатный `showLicensePage`.
  static const Key licenses = Key('app.licenses');

  /// Подпись под пламенем стрик-карточки; её нет, когда серии нет.
  ///
  /// Определение живёт в `lib/ui/streak_card.dart`: карточка о хосте не
  /// знает (пункт 4 «Архитектурного закона»), а два одинаковых литерала в
  /// двух файлах однажды разъедутся.
  static const Key streak = streakCaptionKey;

  /// «Сегодня сыграно» / «Сегодня ещё не сыграно».
  static const Key today = homeTodayKey;

  /// Состояние запаса заморозок; её нет, пока говорить нечего.
  static const Key freeze = homeFreezeKey;
}

/// Домашний экран: выбор уровня и игры перед запуском.
///
/// Сессия создаётся по нажатию, а не при старте приложения: очередь
/// собирается на текущий момент и, пролежав на этом экране до полуночи,
/// протухла бы (0.6, `docs/dev/context.md`).
class PlayView extends StatelessWidget {
  const PlayView({
    required this.onPlay,
    required this.onProgress,
    required this.onSettings,
    required this.onSources,
    super.key,
    this.onLearn,
    this.ritual,
    this.week,
    this.games = const [],
    this.selectedGameId,
    this.onGameSelected,
    this.selectedLevel,
    this.onLevelSelected,
    this.course,
    this.onCourseSelected,
  });

  /// Серия на сегодня; null — состояние не читается.
  ///
  /// Считает её `streakAsOf` в домене, экран только рисует. Это не церемония:
  /// «показывать ли четыре дня, если вчера пропущен» — правило, а не вёрстка,
  /// и виджет, решающий это сам, однажды разойдётся с тем, что засчитает
  /// следующая партия.
  ///
  /// Ошибка чтения здесь молчит: ритуал — украшение, битый документ
  /// становится громким на тапе «Играть».
  final StreakView? ritual;

  /// Семь дней недели для полосы под пламенем; null — журнал ещё читается.
  ///
  /// Отдельно от [ritual], потому что источник другой и он асинхронный:
  /// сыгранные дни знает журнал событий, а не состояние серии. Место под
  /// полосу занято заранее — карточка не прыгает, когда данные приедут.
  final List<WeekDay>? week;

  final List<GameEntry> games;
  final String? selectedGameId;
  final ValueChanged<String>? onGameSelected;
  final CefrLevel? selectedLevel;
  final ValueChanged<CefrLevel>? onLevelSelected;
  final StudyCourse? course;
  final VoidCallback? onCourseSelected;

  final VoidCallback? onPlay;

  final VoidCallback? onLearn;

  /// Вход на «Источники».
  ///
  /// Здесь, а не на итогах: там кнопка конкурировала бы с «Ещё раз» и
  /// «Выйти» — двумя действиями, ради которых экран конца партии и
  /// существует. Домашний экран открывают, когда не играют.
  final VoidCallback onSources;

  /// Вход на «Прогресс».
  final VoidCallback onProgress;

  /// Вход на «Настройки».
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final game = games.where((entry) => entry.id == selectedGameId).firstOrNull;

    final scrollActions =
        MediaQuery.sizeOf(context).height < 640 ||
        MediaQuery.textScalerOf(context).scale(16) > 22;
    final actions = _HomeActions(
      game: game,
      level: selectedLevel,
      ritual: ritual,
      onPlay: onPlay,
      onLearn: onLearn,
      onProgress: onProgress,
      onSettings: onSettings,
    );

    return Scaffold(
      body: SafeArea(
        bottom: scrollActions,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Arcadelingo',
                            style: withWeight(
                              theme.textTheme.headlineMedium!,
                              FontWeight.bold,
                            ).copyWith(fontSize: 30, letterSpacing: -.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        key: AppKeys.sources,
                        tooltip: context.strings.sources,
                        onPressed: onSources,
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceContainerHighest,
                          foregroundColor: colors.onSurfaceVariant,
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline_rounded),
                      ),
                    ],
                  ),
                  if (ritual case final view?) ...[
                    const SizedBox(height: 16),
                    HomeRitualCard(ritual: view, week: week),
                  ],
                  if (course case final selected?) ...[
                    const SizedBox(height: 14),
                    ArcadePanel(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: AppKeys.course,
                          onTap: onCourseSelected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          minTileHeight: 48,
                          minVerticalPadding: 6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: Icon(
                            Icons.language_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          minLeadingWidth: 20,
                          horizontalTitleGap: 10,
                          trailing: Icon(
                            Icons.expand_more_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                          title: Text(
                            context.strings.courseName(selected),
                            style: withWeight(
                              theme.textTheme.titleSmall!,
                              FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (selectedLevel case final level?) ...[
                    SizedBox(height: course == null ? 20 : 14),
                    _LevelSelector(
                      level: level,
                      onSelected: onLevelSelected,
                      language: course?.studyLanguage ?? 'en',
                    ),
                    if (onPlay == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            context.strings.noWordsForLevel(
                              level.name.toUpperCase(),
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                  ],
                  if (games.length > 1) ...[
                    const SizedBox(height: 20),
                    Text(
                      context.strings.chooseGame,
                      style: withWeight(
                        theme.textTheme.titleLarge!,
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GameSelector(
                      key: AppKeys.gameSelector,
                      games: games,
                      selectedId: selectedGameId ?? games.first.id,
                      onSelected: onGameSelected ?? (_) {},
                    ),
                  ],
                  if (scrollActions) ...[const SizedBox(height: 20), actions],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          scrollActions
              ? null
              : SafeArea(
                top: false,
                child: Align(
                  heightFactor: 1,
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: actions,
                    ),
                  ),
                ),
              ),
    );
  }
}

class _HomeActions extends StatelessWidget {
  const _HomeActions({
    required this.game,
    required this.level,
    required this.ritual,
    required this.onPlay,
    required this.onLearn,
    required this.onProgress,
    required this.onSettings,
  });

  final GameEntry? game;
  final CefrLevel? level;
  final StreakView? ritual;
  final VoidCallback? onPlay;
  final VoidCallback? onLearn;
  final VoidCallback onProgress;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (game != null && level != null) ...[
          Text(
            '${game!.titleFor(context.strings)} · ${level!.name.toUpperCase()}',
            textAlign: TextAlign.center,
            style: withWeight(
              theme.textTheme.labelLarge!,
              FontWeight.w500,
            ).copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
        ],
        if (onLearn != null) ...[
          OutlinedButton.icon(
            key: AppKeys.learn,
            onPressed: onLearn,
            icon: const Icon(Icons.school_outlined),
            label: Text(
              context.strings.learnAndPlay,
              textAlign: TextAlign.center,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: withWeight(
                theme.textTheme.titleMedium!,
                FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          key: AppKeys.play,
          onPressed: onPlay,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: withWeight(theme.textTheme.titleLarge!, FontWeight.bold),
          ),
          child: Text(
            ritual == null
                ? context.strings.play
                : ritualCallToAction(ritual!, strings: context.strings),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        _HomeNavigation(onProgress: onProgress, onSettings: onSettings),
      ],
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({
    required this.level,
    required this.onSelected,
    required this.language,
  });

  final CefrLevel level;
  final String language;
  final ValueChanged<CefrLevel>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      key: AppKeys.levelSelector,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.strings.levelOf(language),
          style: withWeight(theme.textTheme.titleMedium!, FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final fontScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            // Шесть целей касания по 48 dp и пять промежутков по 6 dp.
            final columns =
                fontScale > 1.4 || constraints.maxWidth < 318 ? 3 : 6;
            final width = (constraints.maxWidth - 6 * (columns - 1)) / columns;
            return Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final option in CefrLevel.values)
                  SizedBox(
                    width: width,
                    child: ChoiceChip(
                      label: Center(child: Text(option.name.toUpperCase())),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      labelPadding: EdgeInsets.zero,
                      selected: option == level,
                      onSelected:
                          onSelected == null
                              ? null
                              : (_) => onSelected!(option),
                      selectedColor: colors.primary,
                      backgroundColor: colors.surfaceContainerHighest,
                      labelStyle: withWeight(
                        theme.textTheme.labelLarge!,
                        FontWeight.bold,
                      ).copyWith(
                        color:
                            option == level
                                ? colors.onPrimary
                                : colors.onSurface,
                      ),
                      showCheckmark: false,
                      side: BorderSide(
                        color:
                            option == level ? colors.primary : colors.outline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      visualDensity: VisualDensity.standard,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({required this.onProgress, required this.onSettings});

  final VoidCallback onProgress;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 17;
    final destinations = [
      _destination(
        context,
        label: context.strings.games,
        icon: Icons.sports_esports_rounded,
        selected: true,
        onPressed: () {},
      ),
      _destination(
        context,
        key: AppKeys.progress,
        label: context.strings.progress,
        icon: Icons.bar_chart_rounded,
        onPressed: onProgress,
      ),
      _destination(
        context,
        key: AppKeys.settings,
        label: context.strings.settings,
        icon: Icons.settings_rounded,
        onPressed: onSettings,
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: .45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child:
            largeText
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: destinations,
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final destination in destinations)
                      Expanded(child: destination),
                  ],
                ),
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    final color =
        selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      child: TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: const Size(48, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: withWeight(
                theme.textTheme.labelSmall!,
                FontWeight.w500,
              ).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Прогресс не читается: показать причину и дать сбросить.
///
/// Текст [message] — сообщение из `Failure`, целиком. «Что-то пошло не так»
/// не даёт ни понять, что случилось, ни рассказать об этом.
class StateErrorView extends StatelessWidget {
  const StateErrorView({
    required this.message,
    required this.onReset,
    super.key,
  });

  final String message;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _ErrorLayout(
      viewKey: AppKeys.stateError,
      icon: Icons.warning_amber_rounded,
      title: context.strings.progressUnreadable,
      message: context.strings.isEnglish ? null : message,
      hint: context.strings.resetHint,
      action: FilledButton(
        key: AppKeys.reset,
        onPressed: onReset,
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(220, 56)),
        ),
        child: Text(context.strings.resetProgress),
      ),
    );
  }
}

/// Словарь не читается. Кнопки нет намеренно: сид лежит в бандле, и
/// сбрасывать тут нечего — чинится только новой сборкой.
class SeedErrorView extends StatelessWidget {
  const SeedErrorView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ErrorLayout(
      viewKey: AppKeys.seedError,
      icon: Icons.error_outline,
      title: context.strings.dictionaryUnreadable,
      message: context.strings.isEnglish ? null : message,
      hint: context.strings.dictionaryRepairHint,
    );
  }
}

/// Общая раскладка обоих экранов ошибки: иконка, заголовок, причина,
/// подсказка и необязательное действие.
class _ErrorLayout extends StatelessWidget {
  const _ErrorLayout({
    required this.viewKey,
    required this.icon,
    required this.title,
    required this.message,
    required this.hint,
    this.action,
  });

  final Key viewKey;
  final IconData icon;
  final String title;
  final String? message;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ArcadeStatusLayout(
        key: viewKey,
        icon: icon,
        accent: theme.colorScheme.error,
        title: title,
        body: ArcadePanel(
          child: Column(
            children: [
              if (message case final details?)
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        actions: action,
      ),
    );
  }
}
