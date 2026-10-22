#!/usr/bin/env bash
# Every jdBasic run goes through a hard memory cap (tools/capped.exe, a Windows Job Object).
#   tools/jd.sh run    file.jdb [args...]   interpreter
#   tools/jd.sh native file.jdb [args...]   jdBasic -c, then the .exe
#   tools/jd.sh build  file.jdb             jdBasic -c only
# JD_MEM (MB, default 1024) caps the program, JD_TIME (s, default 600) is a wall-clock limit.
set -e -o pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CAP="$HERE/capped.exe"
[ -x "$CAP" ] || "$HERE/build_capped.sh" >&2
J="${JDBASIC:-/c/Users/amine/jdbasic-native/jdBasic.exe}"
MEM="${JD_MEM:-1024}"
TIME="${JD_TIME:-600}"
mode="$1"; shift
src="$1"; shift
exe="$(cygpath -w -a "${src%.jdb}.exe")"
case "$mode" in
  run)    exec "$CAP" "$MEM" "$TIME" "$J" "$src" "$@" ;;
  build)  "$CAP" 4096 600 "$J" -c "$src" 2>&1 | grep -v '^\[jdbasic -c\]' ;;
  native) "$CAP" 4096 600 "$J" -c "$src" 2>&1 | grep -v '^\[jdbasic -c\]'
          exec "$CAP" "$MEM" "$TIME" "$exe" "$@" ;;
  *) echo "usage: jd.sh run|native|build file.jdb [args]"; exit 2 ;;
esac
