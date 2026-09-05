#!/usr/bin/env bash
# sync-introduction.sh — 通过 git 分支管理 .project-memory/ 的独立同步
#
# 原理：远程仓库中每个项目拥有独立分支 (docs/<project-id>)
#       `.project-memory/` 本身是该远程仓库的一个项目记忆工作副本
#       pull/push 使用标准 git 语义，支持真正的合并与冲突处理
#
# 用法:
#   sync-introduction.sh pull   — 拉取/合并远程项目记忆到本地 (标准 git pull)
#   sync-introduction.sh push   — 推送本地项目记忆到远程 (标准 git push)
#   sync-introduction.sh status — 查看项目记忆仓库状态

set -euo pipefail

MEMORY_DIR=".project-memory"

info()  { printf "\033[36m[信息]\033[0m %s\n" "$*"; }
ok()    { printf "\033[32m[  ✓]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[警告]\033[0m %s\n" "$*" >&2; }
err()   { printf "\033[31m[错误]\033[0m %s\n" "$*" >&2; }

# ============================ 项目标识检测 ============================ #

detect_project_id() {
  local project_dir="$1"
  local id=""

  # 1. settings.local.json 中显式配置
  local settings_file="$project_dir/.claude/settings.local.json"
  if [ -f "$settings_file" ]; then
    if command -v jq &>/dev/null; then
      id=$(jq -r '.CLAUDE_DOCS_PROJECT_ID // empty' "$settings_file" 2>/dev/null)
    else
      id=$(grep -o '"CLAUDE_DOCS_PROJECT_ID"[[:space:]]*:[[:space:]]*"[^"]*"' "$settings_file" 2>/dev/null | sed 's/.*: *"\(.*\)"/\1/')
    fi
    [ -n "$id" ] && { echo "$id"; return; }
  fi

  # 2. .claude/project-id 文件
  if [ -f "$project_dir/.claude/project-id" ]; then
    id=$(head -1 "$project_dir/.claude/project-id" | tr -d '[:space:]')
    [ -n "$id" ] && { echo "$id"; return; }
  fi

  # 3. git remote origin 仓库名
  if command -v git &>/dev/null; then
    id=$(cd "$project_dir" && git remote get-url origin 2>/dev/null | xargs basename -s .git 2>/dev/null || true)
    [ -n "$id" ] && { echo "$id"; return; }
  fi

  # 4. 兜底：工作目录名
  id=$(basename "$(cd "$project_dir" && git rev-parse --show-toplevel 2>/dev/null || echo "$project_dir")")
  echo "$id"
}

# ============================ 远程项目记忆仓库 URL 检测 ============================ #
#
# 唯一配置位置：.claude/.cache/docs-sync.conf（一行纯文本 URL）
# 通过 config 子命令写入，不进 git，跨设备需各自配置一次。

detect_remote_repo() {
  local project_dir="$1"
  local cache_conf="$project_dir/.claude/.cache/docs-sync.conf"

  if [ -f "$cache_conf" ]; then
    local url
    url=$(head -1 "$cache_conf" | tr -d '[:space:]')
    [ -n "$url" ] && { echo "$url"; return; }
  fi

  echo ""
}

# 将 URL 写入 .claude/.cache/docs-sync.conf
write_remote_repo() {
  local project_dir="$1" url="$2"
  local cache_dir="$project_dir/.claude/.cache"
  mkdir -p "$cache_dir"
  printf '%s\n' "$url" > "$cache_dir/docs-sync.conf"
  echo "$cache_dir/docs-sync.conf"
}

# ============================ .gitignore 检查 ============================ #

check_gitignore() {
  local project_dir="$1"
  local gitignore="$project_dir/.gitignore"
  local entry="$MEMORY_DIR/"

  if [ -f "$gitignore" ] && grep -q "^$entry" "$gitignore" 2>/dev/null; then
    return 0
  fi

  if cd "$project_dir" && git ls-files --error-unmatch "$MEMORY_DIR/" &>/dev/null 2>&1; then
    warn "$MEMORY_DIR/ 正在被主项目 git 跟踪"
    info "建议取消跟踪，避免项目记忆与主项目代码耦合："
    info "  git rm -r --cached $MEMORY_DIR/"
    info "  echo '$entry' >> .gitignore"
    info "  git add .gitignore && git commit -m 'chore: untrack $MEMORY_DIR/'"
    return 0
  fi

  warn "$MEMORY_DIR/ 不在 .gitignore 中"
  info "建议将以下内容添加到 .gitignore："
  info "  $entry"
}

# ============================ 切换分支（跨设备安全） ============================ #
#
# mode:
#   "track"  (默认) — 当前已在该分支 no-op；本地有则 checkout；远程有则跟踪；
#                     都没有则从当前 HEAD 创建新分支（保留工作区与暂存区内容）
#   "orphan"        - 都没有时创建 orphan 分支并清空暂存区（用于全新初始化）
#
# orphan 模式仅在本地为空且远程也无分支的首次初始化时使用。

switch_to_branch() {
  local intro="$1"
  local branch="$2"
  local mode="${3:-track}"

  cd "$intro" || { err "无法进入 $intro"; return 1; }

  local current
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
  [ "$current" = "$branch" ] && { cd - >/dev/null; return 0; }

  # 本地分支已存在
  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git checkout "$branch" || { err "checkout $branch 失败"; cd - >/dev/null; return 1; }
    cd - >/dev/null
    return 0
  fi

  # 远程已存在该分支
  if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    git checkout -b "$branch" "origin/$branch" || { err "checkout -b $branch 失败"; cd - >/dev/null; return 1; }
    cd - >/dev/null
    return 0
  fi

  # 不存在 → 按 mode 创建
  if [ "$mode" = "orphan" ]; then
    warn "本地与远程均无分支 $branch，创建 orphan 分支"
    git checkout --orphan "$branch" || { err "checkout --orphan $branch 失败"; cd - >/dev/null; return 1; }
    git rm -rf --cached . 2>/dev/null || true
  else
    # track 模式：从当前 HEAD 创建新分支，保留工作区内容
    git checkout -b "$branch" || { err "checkout -b $branch 失败"; cd - >/dev/null; return 1; }
  fi

  cd - >/dev/null
  return 0
}

# ============================ 远程可达性 / 分支存在检测 ============================ #

# 验证远程仓库可达且认证正常
# 区分三种状态：
#   0 = 可达（含"仓库存在但为空"）
#   1 = 仓库不存在 / 认证失败 / 网络
# 通过 stderr 是否有 git 报错判断：空仓库退出码 2 但无 stderr；不存在退出码 128 且有 stderr
verify_remote_access() {
  local repo_url="$1"
  local err_out
  err_out=$(git ls-remote "$repo_url" HEAD 2>&1 >/dev/null) || true
  # 仓库不存在 / 无权限 → git 会输出错误到 stderr
  if [ -n "$err_out" ]; then
    return 1
  fi
  return 0
}

# 检测远程分支是否存在（要求已 fetch 或用 ls-remote）
# 返回 0 存在；1 不存在
remote_branch_exists() {
  local repo_url="$1" branch="$2"
  git ls-remote --exit-code --heads "$repo_url" "$branch" &>/dev/null
}

# ============================ pull ============================ #

do_pull() {
  local project_dir="$1" project_id="$2" repo_url="$3"
  local branch="docs/$project_id"
  local intro="$project_dir/$MEMORY_DIR"

  # === 已有 git 仓库 → 标准 git pull ===
  if [ -d "$intro/.git" ]; then
    cd "$intro"
    # 远程无此分支时不能 pull；提示先 push
    if ! remote_branch_exists "$repo_url" "$branch"; then
      warn "远程尚无分支 $branch，无法拉取"
      info "提示：本地有内容时请先运行 push 创建远程分支"
      cd - >/dev/null
      return 0
    fi
    switch_to_branch "$intro" "$branch" track
    info "拉取远程分支 $branch ..."
    # 显式 merge 策略：避免现代 git 在分叉时要求用户配置 pull.rebase
    if git pull --no-rebase origin "$branch"; then
      ok "拉取完成"
      cd - >/dev/null
      return 0
    else
      err ""
      err "合并冲突，请手动解决后完成合并："
      err "  1. 编辑冲突文件，解决 <<<<<<< / ======= / >>>>>>> 标记"
      err "  2. git add -A"
      err "  3. git commit -m 'merge: 解决冲突'"
      err ""
      err "如需取消本次合并："
      err "  git merge --abort"
      cd - >/dev/null
      return 1
    fi
  fi

  # === 本地已有内容但不是 git 仓库 → 自动纳入版本管理并合并远程 ===
  # 场景：sync-claude-config 刚填充了模板文件，或用户手动放了项目记忆。
  # 既然用了本 skill，.project-memory/ 必然要当 git 仓库，直接自动 init，
  # 不停下来问。本地内容先 commit，再 merge 远程分支，冲突时报告具体文件。
  if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
    info "本地 $MEMORY_DIR/ 有内容但未纳入版本管理，自动初始化 ..."
    cd "$intro"
    git init -q
    git remote add origin "$repo_url"

    # 远程无此分支 → 本地建分支、提交本地内容、提示用 push 创建远程分支
    if ! remote_branch_exists "$repo_url" "$branch"; then
      git checkout -b "$branch"
      info "远程尚无分支 $branch，本地内容已纳入版本管理"
      info "请运行 push 创建远程分支"
      cd - >/dev/null
      return 0
    fi

    # 远程有分支 → fetch，把本地内容合并进来
    git fetch origin "$branch"

    # 配置局部 user（若全局没配，用占位值，让 commit 不失败）
    if [ -z "$(git config user.name)" ]; then
      git config user.email "docs-sync@local"
      git config user.name "docs-sync"
    fi

    # 策略：本地内容先 commit 到默认分支 → 切到跟踪远程的本地分支 →
    # 用 --allow-unrelated-histories 合并本地提交。
    # 不同文件自动并存；同名文件真冲突才需手动解决（不静默覆盖）。
    # 1. 本地内容 commit 到默认分支
    git add -A
    git commit -q -m "chore: 本地内容纳入版本管理" 2>/dev/null || true
    local default_branch local_commit
    default_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo main)
    local_commit=$(git rev-parse HEAD 2>/dev/null)

    # 2. 切到跟踪远程的本地分支（工作区变成远程内容）
    git checkout -b "$branch" "origin/$branch" -q 2>/dev/null || git checkout "$branch" -q 2>/dev/null

    # 3. 合并本地提交（允许无关历史，不同文件自动并存）
    if [ -n "$local_commit" ]; then
      if git merge "$local_commit" --allow-unrelated-histories --no-edit -q 2>/dev/null; then
        ok "已合并本地内容到远程分支 ${branch}"
      else
        # 真正的内容冲突（同名文件两边都改过）→ 报告冲突文件
        warn "合并时出现内容冲突（同名文件两边都有），需手动解决："
        git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  冲突文件: /'
        err "请编辑上述文件解决 <<<<<<< / ======= / >>>>>>> 标记后："
        err "  cd $intro && git add -A && git commit -m 'merge: 解决冲突'"
        err "或放弃本地内容用远程覆盖：cd $intro && git merge --abort && git checkout -f ."
        cd - >/dev/null
        return 1
      fi
    fi
    ok "拉取完成（远程分支 ${branch}）"
    cd - >/dev/null
    return 0
  fi

  # === 首次初始化（本地为空，远程已有分支） ===
  if remote_branch_exists "$repo_url" "$branch"; then
    info "首次拉取：从远程分支 $branch 初始化 $MEMORY_DIR/ ..."
    mkdir -p "$intro"
    cd "$intro"
    git init -q
    git remote add origin "$repo_url"
    git fetch origin "$branch"
    git checkout -b "$branch" "origin/$branch"
    ok "已检出远程分支 $branch"
    cd - >/dev/null
    return 0
  fi

  # === 本地为空，远程也无分支 ===
  err "本地 $MEMORY_DIR/ 为空，远程也无分支 $branch"
  err "请先在工作目录中创建项目记忆，然后运行 push 初始化远程分支"
  return 1
}

# ============================ push ============================ #

do_push() {
  local project_dir="$1" project_id="$2" repo_url="$3"
  local branch="docs/$project_id"
  local intro="$project_dir/$MEMORY_DIR"

  # === 本地有内容但还不是 git 仓库 → 首次初始化 ===
  local just_initialized=0
  if [ ! -d "$intro/.git" ]; then
    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      info "首次推送：将本地 $MEMORY_DIR/ 纳入版本管理 ..."
      cd "$intro"
      git init -q
      git remote add origin "$repo_url"
      # 远程已有分支则跟踪，没有则新建
      if git fetch origin "$branch" 2>/dev/null && git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        git checkout -b "$branch" "origin/$branch"
        info "已跟踪远程分支 $branch（本地新内容将与远程合并）"
      else
        git checkout -b "$branch"
        info "新建本地分支 $branch"
      fi
      cd - >/dev/null
      just_initialized=1
    else
      err "$MEMORY_DIR/ 不存在或为空，请先创建项目记忆再推送"
      return 1
    fi
  fi

  cd "$intro"

  # 确保在正确分支（首次刚初始化已切到目标分支，跳过）
  if [ "$just_initialized" -eq 0 ]; then
    switch_to_branch "$intro" "$branch" track
  fi

  # git 全局 user 未配置时 commit 会失败，提前检测
  if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
    err "未配置 git 用户信息，无法提交"
    err "请运行（可替换为你的信息）："
    err "  git config --global user.name 'Your Name'"
    err "  git config --global user.email 'you@example.com'"
    err "或在 $MEMORY_DIR/ 内只用局部配置："
    err "  cd $intro && git config user.name '...' && git config user.email '...'"
    cd - >/dev/null
    return 1
  fi

  # 检查是否有变更（含未跟踪文件）
  # - git diff --quiet        : worktree vs index
  # - git diff --cached --quiet: index vs HEAD
  # - 检查未跟踪文件           : 新增文件尚未 add
  local has_changes=0
  git diff --quiet || has_changes=1
  git diff --cached --quiet || has_changes=1
  if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    has_changes=1
  fi

  if [ "$has_changes" -eq 0 ]; then
    ok "项目记忆无变更，无需推送"
    cd - >/dev/null
    return 0
  fi

  git add -A
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local project_name
  project_name=$(basename "$project_dir")
  git commit -m "docs($project_id): sync $MEMORY_DIR

自动同步于 $timestamp
项目: $project_name"

  info "推送到远程 (branch: $branch) ..."
  if git push -u origin "$branch"; then
    ok "推送完成！远程: $repo_url (branch: $branch)"
  else
    err "推送失败，远程有更新的提交未合并"
    err "请先运行 pull 合并远程变更，再重新 push"
    cd - >/dev/null
    return 1
  fi

  cd - >/dev/null
}

# ============================ diagnose ============================ #
#
# 专供 SKILL.md 的 `!` 动态注入使用：
#   - 永远以 0 退出（即使未配置/未初始化），不触发 set -e 抖动
#   - 只输出模型决策需要的关键状态：URL 是否配置、项目标识、初始化状态、分支、ahead/behind
#   - 不做网络请求（不 fetch，不验证可达性），避免注入阶段卡住

do_diagnose() {
  local project_dir="$1" project_id="$2"
  local branch="docs/$project_id"
  local intro="$project_dir/$MEMORY_DIR"
  local cache_conf="$project_dir/.claude/.cache/docs-sync.conf"

  echo "--- sync-claude-introduction 诊断 ---"
  echo "项目目录: $project_dir"
  echo "项目标识: ${project_id:-（未确定）}"

  # URL 配置
  local url=""
  if [ -f "$cache_conf" ]; then
    url=$(head -1 "$cache_conf" | tr -d '[:space:]')
  fi
  if [ -n "$url" ]; then
    echo "项目记忆仓库 URL: $url"
    echo "URL 已配置: 是"
  else
    echo "项目记忆仓库 URL: （未配置）"
    echo "URL 已配置: 否"
  fi

  # 初始化状态
  if [ -d "$intro/.git" ]; then
    echo "本地仓库已初始化: 是"
    (cd "$intro" && \
      echo "当前分支: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)" && \
      local_changes=$(git status --short 2>/dev/null | head -20) && \
      if [ -n "$local_changes" ]; then
        echo "本地有未提交变更: 是"
        echo "$local_changes" | sed 's/^/  /'
      else
        echo "本地有未提交变更: 否"
      fi && \
      ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || true) && \
      behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || true) && \
      if [ -z "$ahead" ] && [ -z "$behind" ]; then
        echo "同步状态: 尚无上游分支（本地从未与远程同步过，需先 pull 建立跟踪）"
      else
        echo "领先远程: ${ahead:-0} 个提交（本地未推送的提交）"
        echo "落后远程: ${behind:-0} 个提交（远程未拉取的更新）"
        if [ "${ahead:-0}" = "0" ] && [ "${behind:-0}" = "0" ]; then
          echo "与远程同步: 是"
        else
          echo "与远程同步: 否"
        fi
      fi)
  else
    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      echo "本地仓库已初始化: 否（目录有内容但未纳入版本管理）"
    else
      echo "本地仓库已初始化: 否（目录为空或不存在）"
    fi
  fi

  # git user
  if [ -z "$(git config user.name 2>/dev/null)" ] || [ -z "$(git config user.email 2>/dev/null)" ]; then
    echo "git 用户信息: 未配置（push 会失败）"
  else
    echo "git 用户信息: 已配置"
  fi

  echo "--- 诊断结束 ---"
}

# ============================ info ============================ #
#
# 面向用户的状态查询：本地是否有未提交/未推送变更、远程是否有未拉取更新。
# 永远 0 退出（即使未初始化/未配置/网络不可达），把状态摘要打印出来。
# 不修改任何东西，只读 + 一次 fetch（容忍失败）。

do_info() {
  local project_dir="$1" project_id="$2" repo_url="$3"
  local branch="docs/$project_id"
  local intro="$project_dir/$MEMORY_DIR"

  echo "--- sync-claude-introduction 状态 ---"
  echo "项目标识: ${project_id:-（未确定）}"

  # URL 配置
  if [ -n "$repo_url" ]; then
    echo "项目记忆仓库 URL: $repo_url"
  else
    echo "项目记忆仓库 URL: （未配置）"
  fi

  # 未初始化
  if [ ! -d "$intro/.git" ]; then
    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      echo "本地仓库: 未初始化（目录有内容但未纳入版本管理）"
    else
      echo "本地仓库: 未初始化（目录为空或不存在）"
    fi
    echo "（需先 pull 初始化，或 push 把本地内容纳入版本管理）"
    echo "--- 状态结束 ---"
    return 0
  fi

  cd "$intro" || { echo "--- 状态结束 ---"; return 0; }

  echo "当前分支: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"

  # 本地未提交变更
  local local_changes
  local_changes=$(git status --short 2>/dev/null | head -20)
  if [ -n "$local_changes" ]; then
    echo "本地未提交变更: 有"
    echo "$local_changes" | sed 's/^/  /'
  else
    echo "本地未提交变更: 无"
  fi

  # 远程更新情况（fetch，容忍失败）
  if [ -n "$repo_url" ]; then
    git fetch origin "$branch" 2>/dev/null || true
    local ahead behind
    ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || true)
    behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || true)
    if [ -z "$ahead" ] && [ -z "$behind" ]; then
      echo "远程同步状态: 尚无上游分支（本地从未与远程同步过）"
    else
      echo "本地领先远程: ${ahead:-0} 个提交（未推送）"
      echo "本地落后远程: ${behind:-0} 个提交（远程有未拉取的更新）"
      if [ "${ahead:-0}" = "0" ] && [ "${behind:-0}" = "0" ]; then
        echo "远程同步状态: 已同步"
      fi
    fi
  else
    echo "远程同步状态: 未配置 URL，无法比较"
  fi

  # 最近提交
  echo ""
  echo "最近提交:"
  git log --oneline -3 2>/dev/null || echo "  （暂无提交）"

  cd - >/dev/null
  echo "--- 状态结束 ---"
}

# ============================ status ============================ #

do_status() {
  local project_dir="$1" project_id="$2"
  local branch="docs/$project_id"
  local intro="$project_dir/$MEMORY_DIR"

  if [ ! -d "$intro/.git" ]; then
    err "$MEMORY_DIR/ 尚未初始化为 git 仓库"
    warn "请先运行: bash $(basename "$0") pull"
    return 1
  fi

  cd "$intro"

  echo "=== $MEMORY_DIR/ 项目记忆仓库状态 ==="
  echo "项目标识: $project_id"
  echo "分支:      $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')"
  echo "远程:      $(git remote get-url origin 2>/dev/null || echo '未配置')"
  echo ""

  if [ -n "$(git status --short 2>/dev/null)" ]; then
    git status
  else
    echo "工作区干净，无未提交变更"
  fi

  # 检查 ahead/behind
  echo ""
  git fetch origin "$branch" 2>/dev/null || true
  local ahead behind
  ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "?")
  behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo "?")
  echo "领先远程: $ahead 个提交  |  落后远程: $behind 个提交"

  # 最近提交
  echo ""
  echo "--- 最近提交 ---"
  git log --oneline -5 2>/dev/null || echo "(暂无提交)"

  cd - >/dev/null
}

# ============================ 主流程 ============================ #

main() {
  local op="${1:-}"

  # 方向校验：只接受 pull / push / info / status / config / diagnose
  # 非法或空 → 结构化报错（面向模型读取），退出 2（区分于正常失败的非零）
  # 空参时先输出 diagnose 状态（URL/初始化情况），让模型一眼看到配置是否就绪
  if [ "$op" != "push" ] && [ "$op" != "pull" ] && [ "$op" != "info" ] && [ "$op" != "status" ] && [ "$op" != "config" ] && [ "$op" != "diagnose" ]; then
    # 空参 → 先输出当前状态，帮助模型判断是否还需配置 URL
    if [ -z "$op" ]; then
      local _project_dir
      _project_dir="$(cd "$(dirname "$0")/../../../../" && pwd)"
      local _project_id _repo_url
      _project_id=$(detect_project_id "$_project_dir" 2>/dev/null || echo "")
      _repo_url=$(detect_remote_repo "$_project_dir")
      echo "--- 当前配置状态 ---"
      echo "项目标识: ${_project_id:-（未确定）}"
      if [ -n "$_repo_url" ]; then
        echo "项目记忆仓库 URL: $_repo_url"
        echo "URL 已配置: 是"
      else
        echo "项目记忆仓库 URL: （未配置）"
        echo "URL 已配置: 否"
      fi
      echo "-------------------"
    fi
    echo "[SYNC_ERROR] 参数校验失败"
    if [ -z "$op" ]; then
      echo "原因: 未指定方向（参数为空）"
    else
      echo "原因: 方向必须是 pull / push / info，收到: $op"
    fi
    echo "解决: 用法如下"
    echo "  /sync-claude-introduction pull     从远程拉取项目记忆到本地"
    echo "  /sync-claude-introduction push     把本地项目记忆推送到远程"
    echo "  /sync-claude-introduction info     查看项目记忆同步状态"
    echo "  bash $(basename "$0") config <url> 配置项目记忆仓库 URL"
    exit 2
  fi

  echo "=== sync-claude-introduction ($op) ==="

  local project_dir
  project_dir="$(cd "$(dirname "$0")/../../../../" && pwd)"
  echo "项目目录: $project_dir"

  # config 子命令：写入 URL 后退出（不需要项目标识）
  if [ "$op" = "config" ]; then
    local url="${2:-}"
    if [ -z "$url" ]; then
      err "用法: bash $(basename "$0") config <url>"
      err "示例: bash $(basename "$0") config https://github.com/youruser/claude-project-docs.git"
      exit 1
    fi
    local conf_path
    conf_path=$(write_remote_repo "$project_dir" "$url")
    ok "已写入项目记忆仓库 URL: $url"
    info "配置文件: $conf_path"
    info "现在可以运行 pull / push 同步项目记忆了"
    exit 0
  fi

  # diagnose：只输出摘要，不做 URL 检测 / 可达性预检，永远 0 退出
  if [ "$op" = "diagnose" ]; then
    local project_id_for_diag
    project_id_for_diag=$(detect_project_id "$project_dir" 2>/dev/null || echo "")
    do_diagnose "$project_dir" "$project_id_for_diag"
    exit 0
  fi

  local project_id
  project_id=$(detect_project_id "$project_dir")
  if [ -z "$project_id" ]; then
    err "无法确定项目标识"
    err "请在 .claude/settings.local.json 中设置 CLAUDE_DOCS_PROJECT_ID"
    err "或创建 .claude/project-id 文件"
    exit 1
  fi
  echo "项目标识: $project_id"

  local repo_url
  repo_url=$(detect_remote_repo "$project_dir")

  # info：查状态，不做可达性预检，容忍未配置 URL / 远程不可达，永远 0 退出
  if [ "$op" = "info" ]; then
    do_info "$project_dir" "$project_id" "$repo_url"
    exit 0
  fi

  if [ -z "$repo_url" ]; then
    err "未配置远程项目记忆仓库 URL"
    err "请先在 GitHub 创建一个空仓库（用于存放各项目的项目记忆），然后配置 URL："
    echo ""
    info "运行（把 URL 换成你创建的项目记忆仓库地址）："
    echo "  bash .claude/skills/sync-claude-introduction/scripts/sync-introduction.sh config https://github.com/youruser/claude-project-docs.git"
    echo ""
    err "配置后再次运行 pull / push / status"
    exit 1
  fi
  echo "项目记忆仓库: $repo_url"
  echo ""

  # 远程可达性 / 认证预检
  info "验证远程项目记忆仓库可达性 ..."
  if ! verify_remote_access "$repo_url"; then
    err "远程项目记忆仓库不可访问：$repo_url"
    err "可能原因："
    err "  1. 项目记忆仓库不存在（需先在 GitHub/GitLab 手动创建空仓库）"
    err "  2. 认证失败（检查 SSH key 或 HTTPS token / 凭证）"
    err "  3. 网络问题"
    exit 1
  fi

  # .gitignore / 父 git 跟踪检查（pull 和 push 都提示）
  check_gitignore "$project_dir"
  echo ""

  local rc=0
  case "$op" in
    pull)
      do_pull "$project_dir" "$project_id" "$repo_url" || rc=$?
      ;;
    push)
      do_push "$project_dir" "$project_id" "$repo_url" || rc=$?
      ;;
    status)
      do_status "$project_dir" "$project_id" || rc=$?
      ;;
  esac

  echo ""
  if [ "$rc" -ne 0 ]; then
    echo "=== 完成（有错误，退出码 ${rc}）==="
  else
    echo "=== 完成 ==="
  fi
  exit "$rc"
}

main "$@"
