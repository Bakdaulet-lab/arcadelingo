# Источники и сторонние материалы

## Уровни слов — CEFR-J Wordlist

Уровни A1–B2 в словаре Arcadelingo взяты из открытого набора данных CEFR-J.
Цитата, которой требует его лицензия:

> The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Retrieved from http://www.cefr-j.org/download.html

Копия набора, из которой брались уровни:
<https://github.com/openlanguageprofiles/olp-en-cefrj> (проверено 2026-08-24).

Условия использования, дословно:

> CEFR-J vocabulary and grammar profile datasets can be used for research and commercial purposes with no charge, provided that you cite the dataset properly. The copyright belongs to Tono Laboratory at TUFS (Tokyo University of Foreign Studies). Neither CEFR-J nor Open Language Profiles is responsible or liable for any inaccuracies in the dataset or any damage resulting from using the dataset.

Цитата и условия не переносятся по строкам и не переводятся: «cite properly» —
про дословность. Отсюда длинные строки в этом файле, они намеренные.

## Что здесь чьё

Из CEFR-J взяты только английские слова и их уровни. Русские переводы и
варианты ответа составлены специально для игры, без выгрузки из внешнего
словаря.

Курс «Испанский → английский A1» использует часть тех же английских слов.
Испанские переводы и варианты ответов составлены для ArcadeLingo.

Отказ от ответственности за неточности выше касается уровней. Ошибку в переводе
или в вариантах ответа не списывай на источник — она наша.

## Курсы испанского A1

Испанские слова для обоих курсов A1 отобраны для ArcadeLingo. В курсе
«Английский → испанский A1» для этих слов составлены английские переводы
и варианты ответов.

## Уровни C1 и C2 — Octanove Labs

Английские слова, уровни и части речи взяты из **Octanove Vocabulary Profile
C1/C2 Version 1.0**, Octanove Labs. Исходный набор:
<https://github.com/openlanguageprofiles/olp-en-cefrj/blob/d4e45b75b38f27b30dfc5c44d8c571aec7e7092f/octanove-vocabulary-profile-c1c2-1.0.csv>.

Мы отобрали однословные карточки C1 и C2, устранили повторы и добавили русские
переводы и варианты ответов. Словари `assets/words_c1.json` и `assets/words_c2.json`
распространяются по **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**:
<https://creativecommons.org/licenses/by-sa/4.0/>.

## Курсы с казахского A1–C1

Казахские переводы и варианты ответов составлены для ArcadeLingo. Английская
и русская подборки составлены по темам и навыкам уровней A1–C1. Для испанского
использованы уровни слов из существующих испанских курсов ArcadeLingo.

- Ориентиры по уровням — [шкала CEFR Совета Европы](https://www.coe.int/en/web/common-european-framework-reference-languages/table-1-cefr-3.3-common-reference-levels-global-scale),
  [план Института Сервантеса](https://cvc.cervantes.es/ensenanza/biblioteca_ele/plan_curricular/indice.htm)
  и [уровни ТРКИ](https://bgu.ru/rki/default.aspx).
- Для сверки значений и написания использованы [Oxford Learner’s Dictionaries](https://www.oxfordlearnersdictionaries.com/about/wordlists/oxford3000-5000),
  [Diccionario de la lengua española](https://dle.rae.es/),
  [Emle](https://emle.kz/), [Сөздікқор](https://sozdikqor.kz/)
  и [Termincom](https://termincom.kz/).

## Немецкий язык A1–C1

Слова и выражения отобраны для ArcadeLingo. Переводы и варианты ответов
составлены для русского, английского, испанского и казахского курсов.
Для выбора тем и сложности использованы материалы Goethe-Institut.
Написание, артикли и спорные значения сверены по Duden.

- Уровни A1–B1: <https://www.goethe.de/prj/dvt/de/index.html>
- Уровни B2 и C1: <https://www.goethe.de/ins/de/de/prf/gzb2.cfm> и
  <https://www.goethe.de/ins/de/de/prf/gzc1.cfm>
- Duden: <https://www.duden.de/woerterbuch>

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

Шрифт Lora используется в заголовках светлой темы. Авторы — The Lora Project Authors. Лицензия SIL Open Font License 1.1 входит в приложение в файле `assets/fonts/Lora-OFL.txt`. Источник <https://github.com/google/fonts/tree/main/ofl/lora>.

## Французский, китайский и арабский A1–C1

Словари и варианты ответов составлены для ArcadeLingo на четырёх языках перевода. Французский проверен по словарю Académie française и материалам France Éducation international. Для китайского использованы упрощённые иероглифы и пиньинь с тонами по стандарту GB/T 16159. Арабский курс использует современный литературный арабский. Для уровней китайского и арабского использована учебная последовательность ArcadeLingo.

Источники: <https://www.dictionnaire-academie.fr/9e_edition>, <https://www.france-education-international.fr/document/cecrl>, <https://www.moe.gov.cn/jyb_xwfb/gzdt_gzdt/s5987/202103/t20210329_523304.html>, <https://dictionary.ksaa.gov.sa/about>.

Noto Sans Arabic и Arcade Chinese (подмножество Noto Sans SC) обеспечивают отображение арабского письма и китайских иероглифов офлайн. Оба шрифта распространяются под SIL Open Font License 1.1, тексты лицензий доступны в приложении. Исходные файлы: <https://github.com/google/fonts/tree/main/ofl/notosansarabic> и <https://github.com/google/fonts/tree/main/ofl/notosanssc>.

## Корейский язык A1–C1

Словарь стандартного южнокорейского языка, переводы и варианты ответов составлены для ArcadeLingo. Уровни отражают учебную последовательность приложения. Справочные материалы — [Корейский базовый словарь Национального института корейского языка](https://krdict.korean.go.kr/) и [учебные материалы Фонда короля Седжона](https://app.ksif.or.kr/eng/index.do).

Arcade Korean создан на основе [Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr) и позволяет отображать хангыль без интернета. Лицензия SIL Open Font License 1.1 доступна в приложении.

## Японский язык A1–C1

Словарь, чтения, переводы и варианты ответов составлены для ArcadeLingo. Разбивка отражает учебную последовательность приложения. При вычитке использовались [JF Standard](https://www.jfstandard.jpf.go.jp/summaryen/ja/render.do) и [учебные материалы Marugoto](https://www.marugoto.jpf.go.jp/en/download/) Японского фонда.

Arcade Japanese создан на основе [Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp) и отображает японское письмо без интернета. Лицензия SIL Open Font License 1.1 доступна в приложении.

## Турецкий язык A1–C1

Словарь, переводы и варианты ответов составлены для ArcadeLingo. Уровни отражают учебную последовательность приложения. Справочные материалы — [Güncel Türkçe Sözlük](https://sozluk.gov.tr/) и [правила орфографии](https://tdk.gov.tr/icerik/yazim-kurallari/duzeltme-isareti/) Института турецкого языка, а также [Yedi İklim Türkçe](https://yee.org.tr/_next/yayinlar/yedi-iklim-turkce-seti) Института Юнуса Эмре.

## Звуковые эффекты «Ниндзя-слэша»

- **Автор:** Kenney (Kenney Vleugels).
- **Лицензия:** Creative Commons Zero 1.0 (CC0) —
  <https://creativecommons.org/publicdomain/zero/1.0/>.
- **RPG Audio:** <https://kenney.nl/assets/rpg-audio>. `knifeSlice.ogg`
  → `slice.wav`, `knifeSlice2.ogg` → `slice_hot.wav`.
- **Interface Sounds:** <https://kenney.nl/assets/interface-sounds>.
  `drop_004.ogg` → `miss.wav`, `confirmation_001.ogg` → `round_end.wav`.
- **Обработка:** резы укорочены и ускорены, удар укорочен и приглушён;
  уровни скорректированы, все эффекты переведены в моно PCM WAV.

## Иконки Material

Идут из Flutter SDK (`uses-material-design: true`), Apache License 2.0.

## Звуковые эффекты «Автомата с клешнёй»

Короткие звуки `claw_catch.wav`, `claw_miss.wav` и `claw_word.wav`
синтезируются в `tool/sound/sound_synth.dart` без внешних сэмплов.
