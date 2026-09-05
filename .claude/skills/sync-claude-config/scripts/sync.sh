#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/czh020110/.claude.git"
PROJECT_DIR="$(pwd)"
TMP_DIR=$(mktemp -d)

echo "=== sync-claude-config ==="
echo "项目目录: $PROJECT_DIR"
echo "远程仓库: $REPO_URL"
echo ""

# 1. 克隆远程仓库
echo "[1/7] 克隆远程仓库..."
if ! git clone --depth 1 "$REPO_URL" "$TMP_DIR" 2>&1; then
  echo "错误: 无法克隆仓库"
  rm -rf "$TMP_DIR"
  exit 1
fi
echo "  克隆完成"
echo ""

# 2. 同步 .claude/ 目录（除 CLAUDE.md 和 agents/*.md 外直接覆盖）
echo "[2/7] 同步 .claude/ 目录..."
if [ -d "$TMP_DIR/.claude" ]; then
  cd "$TMP_DIR/.claude"
  synced_count=0

  # 2a. 普通文件（排除 CLAUDE.md 和 agents/）
  while IFS= read -r -d '' rel_path; do
    local_path="$PROJECT_DIR/.claude/$rel_path"
    if cmp -s "$TMP_DIR/.claude/$rel_path" "$local_path" 2>/dev/null; then
      echo "  = 跳过(内容相同): .claude/$rel_path"
    else
      mkdir -p "$(dirname "$local_path")"
      cp -f "$TMP_DIR/.claude/$rel_path" "$local_path"
      echo "  ✓ 覆盖: .claude/$rel_path"
      synced_count=$((synced_count + 1))
    fi
  done < <(find . -type f ! -name "CLAUDE.md" ! -path "./agents/*" -print0 2>/dev/null)

  # 2b. CLAUDE.md — 仅更新 frontmatter（第一个 --- 之前的内容）
  REMOTE_CLAUDE="$TMP_DIR/.claude/CLAUDE.md"
  LOCAL_CLAUDE="$PROJECT_DIR/.claude/CLAUDE.md"
  if [ -f "$REMOTE_CLAUDE" ]; then
    if [ ! -f "$LOCAL_CLAUDE" ]; then
      mkdir -p "$(dirname "$LOCAL_CLAUDE")"
      cp "$REMOTE_CLAUDE" "$LOCAL_CLAUDE"
      echo "  + 新增: .claude/CLAUDE.md"
    else
      remote_fm=$(awk '!found && /^---$/{found=1; next} !found{print}' "$REMOTE_CLAUDE")
      local_fm=$(awk '!found && /^---$/{found=1; next} !found{print}' "$LOCAL_CLAUDE")

      if [ "$remote_fm" != "$local_fm" ]; then
        local_body=$(awk '/^---$/{found=1; next} found{print}' "$LOCAL_CLAUDE")
        printf '%s\n' "$remote_fm" > "$LOCAL_CLAUDE"
        echo '---' >> "$LOCAL_CLAUDE"
        printf '%s\n' "$local_body" >> "$LOCAL_CLAUDE"
        echo "  ✓ 更新 frontmatter: .claude/CLAUDE.md"
      else
        echo "  = 跳过(frontmatter 相同): .claude/CLAUDE.md"
      fi
    fi
  fi

  # 同步 agents/ 下的非 .md 文件
  while IFS= read -r -d '' rel_path; do
    local_path="$PROJECT_DIR/.claude/$rel_path"
    if cmp -s "$TMP_DIR/.claude/$rel_path" "$local_path" 2>/dev/null; then
      echo "  = 跳过(内容相同): .claude/$rel_path"
    else
      mkdir -p "$(dirname "$local_path")"
      cp -f "$TMP_DIR/.claude/$rel_path" "$local_path"
      echo "  ✓ 覆盖: .claude/$rel_path"
      synced_count=$((synced_count + 1))
    fi
  done < <(find ./agents -type f ! -name "*.md" -print0 2>/dev/null)

  if [ "$synced_count" -eq 0 ]; then
    echo "  (无需要覆盖的文件)"
  fi
else
  echo "  远程仓库无 .claude/ 目录"
fi
echo ""

# 3. 同步 .claude/agents/*.md — 保留本地 model 字段
echo "[3/7] 同步 .claude/agents/*.md (保留本地 model 字段)..."
agents_synced=0
agents_skipped=0
agents_covered=0
agents_preserved=0
if [ -d "$TMP_DIR/.claude/agents" ]; then
  while IFS= read -r -d '' agent_file; do
    rel_path=$(echo "$agent_file" | sed "s|$TMP_DIR/.claude/||")
    local_path="$PROJECT_DIR/.claude/$rel_path"

    if [ ! -f "$local_path" ]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$agent_file" "$local_path"
      echo "  + 新增: .claude/$rel_path"
      agents_synced=$((agents_synced + 1))
    else
      # 提取本地 model 值
      local_model=$(awk '/^---/{c++; next} c==1 && /^model:/{sub(/^model:[[:space:]]*/, ""); print; exit}' "$local_path")

      # 生成"远程+本地model"的临时文件，与本地比对
      tmp_merged=$(mktemp)
      cp "$agent_file" "$tmp_merged"
      if [ -n "$local_model" ]; then
        if sed -i '' "s/^model:.*/model: $local_model/" "$tmp_merged" 2>/dev/null; then true; else
          sed -i "s/^model:.*/model: $local_model/" "$tmp_merged"
        fi
      fi

      if cmp -s "$tmp_merged" "$local_path"; then
        echo "  = 跳过(内容相同): .claude/$rel_path"
        agents_skipped=$((agents_skipped + 1))
        rm -f "$tmp_merged"
      else
        # 有差异，执行覆盖
        mv "$tmp_merged" "$local_path"
        if [ -n "$local_model" ]; then
          echo "  ✓ 覆盖(保留 model=$local_model): .claude/$rel_path"
          agents_preserved=$((agents_preserved + 1))
        else
          echo "  ✓ 覆盖(使用远程 model): .claude/$rel_path"
          agents_covered=$((agents_covered + 1))
        fi
      fi
    fi
  done < <(find "$TMP_DIR/.claude/agents" -name "*.md" -type f -print0 2>/dev/null)
fi
echo "  新增: $agents_synced, 覆盖: $agents_covered, 覆盖(保留model): $agents_preserved, 跳过: $agents_skipped"
echo ""

# 4. 同步 .project-script/ 目录（仅添加本地不存在的文件）
# 该目录是基础配置仓库的一部分，但同步到下游项目后由下游 .gitignore 排除。
# 保留下游已有脚本，避免重复同步时覆盖本地验证逻辑。
echo "[4/7] 同步 .project-script/ 目录 (仅添加不存在的文件)..."
project_script_added_count=0
project_script_skipped_count=0
if [ -d "$TMP_DIR/.project-script" ]; then
  cd "$TMP_DIR/.project-script"
  while IFS= read -r -d '' rel_path; do
    local_path="$PROJECT_DIR/.project-script/$rel_path"
    if [ ! -f "$local_path" ]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$TMP_DIR/.project-script/$rel_path" "$local_path"
      echo "  + 新增: .project-script/$rel_path"
      project_script_added_count=$((project_script_added_count + 1))
    else
      echo "  = 跳过(已存在): .project-script/$rel_path"
      project_script_skipped_count=$((project_script_skipped_count + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  echo "  新增: $project_script_added_count, 跳过: $project_script_skipped_count"
else
  echo "  远程仓库无 .project-script/ 目录"
fi
echo ""

# 5. 同步 .project-memory/ 目录（仅添加本地不存在的文件）
echo "[5/7] 同步 .project-memory/ 目录 (仅添加不存在的文件)..."
added_count=0
skipped_count=0
if [ -d "$TMP_DIR/.project-memory" ]; then
  cd "$TMP_DIR/.project-memory"
  while IFS= read -r -d '' rel_path; do
    local_path="$PROJECT_DIR/.project-memory/$rel_path"
    if [ ! -f "$local_path" ]; then
      mkdir -p "$(dirname "$local_path")"
      cp "$TMP_DIR/.project-memory/$rel_path" "$local_path"
      echo "  + 新增: .project-memory/$rel_path"
      added_count=$((added_count + 1))
    else
      echo "  = 跳过(已存在): .project-memory/$rel_path"
      skipped_count=$((skipped_count + 1))
    fi
  done < <(find . -type f -print0 2>/dev/null)
  echo "  新增: $added_count, 跳过: $skipped_count"
else
  echo "  远程仓库无 .project-memory/ 目录"
fi
echo ""

# 6. 管理下游项目 .gitignore
echo "[6/7] 检查下游项目 .gitignore..."
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ ! -f "$GITIGNORE" ]; then
  printf '.claude/\n.project-memory/\n.project-script/\n' > "$GITIGNORE"
  echo "  + 创建 .gitignore 并添加 .claude/、.project-memory/ 和 .project-script/"
else
  added_to_gitignore=0
  if ! grep -q '^\.claude/' "$GITIGNORE"; then
    echo '.claude/' >> "$GITIGNORE"
    echo "  + 追加 .claude/ 到 .gitignore"
    added_to_gitignore=$((added_to_gitignore + 1))
  fi
  if ! grep -q '^\.project-memory/' "$GITIGNORE"; then
    echo '.project-memory/' >> "$GITIGNORE"
    echo "  + 追加 .project-memory/ 到 .gitignore"
    added_to_gitignore=$((added_to_gitignore + 1))
  fi
  if ! grep -q '^\.project-script/$' "$GITIGNORE"; then
    printf '\n# Claude Code 本地验证脚本\n.project-script/\n' >> "$GITIGNORE"
    echo "  + 追加 .project-script/ 到下游项目 .gitignore"
    added_to_gitignore=$((added_to_gitignore + 1))
  fi
  if [ "$added_to_gitignore" -eq 0 ]; then
    echo "  .gitignore 已包含所需条目，无需修改"
  fi
fi
echo ""

# 7. 清理临时目录
echo "[7/7] 清理临时目录..."
rm -rf "$TMP_DIR"
echo "  清理完成"
echo ""

echo "=== 同步完成 ==="
