#!/usr/bin/env bash
# Архитектурные границы как исполняемая гарантия, а не пожелание в CLAUDE.md.
# Быстрый (~1 сек) и тихий при успехе — годится и для Stop-хука, и для CI.
#
# Правила, которые он стережёт, описаны в CLAUDE.md → «Архитектурный закон».
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0

check() {
  local label="$1" dir="$2" pattern="$3"
  [ -d "$dir" ] || return 0
  local hits
  # Второй grep отбрасывает строки, где сразу после «путь:номер:» идёт //, *
  # или /* — то есть само правило, описанное словами в комментарии или доке,
  # больше не считается его нарушением. Код с хвостовым комментарием
  # (`final x = DateTime.now(); // ...`) при этом ловится: до // идёт код.
  hits=$(grep -rnE --include='*.dart' "$pattern" "$dir" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)
  if [ -n "$hits" ]; then
    printf 'ARCH VIOLATION — %s\n%s\n\n' "$label" "$hits" >&2
    fail=1
  fi
}

# 1. domain/ ничего не знает про Flutter, data/ и features/
check 'lib/domain/ импортирует Flutter' \
  lib/domain "^[[:space:]]*import[[:space:]]+'package:flutter/"
# `ui` в списке с 3.5: домен собирал текст напоминания и утащил в импорт
# `lib/ui/streak_label.dart` — русский счёт дней. Правило «домен не знает
# презентацию» было в CLAUDE.md словами, а гейт ловил только data и features.
check 'lib/domain/ импортирует data/, features/ или ui/' \
  lib/domain "^[[:space:]]*import[[:space:]]+'.*(data|features|ui)/"
# Сторонних пакетов в domain нет вовсе, и до Этапа 2.3 это держалось само
# собой: импортировать было нечего. С приходом drift правило перестало быть
# даровым — порт AnswerLog обязан остаться интерфейсом, а БД жить в data/,
# и расстояние между этими двумя состояниями ровно одна строка импорта.
# Строже, чем «не Flutter»: package:meta и package:collection тоже мимо.
# Понадобится — снимать осознанно, а не обнаружить постфактум.
#
# Своим grep, а не через check: исключение «кроме своего пакета» — это
# второй шаблон, а ERE отрицательного просмотра вперёд не знает.
domain_foreign=$(grep -rnE --include='*.dart'   "^[[:space:]]*import[[:space:]]+'package:" lib/domain 2>/dev/null   | grep -v "'package:arcadelingo/" || true)
if [ -n "$domain_foreign" ]; then
  printf 'ARCH VIOLATION — %s
%s

'     'lib/domain/ импортирует сторонний пакет (можно только dart: и себя)'     "$domain_foreign" >&2
  fail=1
fi

# 2. Игра — оболочка. Логика планирования повторов в неё не просачивается.
check 'игра импортирует domain/srs напрямую (должна работать через ReviewSession)' \
  lib/features/games "^[[:space:]]*import[[:space:]]+'.*domain/srs"

# 3. domain детерминирован: ни часов, ни несидированного рандома. Время приходит
#    параметром now — с 0.6 это нужно и сессии, не только srs.
check 'domain/ вызывает DateTime.now() — время должно приходить параметром now' \
  lib/domain 'DateTime\.now\(\)'
# Random.secure() тоже недетерминирован, а под старый паттерн не попадал.
# Random(42) проходит намеренно: сидированный генератор воспроизводим.
check 'domain/ использует Random без seed' \
  lib/domain 'Random\.secure\(|Random\([[:space:]]*\)'

# 4. Направление зависимостей. До Фазы 2 это был единственный пункт закона,
#    который жил только словами в CLAUDE.md: презентация ходит в хранилище
#    через порт, фича не знает композиционного корня, данные — лист графа.
#    Шаблон '[^']*/data/' требует слэша перед именем каталога: без него
#    правило ловило бы и domain/metadata/, если такой появится.
check 'lib/features/ импортирует lib/data/ — хранилище приходит портом, а не напрямую'   lib/features "^[[:space:]]*import[[:space:]]+'[^']*/data/"
check 'lib/features/ импортирует lib/app/ — фича не знает композиционного корня'   lib/features "^[[:space:]]*import[[:space:]]+'[^']*/app/"
check 'lib/data/ импортирует lib/features/ или lib/app/ — данные это лист графа'   lib/data "^[[:space:]]*import[[:space:]]+'[^']*/(features|app)/"
check 'lib/ui/ импортирует data/, features/ или app/ — общая презентация ничего о них не знает'   lib/ui "^[[:space:]]*import[[:space:]]+'[^']*/(data|features|app)/"

# 5. Игры — острова. Общий код двух игр — это либо контракт в domain, либо
#    презентация в lib/ui, но не сосед по каталогу: игра, знающая о другой
#    игре, перестаёт быть модулем, который подключают через ReviewSession.
#
#    Правило вакуумно, пока игра одна, и станет настоящим на второй. Проверять
#    его мутацией надо соответственно: завести вторую папку с импортом первой.
if [ -d lib/features/games ]; then
  for game_dir in lib/features/games/*/; do
    [ -d "$game_dir" ] || continue
    game=$(basename "$game_dir")
    for other_dir in lib/features/games/*/; do
      [ -d "$other_dir" ] || continue
      other=$(basename "$other_dir")
      [ "$game" = "$other" ] && continue
      check "игра $game импортирует игру $other"         "$game_dir" "^[[:space:]]*import[[:space:]]+'[^']*$other/"
    done
  done
fi

if [ "$fail" -ne 0 ]; then
  echo 'Архитектурный гейт не пройден. Правила: CLAUDE.md → «Архитектурный закон».' >&2
  exit 1
fi
exit 0
