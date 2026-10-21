#!/usr/bin/env bash
# Roda dentro do emulador (android-emulator-runner), a partir de app/.
# Deixa a barra de status limpa (modo demo), executa o roteiro de telas e tira
# uma captura do aparelho sempre que o teste grava o nome da tela em
# <systemTemp>/busaogyn_shot (lido com run-as; o app de teste é debuggable).
set -euo pipefail

demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" > /dev/null; }

adb wait-for-device
adb shell settings put global sysui_demo_allowed 1
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false -e powersave false
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile show -e datatype none -e level 4 -e fully true
demo notifications -e visible false
demo status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e mute hide -e speakerphone hide

mkdir -p ../store-screenshots/raw
pkg=com.lucksrei.busaogyn
check="run-as $pkg sh -c 'for f in code_cache/busaogyn_shot cache/busaogyn_shot; do if [ -f \$f ]; then echo \$f; cat \$f; echo; break; fi; done'"
(
  set +e
  while true; do
    found=$(adb shell "$check" 2> /dev/null)
    if [ -n "$found" ]; then
      file=$(printf '%s\n' "$found" | sed -n 1p | tr -d '\r')
      name=$(printf '%s\n' "$found" | sed -n 2p | tr -dc 'a-z0-9_')
      if [ -n "$name" ]; then
        sleep 0.3
        adb exec-out screencap -p > "../store-screenshots/raw/$name.png"
        echo "captura: $name ($file)"
      fi
      adb shell run-as "$pkg" rm -f "$file"
    fi
    sleep 0.3
  done
) &
watcher=$!

status=0
flutter test integration_test/store_screenshots_test.dart -d emulator-5554 || status=$?
sleep 2
kill "$watcher" 2> /dev/null || true
ls -l ../store-screenshots/raw
exit "$status"
