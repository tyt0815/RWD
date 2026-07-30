import tempfile
import unittest
from pathlib import Path

from tools import create_project


class CreateProjectTest(unittest.TestCase):
    def make_root(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        (root / "core").mkdir()
        (root / "core" / "init.lua").write_text(
            "local Core = {}\nCore.CORE_API_VERSION = 7\nreturn Core\n",
            encoding="utf-8",
        )
        self.addCleanup(temporary.cleanup)
        return root

    def test_creates_loadable_empty_project_structure(self):
        root = self.make_root()

        project_path = create_project.create_project(root, "my-game", "My Game")

        self.assertEqual(project_path, root / "projects" / "my-game")
        manifest = (project_path / "project.lua").read_text(encoding="utf-8")
        self.assertIn('id = "my-game"', manifest)
        self.assertIn('title = "My Game"', manifest)
        self.assertIn("coreApiVersion = 7", manifest)
        self.assertIn('entryModule = "projects.my-game.game.Game"', manifest)
        self.assertIn("Core.ProjectCategories.discover", manifest)
        self.assertIn('directoryPath = "projects/my-game/game"', manifest)

        game = (project_path / "game" / "Game.lua").read_text(encoding="utf-8")
        self.assertIn('local Core = require("core")', game)
        self.assertIn("function Game.new(project, options)", game)
        self.assertIn("stageRepository = options.stageRepository", game)
        self.assertIn("Core.ProjectCategories.createHost", game)
        self.assertIn("stageRuntime = Core.StageRuntime.new()", game)
        self.assertIn("function Game:startStage(stage, startBeat)", game)
        self.assertIn("function Game:setAutoPlay(value)", game)
        self.assertIn("self.stageRuntime:start(stage, self.currentBeat)", game)
        self.assertIn("function Game:update(deltaTime, beat)", game)
        self.assertIn("function Game:draw(width, height)", game)

        for relative_path in (
            "stages/README.md",
            "game/README.md",
            "assets/audio/music/README.md",
            "assets/audio/sfx/README.md",
            "assets/image/README.md",
        ):
            self.assertTrue((project_path / relative_path).is_file(), relative_path)
        self.assertFalse((project_path / "game" / "events").exists())

    def test_escapes_lua_title(self):
        root = self.make_root()

        project_path = create_project.create_project(root, "quoted", 'A "quoted" \\ game')

        manifest = (project_path / "project.lua").read_text(encoding="utf-8")
        self.assertIn('title = "A \\"quoted\\" \\\\ game"', manifest)

    def test_rejects_unsafe_or_windows_reserved_ids(self):
        root = self.make_root()

        for project_id in ("BadId", "-bad", "bad/path", "con", "COM1", "lpt9"):
            with self.subTest(project_id=project_id):
                with self.assertRaisesRegex(ValueError, "Project ID"):
                    create_project.create_project(root, project_id, "Bad")

        self.assertFalse((root / "projects").exists())

    def test_does_not_overwrite_existing_project(self):
        root = self.make_root()
        existing = root / "projects" / "existing"
        existing.mkdir(parents=True)
        marker = existing / "keep.txt"
        marker.write_text("keep", encoding="utf-8")

        with self.assertRaisesRegex(FileExistsError, "already exists"):
            create_project.create_project(root, "existing", "Existing")

        self.assertEqual(marker.read_text(encoding="utf-8"), "keep")

    def test_rejects_empty_title(self):
        root = self.make_root()

        with self.assertRaisesRegex(ValueError, "title"):
            create_project.create_project(root, "empty-title", "   ")


if __name__ == "__main__":
    unittest.main()
