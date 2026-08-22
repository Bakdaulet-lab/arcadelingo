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
  hits=$(grep -rnE --include='*.dart' "$pattern" "$dir" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    printf 'ARCH VIOLATION — %s\n%s\n\n' "$label" "$hits" >&2
    fail=1
  fi
}

# 1. domain/ ничего не знает про Flutter, data/ и features/
check 'lib/domain/ импортирует Flutter' \
  lib/domain "^[[:space:]]*import[[:space:]]+'package:flutter/"
check 'lib/domain/ импортирует data/ или features/' \
  lib/domain "^[[:space:]]*import[[:space:]]+'.*(data|features)/"

# 2. Игра — оболочка. Логика планирования повторов в неё не просачивается.
check 'игра импортирует domain/srs напрямую (должна работать через ReviewSession)' \
  lib/features/games "^[[:space:]]*import[[:space:]]+'.*domain/srs"

# 3. SRS детерминирован: без обращения к часам и без несидированного рандома.
check 'domain/srs вызывает DateTime.now() — время должно приходить параметром now' \
  lib/domain/srs 'DateTime\.now\(\)'
check 'domain/srs использует Random без seed' \
  lib/domain/srs 'Random\([[:space:]]*\)'

if [ "$fail" -ne 0 ]; then
  echo 'Архитектурный гейт не пройден. Правила: CLAUDE.md → «Архитектурный закон».' >&2
  exit 1
fi
exit 0
