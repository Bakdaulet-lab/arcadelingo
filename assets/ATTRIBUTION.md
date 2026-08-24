# Источники и сторонние материалы

## Уровни слов — CEFR-J Wordlist

Уровень каждого слова (`a1`, `a2`, …) в словаре Wordarcade взят из открытого
набора данных CEFR-J. Цитата, которой требует его лицензия:

> The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Retrieved from http://www.cefr-j.org/download.html

Копия набора, из которой брались уровни:
<https://github.com/openlanguageprofiles/olp-en-cefrj> (проверено 2026-08-24).

Условия использования, дословно:

> CEFR-J vocabulary and grammar profile datasets can be used for research and commercial purposes with no charge, provided that you cite the dataset properly. The copyright belongs to Tono Laboratory at TUFS (Tokyo University of Foreign Studies). Neither CEFR-J nor Open Language Profiles is responsible or liable for any inaccuracies in the dataset or any damage resulting from using the dataset.

Цитата и условия не переносятся по строкам и не переводятся: «cite properly» —
про дословность. Отсюда длинные строки в этом файле, они намеренные.

## Что здесь чьё

Из CEFR-J взяты только английские слова и их уровни. Русские переводы и
варианты ответа — наши: они подобраны и вычитаны вручную, а не переведены
машинно и не взяты из внешнего словаря.

Отказ от ответственности за неточности выше касается уровней. Ошибку в переводе
или в вариантах ответа не списывай на источник — она наша.

## Шрифт Rubik

- **Автор:** Hubert & Fischer (Philipp Hubert, Sebastian Fischer).
  Кириллица переработана и расширена командой Cyreal — Алексей Ваняшин,
  Никита Канарёв.
- **Лицензия:** SIL Open Font License 1.1 — полный текст в
  `assets/fonts/OFL.txt`, он же вшит в приложение и виден в
  `showLicensePage`.
- **Источник:** <https://github.com/google/fonts/tree/main/ofl/rubik>
- **Файл:** `assets/fonts/Rubik-Variable.ttf` — вариативный, ось `wght`
  300…900, по умолчанию 300.
- **Изменения:** содержимое файла не изменялось. Переименован из
  «Rubik[wght].ttf»: `FontManifest.json` хранит путь percent-encoded, а
  ключ ассета остаётся сырым, и загрузка по манифесту падает.

Проверено при подключении (задача 0.12), а не принято на веру с сайта:
таблица `cmap` покрывает А-Я, а-я, Ё, ё, знак умножения, кавычки-ёлочки,
тире и многоточие — всё, что встречается на экранах.

## Иконки Material

Идут из Flutter SDK (`uses-material-design: true`), Apache License 2.0.
