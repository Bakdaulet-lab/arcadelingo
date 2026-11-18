# Fuentes y materiales de terceros

## Niveles A1–B2 de inglés

Las palabras en inglés y los niveles A1–B2 de ArcadeLingo proceden de la lista de vocabulario CEFR-J.

> The CEFR-J Wordlist Version 1.5. Compiled by Yukio Tono, Tokyo University of Foreign Studies. Retrieved from http://www.cefr-j.org/download.html

Copia del conjunto de datos en GitHub (<https://github.com/openlanguageprofiles/olp-en-cefrj>).

Condiciones de uso

> CEFR-J vocabulary and grammar profile datasets can be used for research and commercial purposes with no charge, provided that you cite the dataset properly. The copyright belongs to Tono Laboratory at TUFS (Tokyo University of Foreign Studies). Neither CEFR-J nor Open Language Profiles is responsible or liable for any inaccuracies in the dataset or any damage resulting from using the dataset.

## Curso de español A1

Las palabras se seleccionaron para ArcadeLingo. Los temas se revisaron con la descripción del DELE A1 (<https://examenes.cervantes.es/es/dele/examenes/a1>). Para comprobar algunos significados se consultó el Diccionario de la lengua española (<https://dle.rae.es/>).

Los cursos de inglés y español incluyen traducciones al ruso y opciones de respuesta redactadas para el juego.

## Niveles C1 y C2 de inglés

Las palabras en inglés, los niveles y las categorías gramaticales proceden de **Octanove Vocabulary Profile C1/C2 Version 1.0**, de Octanove Labs.
Conjunto de datos original <https://github.com/openlanguageprofiles/olp-en-cefrj/blob/d4e45b75b38f27b30dfc5c44d8c571aec7e7092f/octanove-vocabulary-profile-c1c2-1.0.csv>.

Se seleccionaron entradas de una sola palabra, se eliminaron duplicados y se añadieron las traducciones al ruso y las opciones de respuesta. Los diccionarios `assets/words_c1.json` y `assets/words_c2.json` se distribuyen bajo la licencia **Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)** <https://creativecommons.org/licenses/by-sa/4.0/>.

## Tipografía Rubik

- **Autores.** Hubert & Fischer (Philipp Hubert y Sebastian Fischer). El equipo de Cyreal (Alexei Vanyashin y Nikita Kanarev) revisó y amplió los caracteres cirílicos.
- **Licencia.** SIL Open Font License 1.1. El texto completo está en `assets/fonts/OFL.txt` y en la sección de licencias de la aplicación.
- **Origen.** <https://github.com/google/fonts/tree/main/ofl/rubik>.
- **Archivo.** `assets/fonts/Rubik-Variable.ttf`. Fuente variable con pesos de 300 a 900. El peso predeterminado es 300. Se cambió el nombre del archivo para incluirlo en el paquete de recursos.

## Efectos de sonido de Corte ninja

- **Autor.** Kenney (Kenney Vleugels).
- **Licencia.** Creative Commons Zero 1.0 (CC0) <https://creativecommons.org/publicdomain/zero/1.0/>.
- **RPG Audio.** <https://kenney.nl/assets/rpg-audio>. Los archivos `knifeSlice.ogg` y `knifeSlice2.ogg` se convirtieron en `slice.wav` y `slice_hot.wav`.
- **Interface Sounds.** <https://kenney.nl/assets/interface-sounds>. Los archivos `drop_004.ogg` y `confirmation_001.ogg` se convirtieron en `miss.wav` y `round_end.wav`.
- **Modificaciones.** Los efectos se acortaron, se ajustó el volumen y los archivos se convirtieron a WAV PCM mono. Se aceleraron los sonidos de corte y se suavizó el del fallo.

## Iconos de Material

Se incluyen con el SDK de Flutter bajo la licencia Apache 2.0.

## Efectos de sonido de Máquina de garra

Los tres sonidos se sintetizan en `tool/sound/sound_synth.dart` sin muestras de audio de terceros.
