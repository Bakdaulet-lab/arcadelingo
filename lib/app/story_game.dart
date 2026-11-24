import 'dart:async';

import 'package:arcadelingo/app/app_ports.dart';
import 'package:arcadelingo/app/games.dart';
import 'package:arcadelingo/domain/core/result.dart';
import 'package:arcadelingo/domain/events/app_event.dart';
import 'package:arcadelingo/domain/ports/sounds.dart';
import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/session/observed_session.dart';
import 'package:arcadelingo/domain/settings/app_settings.dart';
import 'package:arcadelingo/domain/usecases/count_played_day.dart';
import 'package:arcadelingo/domain/usecases/start_session.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';

const storyStageGames = [wordMahjongEntry, fallingWordsEntry];

/// Finishing the mini-round returns to the current story. A back gesture or
/// an incomplete round leaves its stage available for another attempt.
Future<bool> playStoryStage(
  BuildContext context, {
  required AppPorts ports,
  required StudyCourse course,
  required CefrLevel level,
  required int stage,
  required List<ReviewItem> items,
  required DateTime Function() now,
}) async {
  final game = storyStageGames[stage];
  final started = StartSession(
    cards: ports.cards,
    streaks: ports.streaks,
    now: now,
    target: 3,
    answerLog: ports.answers,
  )(items: items, level: level, gameId: game.id, practiceAll: true);
  final ReviewSession session;
  switch (started) {
    case Err():
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.progressLoadFailed)),
      );
      return false;
    case Ok(:final value):
      session = value;
  }
  if (session.total == 0) return false;
  final soundOn = switch (ports.settings?.load()) {
    Ok(:final value) => value.soundOn,
    Err() || null => AppSettings.defaults.soundOn,
  };
  final sessionId = session is ObservedSession ? session.sessionId : null;
  void record(AppEventKind kind) => unawaited(
    ports.events.append(AppEvent.at(kind, now(), sessionId: sessionId)),
  );
  record(AppEventKind.roundStart);
  final navigator = Navigator.of(context);
  final completed = await navigator.push<bool>(
    _StoryStageRoute(
      builder: (gameContext) {
        void close(bool finished) {
          if (ModalRoute.isCurrentOf(gameContext) == true) {
            navigator.pop(finished);
          }
        }

        return game.build(
          GameLaunch(
            session: session,
            course: course,
            level: level,
            sounds: soundOn ? ports.sounds : const NoopSounds(),
            speech: soundOn ? ports.speech : const NoopWordSpeech(),
            summaryFooter: () => '',
            onExit: () => close(false),
            onPlayAgain: () => close(false),
            onRoundOver: () => close(session.isFinished),
          ),
        );
      },
    ),
  );
  if (completed != true) {
    record(AppEventKind.roundAbandon);
    return false;
  }
  record(AppEventKind.roundOver);
  final counted = CountPlayedDay(streaks: ports.streaks, now: now)();
  if (counted is Err && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.progressLoadFailed)));
  }
  return true;
}

/// The story owns the result screen. Dismiss the arcade before its regular
/// score and replay controls would appear during the reverse transition.
class _StoryStageRoute extends MaterialPageRoute<bool> {
  _StoryStageRoute({required super.builder});

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}
