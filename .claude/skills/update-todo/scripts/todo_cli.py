#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any

RULES_SECTION = "维护规则"
TASK_SECTIONS = ["进行中", "未开始", "阻塞", "暂缓", "最近完成"]
SECTION_TO_STATUS = {
    "进行中": "进行中",
    "未开始": "未开始",
    "阻塞": "阻塞",
    "暂缓": "暂缓",
    "最近完成": "完成",
}
STATUS_TO_SECTION = {
    "进行中": "进行中",
    "未开始": "未开始",
    "阻塞": "阻塞",
    "暂缓": "暂缓",
    "完成": "最近完成",
}
FIELD_ORDER = [
    "来源 STEP",
    "依赖",
    "验收标准",
    "当前进展",
    "阻塞原因",
    "暂缓原因",
    "完成日期",
    "验证方式",
    "关联 Commit",
]
TASK_HEADER_RE = re.compile(r"^###\s+(T-\d+|[^（：\s]+)(?:（(P\d+)）)?：(.*)$")
CHECKBOX_TASK_RE = re.compile(r"^-\s+\[([ xX])\]\s+(T-\d+|[^（：\s]+)(?:（(P\d+)）)?：(.*)$")
FIELD_RE = re.compile(r"^-\s+([^：]+)：\s*(.*)$")
LEGACY_DONE_RE = re.compile(r"^-\s+\[x\]\s+(\d{4}-\d{2}-\d{2})：(.*)$")
VALID_TASK_ID_RE = re.compile(r"^T-\d+$")


@dataclass
class TaskHeader:
    task_id: str | None
    priority: str | None
    title: str


@dataclass
class Task:
    task_id: str | None
    title: str
    priority: str | None
    section: str
    fields: dict[str, str] = field(default_factory=dict)

    @property
    def status(self) -> str:
        return self.fields.get("状态", SECTION_TO_STATUS.get(self.section, "未开始"))

    @status.setter
    def status(self, value: str) -> None:
        self.fields["状态"] = value
        self.section = STATUS_TO_SECTION[value]


@dataclass
class Board:
    header_lines: list[str]
    rules_lines: list[str]
    sections: dict[str, list[Task]]


def claude_root_from_script() -> Path:
    return Path(__file__).resolve().parents[3]


def project_root_from_script() -> Path:
    return claude_root_from_script().parent


def default_todo_path() -> Path:
    return project_root_from_script() / ".claude_introduction" / "TODO" / "TODO.md"


def normalize_depends(values: list[str] | None) -> str:
    if not values:
        return "无"
    cleaned = [value.strip() for value in values if value and value.strip()]
    return "、".join(cleaned) if cleaned else "无"


def parse_task_header(line: str) -> TaskHeader | None:
    checkbox_match = CHECKBOX_TASK_RE.match(line)
    if checkbox_match:
        raw_task_id = checkbox_match.group(2).strip()
        return TaskHeader(
            task_id=raw_task_id if VALID_TASK_ID_RE.match(raw_task_id) else None,
            priority=checkbox_match.group(3),
            title=checkbox_match.group(4).strip(),
        )
    header_match = TASK_HEADER_RE.match(line)
    if header_match:
        raw_task_id = header_match.group(1).strip()
        return TaskHeader(
            task_id=raw_task_id if VALID_TASK_ID_RE.match(raw_task_id) else None,
            priority=header_match.group(2),
            title=header_match.group(3).strip(),
        )
    return None


def is_task_header(line: str, section: str | None = None) -> bool:
    if parse_task_header(line):
        return True
    return bool(section == "最近完成" and LEGACY_DONE_RE.match(line))


def parse_board(path: Path) -> Board:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    header_lines: list[str] = []
    rules_lines: list[str] = []
    sections = {name: [] for name in TASK_SECTIONS}

    index = 0
    while index < len(lines) and not lines[index].startswith("## "):
        header_lines.append(lines[index])
        index += 1

    current_section: str | None = None
    while index < len(lines):
        line = lines[index]
        if line.startswith("## "):
            current_section = line[3:].strip()
            index += 1
            continue
        if current_section == RULES_SECTION:
            rules_lines.append(line)
            index += 1
            continue
        if current_section not in sections:
            index += 1
            continue
        stripped = line.strip()
        if not stripped or stripped == "无":
            index += 1
            continue
        if current_section == "最近完成":
            legacy_match = LEGACY_DONE_RE.match(line)
            if legacy_match:
                task, index = parse_legacy_completed(lines, index, current_section, legacy_match)
                sections[current_section].append(task)
                continue
        task_header = parse_task_header(line)
        if task_header:
            task, index = parse_task_block(lines, index, current_section, task_header)
            sections[current_section].append(task)
            continue
        index += 1

    board = Board(header_lines=header_lines, rules_lines=rules_lines, sections=sections)
    assign_missing_ids(board)
    return board


def parse_task_block(lines: list[str], start: int, section: str, header: TaskHeader) -> tuple[Task, int]:
    task = Task(
        task_id=header.task_id,
        priority=header.priority,
        title=header.title,
        section=section,
    )
    index = start + 1
    while index < len(lines):
        line = lines[index]
        if line.startswith("## ") or is_task_header(line, section):
            break
        stripped = line.strip()
        if not stripped:
            index += 1
            continue
        field_match = FIELD_RE.match(stripped)
        if field_match:
            task.fields[field_match.group(1).strip()] = field_match.group(2).strip()
        index += 1
    if "状态" not in task.fields:
        task.fields["状态"] = SECTION_TO_STATUS[section]
    return task, index


def parse_legacy_completed(
    lines: list[str],
    start: int,
    section: str,
    match: re.Match[str],
) -> tuple[Task, int]:
    completed_date = match.group(1)
    title = match.group(2).strip()
    fields: dict[str, str] = {"状态": "完成", "完成日期": completed_date}
    index = start + 1
    task_id: str | None = None
    while index < len(lines):
        line = lines[index]
        if line.startswith("## ") or is_task_header(line, section):
            break
        stripped = line.strip()
        if not stripped:
            index += 1
            continue
        field_match = FIELD_RE.match(stripped)
        if field_match:
            key = field_match.group(1).strip()
            value = field_match.group(2).strip()
            if key == "关联 TODO" and VALID_TASK_ID_RE.match(value):
                task_id = value
            else:
                fields[key] = value
        index += 1
    return Task(task_id=task_id, priority=None, title=title, section=section, fields=fields), index


def assign_missing_ids(board: Board) -> None:
    used_numbers = {
        int(task.task_id.split("-")[1])
        for section in TASK_SECTIONS
        for task in board.sections[section]
        if task.task_id and VALID_TASK_ID_RE.match(task.task_id)
    }
    next_number = 1
    for section in TASK_SECTIONS:
        for task in board.sections[section]:
            if task.task_id and VALID_TASK_ID_RE.match(task.task_id):
                continue
            while next_number in used_numbers:
                next_number += 1
            task.task_id = f"T-{next_number:03d}"
            used_numbers.add(next_number)
            next_number += 1


def render_task(task: Task) -> list[str]:
    assert task.task_id is not None
    checkbox = "x" if task.status == "完成" else " "
    header = f"- [{checkbox}] {task.task_id}"
    if task.priority:
        header += f"（{task.priority}）"
    header += f"：{task.title}"
    lines = [header]
    for field_name in FIELD_ORDER:
        value = task.fields.get(field_name)
        if value:
            lines.append(f"  - {field_name}：{value}")
    return lines


def render_board(board: Board) -> str:
    lines = list(board.header_lines)
    if lines and lines[-1] != "":
        lines.append("")
    lines.append(f"## {RULES_SECTION}")
    lines.append("")
    if board.rules_lines:
        lines.extend(board.rules_lines)
    else:
        lines.append("无")
    lines.append("")
    for section in TASK_SECTIONS:
        lines.append(f"## {section}")
        lines.append("")
        tasks = board.sections.get(section, [])
        if not tasks:
            lines.append("无")
            lines.append("")
            continue
        for idx, task in enumerate(tasks):
            lines.extend(render_task(task))
            if idx != len(tasks) - 1:
                lines.append("")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def find_task(board: Board, task_id: str) -> Task:
    for section in TASK_SECTIONS:
        for task in board.sections[section]:
            if task.task_id == task_id:
                return task
    raise SystemExit(f"Task not found: {task_id}")


def remove_task(board: Board, task: Task) -> None:
    board.sections[task.section] = [item for item in board.sections[task.section] if item.task_id != task.task_id]


def insert_task(board: Board, task: Task, prepend: bool = False) -> None:
    bucket = board.sections[task.section]
    if prepend:
        bucket.insert(0, task)
    else:
        bucket.append(task)


def next_task_id(board: Board) -> str:
    max_number = 0
    for section in TASK_SECTIONS:
        for task in board.sections[section]:
            if not task.task_id or not VALID_TASK_ID_RE.match(task.task_id):
                continue
            max_number = max(max_number, int(task.task_id.split("-")[1]))
    return f"T-{max_number + 1:03d}"


def apply_add(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    status = args.status or "未开始"
    task = Task(
        task_id=next_task_id(board),
        priority=args.priority,
        title=args.title.strip(),
        section=STATUS_TO_SECTION[status],
        fields={
            "状态": status,
            "来源 STEP": args.source_step or "无",
            "依赖": normalize_depends(args.depends_on),
            "验收标准": args.acceptance.strip(),
        },
    )
    if args.progress:
        task.fields["当前进展"] = args.progress.strip()
    insert_task(board, task)
    return {"action": "add", "task_id": task.task_id, "section": task.section}


def apply_start(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    task = find_task(board, args.id)
    remove_task(board, task)
    task.status = "进行中"
    if args.progress:
        task.fields["当前进展"] = args.progress.strip()
    task.fields.pop("阻塞原因", None)
    task.fields.pop("暂缓原因", None)
    insert_task(board, task)
    return {"action": "start", "task_id": task.task_id, "section": task.section}


def apply_complete(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    task = find_task(board, args.id)
    remove_task(board, task)
    task.status = "完成"
    task.fields.pop("当前进展", None)
    task.fields.pop("阻塞原因", None)
    task.fields.pop("暂缓原因", None)
    task.fields["完成日期"] = args.date or date.today().isoformat()
    task.fields["验证方式"] = args.verification.strip()
    if args.commit:
        task.fields["关联 Commit"] = args.commit.strip()
    insert_task(board, task, prepend=True)
    prune_recent(board, args.keep)
    return {"action": "complete", "task_id": task.task_id, "section": task.section}


def apply_block(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    task = find_task(board, args.id)
    remove_task(board, task)
    task.status = "阻塞"
    if args.depends_on is not None:
        task.fields["依赖"] = normalize_depends(args.depends_on)
    if args.note:
        task.fields["阻塞原因"] = args.note.strip()
    task.fields.pop("当前进展", None)
    task.fields.pop("暂缓原因", None)
    insert_task(board, task)
    return {"action": "block", "task_id": task.task_id, "section": task.section}


def apply_defer(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    task = find_task(board, args.id)
    remove_task(board, task)
    task.status = "暂缓"
    if args.note:
        task.fields["暂缓原因"] = args.note.strip()
    task.fields.pop("当前进展", None)
    task.fields.pop("阻塞原因", None)
    insert_task(board, task)
    return {"action": "defer", "task_id": task.task_id, "section": task.section}


def prune_recent(board: Board, keep: int) -> None:
    if keep < 0:
        raise SystemExit("--keep 必须大于等于 0")
    board.sections["最近完成"] = board.sections["最近完成"][:keep]


def apply_prune_recent(board: Board, args: argparse.Namespace) -> dict[str, Any]:
    before = len(board.sections["最近完成"])
    prune_recent(board, args.keep)
    after = len(board.sections["最近完成"])
    return {"action": "prune-recent", "before": before, "after": after}


def dump_result(result: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    for key, value in result.items():
        print(f"{key}={value}")


def add_output_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Persistent TODO board CLI")
    parser.add_argument("--file", default=str(default_todo_path()), help="Path to TODO.md")
    add_output_args(parser)
    subparsers = parser.add_subparsers(dest="command", required=True)

    add_parser = subparsers.add_parser("add")
    add_output_args(add_parser)
    add_parser.add_argument("--title", required=True)
    add_parser.add_argument("--priority", required=True)
    add_parser.add_argument("--source-step", default="无")
    add_parser.add_argument("--depends-on", action="append")
    add_parser.add_argument("--acceptance", required=True)
    add_parser.add_argument("--status", choices=["未开始", "进行中"], default="未开始")
    add_parser.add_argument("--progress")

    start_parser = subparsers.add_parser("start")
    add_output_args(start_parser)
    start_parser.add_argument("--id", required=True)
    start_parser.add_argument("--progress")

    complete_parser = subparsers.add_parser("complete")
    add_output_args(complete_parser)
    complete_parser.add_argument("--id", required=True)
    complete_parser.add_argument("--verification", required=True)
    complete_parser.add_argument("--commit")
    complete_parser.add_argument("--date")
    complete_parser.add_argument("--keep", type=int, default=12)

    block_parser = subparsers.add_parser("block")
    add_output_args(block_parser)
    block_parser.add_argument("--id", required=True)
    block_parser.add_argument("--depends-on", action="append")
    block_parser.add_argument("--note")

    defer_parser = subparsers.add_parser("defer")
    add_output_args(defer_parser)
    defer_parser.add_argument("--id", required=True)
    defer_parser.add_argument("--note")

    prune_parser = subparsers.add_parser("prune-recent")
    add_output_args(prune_parser)
    prune_parser.add_argument("--keep", type=int, default=12)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    todo_path = Path(args.file).resolve()
    board = parse_board(todo_path)

    if args.command == "add":
        result = apply_add(board, args)
    elif args.command == "start":
        result = apply_start(board, args)
    elif args.command == "complete":
        result = apply_complete(board, args)
    elif args.command == "block":
        result = apply_block(board, args)
    elif args.command == "defer":
        result = apply_defer(board, args)
    elif args.command == "prune-recent":
        result = apply_prune_recent(board, args)
    else:
        raise SystemExit(f"Unsupported command: {args.command}")

    output = render_board(board)
    result["file"] = str(todo_path)
    if args.dry_run:
        result["dry_run"] = True
        result["rendered_length"] = len(output)
        dump_result(result, args.json)
        return

    todo_path.write_text(output, encoding="utf-8")
    result["written"] = True
    dump_result(result, args.json)


if __name__ == "__main__":
    stdout_reconfigure = getattr(sys.stdout, "reconfigure", None)
    stderr_reconfigure = getattr(sys.stderr, "reconfigure", None)
    try:
        if callable(stdout_reconfigure):
            stdout_reconfigure(encoding="utf-8")
        if callable(stderr_reconfigure):
            stderr_reconfigure(encoding="utf-8")
    except Exception:
        pass
    main()
