#!/usr/bin/env bash
# Every jdBasic run goes through a hard memory cap (tools/capped.exe, a Windows Job Object).
#   tools/jd.sh run    file.jdb [args...]   interpreter
#   tools/jd.sh native file.jdb [args...]   jdBasic -c, then the .exe
#   tools/jd.sh build  file.jdb             jdBasic -c only
# JD_MEM (MB, default 1024) caps the program, JD_TIME (s, default 600) is a wall-clock limit.
# On Linux (CI container) it runs the natively built jdbasic; the container's --memory is the memory cap, JD_MEM is ignored.
set -e -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WIN=1 ;;
  *) WIN=0 ;;
esac
if [ "$WIN" = 1 ]; then
  CAP="$HERE/capped.exe"
  [ -x "$CAP" ] || "$HERE/build_capped.sh" >&2
  J="${JDBASIC:-/c/Users/amine/jdbasic-native/jdBasic.exe}"
else
  J="${JDBASIC:-/opt/jdbasic/build/jdbasic}"
  CAP="$HERE/capped-linux.sh"
fi
# the repo's own lib/ (gif.jdb) is on the IMPORT search path
if [ "$WIN" = 1 ]; then
  LIBDIR="$(cygpath -w -a "$HERE/../lib")"; SEP=";"
else
  LIBDIR="$(cd "$HERE/../lib" && pwd)"; SEP=":"
fi
export JDBASIC_PATH="$LIBDIR${JDBASIC_PATH:+$SEP$JDBASIC_PATH}"
MEM="${JD_MEM:-1024}"
TIME="${JD_TIME:-600}"
mode="$1"; shift
src="$1"; shift
if [ "$WIN" = 1 ]; then exe="$(cygpath -w -a "${src%.jdb}.exe")"; else exe="$(cd "$(dirname "$src")" && pwd)/$(basename "${src%.jdb}").exe"; fi
case "$mode" in
  run)    exec "$CAP" "$MEM" "$TIME" "$J" "$src" "$@" ;;
  build)  "$CAP" 4096 600 "$J" -c "$src" 2>&1 | grep -v '^\[jdbasic -c\]' ;;
  native) "$CAP" 4096 600 "$J" -c "$src" 2>&1 | grep -v '^\[jdbasic -c\]'
          exec "$CAP" "$MEM" "$TIME" "$exe" "$@" ;;
  *) echo "usage: jd.sh run|native|build file.jdb [args]"; exit 2 ;;
esac
