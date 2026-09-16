import tempfile
import unittest
import zipfile
from pathlib import Path

from tools import build_rhythm_dotgeo as builder


class BuildRhythmDotgeoTest(unittest.TestCase):
    def test_package_is_isolated_and_executable_contains_love_archive(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            runtime = base / "runtime"
            runtime.mkdir()
            (runtime / "love.exe").write_bytes(b"MZ-test-runtime")
            (runtime / "license.txt").write_text("test license")
            for name in builder.REQUIRED_DLLS:
                (runtime / name).write_bytes(b"test-dll")
            output = base / "output"
            result = builder.build(root, runtime, output)
            archive = output / "RhythmDotgeo.love"
            with zipfile.ZipFile(archive) as package:
                names = package.namelist()
                self.assertIn("main.lua", names)
                self.assertIn("conf.lua", names)
                self.assertIn("projects/rhythm_dotgeo/stages/speaki_song.json", names)
                self.assertIn("projects/rhythm_dotgeo/assets/image/crepe_walk_23.png", names)
                self.assertFalse(any(n.startswith(("editor/", "tests/", "projects/sample/")) for n in names))
                self.assertNotIn("launcher/Launcher.lua", names)
                self.assertIn(b"standalone = true", package.read("main.lua"))
            executable = output / "RhythmDotgeo" / "RhythmDotgeo.exe"
            self.assertEqual(executable.read_bytes(), b"MZ-test-runtime" + archive.read_bytes())
            with zipfile.ZipFile(result) as release:
                self.assertIn("RhythmDotgeo/RhythmDotgeo.exe", release.namelist())
                self.assertIn("RhythmDotgeo/license.txt", release.namelist())
            builder.build(root, runtime, output)
            with zipfile.ZipFile(archive) as package:
                self.assertEqual(names, package.namelist())

    def test_missing_runtime_fails_before_output_is_created(self):
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            with self.assertRaises(FileNotFoundError):
                builder.build(root, base, base / "output")
            self.assertFalse((base / "output").exists())
