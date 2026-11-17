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
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/arcade_panel.dart';
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

  /// Звук в играх.
  static const Key sound = Key('settings.sound');
}

/// Что хост делает с новым выбором.
///
/// Возвращает `true`, если настройку удалось применить. `false` значит
/// «система не дала разрешения»: экран обязан это показать, а не
/// притвориться, что переключатель включился.
typedef ApplySettings = Future<bool> Function(AppSettings settings);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.store, required this.onApply, super.key});

  final SettingsStore store;
  final ApplySettings onApply;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings = switch (widget.store.load()) {
    Ok(:final value) => value,
    // Битые настройки — не битый прогресс: экран ошибки здесь был бы
    // несоразмерен потере. Показываем умолчание; первое же сохранение
    // перезапишет документ целиком.
    Err() => AppSettings.defaults,
  };

  /// Система отказала в разрешении на прошлое включение.
  bool _denied = false;

  Future<void> _apply(AppSettings next) async {
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
      helpText: 'Время напоминания',
      cancelText: 'Отмена',
      confirmText: 'Сохранить',
      hourLabelText: 'Часы',
      minuteLabelText: 'Минуты',
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            timePickerTheme: theme.timePickerTheme.copyWith(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final titleStyle = withWeight(textTheme.titleMedium!, FontWeight.w600);
    final tilePadding = EdgeInsets.symmetric(
      horizontal: largeText ? 4 : 12,
      vertical: 8,
    );
    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );
    return ArcadePage(
      title: 'Настройки',
      child: SingleChildScrollView(
        key: SettingsKeys.view,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArcadePanel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (largeText)
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text('Напоминание', style: titleStyle),
                      ),
                    ),
                  Semantics(
                    label: largeText ? 'Напоминание' : null,
                    child: SwitchListTile(
                      key: SettingsKeys.toggle,
                      value: _settings.enabled,
                      onChanged:
                          (on) => _apply(_settings.copyWith(enabled: on)),
                      contentPadding: tilePadding,
                      secondary:
                          largeText
                              ? null
                              : _SettingSymbol(
                                icon: Icons.notifications_active_rounded,
                                color: scheme.primary,
                              ),
                      title:
                          largeText
                              ? null
                              : Text('Напоминание', style: titleStyle),
                      subtitle: Text(
                        'Одно уведомление в день',
                        style: subtitleStyle,
                      ),
                    ),
                  ),
                  Divider(
                    height: 20,
                    indent: largeText ? 12 : 64,
                    endIndent: 12,
                    color: scheme.outline.withValues(alpha: .45),
                  ),
                  ListTile(
                    key: SettingsKeys.time,
                    enabled: _settings.enabled,
                    onTap: _settings.enabled ? _pickTime : null,
                    contentPadding: tilePadding,
                    leading:
                        largeText
                            ? null
                            : _SettingSymbol(
                              icon: Icons.schedule_rounded,
                              color:
                                  _settings.enabled
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                            ),
                    title: Text('Время', style: titleStyle),
                    subtitle: Text(
                      _settings.at.toString(),
                      style: withWeight(
                        textTheme.headlineSmall!,
                        FontWeight.bold,
                      ).copyWith(
                        color:
                            _settings.enabled
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color:
                          _settings.enabled
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ArcadePanel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SwitchListTile(
                key: SettingsKeys.sound,
                value: _settings.soundOn,
                onChanged: (on) => _apply(_settings.copyWith(soundOn: on)),
                contentPadding: tilePadding,
                secondary:
                    largeText
                        ? null
                        : _SettingSymbol(
                          icon: Icons.volume_up_rounded,
                          color: scheme.tertiary,
                        ),
                title: Text('Звук', style: titleStyle),
                subtitle: Text(
                  'Свист клинка и удар в ниндзя-слэше',
                  style: subtitleStyle,
                ),
              ),
            ),
            if (_denied) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: ArcadePanel(
                  key: SettingsKeys.denied,
                  accent: scheme.error,
                  child: Text(
                    'Система не разрешила уведомления. Включить их можно в '
                    'настройках телефона.',
                    style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingSymbol extends StatelessWidget {
  const _SettingSymbol({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    ),
  );
}
