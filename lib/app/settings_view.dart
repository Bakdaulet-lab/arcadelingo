/// Экран настроек: единственная настройка — напоминание.
///
/// Экран заведён не «на будущее», а под одну вещь, у которой нет другого
/// места: время, в которое человек хочет, чтобы его позвали. Всё остальное,
/// что могло бы сюда попасть — сложность, длина сессии, тема, — либо решено
/// за него, либо не существует.
///
/// Экран ничего не решает сам: он показывает, что лежит в хранилище, и
/// докладывает наверх, что человек нажал. Просить разрешение, ставить
/// напоминание в расписание и снимать его — работа хоста, который и так
/// знает про `data/`.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/settings_store.dart';
import 'package:arcadelingo/domain/reminders/reminder_settings.dart';
import 'package:arcadelingo/ui/theme.dart';
import 'package:flutter/material.dart';

/// Ключи экрана.
abstract final class SettingsKeys {
  static const Key view = Key('settings.view');

  /// Переключатель напоминания.
  static const Key toggle = Key('settings.toggle');

  /// Строка выбора времени.
  static const Key time = Key('settings.time');

  /// Сообщение об отказе в разрешении.
  static const Key denied = Key('settings.denied');
}

/// Что хост делает с новым выбором.
///
/// Возвращает `true`, если настройку удалось применить. `false` значит
/// «система не дала разрешения»: экран обязан это показать, а не
/// притвориться, что переключатель включился.
typedef ApplySettings = Future<bool> Function(ReminderSettings settings);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.store, required this.onApply, super.key});

  final SettingsStore store;
  final ApplySettings onApply;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ReminderSettings _settings = switch (widget.store.load()) {
    Ok(:final value) => value,
    // Битые настройки — не битый прогресс: экран ошибки здесь был бы
    // несоразмерен потере. Показываем умолчание; первое же сохранение
    // перезапишет документ целиком.
    Err() => ReminderSettings.defaults,
  };

  /// Система отказала в разрешении на прошлое включение.
  bool _denied = false;

  Future<void> _apply(ReminderSettings next) async {
    final ok = await widget.onApply(next);
    if (!mounted) return;
    setState(() {
      _denied = !ok;
      if (ok) _settings = next;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.at.hour,
        minute: _settings.at.minute,
      ),
    );
    if (picked == null) return;
    await _apply(
      _settings.copyWith(at: ReminderTime(picked.hour, picked.minute)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        key: SettingsKeys.view,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            key: SettingsKeys.toggle,
            value: _settings.enabled,
            onChanged: (on) => _apply(_settings.copyWith(enabled: on)),
            title: const Text('Напоминание'),
            subtitle: const Text('Одно уведомление в день'),
          ),
          ListTile(
            key: SettingsKeys.time,
            enabled: _settings.enabled,
            onTap: _settings.enabled ? _pickTime : null,
            title: const Text('Время'),
            trailing: Text(
              _settings.at.toString(),
              style: withWeight(
                textTheme.titleMedium!,
                FontWeight.bold,
              ).copyWith(
                color:
                    _settings.enabled
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_denied)
            Padding(
              key: SettingsKeys.denied,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Система не разрешила уведомления. Включить их можно в '
                'настройках телефона.',
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
