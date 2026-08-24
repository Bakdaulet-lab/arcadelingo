# Сторонние материалы

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
