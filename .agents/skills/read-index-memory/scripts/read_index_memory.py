#!/usr/bin/env python3
"""Read the MEMORY.md index of every topic under .project-memory/.

Also reads the three planning files under .project-memory/TODO/ (Pending, TODO,
STEP) so unsettled plans and the user's own backlog are visible at the start of
a task instead of being lost.

Cross-platform: uses only the Python standard library. Accepts an optional
positional argument as the project root directory, defaults to the current
working directory. Read-only, never modifies files.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Planning files read after the topic indexes, in this order.
PLANNING_FILES = (
    "TODO/Pending.md",
    "TODO/TODO.md",
    "TODO/STEP.md",
)


def find_memory_roots(root: Path) -> list[Path]:
    """Return topic directories under .project-memory that contain MEMORY.md (non-recursive)."""
    roots: list[Path] = []
    memory_root = root / ".project-memory"
    if not memory_root.is_dir():
        return roots

    # List the fixed major topics first so output order stays stable.
    preferred = [
        "Documents",
        "Boundary",
        "Target",
        "Environment",
        "Commands",
        "Design",
        "Tools",
        "Pitfalls",
    ]
    listed: set[Path] = set()
    for name in preferred:
        p = memory_root / name
        if p.is_dir() and (p / "MEMORY.md").is_file():
            roots.append(p)
            listed.add(p)

    # Any remaining subdirectories that have MEMORY.md (kept in lexicographic order)
    for child in sorted(memory_root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir() or child in listed:
            continue
        if (child / "MEMORY.md").is_file():
            roots.append(child)
    return roots


def file_segments(root: Path, path: Path) -> list[str]:
    """Render one existing file as a labelled segment; a missing file yields nothing."""
    if not path.is_file():
        return []
    rel = path.relative_to(root).as_posix()
    return [
        f"===== {rel} =====",
        "# Content",
        path.read_text(encoding="utf-8").rstrip("\n"),
        "",
    ]


def render(root: Path) -> str:
    segments: list[str] = []
    for topic_dir in find_memory_roots(root):
        segments.extend(file_segments(root, topic_dir / "MEMORY.md"))
    memory_root = root / ".project-memory"
    for rel in PLANNING_FILES:
        segments.extend(file_segments(root, memory_root / rel))
    return "\n".join(segments)


def main() -> int:
    project_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    project_dir = project_dir.resolve()
    if not project_dir.is_dir():
        print(f"Error: project directory does not exist: {project_dir}", file=sys.stderr)
        return 1

    memory_root = project_dir / ".project-memory"
    if not memory_root.is_dir():
        print(
            "read-index-memory: project has no .project-memory/ yet, no memory index to read.",
            file=sys.stderr,
        )
        return 0

    output = render(project_dir)
    if not output:
        print(
            "read-index-memory: no MEMORY.md index or planning file found under .project-memory/.",
            file=sys.stderr,
        )
        return 0

    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
