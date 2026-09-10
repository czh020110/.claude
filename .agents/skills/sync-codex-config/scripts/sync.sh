#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}"
PROJECT_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== sync-codex-config ==="
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

# 2. 同步 AGENTS.md —— 保留本地非托管区（如有）
echo "[2/8] 同步 AGENTS.md..."
REMOTE_AGENTS="$TMP_DIR/AGENTS.md"
LOCAL_AGENTS="$PROJECT_DIR/AGENTS.md"
if [ -f "$REMOTE_AGENTS" ]; then
  if [ ! -f "$LOCAL_AGENTS" ]; then
    mkdir -p "$(dirname "$LOCAL_AGENTS")"
    cp "$REMOTE_AGENTS" "$LOCAL_AGENTS"
    echo "  + 新增: AGENTS.md"
  elif grep -q '<!-- CODEX-CONFIG:MANAGED:BEGIN -->' "$LOCAL_AGENTS" && grep -q '<!-- CODEX-CONFIG:MANAGED:END -->' "$LOCAL_AGENTS"; then
    custom=$(awk '/<!-- CODEX-CONFIG:MANAGED:END -->/{found=1; next} found{print}' "$LOCAL_AGENTS")
    managed=$(awk '/<!-- CODEX-CONFIG:MANAGED:BEGIN -->/{print; print; found=1; next} found && /<!-- CODEX-CONFIG:MANAGED:END -->/{print; found=0; next} found{next} {print}' "$REMOTE_AGENTS" | sed '/^$/N;/^\n$/D')
    # 更稳妥：直接以远程托管区 + 本地自定义区合并
    begin=$(grep -n '<!-- CODEX-CONFIG:MANAGED:BEGIN -->' "$REMOTE_AGENTS" | head -1 | cut -d: -f1)
    end=$(grep -n '<!-- CODEX-CONFIG:MANAGED:END -->' "$REMOTE_AGENTS" | head -1 | cut -d: -f1)
    if [ -n "$begin" ] && [ -n "$end" ]; then
      head -n "$end" "$REMOTE_AGENTS" > "$LOCAL_AGENTS.tmp"
      if [ -n "$custom" ]; then
        printf '\n%s\n' "$custom" >> "$LOCAL_AGENTS.tmp"
      fi
      mv "$LOCAL_AGENTS.tmp" "$LOCAL_AGENTS"
      echo "  ✓ 更新 AGENTS.md 托管区块（保留自定义区）"
    fi
  else
    cp "$REMOTE_AGENTS" "$LOCAL_AGENTS"
    echo "  ✓ 覆盖 AGENTS.md"
  fi
fi
echo ""

# 3. 同步 .codex/（config.toml、agents/*.toml、rules 默认文件覆盖；缓存/本地敏感跳过）
echo "[3/8] 同步 .codex/ 目录..."
synced_count=0
if [ -d "$TMP_DIR/.codex" ]; then
  cd "$TMP_DIR/.codex"
  while IFS= read -r -d '' rel_path; do
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
      cp -f "$rel_path" "$local_path"
      echo "  ✓ 覆盖: .codex/$rel_path"
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
if [ ! -f "$GITIGNORE" ]; then
  printf '.codex/\n.agents/\n.project-memory/\n.project-script/\n' > "$GITIGNORE"
  echo "  + 创建 .gitignore"
else
  for entry in '.codex/' '.agents/' '.project-memory/' '.project-script/'; do
    if ! grep -q "^$entry" "$GITIGNORE"; then
      echo "$entry" >> "$GITIGNORE"
      echo "  + 追加 $entry 到 .gitignore"
    fi
  done
fi
echo ""

# 8. 清理（trap 已处理）
echo "[8/8] 同步完成"
