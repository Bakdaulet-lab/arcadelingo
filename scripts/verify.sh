#!/usr/bin/env bash
# Единственный гейт «готово». Definition of Done в CLAUDE.md ссылается сюда.
# Вывод этого скрипта — то доказательство, которое агент обязан приложить к задаче.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Голдены сняты на одной платформе и только на ней зелёные: Windows и Linux
# растрируют текст по-разному. Платформа эталонов — Linux (docs/dev/goldens.md),
# поэтому гейт делится надвое, и обе половины называют себя в выводе. Это не
# косметика: DoD в CLAUDE.md просит вставить этот вывод как доказательство, и
# доказательство не имеет права умалчивать, какая половина отработала.
#
#   all (по умолчанию) — всё, включая восемь кадров
#   off                — всё, кроме кадров; вторую половину даёт scripts/goldens.sh
#
# Канарейки шрифтов тегом не помечены и идут в обоих режимах: их работа —
# сказать «в этом окружении Rubik не приехал», и на чужой машине она нужнее.
goldens="${WORDARCADE_GOLDENS:-all}"
case "$goldens" in
  all)
    goldens_note='голдены: проверены'
    ;;
  off)
    goldens_note='голдены: пропущены, вторая половина — scripts/goldens.sh'
    ;;
  *)
    echo "WORDARCADE_GOLDENS=$goldens — неизвестный режим, допустимы all и off" >&2
    echo 'Молча свалиться в all нельзя: опечатка сделала бы вывод враньём.' >&2
    exit 2
    ;;
esac

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

step "Тесты ($goldens_note)"
if [ -d test ]; then
  if [ "$goldens" = 'off' ]; then
    run_tests() { flutter test --exclude-tags golden; }
  else
    run_tests() { flutter test; }
  fi
  if run_tests; then echo 'OK'; else status=1; fi
else
  echo 'ПРОПУЩЕНО: каталога test/ нет. Для непустого проекта это провал.' >&2
  status=1
fi

printf '\n'
if [ "$status" -eq 0 ]; then
  echo "VERIFY: PASS ($goldens_note)"
else
  echo "VERIFY: FAIL ($goldens_note)"
fi
exit "$status"
