# Sources and third-party materials

## Turkish A1–C1

The Turkish words, translations, and answer choices were written for ArcadeLingo. Levels follow the app’s learning sequence. Editorial references include the Turkish Language Association’s [Güncel Türkçe Sözlük](https://sozluk.gov.tr/) and [spelling rules](https://tdk.gov.tr/icerik/yazim-kurallari/duzeltme-isareti/) and the Yunus Emre Institute’s [Yedi İklim Türkçe](https://yee.org.tr/_next/yayinlar/yedi-iklim-turkce-seti) teaching materials.

## Japanese A1–C1

The Japanese words, readings, translations, and answer choices were written for ArcadeLingo. Levels reflect the app's learning sequence. Editorial references include the Japan Foundation's [JF Standard](https://www.jfstandard.jpf.go.jp/summaryen/ja/render.do) and [Marugoto learning materials](https://www.marugoto.jpf.go.jp/en/download/).

Arcade Japanese is derived from [Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp) and renders Japanese script offline. The SIL Open Font License 1.1 is available in the app.

## Korean A1–C1

The Standard South Korean vocabulary, translations, and answer choices were written for ArcadeLingo. Levels follow the app's learning sequence. Editorial references include the [National Institute of Korean Language's Korean Basic Dictionary](https://krdict.korean.go.kr/) and [King Sejong Institute Foundation's learning materials](https://app.ksif.or.kr/eng/index.do).

Arcade Korean is derived from [Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr) and renders Hangul offline. The SIL Open Font License 1.1 is available in the app.

## A1–B2 levels — CEFR-J Wordlist

ArcadeLingo uses the CEFR-J dataset for its A1–B2 English headwords and levels.

> The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Retrieved from http://www.cefr-j.org/download.html

Dataset copy: <https://github.com/openlanguageprofiles/olp-en-cefrj>.

Terms of use:

> CEFR-J vocabulary and grammar profile datasets can be used for research and commercial purposes with no charge, provided that you cite the dataset properly. The copyright belongs to Tono Laboratory at TUFS (Tokyo University of Foreign Studies). Neither CEFR-J nor Open Language Profiles is responsible or liable for any inaccuracies in the dataset or any damage resulting from using the dataset.

## Translations and answer choices

The Russian translations and answer choices were written for ArcadeLingo.

The English A1 course for Spanish speakers uses a selection of the same English headwords. Its Spanish translations and answer choices were written for ArcadeLingo.

## Spanish A1 courses

The two Spanish A1 courses use the same Spanish headwords selected for
ArcadeLingo. The course for English speakers has English translations and
answer choices written for the game.

## C1 and C2 levels — Octanove Labs

English headwords, levels, and parts of speech come from the **Octanove Vocabulary Profile C1/C2 Version 1.0**, Octanove Labs.
Source: <https://github.com/openlanguageprofiles/olp-en-cefrj/blob/d4e45b75b38f27b30dfc5c44d8c571aec7e7092f/octanove-vocabulary-profile-c1c2-1.0.csv>.

ArcadeLingo selected single-word entries, removed duplicates, and added Russian translations and answer choices. The C1 and C2 dictionaries in `assets/words_c1.json` and `assets/words_c2.json` are distributed under **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**: <https://creativecommons.org/licenses/by-sa/4.0/>.

## German A1–C1 courses

The German vocabulary, glosses, and answer choices were selected and written
for ArcadeLingo. Goethe-Institut materials informed the topics and difficulty.
Duden was used to check spelling, articles, and individual senses.

- A1–B1: <https://www.goethe.de/prj/dvt/de/index.html>
- B2 and C1: <https://www.goethe.de/ins/de/de/prf/gzb2.cfm> and
  <https://www.goethe.de/ins/de/de/prf/gzc1.cfm>
- Duden: <https://www.duden.de/woerterbuch>

## Rubik font

- **Authors:** Hubert & Fischer (Philipp Hubert and Sebastian Fischer). Cyreal (Alexei Vanyashin and Nikita Kanarev) revised and extended the Cyrillic glyphs.
- **License:** SIL Open Font License 1.1. The full text is available in `assets/fonts/OFL.txt` and under Full license texts in the app.
- **Source:** <https://github.com/google/fonts/tree/main/ofl/rubik>.
- **File:** `assets/fonts/Rubik-Variable.ttf`, with a weight range of 300–900 and a default of 300. The original variable font file was renamed for compatibility with the asset bundle.

The light theme uses Lora by The Lora Project Authors for headings. The bundled SIL Open Font License 1.1 is in `assets/fonts/Lora-OFL.txt`. Source <https://github.com/google/fonts/tree/main/ofl/lora>.

## French, Chinese and Arabic A1–C1

ArcadeLingo curated these words and their four sets of translations and answer choices. French uses references from the Académie française and France Éducation international. Mandarin uses simplified characters and marked pinyin following GB/T 16159. Arabic uses Modern Standard Arabic. The Chinese and Arabic levels follow ArcadeLingo's learning progression.

References: <https://www.dictionnaire-academie.fr/9e_edition>, <https://www.france-education-international.fr/document/cecrl>, <https://www.moe.gov.cn/jyb_xwfb/gzdt_gzdt/s5987/202103/t20210329_523304.html>, <https://dictionary.ksaa.gov.sa/about>.

Noto Sans Arabic and Arcade Chinese (a subset of Noto Sans SC) render Arabic and Chinese offline. Both fonts are licensed under the SIL Open Font License 1.1, available in the app. Sources: <https://github.com/google/fonts/tree/main/ofl/notosansarabic> and <https://github.com/google/fonts/tree/main/ofl/notosanssc>.

## Ninja Slash sound effects

- **Author:** Kenney (Kenney Vleugels).
- **License:** Creative Commons Zero 1.0 (CC0): <https://creativecommons.org/publicdomain/zero/1.0/>.
- **RPG Audio:** <https://kenney.nl/assets/rpg-audio>. `knifeSlice.ogg` and `knifeSlice2.ogg` became `slice.wav` and `slice_hot.wav`.
- **Interface Sounds:** <https://kenney.nl/assets/interface-sounds>. `drop_004.ogg` and `confirmation_001.ogg` became `miss.wav` and `round_end.wav`.
- **Edits:** The effects were shortened, their levels adjusted, and the files converted to mono PCM WAV. The slash sounds were sped up and the miss sound was softened.

## Material icons

Bundled with the Flutter SDK under the Apache License 2.0.

## Claw Machine sound effects

The three Claw Machine sounds are synthesized by `tool/sound/sound_synth.dart` without external audio samples.
