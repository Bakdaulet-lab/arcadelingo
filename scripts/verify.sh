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
#   off (по умолчанию) — всё, кроме восьми кадров
#   all                — вместе с кадрами; осмысленно только на Linux
#
# Умолчание именно off, и это не удобство, а измеренный факт: эталоны сняты на
# Linux, и на Windows все восемь кадров расходятся с ними попиксельно. Прогон в
# режиме all на Windows красный не потому, что что-то сломано, — а такая
# краснота за неделю приучает не смотреть на красное. Вторую половину гейта
# держит CI (scripts/goldens.sh), и там она блокирующая.
#
# Канарейки шрифтов тегом не помечены и идут в обоих режимах: их работа —
# сказать «в этом окружении Rubik не приехал», и на чужой машине она нужнее.
goldens="${WORDARCADE_GOLDENS:-off}"
case "$goldens" in
  all)
    # Страж платформы. На не-Linux кадры отрисуются, разойдутся с эталонами и
    # положат рядом .new.png — файлы, неотличимые с виду от настоящих
    # кандидатов. Принять такой «кандидат» руками по docs/dev/goldens.md — и
    # эталоны молча станут windows-овыми. Дешевле отказаться.
    if [ "$(uname -s)" != 'Linux' ]; then
      echo "WORDARCADE_GOLDENS=all на $(uname -s): кадры заведомо разойдутся," >&2
      echo 'а рядом с эталонами лягут кандидаты, которые нельзя принимать.' >&2
      echo 'Эталоны сняты на Linux — docs/dev/goldens.md.' >&2
      echo 'Быстрая петля из-под Windows: ./scripts/goldens_wsl.sh' >&2
      exit 2
    fi
    goldens_note='голдены: проверены здесь'
    ;;
  off)
    goldens_note='голдены: пропущены — эталоны Linux, их сторожит CI'
    ;;
  *)
    echo "WORDARCADE_GOLDENS=$goldens — неизвестный режим, допустимы all и off" >&2
    echo 'Молча свалиться в умолчание нельзя: опечатка сделала бы вывод враньём.' >&2
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
  # Снималка экранов (test/peek/) отсекается в обоих режимах и всегда: она
  # ничего не проверяет и всегда зелёная, а зелёный навсегда шаг внутри гейта
  # — это враньё про покрытие. Исключение живёт здесь, а не в dart_test.yaml,
  # по измеренной причине: там оно победило бы и явный `--tags peek`, то есть
  # сломало бы ручную съёмку. Подробности — в самом dart_test.yaml.
  if [ "$goldens" = 'off' ]; then
    run_tests() { flutter test --exclude-tags 'golden || peek'; }
  else
    run_tests() { flutter test --exclude-tags peek; }
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
