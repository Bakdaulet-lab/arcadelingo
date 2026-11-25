import 'dart:async';

import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_game.dart';
import 'package:arcadelingo/features/games/falling_words/falling_words_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_review_session.dart';

const _items = [
  ReviewItem(
    word: Word(id: 'key', text: 'llave', translation: 'ключ'),
    distractors: ['дом'],
  ),
  ReviewItem(
    word: Word(id: 'house', text: 'casa', translation: 'дом'),
    distractors: ['ключ'],
  ),
];

class _Session implements BoardReviewSession {
  final _inner = FakeReviewSession(_items);
  List<ReportRecord> get reports => _inner.reports;
  @override
  int get answered => _inner.answered;
  @override
  int get total => _inner.total;
  @override
  bool get isFinished => _inner.isFinished;
  @override
  ReviewItem? nextItem() => _inner.nextItem();
  @override
  void report(ReviewOutcome outcome) => _inner.report(outcome);
  @override
  List<ReviewItem> get remainingItems => _items.skip(answered).toList();
  @override
  void reportPair(ReviewItem item, ReviewOutcome outcome) =>
      throw UnsupportedError('sequential game');
}

class _Speech implements WordSpeech {
  final words = <String>[];
  final pending = <Completer<SpeechResult>>[];
  int stops = 0;
  @override
  Future<SpeechResult> speak(String text) {
    words.add(text);
    final completion = Completer<SpeechResult>();
    pending.add(completion);
    return completion.future;
  }

  @override
  Future<void> stop() async => stops++;
}

Future<void> _show(
  WidgetTester tester,
  _Session session,
  _Speech speech,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FallingWordsGame(
        session: session,
        speech: speech,
        listeningMode: true,
        studyLanguage: 'es',
        onExit: () {},
        onPlayAgain: () {},
      ),
    ),
  );
  await tester.pump();
}

Future<void> _finishAudio(
  WidgetTester tester,
  Completer<SpeechResult> request, [
  SpeechResult result = SpeechResult.completed,
]) async {
  request.complete(result);
  await tester.pump();
  await tester.pump();
}

Finder _key(String name) => find.byKey(Key('falling.listening.$name'));

Future<void> _lifecycle(WidgetTester tester, AppLifecycleState state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'full audio precedes each word; replay freezes position and grading time',
    (tester) async {
      final session = _Session();
      final speech = _Speech();
      await _show(tester, session, speech);
      expect(speech.words, ['llave']);
      expect(find.text('llave'), findsNothing);
      expect(find.text('ключ'), findsNothing);
      await tester.pump(const Duration(seconds: 20));
      expect(session.reports, isEmpty);

      await _finishAudio(tester, speech.pending.single);
      final marker = _key('marker');
      final start = tester.getCenter(marker);
      await tester.pump(const Duration(seconds: 2));
      final stopped = tester.getCenter(marker);
      expect(stopped.dy, greaterThan(start.dy));
      await tester.tap(_key('replay'));
      await tester.pump();
      expect(speech.words, ['llave', 'llave']);
      await tester.tap(find.text('дом'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 20));
      expect(tester.getCenter(marker), stopped);
      expect(session.reports, isEmpty);
      await _finishAudio(tester, speech.pending.last);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('ключ'));
      await tester.pump();
      expect(session.reports.single.outcome.correct, isTrue);
      expect(
        session.reports.single.outcome.responseTime,
        const Duration(seconds: 3),
      );
      expect(find.text('llave'), findsOneWidget);
      expect(find.text('ключ'), findsWidgets);
      await tester.pump(const Duration(seconds: 12));
      expect(speech.words, ['llave', 'llave']);
      await tester.tap(_key('next'));
      await tester.pump();
      expect(speech.words.last, 'casa');
      expect(find.text('casa'), findsNothing);
      expect(find.text('дом'), findsNothing);
      await _finishAudio(tester, speech.pending.last);
      await tester.pump(FallingWordsRun.baseFallTime);
      expect(session.reports.last.outcome.timedOut, isTrue);
      expect(find.text('casa'), findsOneWidget);
    },
  );

  testWidgets('a wrong answer reveals its spelling and the correct meaning', (
    tester,
  ) async {
    final session = _Session();
    final speech = _Speech();
    await _show(tester, session, speech);
    await _finishAudio(tester, speech.pending.single);
    await tester.tap(find.text('дом'));
    await tester.pump();
    expect(session.reports.single.outcome.selectedAnswer, 'дом');
    expect(find.text('llave'), findsOneWidget);
    expect(find.text('ключ'), findsWidgets);
    expect(_key('next'), findsOneWidget);
  });

  testWidgets(
    'missing voice freezes the question; retry or continue by reading',
    (tester) async {
      final session = _Session();
      final speech = _Speech();
      await _show(tester, session, speech);
      await _finishAudio(
        tester,
        speech.pending.single,
        SpeechResult.unavailable,
      );
      expect(find.text('llave'), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(session.reports, isEmpty);
      await tester.tap(_key('retry'));
      await tester.pump();
      await _finishAudio(tester, speech.pending.last, SpeechResult.failed);
      await tester.tap(_key('useText'));
      await tester.pump();
      expect(find.text('llave'), findsOneWidget);
      expect(session.reports, isEmpty);
      await tester.tap(find.text('ключ'));
      await tester.pump();
      await tester.pump(FallingWordsRun.correctReveal);
      expect(find.text('casa'), findsOneWidget);
      expect(speech.words, ['llave', 'llave']);
    },
  );

  testWidgets(
    'background completion is stale, and exit before hearing preserves the card',
    (tester) async {
      final session = _Session();
      final speech = _Speech();
      await _show(tester, session, speech);
      await _lifecycle(tester, AppLifecycleState.paused);
      expect(speech.stops, greaterThan(0));
      await _lifecycle(tester, AppLifecycleState.resumed);
      expect(speech.words, ['llave', 'llave']);
      await _finishAudio(tester, speech.pending.first);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('ключ'), findsNothing);
      expect(session.reports, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await _finishAudio(tester, speech.pending.last);
      expect(speech.stops, greaterThan(1));
      expect(session.reports, isEmpty);
      expect(session.nextItem()!.word.text, 'llave');
      expect(tester.takeException(), isNull);
    },
  );
}
