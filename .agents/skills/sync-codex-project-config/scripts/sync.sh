#!/usr/bin/env bash
set -euo pipefail

# macOS 自带 bash 3.2 在 UTF-8 locale 下解析脚本中的多字节字符存在缺陷（变量名会吞入
# 相邻中文字节，报 unbound variable）。统一切到 C locale 按字节处理：脚本内 grep/cmp
# 均为字节精确比较，中文仅作输出文本，语义不受影响。
export LC_ALL=C

# 平台参数：sync.sh codex | sync.sh zcode
PLATFORM_ARG="${1:-codex}"
case "$PLATFORM_ARG" in
  codex|Codex|--codex)
    PLATFORM="codex"
    ;;
  zcode|ZCode|--zcode)
    PLATFORM="zcode"
    ;;
  *)
    echo "错误: 未知平台 '$PLATFORM_ARG'。可用值: codex / zcode" >&2
    exit 2
    ;;
esac
if [ "$PLATFORM" = "codex" ]; then
  PLATFORM_DIR=".codex"
else
  PLATFORM_DIR=".zcode"
fi

REPO_URL="${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}"
PROJECT_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# 全局 skill 目录：默认 ~/.agents/skills，可用 CODEX_GLOBAL_SKILL_DIR 覆盖
GLOBAL_SKILL_DIR="${CODEX_GLOBAL_SKILL_DIR:-$HOME/.agents/skills}"
SKILL_NAME="sync-codex-project-config"

# 同步 agent toml 时保留本地用户自定义 model 字段：远程默认模型不覆盖项目本地设置。
merge_agent_model() {
  local remote_file="$1"
  local local_file="$2"
  local model_line
  model_line="$(grep -E '^model[[:space:]]*=' "$local_file" 2>/dev/null || true)"
  if [ -n "$model_line" ]; then
    python3 - "$remote_file" "$local_file" "$model_line" <<'PY'
import sys
from pathlib import Path

remote, local, model_line = sys.argv[1], sys.argv[2], sys.argv[3]
text = Path(remote).read_text(encoding="utf-8")
out = []
for line in text.splitlines(keepends=True):
    if line.lstrip().startswith("model =") or line.lstrip().startswith("model="):
        out.append(model_line.rstrip("\n") + "\n")
    else:
        out.append(line)
Path(local).write_text("".join(out), encoding="utf-8")
PY
    echo "  ✓ 覆盖(保留本地 model): $local_file"
  else
    cp -f "$remote_file" "$local_file"
    echo "  ✓ 覆盖: $local_file"
  fi
}

# zcode 平台工具名适配：模板 AGENTS.md 使用 Codex 工具名，zcode 下替换为对应工具名。
# 只替换「自定义提示词说明」标题之前的规则区；无该标题时替换整个文件。
adapt_agent_tools() {
  python3 - "$1" "$2" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
heading = sys.argv[2]
text = path.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
rule_end = len(lines)
for i, line in enumerate(lines):
    if line.rstrip("\n") == heading:
        rule_end = i
        break
rule = "".join(lines[:rule_end]).replace("update_plan", "TodoWrite").replace("request_user_input", "AskUserQuestion")
path.write_text(rule + "".join(lines[rule_end:]), encoding="utf-8")
PY
}

# 仅当平台为 zcode 时对文件执行工具名适配
adapt_agent_tools_if_zcode() {
  if [ "$PLATFORM" = "zcode" ]; then
    adapt_agent_tools "$1" "$CUSTOM_HEADING"
    echo "  ✓ ZCode 工具名适配: update_plan→TodoWrite, request_user_input→AskUserQuestion"
  fi
}

echo "=== sync-codex-project-config ($PLATFORM) ==="
echo "项目目录: $PROJECT_DIR"
echo "远程仓库: $REPO_URL"
echo ""

# 1. 克隆远程仓库
echo "[1/8] 克隆远程仓库..."
if ! git clone --depth 1 "$REPO_URL" "$TMP_DIR" 2>&1; then
  echo "错误: 无法克隆仓库"
  exit 1
fi
echo "  克隆完成"
echo ""

# 1.5 全局自同步：把本 skill 覆盖到各 agent 的全局 skill 目录（codex / zcode / claude code 均可用）
echo "[1.5/8] 同步本 skill 到全局目录..."
SELF_SOURCE=""
SELF_SOURCE_DESC=""
if [ -d "${PROJECT_DIR}/.agents/skills/${SKILL_NAME}" ]; then
  # 优先使用当前项目里的版本（可能包含本地未提交修改）
  SELF_SOURCE="${PROJECT_DIR}/.agents/skills/${SKILL_NAME}"
  SELF_SOURCE_DESC="当前项目"
elif [ -d "${TMP_DIR}/.agents/skills/${SKILL_NAME}" ]; then
  SELF_SOURCE="${TMP_DIR}/.agents/skills/${SKILL_NAME}"
  SELF_SOURCE_DESC="模板仓库"
fi
install_self_to_global() {
  # 整目录先删后拷：清掉旧版本残留文件；rm 生成新 inode，从全局副本运行本脚本时
  # 不会截断正在执行的脚本文件（原地覆盖有执行中途损坏风险）。
  local dest_root="$1"
  mkdir -p "${dest_root}"
  rm -rf "${dest_root:?}/${SKILL_NAME}"
  cp -R "${SELF_SOURCE}" "${dest_root}/${SKILL_NAME}"
  echo "  ✓ 覆盖全局 skill: ${dest_root}/${SKILL_NAME}（来自${SELF_SOURCE_DESC}）"
}
if [ -n "${SELF_SOURCE}" ]; then
  # 全局 skill 首选 ~/.agents/skills：Codex 与 Zcode 都按 .agents 约定读取该目录
  install_self_to_global "${GLOBAL_SKILL_DIR}"
  # ZCode 中 ~/.zcode/skills 优先级高于 ~/.agents/skills，已存在同名副本时必须一并刷新，
  # 否则旧副本会遮蔽更新结果；不存在时不创建（ZCode 已读取 ~/.agents/skills）。
  if [ -d "${HOME}/.zcode/skills/${SKILL_NAME}" ]; then
    install_self_to_global "${HOME}/.zcode/skills"
  fi
  # Claude Code 不读 ~/.agents/skills，只认 ~/.claude/skills：检测到 ~/.claude（用户装有
  # Claude Code）时确保最新副本，保证三个 agent 都能用；未安装时不创建。
  if [ -d "${HOME}/.claude" ]; then
    install_self_to_global "${HOME}/.claude/skills"
  fi
else
  echo "  = 模板仓库与当前项目均无此 skill，跳过全局同步"
fi
echo ""

# 2. 同步 AGENTS.md —— 只更新规则区，保留本地「自定义提示词」区
echo "[2/8] 同步 AGENTS.md..."
REMOTE_AGENTS="$TMP_DIR/AGENTS.md"
LOCAL_AGENTS="$PROJECT_DIR/AGENTS.md"
# 规则区 = `# 自定义提示词说明` 之前的内容；自定义提示词区 = 该标题之后的内容（含该标题）。
# 说明：规则正文里本身含 `---` 分隔线，不能用 `---` 作为切分依据。
CUSTOM_HEADING='# 自定义提示词说明'
if [ -f "$REMOTE_AGENTS" ]; then
  if [ ! -f "$LOCAL_AGENTS" ]; then
    mkdir -p "$(dirname "$LOCAL_AGENTS")"
    cp "$REMOTE_AGENTS" "$LOCAL_AGENTS"
    echo "  + 新增: AGENTS.md"
    adapt_agent_tools_if_zcode "$LOCAL_AGENTS"
  elif grep -qxF "$CUSTOM_HEADING" "$LOCAL_AGENTS" && grep -qxF "$CUSTOM_HEADING" "$REMOTE_AGENTS"; then
    remote_end=$(grep -n -xF "$CUSTOM_HEADING" "$REMOTE_AGENTS" | head -1 | cut -d: -f1)
    local_start=$(grep -n -xF "$CUSTOM_HEADING" "$LOCAL_AGENTS" | head -1 | cut -d: -f1)

    already_adapted=0
    if [ "$PLATFORM" = "zcode" ]; then
      # zcode 下规则区与远程一致但仍是 Codex 工具名时，需要做工具名适配
      if cmp -s <(head -n "$((remote_end - 1))" "$REMOTE_AGENTS" | sed -e 's/update_plan/TodoWrite/g' -e 's/request_user_input/AskUserQuestion/g') <(head -n "$((local_start - 1))" "$LOCAL_AGENTS"); then
        already_adapted=1
      fi
    fi

    if [ "$already_adapted" -eq 1 ]; then
      echo "  = 跳过(规则区相同): AGENTS.md"
    else
      head -n "$((remote_end - 1))" "$REMOTE_AGENTS" > "$LOCAL_AGENTS.tmp"
      adapt_agent_tools_if_zcode "$LOCAL_AGENTS.tmp"
      tail -n +"$local_start" "$LOCAL_AGENTS" >> "$LOCAL_AGENTS.tmp"
      mv "$LOCAL_AGENTS.tmp" "$LOCAL_AGENTS"
      echo "  ✓ 更新 AGENTS.md 规则区（保留自定义提示词区）"
    fi
  else
    cp "$REMOTE_AGENTS" "$LOCAL_AGENTS"
    echo "  ✓ 覆盖 AGENTS.md（本地缺少自定义提示词标题，无法增量合并）"
    adapt_agent_tools_if_zcode "$LOCAL_AGENTS"
  fi
fi
echo ""

# 3. 同步平台目录（codex: .codex，zcode: .zcode；缓存/本地敏感跳过）
echo "[3/8] 同步 $PLATFORM_DIR/ 目录..."
synced_count=0
# zcode 模式下优先使用远程 .zcode/；远程只有 .codex/ 时把它当作平台目录内容
if [ "$PLATFORM" = "zcode" ] && [ -d "$TMP_DIR/.zcode" ]; then
  PLATFORM_DIR=".zcode"
elif [ "$PLATFORM" = "zcode" ]; then
  PLATFORM_DIR=".codex"
fi
if [ -d "$TMP_DIR/$PLATFORM_DIR" ]; then
  cd "$TMP_DIR/$PLATFORM_DIR"
  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      .cache/*|settings.local.json|*.local.json|*.secret*|*.key)
        echo "  = 跳过(本地/敏感): $PLATFORM_DIR/$rel_path"
        continue
        ;;
    esac
    local_path="$PROJECT_DIR/$PLATFORM_DIR/$rel_path"
    if cmp -s "$rel_path" "$local_path" 2>/dev/null; then
      echo "  = 跳过(内容相同): $PLATFORM_DIR/$rel_path"
    else
      mkdir -p "$(dirname "$local_path")"
      case "$rel_path" in
        config.toml)
          if [ -f "$local_path" ]; then
            # 只把远程 config.toml 中本地缺失的 table 整块与顶级键追加，不拆散字段。
            python3 - "$rel_path" "$local_path" <<'PY'
import sys
from pathlib import Path

remote_text = Path(sys.argv[1]).read_text(encoding="utf-8")
local_text = Path(sys.argv[2]).read_text(encoding="utf-8")

# 本项目 config.toml 不需要完整 TOML 解析：按 table 头切块即可。
# TOML 语义：table 头之后的所有键都属于该 table（无论是否缩进），
# 直到下一个 table 头为止；只有第一个 table 头之前的键是顶级键。
def is_table_header(line):
    s = line.strip()
    return s.startswith("[") and s.endswith("]")

def split_blocks(text):
    blocks = []
    current_header = None
    current_lines = []
    for line in text.splitlines():
        if is_table_header(line):
            if current_header is not None:
                blocks.append(("table", current_header, current_lines))
            elif current_lines:
                blocks.append(("top", None, current_lines))
            current_header = line.strip()
            current_lines = [line.rstrip()]
        elif current_header is not None:
            # table 块只保留 `key = value` 行，跳过注释，避免把后续注释当字段带进来
            if line.strip() and not line.lstrip().startswith("#"):
                current_lines.append(line.rstrip())
        else:
            current_lines.append(line.rstrip())
    if current_header is not None:
        blocks.append(("table", current_header, current_lines))
    elif current_lines:
        blocks.append(("top", None, current_lines))
    return blocks

# 解析本地已有的顶级键和 table 名
local_lines = local_text.splitlines()
existing_top_keys = set()
existing_tables = set()
current = None
for line in local_lines:
    s = line.strip()
    if is_table_header(line):
        current = s
    elif s and not s.startswith("#") and "=" in s:
        key = s.split("=", 1)[0].strip()
        if current is None:
            existing_top_keys.add(key)
        else:
            existing_tables.add(current)

missing_blocks = []
for kind, header, lines in split_blocks(remote_text):
    if kind == "table":
        if header not in existing_tables:
            missing_blocks.append("\n".join(lines))
    else:
        # 顶级块：只补缺失的键行，不复制注释
        for line in lines:
            s = line.strip()
            if s and not s.startswith("#") and "=" in s:
                key = s.split("=", 1)[0].strip()
                if key not in existing_top_keys:
                    missing_blocks.append(line)

if missing_blocks:
    with Path(sys.argv[2]).open("a", encoding="utf-8") as f:
        for block in missing_blocks:
            f.write("\n# synced from template\n" + block + "\n")
PY
            echo "  ✓ 合并 config.toml（只追加新增字段）"
          else
            cp -f "$rel_path" "$local_path"
            echo "  ✓ 新增: $PLATFORM_DIR/$rel_path"
          fi
          ;;
        config.json)
          if [ -f "$local_path" ]; then
            # 只把远程 config.json 中本地缺失的 mcp server 追加进本地文件，不覆盖本地已有配置。
            if ! python3 - "$rel_path" "$local_path" <<'PY'
import json
import sys
from pathlib import Path

remote_path, local_path = Path(sys.argv[1]), Path(sys.argv[2])
try:
    remote = json.loads(remote_path.read_text(encoding="utf-8"))
    local = json.loads(local_path.read_text(encoding="utf-8"))
except (json.JSONDecodeError, OSError) as exc:
    print(f"  警告: config.json 合并跳过（解析失败: {exc}）", file=sys.stderr)
    sys.exit(1)

remote_servers = remote.get("mcp", {}).get("servers", {})
if not isinstance(remote_servers, dict):
    remote_servers = {}
local_servers = local.setdefault("mcp", {}).setdefault("servers", {})
if not isinstance(local_servers, dict):
    local_servers = {}
    local["mcp"]["servers"] = local_servers

missing = {name: cfg for name, cfg in remote_servers.items() if name not in local_servers}
if not missing:
    print("  = config.json 无新增 mcp server")
    sys.exit(1)

local_servers.update(missing)
local_path.write_text(json.dumps(local, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("  ✓ 合并 config.json（追加 mcp server: " + ", ".join(sorted(missing)) + "）")
PY
            then
              : # python 已输出跳过原因或无新增说明
            fi
          else
            cp -f "$rel_path" "$local_path"
            echo "  ✓ 新增: $PLATFORM_DIR/$rel_path"
          fi
          ;;
        agents/*.toml)
          if [ -f "$local_path" ] && grep -E '^model[[:space:]]*=' "$local_path" >/dev/null 2>&1; then
            merge_agent_model "$rel_path" "$local_path"
          else
            cp -f "$rel_path" "$local_path"
            echo "  ✓ 覆盖: $PLATFORM_DIR/$rel_path"
          fi
          ;;
        *)
          cp -f "$rel_path" "$local_path"
          echo "  ✓ 覆盖: $PLATFORM_DIR/$rel_path"
          ;;
      esac
      synced_count=$((synced_count + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  cd "$PROJECT_DIR"
  if [ "$synced_count" -eq 0 ]; then echo "  (无需要覆盖的文件)"; fi
else
echo "  远程仓库无 $PLATFORM_DIR/ 目录"
fi
echo ""

# 4. 同步 .agents/skills/（SKILL.md 与 agents/openai.yaml 等直接覆盖）
synced_skills=0
echo "[4/8] 同步 .agents/skills/ 目录..."
if [ -d "$TMP_DIR/.agents/skills" ]; then
  cd "$TMP_DIR/.agents/skills"
  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    local_path="$PROJECT_DIR/.agents/skills/$rel_path"
    if cmp -s "$rel_path" "$local_path" 2>/dev/null; then
      echo "  = 跳过(内容相同): .agents/skills/$rel_path"
    else
      mkdir -p "$(dirname "$local_path")"
      cp -f "$rel_path" "$local_path"
      echo "  ✓ 覆盖: .agents/skills/$rel_path"
      synced_skills=$((synced_skills + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  cd "$PROJECT_DIR"
  echo "  覆盖: $synced_skills"
else
  echo "  远程仓库无 .agents/skills/ 目录"
fi
echo ""

# 5. 同步 .project-memory/（仅添加本地不存在的文件）
echo "[5/8] 同步 .project-memory/ 目录 (仅添加不存在的文件)..."
memory_added=0
memory_skipped=0
if [ -d "$TMP_DIR/.project-memory" ]; then
  cd "$TMP_DIR/.project-memory"
  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    if [[ "$rel_path" == TODO/DONE.md ]]; then
      echo "  = 跳过(已弃用): .project-memory/$rel_path"
      continue
    fi
    local_path="$PROJECT_DIR/.project-memory/$rel_path"
    if [ ! -f "$local_path" ]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$rel_path" "$local_path"
      echo "  + 新增: .project-memory/$rel_path"
      memory_added=$((memory_added + 1))
    else
      echo "  = 跳过(已存在): .project-memory/$rel_path"
      memory_skipped=$((memory_skipped + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  cd "$PROJECT_DIR"
  echo "  新增: $memory_added, 跳过: $memory_skipped"
else
  echo "  远程仓库无 .project-memory/ 目录"
fi
echo ""

# 6. 同步 .project-script/（仅添加本地不存在的文件）
echo "[6/8] 同步 .project-script/ 目录 (仅添加不存在的文件)..."
script_added=0
script_skipped=0
if [ -d "$TMP_DIR/.project-script" ]; then
  cd "$TMP_DIR/.project-script"
  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    local_path="$PROJECT_DIR/.project-script/$rel_path"
    if [ ! -f "$local_path" ]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$rel_path" "$local_path"
      echo "  + 新增: .project-script/$rel_path"
      script_added=$((script_added + 1))
    else
      echo "  = 跳过(已存在): .project-script/$rel_path"
      script_skipped=$((script_skipped + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  cd "$PROJECT_DIR"
  echo "  新增: $script_added, 跳过: $script_skipped"
else
  echo "  远程仓库无 .project-script/ 目录"
fi
echo ""

# 7. 管理下游项目 .gitignore
echo "[7/8] 检查下游项目 .gitignore..."
GITIGNORE="$PROJECT_DIR/.gitignore"

# 条目是否已存在（同时兼容带/不带尾斜杠的写法）
gitignore_has_entry() {
  local entry="$1"
  grep -qxF "$entry" "$GITIGNORE" 2>/dev/null || grep -qxF "${entry%/}" "$GITIGNORE" 2>/dev/null
}

if [ ! -f "$GITIGNORE" ]; then
  printf '.codex/\n.zcode/\n.agents/\n.project-memory/\n.project-script/\nAGENTS.md\n' > "$GITIGNORE"
  echo "  + 创建 .gitignore"
else
  missing_list=""
  for entry in '.codex/' '.zcode/' '.agents/' '.project-memory/' '.project-script/' 'AGENTS.md'; do
    if ! gitignore_has_entry "$entry"; then
      missing_list="${missing_list}${entry}"$'\n'
    fi
  done

  if [ -n "$missing_list" ]; then
    if [ -s "$GITIGNORE" ]; then
      # 文件末尾无换行时先补一个，避免与已有内容粘连
      if [ -n "$(tail -c1 "$GITIGNORE")" ]; then
        printf '\n' >> "$GITIGNORE"
      fi
      printf '\n# Codex / 项目本地配置\n' >> "$GITIGNORE"
    else
      printf '# Codex / 项目本地配置\n' >> "$GITIGNORE"
    fi
    printf '%s' "$missing_list" >> "$GITIGNORE"
    while IFS= read -r entry; do
      [ -n "$entry" ] && echo "  + 追加 $entry 到 .gitignore"
    done <<< "$missing_list"
  else
    echo "  .gitignore 已包含所需条目，无需修改"
  fi
fi
echo ""

# 8. 清理（trap 已处理）
echo "[8/8] 同步完成"
