#!/usr/bin/env python3
"""Confere bibliotecas nativas de um APK/AAB para páginas de 16 KB.

Para cada `.so` de 64 bits (arm64-v8a, x86_64):
- todos os segmentos PT_LOAD precisam de alinhamento >= 16 KB;
- no APK, a biblioteca precisa estar sem compressão e com os dados
  alinhados a 16 KB dentro do zip (requisito para carregar direto do APK).

Uso: python3 tool/check_android_release.py build/.../app-release.apk [...aab]
Sai com código 1 se alguma biblioteca não estiver pronta.
"""

from __future__ import annotations

import struct
import sys
import zipfile

PAGE = 16 * 1024
ABIS_64 = ('arm64-v8a', 'x86_64')
PT_LOAD = 1


def load_alignments(elf: bytes) -> list[int]:
    if elf[:4] != b'\x7fELF' or elf[4] != 2:
        raise ValueError('não é ELF de 64 bits')
    endian = '<' if elf[5] == 1 else '>'
    phoff, = struct.unpack_from(endian + 'Q', elf, 0x20)
    phentsize, phnum = struct.unpack_from(endian + 'HH', elf, 0x36)
    aligns = []
    for i in range(phnum):
        base = phoff + i * phentsize
        p_type, = struct.unpack_from(endian + 'I', elf, base)
        if p_type == PT_LOAD:
            p_align, = struct.unpack_from(endian + 'Q', elf, base + 0x30)
            aligns.append(p_align)
    return aligns


def data_offset(archive: zipfile.ZipFile, info: zipfile.ZipInfo) -> int:
    fp = archive.fp
    fp.seek(info.header_offset)
    header = fp.read(30)
    name_len, extra_len = struct.unpack_from('<HH', header, 26)
    return info.header_offset + 30 + name_len + extra_len


def check(path: str) -> list[str]:
    problems = []
    is_apk = path.endswith('.apk')
    with zipfile.ZipFile(path) as archive:
        libs = [
            info
            for info in archive.infolist()
            if info.filename.endswith('.so')
            and any(f'lib/{abi}/' in info.filename for abi in ABIS_64)
        ]
        if not libs:
            problems.append(f'{path}: nenhuma biblioteca nativa de 64 bits')
        for info in libs:
            aligns = load_alignments(archive.read(info))
            worst = min(aligns) if aligns else 0
            status = 'ok' if worst >= PAGE else 'FALHA'
            line = f'{info.filename}: PT_LOAD align mínimo {worst}'
            if is_apk:
                stored = info.compress_type == zipfile.ZIP_STORED
                offset = data_offset(archive, info)
                zip_ok = stored and offset % PAGE == 0
                line += f', zip {"sem compressão" if stored else "comprimido"}'
                line += f' offset%16K={offset % PAGE}'
                if not zip_ok:
                    status = 'FALHA'
            print(f'[{status}] {path}: {line}')
            if status != 'ok':
                problems.append(f'{path}: {line}')
    return problems


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    problems = [p for path in sys.argv[1:] for p in check(path)]
    if problems:
        print('\nBibliotecas sem suporte a páginas de 16 KB:', file=sys.stderr)
        print('\n'.join(problems), file=sys.stderr)
        sys.exit(1)
    print('\nTodas as bibliotecas de 64 bits estão alinhadas a 16 KB.')


if __name__ == '__main__':
    main()
