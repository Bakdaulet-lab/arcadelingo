import 'dart:async';

import 'package:arcadelingo/app/daily_word_view.dart';
import 'package:arcadelingo/domain/daily_word/daily_word.dart';
import 'package:arcadelingo/domain/ports/daily_word_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/domain/streak/streak.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:arcadelingo/ui/daily_word_share.dart';
import 'package:flutter/material.dart';

class DailyWordRoute extends StatefulWidget {
  const DailyWordRoute({
    required this.course,
    required this.level,
    required this.vocabulary,
    required this.store,
    required this.now,
    super.key,
  });

  final StudyCourse course;
  final CefrLevel level;
  final List<Word> vocabulary;
  final DailyWordStore store;
  final DateTime Function() now;

  @override
  State<DailyWordRoute> createState() => _DailyWordRouteState();
}

class _DailyWordRouteState extends State<DailyWordRoute>
    with WidgetsBindingObserver {
  StreakDay? _day;
  DailyWordPuzzle? _puzzle;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDay();
  }

  void _refreshDay() {
    final now = widget.now();
    final day = StreakDay.of(now);
    if (day != _day) {
      final saved = widget.store.load(level: widget.level, day: now);
      final puzzle = selectDailyWord(
        course: widget.course,
        level: widget.level,
        date: now,
        vocabulary: widget.vocabulary,
        targetId: saved?.targetId,
      );
      setState(() {
        _day = day;
        _puzzle = puzzle;
      });
    }
    final midnight =
        now.isUtc
            ? DateTime.utc(now.year, now.month, now.day + 1)
            : DateTime(now.year, now.month, now.day + 1);
    _midnight?.cancel();
    _midnight = Timer(midnight.difference(now), _refreshDay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDay();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _midnight?.cancel();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _share(String text) async {
    final outcome = await shareDailyWordResult(text);
    if (!mounted || outcome == DailyWordShareOutcome.opened) return;
    final strings = context.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == DailyWordShareOutcome.copied
              ? strings.dailyWordCopied
              : strings.dailyWordShareFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return ArcadePage(
        title: context.strings.dailyWord,
        child: Center(child: Text(context.strings.dailyWordUnavailable)),
      );
    }
    return DailyWordScreen(
      key: ValueKey(puzzle.day),
      puzzle: puzzle,
      store: widget.store,
      onShare: _share,
    );
  }
}
