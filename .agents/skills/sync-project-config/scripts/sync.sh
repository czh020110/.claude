#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

PLATFORM_ARG="${1:-}"
case "$PLATFORM_ARG" in
  codex|Codex|--codex)
    PLATFORM="codex"
    ;;
  zcode|ZCode|--zcode)
    PLATFORM="zcode"
    ;;
  claude|Claude|--claude)
    PLATFORM="claude"
    ;;
  codebuddy|CodeBuddy|workbuddy|WorkBuddy|--codebuddy|--workbuddy)
    PLATFORM="codebuddy"
    ;;
  *)
    echo "用法: ${0##*/} codex|zcode|claude|codebuddy" >&2
    exit 2
    ;;
esac

if [ "$PLATFORM" = "codebuddy" ]; then
  REPO_URL="${PROJECT_CONFIG_REPO_URL:-${CODEBUDDY_CONFIG_REPO_URL:-${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}}}"
else
  REPO_URL="${PROJECT_CONFIG_REPO_URL:-${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}}"
fi

PROJECT_DIR="$(pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SKILL_NAME="sync-project-config"
if [ "$PLATFORM" = "codebuddy" ]; then
  GLOBAL_SKILL_DIR="${CODEBUDDY_GLOBAL_SKILL_DIR:-$HOME/.codebuddy/skills}"
elif [ "$PLATFORM" = "claude" ]; then
  GLOBAL_SKILL_DIR="${CLAUDE_GLOBAL_SKILL_DIR:-$HOME/.claude/skills}"
else
  GLOBAL_SKILL_DIR="${CODEX_GLOBAL_SKILL_DIR:-$HOME/.agents/skills}"
fi

CUSTOM_HEADING='# 自定义提示词说明'

echo "=== sync-project-config ($PLATFORM) ==="
echo "项目目录: $PROJECT_DIR"
echo "远程仓库: $REPO_URL"
echo ""

echo "[1/7] 克隆配置源..."
if ! git clone --depth 1 "$REPO_URL" "$TMP_DIR" 2>&1; then
  echo "错误: 无法克隆仓库" >&2
  exit 1
fi
echo "  克隆完成"
echo ""

copy_tree() {
  local src="$1"
  local dest="$2"
  [ -d "$src" ] || return 0

  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      .cache/*|settings.local.json|*.local.json|*.secret*|*.key|.DS_Store|CODEBUDDY.local.md)
        continue
        ;;
    esac
    local src_file="$src/$rel_path"
    local dest_file="$dest/$rel_path"
    mkdir -p "$(dirname "$dest_file")"
    if cmp -s "$src_file" "$dest_file" 2>/dev/null; then
      continue
    fi
    cp -f "$src_file" "$dest_file"
    echo "  ✓ 同步: ${dest_file#"$PROJECT_DIR/"}"
  done < <(cd "$src" && find . -type f -print0)
}

copy_missing_tree() {
  local src="$1"
  local dest="$2"
  [ -d "$src" ] || return 0

  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      .DS_Store) continue ;;
    esac
    local src_file="$src/$rel_path"
    local dest_file="$dest/$rel_path"
    if [ -f "$dest_file" ]; then
      continue
    fi
    mkdir -p "$(dirname "$dest_file")"
    cp -f "$src_file" "$dest_file"
    echo "  + 新增: ${dest_file#"$PROJECT_DIR/"}"
  done < <(cd "$src" && find . -type f -print0)
}

copy_skill_tree() {
  local src="$1"
  local dest="$2"
  local target_platform="$3"
  [ -d "$src" ] || return 0

  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      */agents/openai.yaml|*/agents/*.yaml|.DS_Store)
        continue
        ;;
    esac
    local src_file="$src/$rel_path"
    local dest_file="$dest/$rel_path"
    mkdir -p "$(dirname "$dest_file")"
    if [[ "$rel_path" == */SKILL.md ]]; then
      python3 - "$src_file" "$dest_file" "$target_platform" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
platform = sys.argv[3]
text = source.read_text(encoding="utf-8")
if not text.startswith("---\n"):
    target.write_text(text, encoding="utf-8")
    raise SystemExit

end = text.find("\n---\n", 4)
if end < 0:
    target.write_text(text, encoding="utf-8")
    raise SystemExit

front = text[4:end].splitlines()
body = text[end + len("\n---\n"):]
if platform in {"claude", "codebuddy"} and not any(line.startswith("user-invocable:") for line in front):
    front.append("user-invocable: true")
target.write_text("---\n" + "\n".join(front) + "\n---\n" + body, encoding="utf-8")
PY
    elif [[ "$rel_path" == sync-project-memory/scripts/sync-memory.sh && "$target_platform" != "zcode" ]]; then
      python3 - "$src_file" "$dest_file" "$target_platform" <<'PY'
import sys
from pathlib import Path

source, target, platform = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
text = source.read_text(encoding="utf-8")
prefix = {"claude": ".claude", "codebuddy": ".codebuddy"}[platform]
text = text.replace(".agents/.cache", f"{prefix}/.cache")
text = text.replace(".agents/skills/sync-project-memory/scripts/sync-memory.sh", f"{prefix}/skills/sync-project-memory/scripts/sync-memory.sh")
target.write_text(text, encoding="utf-8")
PY
    else
      cp -f "$src_file" "$dest_file"
    fi
    echo "  ✓ Skill: ${dest_file#"$PROJECT_DIR/"}"
  done < <(cd "$src" && find . -type f -print0)
}

generate_agents() {
  local src="$1"
  local dest="$2"
  local target_platform="$3"
  [ -d "$src" ] || return 0
  mkdir -p "$dest"

  python3 - "$src" "$dest" "$target_platform" <<'PY'
import json
import re
import sys
from pathlib import Path

source_dir = Path(sys.argv[1])
target_dir = Path(sys.argv[2])
platform = sys.argv[3]

claude_models = {
    "code_review_custom": "sonnet",
    "docs_research": "haiku",
}
codebuddy_tools = {
    "code_review_custom": ("Read, Grep, Glob, Bash", "Edit, Write"),
    "collect_update_memory": ("Read, Grep, Glob, Bash, Write, Edit", ""),
    "docs_research": ("Read, Grep, Glob, Bash, WebFetch", "Edit, Write"),
}

for source in sorted(source_dir.glob("*.toml")):
    text = source.read_text(encoding="utf-8")
    name_match = re.search(r'^name\s*=\s*"([^"]+)"', text, re.MULTILINE)
    desc_match = re.search(r'^description\s*=\s*"([^"]*)"', text, re.MULTILINE)
    body_match = re.search(r'developer_instructions\s*=\s*"""\n(.*?)\n"""', text, re.DOTALL)
    if not (name_match and desc_match and body_match):
        raise SystemExit(f"无法解析 Codex agent: {source}")

    source_name = name_match.group(1)
    target_name = source_name.replace("_", "-")
    description = desc_match.group(1)
    body = body_match.group(1)
    lines = [
        "---",
        f"name: {target_name}",
        f"description: {json.dumps(description, ensure_ascii=False)}",
    ]
    if platform == "claude" and source_name in claude_models:
        lines.append(f"model: {claude_models[source_name]}")
    elif platform == "zcode":
        lines.append("model: glm-5.3-flash")
    elif platform == "codebuddy":
        tools, disallowed = codebuddy_tools.get(source_name, ("", ""))
        if tools:
            lines.append(f"tools: {tools}")
        if disallowed:
            lines.append(f"disallowedTools: {disallowed}")
    lines += ["---", body, ""]
    (target_dir / f"{target_name}.md").write_text("\n".join(lines), encoding="utf-8")
PY

  echo "  ✓ Agent: $dest"
}

adapt_agent_tools() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import sys
from pathlib import Path

path, heading, from1, to1, from2, to2 = sys.argv[1:7]
text = Path(path).read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
rule_end = len(lines)
for i, line in enumerate(lines):
    if line.rstrip("\n") == heading:
        rule_end = i
        break
rule = "".join(lines[:rule_end]).replace(from1, to1).replace(from2, to2)
Path(path).write_text(rule + "".join(lines[rule_end:]), encoding="utf-8")
PY
}

sync_agents_md() {
  local remote="$TMP_DIR/AGENTS.md"
  local local_file="$PROJECT_DIR/AGENTS.md"
  [ -f "$remote" ] || return 0

  if [ ! -f "$local_file" ]; then
    cp "$remote" "$local_file"
  elif grep -qxF "$CUSTOM_HEADING" "$local_file" && grep -qxF "$CUSTOM_HEADING" "$remote"; then
    local remote_end local_start
    remote_end=$(grep -n -xF "$CUSTOM_HEADING" "$remote" | head -1 | cut -d: -f1)
    local_start=$(grep -n -xF "$CUSTOM_HEADING" "$local_file" | head -1 | cut -d: -f1)
    head -n "$((remote_end - 1))" "$remote" > "$local_file.tmp"
    tail -n +"$local_start" "$local_file" >> "$local_file.tmp"
    mv "$local_file.tmp" "$local_file"
  else
    cp "$remote" "$local_file"
  fi

  if [ "$PLATFORM" = "zcode" ]; then
    adapt_agent_tools "$local_file" "$CUSTOM_HEADING" update_plan TodoWrite request_user_input AskUserQuestion
  fi
}

sync_claude_md() {
  [ "$PLATFORM" = "claude" ] || return 0
  local remote="$TMP_DIR/AGENTS.md"
  [ -f "$remote" ] || return 0
  local target="$PROJECT_DIR/CLAUDE.md"
  local tmp="$PROJECT_DIR/CLAUDE.md.tmp"
  if grep -qxF "$CUSTOM_HEADING" "$remote"; then
    local remote_end
    remote_end=$(grep -n -xF "$CUSTOM_HEADING" "$remote" | head -1 | cut -d: -f1)
    head -n "$((remote_end - 1))" "$remote" > "$tmp"
    adapt_agent_tools "$tmp" "$CUSTOM_HEADING" update_plan TaskCreate request_user_input AskUserQuestion
    if [ -f "$target" ] && grep -qxF "$CUSTOM_HEADING" "$target"; then
      local custom_start
      custom_start=$(grep -n -xF "$CUSTOM_HEADING" "$target" | head -1 | cut -d: -f1)
      tail -n +"$custom_start" "$target" >> "$tmp"
    else
      tail -n +"$remote_end" "$remote" >> "$tmp"
    fi
    mv "$tmp" "$target"
  else
    cp "$remote" "$target"
  fi
}

sync_platform() {
  case "$PLATFORM" in
    codex)
      copy_tree "$TMP_DIR/.codex" "$PROJECT_DIR/.codex"
      copy_tree "$TMP_DIR/.agents" "$PROJECT_DIR/.agents"
      ;;
    zcode)
      copy_tree "$TMP_DIR/.zcode" "$PROJECT_DIR/.zcode"
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.agents/skills" zcode
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.zcode/agents" zcode
      ;;
    claude)
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.claude/agents" claude
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.claude/skills" claude
      ;;
    codebuddy)
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.codebuddy/agents" codebuddy
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.codebuddy/skills" codebuddy
      if [ -f "$TMP_DIR/.mcp.json" ] && [ ! -f "$PROJECT_DIR/.mcp.json" ]; then
        cp "$TMP_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json"
      fi
      ;;
  esac
}

sync_global_skill() {
  local source=""
  for candidate in "$PROJECT_DIR/.agents/skills/$SKILL_NAME" "$TMP_DIR/.agents/skills/$SKILL_NAME"; do
    if [ -d "$candidate" ]; then
      source="$candidate"
      break
    fi
  done
  [ -n "$source" ] || return 0
  mkdir -p "$GLOBAL_SKILL_DIR"
  rm -rf "$GLOBAL_SKILL_DIR/$SKILL_NAME"
  cp -R "$source" "$GLOBAL_SKILL_DIR/$SKILL_NAME"
  echo "  ✓ 全局 Skill: $GLOBAL_SKILL_DIR/$SKILL_NAME"
  if [ "$PLATFORM" = "zcode" ] && [ -d "$HOME/.zcode/skills" ]; then
    rm -rf "$HOME/.zcode/skills/$SKILL_NAME"
    cp -R "$source" "$HOME/.zcode/skills/$SKILL_NAME"
  fi
}

sync_agents_md
sync_claude_md
echo "[2/7] 同步 AGENTS.md 与全局 Skill..."
sync_global_skill
echo ""

echo "[3/7] 生成平台 Agent/Skill..."
sync_platform
echo ""

echo "[4/7] 同步项目记忆模板..."
copy_missing_tree "$TMP_DIR/.project-memory" "$PROJECT_DIR/.project-memory"
echo ""

echo "[5/7] 同步项目验证模板..."
copy_missing_tree "$TMP_DIR/.project-script" "$PROJECT_DIR/.project-script"
echo ""

echo "[6/7] 检查 .gitignore..."
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ "$PLATFORM" = "codebuddy" ]; then
  ENTRIES=( ".project-memory/" ".project-script/" ".codebuddy/settings.local.json" ".codebuddy/CODEBUDDY.local.md" ".codebuddy/.cache/" )
  HEADER="# CodeBuddy / 项目本地配置"
else
  ENTRIES=( ".codex/" ".zcode/" ".claude/" ".agents/" ".project-memory/" ".project-script/" "AGENTS.md" "CLAUDE.md" )
  HEADER="# Agent / 项目本地配置"
fi
if [ ! -f "$GITIGNORE" ]; then
  for entry in "${ENTRIES[@]}"; do printf '%s\n' "$entry"; done > "$GITIGNORE"
else
  missing=""
  for entry in "${ENTRIES[@]}"; do
    if ! grep -qxF "$entry" "$GITIGNORE" 2>/dev/null && ! grep -qxF "${entry%/}" "$GITIGNORE" 2>/dev/null; then
      missing="${missing}${entry}"$'\n'
    fi
  done
  if [ -n "$missing" ]; then
    [ -s "$GITIGNORE" ] && [ -n "$(tail -c1 "$GITIGNORE")" ] && printf '\n' >> "$GITIGNORE"
    printf '\n%s\n' "$HEADER" >> "$GITIGNORE"
    printf '%s' "$missing" >> "$GITIGNORE"
  fi
fi
echo ""

echo "[7/7] 同步完成"
