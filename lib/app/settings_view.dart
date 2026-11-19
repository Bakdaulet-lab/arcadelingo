/// Тема, язык интерфейса, звук и ежедневное напоминание.
library;

import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/ports/settings_store.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_choice_dialog.dart';
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
  static const Key language = Key('settings.language');
  static const Key theme = Key('settings.theme');
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
  bool _saving = false;
  bool _choosing = false;
  bool _appearanceSaveFailed = false;

  Future<void> _apply(AppSettings next) async {
    if (_saving) return;
    final preferenceChanged =
        next.interfaceLanguage != _settings.interfaceLanguage ||
        next.theme != _settings.theme;
    setState(() => _saving = true);
    try {
      final ok = await widget.onApply(next);
      if (!mounted) return;
      setState(() {
        _appearanceSaveFailed = preferenceChanged && !ok;
        if (!preferenceChanged) _denied = !ok;
        if (ok) _settings = next;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _languageLabel(InterfaceLanguage language, AppStrings strings) =>
      switch (language) {
        InterfaceLanguage.system => strings.systemLanguage,
        InterfaceLanguage.russian => 'Русский',
        InterfaceLanguage.english => 'English',
        InterfaceLanguage.spanish => 'Español',
      };

  String _themeLabel(AppTheme theme, AppStrings strings) => switch (theme) {
    AppTheme.light => strings.lightTheme,
    AppTheme.dark => strings.darkTheme,
  };

  Future<void> _chooseLanguage() {
    final strings = context.strings;
    return _choose(
      title: strings.appLanguage,
      choices: InterfaceLanguage.values,
      current: _settings.interfaceLanguage,
      label: (language) => _languageLabel(language, strings),
      key: (language) => ValueKey('settings.language.${language.tag}'),
      update: (language) => _settings.copyWith(interfaceLanguage: language),
    );
  }

  Future<void> _chooseTheme() {
    final strings = context.strings;
    return _choose(
      title: strings.appearance,
      choices: const [AppTheme.light, AppTheme.dark],
      current: _settings.theme,
      label: (theme) => _themeLabel(theme, strings),
      key: (theme) => ValueKey('settings.theme.${theme.name}'),
      update: (theme) => _settings.copyWith(theme: theme),
    );
  }

  Future<void> _choose<T>({
    required String title,
    required List<T> choices,
    required T current,
    required String Function(T) label,
    required Key Function(T) key,
    required AppSettings Function(T) update,
  }) async {
    if (_saving || _choosing) return;
    _choosing = true;
    try {
      final value = await showArcadeChoice<T>(
        context,
        title: title,
        choices: choices,
        selected: current,
        label: label,
        optionKey: key,
      );
      if (value != null && mounted && value != current) {
        await _apply(update(value));
      }
    } finally {
      _choosing = false;
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.at.hour,
        minute: _settings.at.minute,
      ),
      helpText: context.strings.reminderTime,
      cancelText: context.strings.cancel,
      confirmText: context.strings.save,
      hourLabelText: context.strings.hours,
      minuteLabelText: context.strings.minutes,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = context.strings;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final titleStyle = withWeight(theme.textTheme.titleSmall!, FontWeight.w600);
    final valueStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    const rowPadding = EdgeInsets.symmetric(horizontal: 12);
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: largeText ? 12 : 54,
      endIndent: 12,
      color: scheme.outline.withValues(alpha: .55),
    );
    final canPickTime = _settings.enabled && !_saving;
    final time =
        strings.isRussian
            ? _settings.at.toString()
            : TimeOfDay(
              hour: _settings.at.hour,
              minute: _settings.at.minute,
            ).format(context);
    final formattedTime = Text(
      time,
      style: withWeight(
        valueStyle,
        FontWeight.w600,
      ).copyWith(color: canPickTime ? scheme.primary : scheme.onSurfaceVariant),
    );

    Widget? symbol(IconData icon, Color color) =>
        largeText ? null : _SettingSymbol(icon: icon, color: color);

    return ArcadePage(
      title: strings.settings,
      compactHeader: true,
      child: SingleChildScrollView(
        key: SettingsKeys.view,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArcadePanel(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: ListTileTheme(
                  data: ListTileThemeData(
                    horizontalTitleGap: 10,
                    minLeadingWidth: 30,
                    titleTextStyle: titleStyle,
                    subtitleTextStyle: valueStyle,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        key: SettingsKeys.theme,
                        onTap: _saving ? null : _chooseTheme,
                        contentPadding: rowPadding,
                        minTileHeight: 56,
                        minVerticalPadding: 5,
                        leading: symbol(
                          Icons.light_mode_outlined,
                          scheme.primary,
                        ),
                        title: Text(strings.appearance),
                        subtitle: Text(_themeLabel(_settings.theme, strings)),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                      ),
                      divider,
                      ListTile(
                        key: SettingsKeys.language,
                        onTap: _saving ? null : _chooseLanguage,
                        contentPadding: rowPadding,
                        minTileHeight: 56,
                        minVerticalPadding: 5,
                        leading: symbol(Icons.language_rounded, scheme.primary),
                        title: Text(strings.appLanguage),
                        subtitle: Text(
                          _languageLabel(_settings.interfaceLanguage, strings),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                      ),
                      divider,
                      SwitchListTile(
                        key: SettingsKeys.toggle,
                        value: _settings.enabled,
                        onChanged:
                            _saving
                                ? null
                                : (on) =>
                                    _apply(_settings.copyWith(enabled: on)),
                        contentPadding: rowPadding,
                        secondary: symbol(
                          Icons.notifications_none_rounded,
                          scheme.primary,
                        ),
                        title: Text(strings.dailyReminder),
                      ),
                      divider,
                      ListTile(
                        key: SettingsKeys.time,
                        enabled: canPickTime,
                        onTap: canPickTime ? _pickTime : null,
                        contentPadding: rowPadding,
                        minTileHeight: 52,
                        minVerticalPadding: 5,
                        leading: symbol(
                          Icons.schedule_rounded,
                          scheme.onSurfaceVariant,
                        ),
                        title: Text(strings.time),
                        subtitle: largeText ? formattedTime : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!largeText) formattedTime,
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color:
                                  canPickTime
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      divider,
                      SwitchListTile(
                        key: SettingsKeys.sound,
                        value: _settings.soundOn,
                        onChanged:
                            _saving
                                ? null
                                : (on) =>
                                    _apply(_settings.copyWith(soundOn: on)),
                        contentPadding: rowPadding,
                        secondary: symbol(
                          Icons.volume_up_rounded,
                          scheme.tertiary,
                        ),
                        title: Text(strings.gameSounds),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_appearanceSaveFailed || _denied) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: ArcadePanel(
                  key: _denied ? SettingsKeys.denied : null,
                  accent: scheme.error,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _appearanceSaveFailed
                        ? strings.settingsSaveFailed
                        : strings.notificationsDenied,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
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
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}
