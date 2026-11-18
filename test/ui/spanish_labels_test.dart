import 'package:arcadelingo/domain/reminders/reminder_policy.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/reminder_labels.dart';
import 'package:arcadelingo/ui/ritual_labels.dart';
import 'package:arcadelingo/ui/streak_label.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ritual_views.dart';

void main() {
  final strings = AppStrings(InterfaceLanguage.fromTag('es'));

  test('Spanish streak and accessibility labels use the right forms', () {
    expect(streakLabel(1, strings: strings), 'Racha: 1 día');
    expect(streakLabel(2, strings: strings), 'Racha: 2 días');
    expect(
      ritualStreakLabel(ritualView(days: 1), strings: strings),
      'día seguido',
    );
    expect(
      ritualStreakLabel(ritualView(days: 2), strings: strings),
      'días seguidos',
    );
    expect(strings.answersForDay('18 nov', 1), '18 nov, 1 respuesta');
    expect(strings.answersForDay('18 nov', 2), '18 nov, 2 respuestas');
    expect(strings.weekday(3, 'Ср'), 'mié');
  });

  test('Spanish freeze, answer hints and reminders use localized wording', () {
    expect(
      ritualFreezeLabel(ritualView(days: 5, frozenOffset: 1), strings: strings),
      'Protección usada el 25 de agosto',
    );
    expect(
      strings.capsule('Ñ', hintShown: true),
      'Cápsula con la letra Ñ, pista',
    );
    final atRisk = reminderText(
      ReminderPlan(
        at: DateTime(2026, 11, 18),
        reason: ReminderReason.atRisk,
        days: 5,
      ),
      strings: strings,
    );
    expect(atRisk.$1, 'Tu racha de 5 días está en riesgo');
    expect(
      atRisk.$2,
      'Juega hoy. La protección de racha cubrirá el día que faltaste.',
    );
  });
}
