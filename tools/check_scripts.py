#!/usr/bin/env python3
"""Compila ogni .gd del progetto con `godot --check-only --script` e riporta
solo gli errori veri.

Perche' serve un filtro: `--check-only --script` non registra gli autoload,
quindi ogni riferimento a AIServerManager, GameState o FeedbackPopup viene
segnalato come "Identifier not found" anche quando il file e' corretto. Un
file i cui unici errori sono di quel tipo viene considerato buono.

Uso:
  python3 tools/check_scripts.py /percorso/di/godot
  GODOT=/percorso/di/godot python3 tools/check_scripts.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SKIP = {".godot", "python_venv", "models", "export"}
AUTOLOADS = ["AIServerManager", "GameState", "FeedbackPopup"]

NOISE = re.compile(
    r"Image width|image is empty|initialize_data|create_from_image"
    r"|^Godot Engine|^\s*$|^\s*at: |^\s*GDScript backtrace|^\s*\[\d+\] "
)


def find_scripts():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP and not d.startswith(".")]
        for f in sorted(filenames):
            if f.endswith(".gd"):
                out.append(os.path.relpath(os.path.join(dirpath, f), ROOT))
    return sorted(out)


def real_errors(output):
    """Errori che non sono ne' rumore ne' autoload mancanti."""
    errs = []
    for line in output.splitlines():
        if NOISE.search(line):
            continue
        if "SCRIPT ERROR" not in line and "ERROR:" not in line:
            continue
        if any("Identifier not found: " + a in line for a in AUTOLOADS):
            continue
        # conseguenza diretta di un errore su autoload, non un difetto in piu'
        if 'Failed to load script' in line and 'Compilation failed' in line:
            continue
        errs.append(line.strip())
    return errs


def main():
    godot = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GODOT", "godot")
    files = find_scripts()
    print("=" * 70)
    print("  CONTROLLO DI COMPILAZIONE — %d script" % len(files))
    print("=" * 70)

    ko = {}
    autoload_only = 0
    for rel in files:
        proc = subprocess.run(
            [godot, "--headless", "--path", ROOT, "--check-only", "--script", "res://" + rel],
            capture_output=True, text=True, timeout=120,
        )
        output = proc.stdout + proc.stderr
        errs = real_errors(output)
        if errs:
            ko[rel] = errs
            print("  FAIL  %s" % rel)
            for e in errs[:4]:
                print("          %s" % e)
        else:
            if any("Identifier not found: " + a in output for a in AUTOLOADS):
                autoload_only += 1
            print("  ok    %s" % rel)

    print("")
    print("  %d/%d script senza errori reali (%d contengono solo riferimenti a autoload)."
          % (len(files) - len(ko), len(files), autoload_only))
    if ko:
        print("  Falliti: %s" % ", ".join(sorted(ko)))
    print("=" * 70)
    return 1 if ko else 0


if __name__ == "__main__":
    sys.exit(main())
