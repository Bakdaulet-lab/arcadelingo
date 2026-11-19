# Sources and third-party materials

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

## Rubik font

- **Authors:** Hubert & Fischer (Philipp Hubert and Sebastian Fischer). Cyreal (Alexei Vanyashin and Nikita Kanarev) revised and extended the Cyrillic glyphs.
- **License:** SIL Open Font License 1.1. The full text is available in `assets/fonts/OFL.txt` and under Full license texts in the app.
- **Source:** <https://github.com/google/fonts/tree/main/ofl/rubik>.
- **File:** `assets/fonts/Rubik-Variable.ttf`, with a weight range of 300–900 and a default of 300. The original variable font file was renamed for compatibility with the asset bundle.

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
