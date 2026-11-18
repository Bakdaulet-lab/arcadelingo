import 'dart:async';

import 'package:arcadelingo/domain/ports/word_speech.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:flutter/material.dart';

/// Кнопка системного произношения для карточки слова.
class WordPronunciation extends StatefulWidget {
  const WordPronunciation({
    required this.text,
    required this.speech,
    this.studyLanguage = 'en',
    this.enabled = true,
    super.key,
  });

  static const buttonKey = Key('learning.speak');
  static const messageKey = Key('learning.speech_message');

  final String text;
  final WordSpeech speech;
  final String studyLanguage;
  final bool enabled;

  @override
  State<WordPronunciation> createState() => _WordPronunciationState();
}

class _WordPronunciationState extends State<WordPronunciation>
    with WidgetsBindingObserver {
  int _request = 0;
  bool _speaking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _stop();
    if (_speaking) setState(() => _speaking = false);
  }

  void _stop() {
    _request++;
    unawaited(widget.speech.stop());
  }

  bool _isCurrent(int request) =>
      mounted &&
      widget.enabled &&
      _request == request &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _speak() async {
    final request = ++_request;
    setState(() {
      _speaking = true;
      _message = null;
    });
    await widget.speech.stop();
    if (!_isCurrent(request)) return;
    final result = await widget.speech.speak(widget.text);
    if (!_isCurrent(request)) return;
    setState(() {
      _speaking = false;
      _message = switch (result) {
        SpeechResult.completed || SpeechResult.cancelled => null,
        SpeechResult.unavailable => context.strings.voiceUnavailable(
          widget.studyLanguage,
        ),
        SpeechResult.failed => context.strings.speechFailed,
      };
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _stop();
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: context.strings.pronounce(widget.text),
          child: OutlinedButton(
            key: WordPronunciation.buttonKey,
            onPressed: widget.enabled ? _speak : null,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _speaking
                          ? Icons.graphic_eq_rounded
                          : Icons.volume_up_rounded,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _speaking
                            ? context.strings.listenAgain
                            : context.strings.listen,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_message case final message?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: WordPronunciation.messageKey,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
