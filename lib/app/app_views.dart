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

import 'package:arcadelingo/domain/streak/streak_view.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_card.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:arcadelingo/ui/week_strip.dart';
import 'package:flutter/material.dart';

/// Ключи экранов хоста. Тест ищет по ним то, что не опознать по тексту:
/// какой именно экран показан и есть ли на нём кнопка сброса.
abstract final class AppKeys {
  /// Кнопка «Играть». Она же признак того, что показан домашний экран.
  static const Key play = Key('app.play');

  static const Key stateError = Key('app.state_error');

  static const Key seedError = Key('app.seed_error');

  /// «Сбросить прогресс» — только на экране ошибки состояния.
  static const Key reset = Key('app.reset');

  /// Вход на «Настройки» с домашнего экрана.
  static const Key settings = Key('app.settings');

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
  static const Key today = Key('app.today');

  /// Состояние запаса заморозок; её нет, пока говорить нечего.
  static const Key freeze = Key('app.freeze');
}

/// Домашний экран: одна кнопка.
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
    this.ritual,
    this.week,
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

  final VoidCallback onPlay;

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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Arcadelingo',
                textAlign: TextAlign.center,
                // `withWeight`, а не `copyWith(fontWeight:)`. Оси `wght`
                // обычный fontWeight не двигает (шапка lib/ui/theme.dart), и
                // заголовок всё это время рисовался обычным начертанием, а не
                // жирным. Заметно ровно здесь: это единственная строка в
                // приложении, набранная кеглем displaySmall.
                style: withWeight(textTheme.displaySmall!, FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Английские слова через аркаду',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              if (ritual case final view?) ...[
                const SizedBox(height: 24),
                StreakCard(ritual: view, week: week),
                const SizedBox(height: 12),
                Text(
                  ritualTodayLabel(view),
                  key: AppKeys.today,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color:
                        view.playedToday
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (ritualFreezeLabel(view) case final freeze?) ...[
                  const SizedBox(height: 4),
                  Text(
                    freeze,
                    key: AppKeys.freeze,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 40),
              FilledButton(
                key: AppKeys.play,
                onPressed: onPlay,
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(220, 56)),
                  textStyle: WidgetStateProperty.all(textTheme.titleMedium),
                ),
                child: Text(
                  ritual == null ? 'Играть' : ritualCallToAction(ritual!),
                ),
              ),
              const SizedBox(height: 8),
              // `Wrap`, а не `Row`: три ссылки в строку не помещаются на
              // экране 360 dp — тест поймал переполнение на 127 px, — а при
              // системном шрифте 2× не поместились бы и две. Перенос на
              // вторую строку честнее, чем обрезанная третья кнопка.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    key: AppKeys.progress,
                    onPressed: onProgress,
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: const Text('Прогресс'),
                  ),
                  TextButton(
                    key: AppKeys.settings,
                    onPressed: onSettings,
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: const Text('Настройки'),
                  ),
                  TextButton(
                    key: AppKeys.sources,
                    onPressed: onSources,
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: const Text('Источники'),
                  ),
                ],
              ),
            ],
          ),
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
      title: 'Прогресс не читается',
      message: message,
      hint:
          'Сброс удалит коробки повторения: слова начнутся заново, '
          'как при первом запуске.',
      action: FilledButton(
        key: AppKeys.reset,
        onPressed: onReset,
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(220, 56)),
        ),
        child: const Text('Сбросить прогресс'),
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
      title: 'Словарь не читается',
      message: message,
      hint: 'Это дефект сборки: сбрасывать нечего, поможет только обновление.',
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
  final String message;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final button = action;
    return Scaffold(
      body: Center(
        key: viewKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              if (button != null) ...[const SizedBox(height: 32), button],
            ],
          ),
        ),
      ),
    );
  }
}
