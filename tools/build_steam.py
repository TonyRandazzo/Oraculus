#!/usr/bin/env python3
"""Create the offline Windows and Linux depots from the Steam Godot presets."""

from __future__ import annotations

import argparse
import mmap
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    "Steam Windows": ROOT / "export/steam/windows/Oraculus.exe",
    "Steam Linux": ROOT / "export/steam/linux/Oraculus.x86_64",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot 4.7 non trovato: passa --godot /percorso/Godot")

    version = subprocess.run([args.godot, "--version"], capture_output=True, text=True)
    if version.returncode != 0 or not version.stdout.startswith("4.7"):
        parser.error("servono Godot 4.7 e i template di export della stessa versione")

    for preset, output in OUTPUTS.items():
        output.parent.mkdir(parents=True, exist_ok=True)
        command = [args.godot, "--headless", "--path", str(ROOT), "--export-release", preset, str(output)]
        print("Export:", preset, flush=True)
        log_path = ROOT / "export/steam/logs" / ("windows.log" if preset == "Steam Windows" else "linux.log")
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode != 0 or not output.is_file():
            tail = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-40:]
            print(f"Export fallito: {preset}\n" + "\n".join(tail), file=sys.stderr)
            return 1
        pack_path = output.with_suffix(".pck")
        if not pack_path.is_file():
            print(f"Pacchetto Godot mancante: {pack_path}", file=sys.stderr)
            return 1
        with pack_path.open("rb") as pack_file, mmap.mmap(pack_file.fileno(), 0, access=mmap.ACCESS_READ) as pack:
            for forbidden_path in (b"res://models/", b"res://addons/nobodywho/"):
                if pack.find(forbidden_path) >= 0:
                    print(f"Risorsa esclusa presente nel PCK: {forbidden_path.decode()}", file=sys.stderr)
                    return 1
        if preset == "Steam Linux":
            output.chmod(output.stat().st_mode | 0o111)
        license_dir = output.parent / "licenses"
        license_dir.mkdir(exist_ok=True)
        shutil.copy2(ROOT / "licenses/GODOT_COPYRIGHT.txt", license_dir / "GODOT_COPYRIGHT.txt")
        shutil.copy2(ROOT / "oraculus/thirdparty/kenney/fonts/License.txt", license_dir / "KENNEY_FONTS.txt")
        shutil.copy2(ROOT / "oraculus/thirdparty/kenney/ui-pack-adventure/License.txt", license_dir / "KENNEY_UI.txt")
        # Il pacchetto Steam non usa il modello o l'addon nativo: nessun
        # download, chiave API o runtime Python deve essere distribuito.
        for forbidden in ("models", "server", "python_venv"):
            if (output.parent / forbidden).exists():
                print(f"File non previsto nel depot: {forbidden}", file=sys.stderr)
                return 1
        log_text = log_path.read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR:" in log_text or "Parse Error:" in log_text:
            print(f"Errori GDScript in {log_path}", file=sys.stderr)
            return 1
        print(f"Creato: {output.relative_to(ROOT)} ({output.stat().st_size:,} byte); log: {log_path.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
