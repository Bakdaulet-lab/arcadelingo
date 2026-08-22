#!/usr/bin/env bash
# PreToolUse-хук: блокирует запись в сгенерированные файлы.
#
# То же правило есть в CLAUDE.md, но там это просьба. Здесь — закон:
# хук срабатывает всегда, независимо от того, что в контексте.
# Код выхода 2 = блокировать действие, stderr уходит агенту как причина.
set -uo pipefail

for f in ${CLAUDE_FILE_PATHS:-}; do
  case "$f" in
    *.g.dart | *.freezed.dart | *.mocks.dart)
      {
        echo "Блокировано: $f — генерируемый файл."
        echo 'Правь источник (freezed/riverpod/drift-аннотации) и перегенерируй:'
        echo '  dart run build_runner build --delete-conflicting-outputs'
      } >&2
      exit 2
      ;;
  esac
done
exit 0
