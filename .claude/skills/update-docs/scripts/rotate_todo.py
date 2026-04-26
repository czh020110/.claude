#!/usr/bin/env python3
"""Rotate fine-grained TODO items into DONE and write the next TODO list."""

from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[3]


def normalize_commit_ref(value: str | None) -> str:
    return value.strip() if value and value.strip() else "无"


def read_new_todos(args: argparse.Namespace) -> list[str]:
    if args.todos_json:
        data = json.loads(args.todos_json)
    elif args.todos_file:
        data = json.loads(Path(args.todos_file).read_text(encoding="utf-8"))
    else:
        raise SystemExit("Either --todos-json or --todos-file is required")

    if not isinstance(data, list) or not all(isinstance(item, str) for item in data):
        raise SystemExit("TODO input must be a JSON array of strings")

    todos = [item.strip() for item in data if item.strip()]
    if not todos:
        raise SystemExit("TODO list must not be empty")
    return todos


def extract_existing_tasks(todo_text: str) -> list[str]:
    tasks: list[str] = []
    for line in todo_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("- [ ]"):
            task = re.sub(r"^- \[ \]\s*", "", stripped).strip()
            if task:
                tasks.append(task)
    return tasks


def format_done_entry(task: str, commit_ref: str, change_record: str, today: str) -> str:
    return (
        f"- [x] {today}：{task}\n"
        f"  - 关联 TODO：自动迁移自上一次 TODO.md\n"
        f"  - 验证方式：随本次提交验收\n"
        f"  - 关联修改记录：{change_record}\n"
        f"  - 关联 Commit：{commit_ref}\n"
    )


def format_todo(tasks: list[str]) -> str:
    lines = ["# TODO", "", "## 本次可提交任务", ""]
    for index, task in enumerate(tasks, start=1):
        task_id = f"T-{index:03d}"
        lines.extend(
            [
                f"- [ ] {task_id}（P0）：{task}",
                "  - 来源 STEP：无",
                "  - 依赖：无",
                "  - 验收标准：本次提交内可验证完成",
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Rotate TODO.md into DONE.md and write next TODO.md")
    parser.add_argument("--todos-json", help="JSON string array of next TODO items")
    parser.add_argument("--todos-file", help="Path to a JSON file containing a string array")
    parser.add_argument("--commit", help="Commit description or commit hash associated with completed TODOs")
    parser.add_argument("--change-record", help="Path or file name of the change record")
    parser.add_argument("--root", help="Project .claude root; defaults to claude-copy in this template")
    args = parser.parse_args()

    root = Path(args.root).resolve() if args.root else repo_root_from_script()
    todo_path = root / "introduction" / "TODO" / "TODO.md"
    done_path = root / "introduction" / "TODO" / "DONE.md"

    todo_path.parent.mkdir(parents=True, exist_ok=True)
    done_path.parent.mkdir(parents=True, exist_ok=True)

    old_todo = todo_path.read_text(encoding="utf-8") if todo_path.exists() else ""
    old_tasks = extract_existing_tasks(old_todo)
    new_tasks = read_new_todos(args)

    today = date.today().isoformat()
    commit_ref = normalize_commit_ref(args.commit)
    change_record = normalize_commit_ref(args.change_record)

    if old_tasks:
        existing_done = done_path.read_text(encoding="utf-8") if done_path.exists() else ""
        if existing_done.strip():
            existing_done = existing_done.rstrip() + "\n\n"
        else:
            existing_done = "# DONE\n\n"
        done_entries = "\n".join(
            format_done_entry(task, commit_ref, change_record, today).rstrip() for task in old_tasks
        )
        done_path.write_text(existing_done + done_entries + "\n", encoding="utf-8")
    elif not done_path.exists():
        done_path.write_text("# DONE\n", encoding="utf-8")

    todo_path.write_text(format_todo(new_tasks), encoding="utf-8")

    print(f"migrated_done_items={len(old_tasks)}")
    print(f"new_todo_items={len(new_tasks)}")
    print(f"todo_path={todo_path}")
    print(f"done_path={done_path}")


if __name__ == "__main__":
    main()
