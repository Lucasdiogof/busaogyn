#!/usr/bin/env bash
# Falha se um artefato de build contiver o catálogo oficial da CMTC
# (licença de redistribuição pendente).
# Uso: scripts/check-no-official-catalog.sh build/web [app.apk app.aab Runner.app …]
# Aceita pastas e arquivos; .apk/.aab/.ipa/.zip são abertos.
#
# As marcas são procuradas em UTF-8 e em UTF-16LE: o AOT do Dart guarda
# strings com caracteres não ASCII (o payload tem "Goiânia") em UTF-16, e um
# grep simples não as encontraria em libapp.so / App.framework.
set -euo pipefail

[ "$#" -ge 1 ] || { echo "uso: $0 <pasta-ou-arquivo> ..." >&2; exit 2; }

status=0
for target in "$@"; do
  if [ ! -e "$target" ]; then
    echo "não existe: $target" >&2
    status=2
    continue
  fi
  python3 -I - "$target" <<'PY' || status=1
import os, sys, zipfile

# Marcas que só existem no payload gerado por data/cmtc/pipeline/export_catalog.py.
MARKERS = ['busaogyn-cmtc-payload', 'cmtc-2026-10', '"stops":{"fields"', '\\"stops\\":{\\"fields\\"',
           '"trips":{"fields"', '"sequences":{"fields"', 'projecao-kmz-v2']
NEEDLES = [(m, enc, m.encode(enc)) for m in MARKERS for enc in ('utf-8', 'utf-16-le')]
target = sys.argv[1]
hits = []

def scan(name, data):
    for marker, enc, needle in NEEDLES:
        if needle in data:
            hits.append(f'{name}: {marker!r} ({enc})')

def scan_zip(path_or_file, prefix):
    with zipfile.ZipFile(path_or_file) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            data = z.read(info)
            name = f'{prefix}!{info.filename}'
            if info.filename.lower().endswith(('.apk', '.aab', '.zip', '.jar')):
                import io
                try:
                    scan_zip(io.BytesIO(data), name)
                    continue
                except zipfile.BadZipFile:
                    pass
            scan(name, data)

if os.path.isdir(target):
    for root, _, files in os.walk(target):
        for f in files:
            p = os.path.join(root, f)
            with open(p, 'rb') as fh:
                scan(p, fh.read())
elif zipfile.is_zipfile(target):
    scan_zip(target, target)
else:
    with open(target, 'rb') as fh:
        scan(target, fh.read())

if hits:
    print('ENCONTRADO catálogo oficial em', target, file=sys.stderr)
    for h in hits[:10]:
        print('  ' + h, file=sys.stderr)
    sys.exit(1)
print('OK: nenhum dado do catálogo oficial em', target)
PY
done
exit "$status"
