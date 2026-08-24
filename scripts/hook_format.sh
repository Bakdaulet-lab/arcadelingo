#!/usr/bin/env bash
# PostToolUse-хук: форматирует только что изменённый dart-файл.
#
# Молчит при успехе. Это важно: вывод хука попадает в контекст, и болтливый
# форматтер на каждый Edit способен сжечь десятки тысяч токенов за сессию.
set -uo pipefail

for f in ${CLAUDE_FILE_PATHS:-}; do
  case "$f" in
    *.g.dart | *.freezed.dart | *.mocks.dart) continue ;;
    *.dart) dart format "$f" >/dev/null 2>&1 || true ;;
  esac
done
exit 0
