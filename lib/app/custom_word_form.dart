import 'package:arcadelingo/domain/ports/custom_words_store.dart';
import 'package:arcadelingo/domain/review/review_contract.dart';
import 'package:arcadelingo/domain/review/study_course.dart';
import 'package:arcadelingo/ui/app_strings.dart';
import 'package:arcadelingo/ui/arcade_page.dart';
import 'package:flutter/material.dart';

class CustomWordForm extends StatefulWidget {
  const CustomWordForm({
    required this.store,
    required this.course,
    required this.level,
    super.key,
  });

  final CustomWordsStore store;
  final StudyCourse course;
  final CefrLevel level;

  @override
  State<CustomWordForm> createState() => _CustomWordFormState();
}

class _CustomWordFormState extends State<CustomWordForm> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _translation = TextEditingController();
  CustomWordSaveResult? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _translation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.store.add(
      level: widget.level,
      text: _text.text.trim(),
      translation: _translation.text.trim(),
    );
    if (!mounted) return;
    if (result == CustomWordSaveResult.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = result;
    });
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final error = switch (_error) {
      CustomWordSaveResult.duplicate => strings.duplicateCustomWord,
      CustomWordSaveResult.invalid => strings.customWordNeedsLetter,
      CustomWordSaveResult.failed => strings.customWordSaveFailed,
      _ => null,
    };
    return PopScope<bool>(
      canPop: !_saving,
      child: ArcadePage(
        title: strings.addWord,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                '${strings.courseName(widget.course)} · ${widget.level.name.toUpperCase()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('customWord.text'),
                controller: _text,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                readOnly: _saving,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.customWordLabel(
                    widget.course.studyLanguage,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _clearError,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? strings.enterWord
                            : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('customWord.translation'),
                controller: _translation,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                readOnly: _saving,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: strings.customTranslationLabel(
                    widget.course.translationLanguage,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _clearError,
                onFieldSubmitted: (_) => _save(),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? strings.enterTranslation
                            : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
