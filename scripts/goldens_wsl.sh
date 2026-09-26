#!/usr/bin/env bash
# Быстрая локальная петля для голденов: те же восемь кадров в WSL2.
#
# Зачем. Эталоны сняты на Linux, и на Windows все восемь расходятся — значит
# единственным источником кандидатов оставался артефакт красного прогона CI:
# запушил, подождал, скачал, посмотрел. Для правки вёрстки это дорого.
#
# Измерено 2026-08-25 на этой машине: WSL2 Ubuntu 24.04 + Flutter 3.29.2 из
# официального архива даёт кадры, совпадающие с раннером GitHub **байт-в-байт**,
# 8 из 8. Поэтому локальная петля возможна и не является приблизительной.
#
# Судьёй остаётся CI. Зелёный здесь — предсказание, а не вердикт: этот скрипт
# ничего не принимает, ничего не пишет в эталоны и не входит ни в один гейт.
# Худшее, что он может, — соврать красным (чужой SDK, другой дистрибутив);
# соврать зелёным он не может, потому что зелёный тут и означает совпадение
# байтов с той сборкой, которую запускает CI.
#
# Запуск из Git Bash в корне репозитория:
#
#   ./scripts/goldens_wsl.sh
#
# Кандидаты и попиксельная разница возвращаются в рабочую копию, дальше —
# обычная процедура приёмки человеком из docs/dev/goldens.md.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Git Bash переводит POSIX-пути в аргументах нативных .exe в windows-овые:
# /opt/flutter/bin/flutter уезжал в «C:/Program Files/Git/opt/flutter/...», и
# wsl.exe получал несуществующий путь. Здесь все пути в аргументах —
# линуксовые и переводить их не надо.
export MSYS_NO_PATHCONV=1

DISTRO="${WORDARCADE_WSL_DISTRO:-Ubuntu-24.04}"
FLUTTER_DIR="${WORDARCADE_WSL_FLUTTER:-/opt/flutter}"
WORK="${WORDARCADE_WSL_WORKDIR:-/root/wordarcade-goldens}"

die() { printf '%s\n' "$@" >&2; exit 2; }

# --- 1. WSL вообще есть? -----------------------------------------------------

command -v wsl.exe >/dev/null 2>&1 || die \
  'wsl.exe не найден: это не Windows либо WSL не установлен.' \
  'На Linux голдены гоняются напрямую: ./scripts/goldens.sh'

# Вывод wsl.exe — UTF-16LE, отсюда tr -d "\0" во всех местах, где он читается.
if ! wsl.exe -l -q 2>/dev/null | tr -d '\0' | tr -d '\r' | grep -qx "$DISTRO"; then
  die \
    "Дистрибутив $DISTRO в WSL не найден." \
    '' \
    'Установка (PowerShell или Git Bash, один раз, ~1.5 ГБ):' \
    '' \
    "  wsl.exe --install $DISTRO --no-launch" \
    '' \
    'Затем зависимости и Flutter внутри него:' \
    '' \
    "  wsl.exe -d $DISTRO -u root -- bash -c 'apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa'" \
    "  wsl.exe -d $DISTRO -u root -- bash -c 'curl -fsSL -o /tmp/f.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_<версия>-stable.tar.xz && tar -xf /tmp/f.tar.xz -C /opt'" \
    '' \
    "Версию подставь ту, что стоит в .github/workflows/verify.yml (FLUTTER_VERSION)." \
    'Другой дистрибутив или путь — переменные WORDARCADE_WSL_DISTRO и WORDARCADE_WSL_FLUTTER.'
fi

# --- 2. Версия Flutter — из workflow, а не из этого файла --------------------

# Единственный источник правды о версии — тот же файл, который читает CI.
# Иначе подъём версии на CI молча рассинхронил бы локальную петлю, и она
# начала бы предсказывать не тот рендер, оставаясь зелёной.
WANT=$(sed -n "s/^ *FLUTTER_VERSION: *['\"]\{0,1\}\([0-9.]*\)['\"]\{0,1\} *$/\1/p" \
  .github/workflows/verify.yml | head -1)
[ -n "$WANT" ] || die \
  'Не смог прочитать FLUTTER_VERSION из .github/workflows/verify.yml.' \
  'Петля обязана брать версию оттуда: своя копия числа разъедется с CI.'

echo "версия из workflow: $WANT"

# Абсолютным путём, а не через PATH. WSL по умолчанию подмешивает в PATH
# windows-овые каталоги, и в них есть «Program Files (x86)»: присваивание
# PATH=... перед командой роняло разбор на скобке.
GOT=$(wsl.exe -d "$DISTRO" -u root -- "$FLUTTER_DIR/bin/flutter" --version \
  2>/dev/null | tr -d '\0' | tr -d '\r' \
  | sed -n 's/^Flutter \([0-9.]*\) .*/\1/p' | head -1)

[ -n "$GOT" ] || die \
  "В $DISTRO нет рабочего flutter по пути $FLUTTER_DIR/bin." \
  'Установка — см. сообщение выше про дистрибутив, шаг с tar.'

if [ "$GOT" != "$WANT" ]; then
  die \
    "Версия Flutter в WSL — $GOT, а CI снимает эталоны на $WANT." \
    'Это и есть канарейка этого скрипта: на чужом SDK кадры разойдутся,' \
    'и зелёный локальный прогон стал бы враньём про то, что покажет CI.' \
    '' \
    "Поставь $WANT в $FLUTTER_DIR либо укажи другой путь в WORDARCADE_WSL_FLUTTER."
fi

wsl.exe -d "$DISTRO" -u root -- "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null \
  | tr -d '\0' | tr -d '\r' | sed -n '2,3p'

# --- 3. Рабочее дерево в ext4 ------------------------------------------------

# Не /mnt/c: там и медленно (9p), и .dart_tool/package_config.json начнёт
# перетягиваться между Windows- и Linux-Flutter — у них разные пути к SDK.
#
# Синхронизируется рабочее дерево, а не коммит: петля нужна ровно тогда, когда
# правка ещё не закоммичена.
if ! wsl.exe -d "$DISTRO" -u root -- bash -c 'command -v rsync' >/dev/null 2>&1; then
  die \
    "В $DISTRO нет rsync." \
    "  wsl.exe -d $DISTRO -u root -- bash -c 'apt-get update && apt-get install -y rsync'"
fi

HERE=$(wsl.exe -d "$DISTRO" -u root -- wslpath -a "$(pwd -W 2>/dev/null || pwd)" \
  | tr -d '\0' | tr -d '\r')
[ -n "$HERE" ] || die 'Не смог перевести путь репозитория в WSL-путь.'

echo "синхронизирую $HERE -> $WORK"
wsl.exe -d "$DISTRO" -u root -- bash -s <<WSLEOF | tr -d '\0'
set -e
mkdir -p '$WORK'
rsync -a --delete \
  --exclude '.git/' --exclude '.dart_tool/' --exclude 'build/' \
  --exclude 'test/peek/out/' --exclude 'test/golden/failures/' \
  --exclude '*.new.png' \
  '$HERE/' '$WORK/'
cd '$WORK'
# Кавычки вокруг значения обязательны: WSL подмешивает в PATH windows-овые
# каталоги, среди них «Program Files (x86)», и без кавычек скобка роняет разбор.
export PATH="$FLUTTER_DIR/bin:\$PATH"
# Кандидаты прошлого прогона — долой до старта. rsync их не трогает
# (exclude выше), а копирование обратно берёт все *.new.png подряд: тест,
# упавший раньше компаратора, кандидата не пишет, и на его место приезжал
# бы старый — с датой этой минуты и содержимым прошлого прогона. Так и
# случилось на переделке 4.3 (docs/dev/context.md).
rm -f test/golden/images/*.new.png
'$FLUTTER_DIR/bin/flutter' pub get > /tmp/wordarcade_pubget.log 2>&1 \
  || { tail -20 /tmp/wordarcade_pubget.log; exit 1; }
./scripts/goldens.sh
WSLEOF
rc=${PIPESTATUS[0]}

# --- 4. Кандидаты обратно в рабочую копию ------------------------------------

# Чтобы docs/dev/goldens.md работал дословно: человек смотрит .new.png рядом с
# эталоном и переименовывает руками. Скрипт не переименовывает ничего.
echo
echo 'забираю кандидатов и попиксельную разницу'
wsl.exe -d "$DISTRO" -u root -- bash -s <<WSLEOF | tr -d '\0'
set -e
cd '$WORK'
mkdir -p '$HERE/test/golden/failures'
cp -f test/golden/images/*.new.png '$HERE/test/golden/images/' 2>/dev/null || true
cp -rf test/golden/failures/. '$HERE/test/golden/failures/' 2>/dev/null || true
WSLEOF

candidates=$(ls test/golden/images/*.new.png 2>/dev/null | wc -l | tr -d ' ')

echo
if [ "$rc" -eq 0 ]; then
  echo 'WSL-ГОЛДЕНЫ: PASS — кадры совпали с эталонами'
  echo 'Это предсказание того, что покажет CI. Судья — CI.'
else
  echo "WSL-ГОЛДЕНЫ: FAIL — кандидатов в рабочей копии: $candidates"
  echo 'Смотреть: test/golden/images/*.new.png'
  echo '          test/golden/failures/*_isolatedDiff.png'
  echo 'Принимает эталон человек переименованием — docs/dev/goldens.md.'
fi
exit "$rc"
