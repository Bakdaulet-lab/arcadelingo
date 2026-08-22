// Проверка формы и инвариантов сида слов.
//
// Качество обманок (не синоним, не однокоренное) тест не ловит — это ручная
// вычитка. Здесь только то, что можно проверить механически.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetPath = 'assets/words_seed.json';
const _partsOfSpeech = {'noun', 'verb', 'adj', 'adv'};

final _cyrillic = RegExp(r'^[а-яё][а-яё -]*$');
final _latin = RegExp(r'^[a-z]+$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> root;
  late List<Map<String, dynamic>> words;

  // rootBundle, а не dart:io: заодно проверяет регистрацию ассета в pubspec.yaml.
  setUpAll(() async {
    final raw = await rootBundle.loadString(_assetPath);
    root = jsonDecode(raw) as Map<String, dynamic>;
    words = (root['words'] as List).cast<Map<String, dynamic>>();
  });

  test('корень: version 1, en → ru', () {
    expect(root['version'], 1);
    expect(root['source_lang'], 'en');
    expect(root['target_lang'], 'ru');
  });

  test('ровно 50 слов', () {
    // Жёсткость намеренная: сид — калибровочный набор фиксированного размера.
    // Добавил слова — осознанно поправь число здесь.
    expect(words, hasLength(50));
  });

  test('id и text уникальны', () {
    final ids = words.map((w) => w['id']).toSet();
    final texts = words.map((w) => w['text']).toSet();
    expect(ids, hasLength(words.length), reason: 'дубли id');
    expect(texts, hasLength(words.length), reason: 'дубли text');
  });

  test('id, text, translation непустые; id == text в нижнем регистре', () {
    for (final w in words) {
      final id = w['id'];
      final text = w['text'];
      final translation = w['translation'];
      expect(id, isA<String>().having((s) => s.isNotEmpty, 'непустой', true));
      expect(text, isA<String>().having((s) => s.isNotEmpty, 'непустой', true));
      expect(
        translation,
        isA<String>().having((s) => s.isNotEmpty, 'непустой', true),
        reason: 'слово $id',
      );
      expect(id, (text as String).toLowerCase(), reason: 'слово $id');
    }
  });

  test('part_of_speech из закрытого набора', () {
    for (final w in words) {
      expect(
        _partsOfSpeech,
        contains(w['part_of_speech']),
        reason: 'слово ${w['id']}',
      );
    }
  });

  test('ровно три дистрактора, уникальны, не равны переводу', () {
    String norm(Object? s) => (s as String).trim().toLowerCase();

    for (final w in words) {
      final id = w['id'];
      final distractors = (w['distractors'] as List).cast<String>();
      expect(distractors, hasLength(3), reason: 'слово $id');
      expect(
        distractors.every((d) => d.trim().isNotEmpty),
        isTrue,
        reason: 'слово $id: пустой дистрактор',
      );
      expect(
        distractors.map(norm).toSet(),
        hasLength(3),
        reason: 'слово $id: дистракторы повторяются',
      );
      expect(
        distractors.map(norm),
        isNot(contains(norm(w['translation']))),
        reason: 'слово $id: дистрактор совпадает с переводом',
      );
    }
  });

  test('перевод и дистракторы — кириллица, text — латиница', () {
    for (final w in words) {
      final id = w['id'];
      expect(w['text'], matches(_latin), reason: 'слово $id: text');
      expect(
        w['translation'],
        matches(_cyrillic),
        reason: 'слово $id: translation',
      );
      for (final d in (w['distractors'] as List).cast<String>()) {
        expect(d, matches(_cyrillic), reason: 'слово $id: дистрактор "$d"');
      }
    }
  });
}
