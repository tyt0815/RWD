#!/usr/bin/env python3
"""RWD 빈 Project 구조를 생성한다."""

import argparse
import re
import shutil
import sys
import tempfile
from pathlib import Path

SAFE_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
WINDOWS_RESERVED_NAMES = {"con", "prn", "aux", "nul"}
WINDOWS_RESERVED_NAMES.update(f"com{number}" for number in range(1, 10))
WINDOWS_RESERVED_NAMES.update(f"lpt{number}" for number in range(1, 10))
CORE_API_PATTERN = re.compile(r"Core\.CORE_API_VERSION\s*=\s*(\d+)")


def validate_project_id(project_id):
    if not SAFE_ID_PATTERN.fullmatch(project_id):
        raise ValueError(
            "Project ID must start with a lowercase letter or digit and contain "
            "only lowercase letters, digits, '_' or '-'."
        )
    if project_id.lower() in WINDOWS_RESERVED_NAMES:
        raise ValueError("Project ID must not be a Windows reserved name.")


def read_core_api_version(root):
    core_init_path = root / "core" / "init.lua"
    try:
        contents = core_init_path.read_text(encoding="utf-8")
    except OSError as error:
        raise RuntimeError(f"Cannot read Core API version: {core_init_path}") from error

    match = CORE_API_PATTERN.search(contents)
    if not match:
        raise RuntimeError(f"Cannot find CORE_API_VERSION in {core_init_path}")
    return int(match.group(1))


def lua_string(value):
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def project_manifest(project_id, title, core_api_version):
    return f"""local Core = require(\"core\")

local eventCategories, categoryError = Core.ProjectCategories.discover({{
    directoryPath = {lua_string(f"projects/{project_id}/game")},
    modulePrefix = {lua_string(f"projects.{project_id}.game")},
}})
if not eventCategories then error(categoryError) end

return {{
    id = {lua_string(project_id)},
    title = {lua_string(title)},
    coreApiVersion = {core_api_version},
    entryModule = {lua_string(f"projects.{project_id}.game.Game")},
    eventCategories = eventCategories,
}}
"""


def game_module():
    return """local Core = require(\"core\")

local Game = {}
Game.__index = Game

function Game.new(project, options)
    options = options or {}
    local categoryHost, hostError = Core.ProjectCategories.createHost(project)
    if not categoryHost then error(hostError) end
    return setmetatable({
        project = project,
        stageStore = options.stageStore,
        categoryHost = categoryHost,
        stage = nil,
        stageRuntime = Core.StageRuntime.new(),
        currentBeat = 0,
    }, Game)
end

function Game:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.stageRuntime = Core.StageRuntime.new()
    self.categoryHost:startStage(stage, self.currentBeat)
    local occurrences, errorMessage = self.stageRuntime:start(stage, self.currentBeat)
    if not occurrences then error(errorMessage) end
    self.categoryHost:applyOccurrences(occurrences, self.currentBeat)
end

function Game:setAutoPlay(value)
    self.categoryHost:setAutoPlay(value or "none")
end

function Game:update(deltaTime, beat)
    if beat == nil or not self.stage then return end
    local occurrences, errorMessage = self.stageRuntime:update(beat)
    if not occurrences then error(errorMessage) end
    self.currentBeat = self.stageRuntime:getCurrentBeat()
    self.categoryHost:applyOccurrences(occurrences, self.currentBeat)
    self.categoryHost:update(deltaTime, self.currentBeat)
end

function Game:isInputEnabled()
    return self.stageRuntime:isInputEnabled()
end

function Game:keypressed(key, beat)
    if not self.stageRuntime:isInputEnabled() then return end
    self.categoryHost:keypressed(key, beat)
end

function Game:getCategoryRuntime(categoryId)
    return self.categoryHost:getRuntime(categoryId)
end

function Game:draw(width, height)
    love.graphics.clear(0.07, 0.08, 0.1, 1)
    self.categoryHost:draw(width, height)
    if #self.project.eventCategories == 0 then
        love.graphics.setColor(0.92, 0.93, 0.96, 1)
        love.graphics.printf(self.project.title, 0, height * 0.45, width, "center")
    end
end

return Game
"""


def write_template(project_path, project_id, title, core_api_version):
    files = {
        "project.lua": project_manifest(project_id, title, core_api_version),
        "game/Game.lua": game_module(),
        "stages/README.md": "# Stages\n\n에디터가 생성한 Stage JSON을 이 폴더에 저장한다.\n",
        "game/README.md": (
            "# Game Categories\n\n"
            "Project 기능은 `game/<CategoryName>/`에 Category 단위로 둔다. "
            "Definition.lua와 Runtime.lua를 만들면 manifest와 Game을 수정하지 않아도 자동 등록·실행된다. "
            "Definition은 순수 등록 정보만, Runtime과 Event 파일은 Category 조립과 연출을 맡는다. "
            "Actor는 규모와 변경 이유에 따라 공통 모듈의 여러 인스턴스 또는 역할별 모듈로 나눈다.\n"
        ),
        "assets/audio/music/README.md": (
            "# Music\n\nProject 음악 파일(`.ogg`, `.mp3`, `.wav`)을 이 폴더 또는 하위 폴더에 둔다.\n"
        ),
        "assets/audio/sfx/README.md": (
            "# SFX\n\nProject 효과음 파일(`.ogg`, `.mp3`, `.wav`)을 이 폴더 또는 하위 폴더에 둔다.\n"
        ),
        "assets/image/README.md": "# Images\n\nProject 이미지 리소스를 이 폴더 또는 하위 폴더에 둔다.\n",
    }

    for relative_path, contents in files.items():
        path = project_path / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8", newline="\n")


def create_project(root, project_id, title):
    root = Path(root).resolve()
    validate_project_id(project_id)
    if not isinstance(title, str) or not title.strip():
        raise ValueError("Project title must not be empty.")

    project_path = root / "projects" / project_id
    if project_path.exists():
        raise FileExistsError(f"Project already exists: {project_path}")

    core_api_version = read_core_api_version(root)
    projects_path = root / "projects"
    projects_path.mkdir(parents=True, exist_ok=True)
    temporary_path = Path(tempfile.mkdtemp(prefix=f".{project_id}-", dir=projects_path))

    try:
        write_template(temporary_path, project_id, title, core_api_version)
        temporary_path.rename(project_path)
    except Exception:
        shutil.rmtree(temporary_path, ignore_errors=True)
        raise

    return project_path


def parse_args(arguments=None):
    parser = argparse.ArgumentParser(description="RWD 빈 Project를 생성합니다.")
    parser.add_argument("project_id", help="소문자 Project ID (예: my-game)")
    parser.add_argument("title", help='표시 이름 (예: "My Game")')
    return parser.parse_args(arguments)


def main(arguments=None):
    args = parse_args(arguments)
    root = Path(__file__).resolve().parent.parent
    try:
        project_path = create_project(root, args.project_id, args.title)
    except (ValueError, FileExistsError, RuntimeError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Created Project: {project_path.relative_to(root)}")
    print("Next: love . --test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
