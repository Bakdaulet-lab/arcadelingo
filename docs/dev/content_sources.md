# Источники контента

Правило из `.claude/skills/content-pipeline/SKILL.md`: ничего не попадает в `assets/`,
пока здесь не записаны источник, лицензия дословно, дата проверки и ответ на вопрос
«можно ли коммерчески и в производных работах». Перепроверяй сам — условия меняются.

| Ассет | Источник | Лицензия | Проверено | Коммерческое / производные |
|---|---|---|---|---|
| `assets/words_seed.json`, поля `text` и `level` | CEFR-J Wordlist 1.5, копия <https://github.com/openlanguageprofiles/olp-en-cefrj> | «can be used for research and commercial purposes with no charge, provided that you cite the dataset properly». Копирайт — Tono Laboratory at TUFS | 2026-11-17 | Да / да, при дословном цитировании |
| `assets/words_seed.json`, поля `translation` и `distractors` | Составлены для игры. Для порций 19–127 черновики подготовлены с помощью агента и отредактированы перед сведением. Без выгрузки из внешнего словаря | Не требуется — внешнего источника нет | 2026-11-17 | Да / да |
| `assets/words_c1.json`, `assets/words_c2.json` | [Octanove Vocabulary Profile C1/C2 Version 1.0](https://github.com/openlanguageprofiles/olp-en-cefrj/blob/d4e45b75b38f27b30dfc5c44d8c571aec7e7092f/octanove-vocabulary-profile-c1c2-1.0.csv), Octanove Labs. Русские переводы и варианты порций 128–162 составлены для игры и вычитаны | [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en) | 2026-11-17 | Да / да, с атрибуцией, указанием изменений и сохранением лицензии адаптации |
| `assets/words_es_a1.json` | Самостоятельная подборка общеупотребительных испанских слов. Русские переводы и варианты составлены и вычитаны для ArcadeLingo. Тематика сверена с [DELE A1](https://examenes.cervantes.es/es/dele/examenes/a1), отдельные значения — с [Diccionario de la lengua española](https://dle.rae.es/tarde) (RAE / ASALE). | Внешние данные в ассет не включались | 2026-11-18 | Да / да |
| `assets/words_en_a1_es.json`, поля `text` и `level` | Однословные карточки A1 из `assets/words_seed.json`, основанные на CEFR-J Wordlist 1.5, копия <https://github.com/openlanguageprofiles/olp-en-cefrj> | «can be used for research and commercial purposes with no charge, provided that you cite the dataset properly». Копирайт — Tono Laboratory at TUFS | 2026-11-18 | Да / да, при дословном цитировании |
| `assets/words_en_a1_es.json`, поля `translation` и `distractors` | Испанские переводы и варианты ответов составлены и вычитаны для ArcadeLingo. Отдельные значения сверены с [Cambridge English–Spanish Dictionary](https://dictionary.cambridge.org/dictionary/english-spanish/fish). | Внешние данные в ассет не включались | 2026-11-19 | Да / да |
| `assets/words_es_a1_en.json` | Испанские слова и уровни взяты из нашей подборки `assets/words_es_a1.json`. Английские переводы и варианты ответов составлены и вычитаны для ArcadeLingo. Отдельные значения сверены с [Cambridge Spanish–English Dictionary](https://dictionary.cambridge.org/es/diccionario/espanol-ingles/billete). | Внешние данные в ассет не включались | 2026-11-19 | Да / да |
| `assets/words_es_a2.json`, `assets/words_es_a2_en.json` | Самостоятельная подборка из 120 слов. Темы сверены с [DELE A2](https://examenes.cervantes.es/es/dele/examenes/a2). Русские и английские переводы и варианты составлены и вычитаны для ArcadeLingo. Отдельные значения сверены со статьями Cambridge для [andén](https://dictionary.cambridge.org/es/diccionario/espanol-ingles/anden), [ración](https://dictionary.cambridge.org/es/diccionario/espanol-ingles/racion), [cita](https://dictionary.cambridge.org/es/diccionario/espanol-ingles/cita) и [ensayo](https://dictionary.cambridge.org/es/diccionario/espanol-ingles/ensayo). | Внешние словники, определения и примеры в ассеты не включались | 2026-11-20 | Да / да |
| `assets/fonts/Lora-Variable.ttf` | [Lora, The Lora Project Authors](https://github.com/google/fonts/tree/main/ofl/lora). Исходный шрифт с осью веса, файл переименован для бандла. | SIL Open Font License 1.1, полный текст с копирайтом в `assets/fonts/Lora-OFL.txt` | 2026-11-19 | Да / да, с условиями OFL |
| `assets/ATTRIBUTION.md` | Дословные цитата и условия CEFR-J, сведения об Octanove и других источниках | — | 2026-11-17 | Да / да |

Цитата обязана быть **в продукте**, а не только в репозитории: «cite properly» адресован
пользователю, а репозитория он не видит. Поэтому `assets/ATTRIBUTION.md` зарегистрирован
как ассет. Его показывает экран «Источники», а тест атрибуции загружает через
`rootBundle` и проверяет цитаты, авторство и лицензию.

Сам CSV источника в репозитории **не лежит**: условия требуют цитирования, а не
перепубликации, и мегабайт чужих данных в истории ничего нам не даёт. Импортёр
`tool/import_cefrj.dart` берёт путь к файлу аргументом — качать по ссылке из таблицы.

## Данные C1 и C2

C1 и C2 поставляются отдельными `assets/words_c1.json` и `assets/words_c2.json`
с соответствующими уведомлениями `.LICENSE.md`. Приложение объединяет карточки
в памяти. Редакционные записи хранятся в `tool/c1/` и `tool/c2/`. В выборки
вошли однословные существительные, глаголы, прилагательные и наречия после
исключения принятых и отклонённых слов с предыдущих уровней.

## Ожидает решения

- **Частотность.** CEFR-J её не содержит вовсе, а `level` — это две градации, а не ранг.
  Правило дистракторов №2 из скилла (±20% по рангу) на нём не работает, и сильнее всего
  это бьёт по существительным: у них стратегия «категория + близкая частотность», и они же
  62% импорта. Кандидаты — NGSL и частотные списки Wiktionary — оба CC BY-SA, то есть та же
  вирусность, что у Octanove. Искать источник **без ShareAlike** либо решать вопрос SA для
  всего `words_seed.json` до подмешивания, а не после
