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
}

/// Домашний экран: одна кнопка.
///
/// Сессия создаётся по нажатию, а не при старте приложения: очередь
/// собирается на текущий момент и, пролежав на этом экране до полуночи,
/// протухла бы (0.6, `docs/dev/context.md`).
class PlayView extends StatelessWidget {
  const PlayView({required this.onPlay, super.key});

  final VoidCallback onPlay;

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
                'Wordarcade',
                textAlign: TextAlign.center,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Английские слова через аркаду',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),
              FilledButton(
                key: AppKeys.play,
                onPressed: onPlay,
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(220, 56)),
                  textStyle: WidgetStateProperty.all(textTheme.titleMedium),
                ),
                child: const Text('Играть'),
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
