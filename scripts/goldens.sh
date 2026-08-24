#!/usr/bin/env bash
# Вторая половина гейта: восемь кадров, зафиксированных картинкой.
#
# Отдельным скриптом, а не третьим режимом verify.sh, по одной причине: строка
# «VERIFY: PASS» обязана означать одно и то же везде. Прогон, пропустивший
# analyze и формат, не имеет права её печатать — а именно её DoD в CLAUDE.md
# просит вставить в ответ как доказательство.
#
# Эталоны существуют ровно для одной платформы: Windows и Linux растрируют
# текст по-разному. Платформа эталонов — Linux, и снимает их CI.
# Процедура приёмки человеком — docs/dev/goldens.md.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

printf '\n=== Голдены (тег golden) ===\n'
if flutter test --tags golden; then
  printf '\nGOLDENS: PASS\n'
  exit 0
fi

# Кандидатов пишет компаратор из test/golden/flutter_test_config.dart, а не
# этот скрипт: --update-goldens в проекте выключен на уровне кода, и эталон
# принимает человек переименованием.
printf '\nGOLDENS: FAIL\n'
printf 'Кандидаты:            test/golden/images/*.new.png\n'
printf 'Попиксельная разница: test/golden/failures/*_isolatedDiff.png\n'
printf 'Эталон принимает человек — docs/dev/goldens.md\n'
exit 1
