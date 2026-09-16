#!/usr/bin/env python3
"""Rhythm Dotgeo 전용 Windows EXE, .love, 배포 ZIP을 만든다."""

import argparse
import shutil
import subprocess
import zipfile
from pathlib import Path

REQUIRED_DLLS = (
    "love.dll", "lua51.dll", "mpg123.dll", "msvcp120.dll",
    "msvcr120.dll", "OpenAL32.dll", "SDL2.dll",
)
LAUNCHER_FILES = ("AppFont.lua", "ProjectLoader.lua", "NativeFileSystem.lua", "WindowsFileSystem.lua")


def build(root, love_dir, output):
    root, love_dir, output = Path(root), Path(love_dir), Path(output)
    for name in ("love.exe", "license.txt", *REQUIRED_DLLS):
        if not (love_dir / name).is_file():
            raise FileNotFoundError(f"LÖVE 11.5 runtime file missing: {love_dir / name}")
    files = {}
    for directory in ("core", "projects/rhythm_dotgeo", "assets/fonts"):
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and path.suffix.lower() != ".md":
                files[path.relative_to(root).as_posix()] = path
    for name in LAUNCHER_FILES:
        files[f"launcher/{name}"] = root / "launcher" / name
    files["vendor/dkjson.lua"] = root / "vendor/dkjson.lua"
    for name in ("main.lua", "conf.lua"):
        files[name] = root / "tools/packaging/rhythm_dotgeo" / name
    for path in files.values():
        if not path.is_file():
            raise FileNotFoundError(path)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "RhythmDotgeo.love"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
        for name, path in sorted(files.items()):
            package.write(path, name)
    release = output / "RhythmDotgeo"
    release.mkdir(exist_ok=True)
    executable = release / "RhythmDotgeo.exe"
    with executable.open("wb") as destination:
        for source in (love_dir / "love.exe", archive):
            with source.open("rb") as stream:
                shutil.copyfileobj(stream, destination)
    runtime_names = ("license.txt", *REQUIRED_DLLS)
    for name in runtime_names:
        shutil.copy2(love_dir / name, release / name)
    result = output / "RhythmDotgeo-windows.zip"
    with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as package:
        for name in ("RhythmDotgeo.exe", *runtime_names):
            package.write(release / name, f"RhythmDotgeo/{name}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--love-dir", type=Path, default=Path("C:/Program Files/LOVE"),
                        help="LÖVE 11.5 Windows runtime folder")
    parser.add_argument("--verify", action="store_true", help="Run packaged EXE smoke test")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / "dist"
    result = build(root, args.love_dir, output)
    if args.verify:
        subprocess.run([str(output / "RhythmDotgeo/RhythmDotgeo.exe"), "--smoke-test"],
                       cwd=output / "RhythmDotgeo", check=True, timeout=60)
    print(result)


if __name__ == "__main__":
    main()
