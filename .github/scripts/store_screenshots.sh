#!/usr/bin/env bash
# Roda dentro do emulador (android-emulator-runner), a partir de app/.
# Deixa a barra de status limpa (modo demo), executa o roteiro de telas e tira
# uma captura do aparelho a cada `BUSAOGYN_SHOT <nome>` impresso pelo teste.
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
adb logcat -c
(
  adb logcat -v raw -s flutter:I | while IFS= read -r line; do
    case "$line" in
      *BUSAOGYN_SHOT*)
        name=$(printf '%s' "${line##*BUSAOGYN_SHOT }" | tr -dc 'a-z0-9_')
        sleep 0.5
        adb exec-out screencap -p > "../store-screenshots/raw/$name.png"
        echo "captura: $name"
        ;;
      *BUSAOGYN_LOG*) echo "$line" ;;
    esac
  done
) &
watcher=$!

status=0
flutter test integration_test/store_screenshots_test.dart -d emulator-5554 || status=$?
sleep 2
kill "$watcher" 2> /dev/null || true
ls -l ../store-screenshots/raw
exit "$status"
