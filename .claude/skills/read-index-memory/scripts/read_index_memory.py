#!/usr/bin/env python3
"""读取 .project-memory/ 下所有主题的 MEMORY.md 索引（不含 DONE.md）。

跨平台：仅使用 Python 标准库。接受可选位置参数作为项目根目录，
默认为当前工作目录。只读，不修改文件。
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def find_memory_roots(root: Path) -> list[Path]:
    """返回 .project-memory 下包含 MEMORY.md 的主题目录（非递归深挖）。"""
    roots: list[Path] = []
    memory_root = root / ".project-memory"
    if not memory_root.is_dir():
        return roots

    # 优先列出固定大主题顺序，便于稳定输出。
    preferred = [
        "Documents",
        "Boundary",
        "Target",
        "Environment",
        "Commands",
        "Design",
        "TODO",
    ]
    listed: set[Path] = set()
    for name in preferred:
        p = memory_root / name
        if p.is_dir() and (p / "MEMORY.md").is_file():
            roots.append(p)
            listed.add(p)

    # 其余带 MEMORY.md 的子目录（保持字典序）
    for child in sorted(memory_root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir() or child in listed:
            continue
        if (child / "MEMORY.md").is_file():
            roots.append(child)
    return roots


def render(root: Path) -> str:
    segments: list[str] = []
    for topic_dir in find_memory_roots(root):
        memory_file = topic_dir / "MEMORY.md"
        rel = memory_file.relative_to(root).as_posix()
        segments.append(f"===== {rel} =====")
        segments.append("# 内容")
        segments.append(memory_file.read_text(encoding="utf-8").rstrip("\n"))
        segments.append("")
    return "\n".join(segments)


def main() -> int:
    project_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    project_dir = project_dir.resolve()
    if not project_dir.is_dir():
        print(f"错误: 项目目录不存在: {project_dir}", file=sys.stderr)
        return 1

    memory_root = project_dir / ".project-memory"
    if not memory_root.is_dir():
        print(
            "read-index-memory: 项目未初始化 .project-memory/，无记忆索引可读。",
            file=sys.stderr,
        )
        return 0

    output = render(project_dir)
    if not output:
        print(
            "read-index-memory: .project-memory/ 下没有找到 MEMORY.md 索引文件。",
            file=sys.stderr,
        )
        return 0

    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
