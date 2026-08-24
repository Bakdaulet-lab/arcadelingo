#!/usr/bin/env bash
# Единственный гейт «готово». Definition of Done в CLAUDE.md ссылается сюда.
# Вывод этого скрипта — то доказательство, которое агент обязан приложить к задаче.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

status=0
step() { printf '\n=== %s ===\n' "$1"; }

step 'Архитектурные границы'
if ./scripts/arch_check.sh; then echo 'OK'; else status=1; fi

step 'Форматирование'
if [ -d lib ] || [ -d test ] || [ -d tool ]; then
  targets=()
  [ -d lib ] && targets+=(lib)
  [ -d test ] && targets+=(test)
  # tool/ — тоже наш исходник: flutter analyze его уже проверяет, а форматом
  # он до Трека К просто не был покрыт, потому что каталога не существовало.
  [ -d tool ] && targets+=(tool)
  if dart format --output=none --set-exit-if-changed "${targets[@]}"; then
    echo 'OK'
  else
    echo 'Не отформатировано. Запусти: dart format lib test tool' >&2
    status=1
  fi
else
  echo 'пропущено (нет lib/ и test/)'
fi

step 'Статический анализ'
if flutter analyze; then echo 'OK'; else status=1; fi

step 'Тесты'
if [ -d test ]; then
  if flutter test; then echo 'OK'; else status=1; fi
else
  echo 'ПРОПУЩЕНО: каталога test/ нет. Для непустого проекта это провал.' >&2
  status=1
fi

printf '\n'
if [ "$status" -eq 0 ]; then
  echo 'VERIFY: PASS'
else
  echo 'VERIFY: FAIL'
fi
exit "$status"
