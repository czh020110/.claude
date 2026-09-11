#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}"
PROJECT_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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

echo "=== sync-codex-project-config ==="
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
  elif grep -qxF "$CUSTOM_HEADING" "$LOCAL_AGENTS" && grep -qxF "$CUSTOM_HEADING" "$REMOTE_AGENTS"; then
    remote_end=$(grep -n -xF "$CUSTOM_HEADING" "$REMOTE_AGENTS" | head -1 | cut -d: -f1)
    local_start=$(grep -n -xF "$CUSTOM_HEADING" "$LOCAL_AGENTS" | head -1 | cut -d: -f1)

    if cmp -s <(head -n "$((remote_end - 1))" "$REMOTE_AGENTS") <(head -n "$((local_start - 1))" "$LOCAL_AGENTS"); then
      echo "  = 跳过(规则区相同): AGENTS.md"
    else
      head -n "$((remote_end - 1))" "$REMOTE_AGENTS" > "$LOCAL_AGENTS.tmp"
      tail -n +"$local_start" "$LOCAL_AGENTS" >> "$LOCAL_AGENTS.tmp"
      mv "$LOCAL_AGENTS.tmp" "$LOCAL_AGENTS"
      echo "  ✓ 更新 AGENTS.md 规则区（保留自定义提示词区）"
    fi
  else
    cp "$REMOTE_AGENTS" "$LOCAL_AGENTS"
    echo "  ✓ 覆盖 AGENTS.md（本地缺少自定义提示词标题，无法增量合并）"
  fi
fi
echo ""

# 3. 同步 .codex/（config.toml、agents/*.toml、rules 默认文件覆盖；缓存/本地敏感跳过）
echo "[3/8] 同步 .codex/ 目录..."
synced_count=0
if [ -d "$TMP_DIR/.codex" ]; then
  cd "$TMP_DIR/.codex"
  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      .cache/*|settings.local.json|*.local.json|*.secret*|*.key)
        echo "  = 跳过(本地/敏感): .codex/$rel_path"
        continue
        ;;
    esac
    local_path="$PROJECT_DIR/.codex/$rel_path"
    if cmp -s "$rel_path" "$local_path" 2>/dev/null; then
      echo "  = 跳过(内容相同): .codex/$rel_path"
    else
      mkdir -p "$(dirname "$local_path")"
      case "$rel_path" in
        agents/*.toml)
          if [ -f "$local_path" ] && grep -E '^model[[:space:]]*=' "$local_path" >/dev/null 2>&1; then
            merge_agent_model "$rel_path" "$local_path"
          else
            cp -f "$rel_path" "$local_path"
            echo "  ✓ 覆盖: .codex/$rel_path"
          fi
          ;;
        *)
          cp -f "$rel_path" "$local_path"
          echo "  ✓ 覆盖: .codex/$rel_path"
          ;;
      esac
      synced_count=$((synced_count + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  cd "$PROJECT_DIR"
  if [ "$synced_count" -eq 0 ]; then echo "  (无需要覆盖的文件)"; fi
else
  echo "  远程仓库无 .codex/ 目录"
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
  printf '.codex/\n.agents/\n.project-memory/\n.project-script/\n' > "$GITIGNORE"
  echo "  + 创建 .gitignore"
else
  missing_list=""
  for entry in '.codex/' '.agents/' '.project-memory/' '.project-script/'; do
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
