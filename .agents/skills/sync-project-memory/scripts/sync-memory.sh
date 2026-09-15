#!/usr/bin/env bash
# sync-memory.sh — 通过 git 分支管理 .project-memory/ 项目记忆
#
# 原理：远程仓库中每个项目拥有独立分支，分支名由主代码仓库 origin remote URL 唯一映射
#       pull/push 使用标准 git 语义，支持真正的合并与冲突处理
#
# 用法:
#   sync-memory.sh pull   — 拉取/合并项目记忆到本地
#   sync-memory.sh push   — 推送本地项目记忆到远程
#   sync-memory.sh status — 查看项目记忆仓库状态

set -euo pipefail

SYNC_DIRS=(".project-memory")

info()  { printf "\033[36m[信息]\033[0m %s\n" "$*"; }
ok()    { printf "\033[32m[  ✓]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[警告]\033[0m %s\n" "$*" >&2; }
err()   { printf "\033[31m[错误]\033[0m %s\n" "$*" >&2; }

# ============================ 项目标识检测 ============================ #
#
# 唯一标识 = 主代码仓库 origin 远程 URL。
# 分支名 = docs/<URL slug>（SSH/HTTPS 转换成连续 slug，保证同一仓库/不同仓库不冲突）。
# 未配置 origin 时报错，不再回退到目录名或本地自定义 ID。

detect_main_repo_url() {
  local project_dir="$1"
  if command -v git &>/dev/null; then
    local url
    url=$(cd "$project_dir" && git remote get-url origin 2>/dev/null | head -1 | tr -d '[:space:]')
    [ -n "$url" ] && { echo "$url"; return; }
  fi
  echo ""
}

# 将远程 URL 转换成稳定的分支 slug：
#   https://github.com/user/repo.git -> github.com-user-repo
#   git@github.com:user/repo.git     -> github.com-user-repo
detect_project_branch() {
  local project_dir="$1"
  local url
  url=$(detect_main_repo_url "$project_dir")
  if [ -z "$url" ]; then
    echo ""
    return
  fi

  local slug
  slug=$(printf '%s' "$url"     | sed -E 's#^[[:space:]]*ssh://([^@]+@)?##; s#^[[:space:]]*https?://##; s#^[[:space:]]*git@([^:]+):#\1-#'     | sed -E 's#\.git$##; s#[^A-Za-z0-9._-]+#-#g; s/^-+//; s/-+$//')
  [ -n "$slug" ] && { printf '%s' "$slug"; return; }

  # 极端情况下 slug 为空：退回 URL 的 sha1 前缀，保持唯一性。
  slug=$(printf '%s' "$url" | shasum -a 1 2>/dev/null | cut -c1-12)
  [ -n "$slug" ] && { printf 'url-%s' "$slug"; return; }

  echo ""
}

# ============================ 远程项目记忆仓库 URL 检测 ============================ #
#
# 唯一配置位置： .agents/.cache/docs-sync.conf（一行纯文本 URL）
# 通过 config 子命令写入，不进 git，跨设备需各自配置一次。

detect_remote_repo() {
  local project_dir="$1"
  local cache_conf="$project_dir/ .agents/.cache/docs-sync.conf"

  if [ -f "$cache_conf" ]; then
    local url
    url=$(head -1 "$cache_conf" | tr -d '[:space:]')
    [ -n "$url" ] && { echo "$url"; return; }
  fi

  echo ""
}

# 将 URL 写入  .agents/.cache/docs-sync.conf
write_remote_repo() {
  local project_dir="$1" url="$2"
  local cache_dir="$project_dir/.agents/.cache"
  if ! mkdir -p "$cache_dir" 2>/dev/null; then
    err "创建失败: $cache_dir"
    err "请确认 .agents/.cache 目录存在且当前用户可写"
    return 1
  fi
  if ! printf '%s\n' "$url" > "$cache_dir/docs-sync.conf" 2>/dev/null; then
    err "写入失败: $cache_dir/docs-sync.conf"
    err "请确认  .agents/.cache 目录存在且当前用户可写"
    return 1
  fi
  echo "$cache_dir/docs-sync.conf"
}

# ============================ .gitignore 检查 ============================ #

check_gitignore() {
  local project_dir="$1"
  local gitignore="$project_dir/.gitignore"

  for entry in "${SYNC_DIRS[@]}/"; do
    if [ -f "$gitignore" ] && grep -q "^$entry" "$gitignore" 2>/dev/null; then
      continue
    fi

    if cd "$project_dir" && git ls-files --error-unmatch "$entry" >/dev/null 2>&1; then
      warn "$entry 正在被主项目 git 跟踪"
      info "建议取消跟踪，避免本地组与主项目代码耦合："
      info "  git rm -r --cached $entry"
      info "  echo '$entry' >> .gitignore"
      info "  git add .gitignore && git commit -m 'chore: untrack $entry'"
      continue
    fi

    warn "$entry 不在 .gitignore 中"
    info "建议将以下内容添加到 .gitignore："
    info "  $entry"
  done
}

# ============================ 切换分支（跨设备安全） ============================ #

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

# ============================ 单目录同步核心 ============================ #

sync_single_dir() {
  local op="$1" project_dir="$2" project_branch="$3" repo_url="$4" rel_dir="$5"
  local branch="docs/$project_branch"
  local intro="$project_dir/$rel_dir"

  if [ "$op" = "pull" ]; then
    if [ -d "$intro/.git" ]; then
      cd "$intro"
      if ! remote_branch_exists "$repo_url" "$branch"; then
        warn "$rel_dir 远程尚无分支 $branch，无法拉取"
        info "提示：本地有内容时请先运行 push 创建远程分支"
        cd - >/dev/null
        return 0
      fi
      switch_to_branch "$intro" "$branch" track
      info "拉取 $rel_dir 远程分支 $branch ..."
      if git pull --no-rebase origin "$branch"; then
        ok "$rel_dir 拉取完成"
        cd - >/dev/null
        return 0
      else
        err "$rel_dir 合并冲突，请手动解决后完成合并："
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

    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      info "$rel_dir 本地有内容但未纳入版本管理，自动初始化 ..."
      mkdir -p "$intro"
      cd "$intro"
      git init -q
      if git remote | grep -q '^origin$'; then
        git remote set-url origin "$repo_url"
      else
        git remote add origin "$repo_url"
      fi

      if ! remote_branch_exists "$repo_url" "$branch"; then
        git checkout -b "$branch"
        info "$rel_dir 远程尚无分支 $branch，本地内容已纳入版本管理"
        info "请运行 push 创建远程分支"
        cd - >/dev/null
        return 0
      fi

      git fetch origin "$branch"

      if [ -z "$(git config user.name)" ]; then
        git config user.email "docs-sync@local"
        git config user.name "docs-sync"
      fi

      git add -A
      git commit -q -m "chore: $rel_dir 本地内容纳入版本管理" 2>/dev/null || true
      local local_commit
      local_commit=$(git rev-parse HEAD 2>/dev/null)

      git checkout -b "$branch" "origin/$branch" -q 2>/dev/null || git checkout "$branch" -q 2>/dev/null

      if [ -n "$local_commit" ]; then
        if git merge "$local_commit" --allow-unrelated-histories --no-edit -q 2>/dev/null; then
          ok "$rel_dir 已合并本地内容到远程分支 ${branch}"
        else
          warn "$rel_dir 合并时出现内容冲突（同名文件两边都有），需手动解决："
          git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  冲突文件: /'
          err "请编辑上述文件解决冲突后："
          err "  cd $intro && git add -A && git commit -m 'merge: 解决冲突'"
          err "或放弃本地内容用远程覆盖：cd $intro && git merge --abort && git checkout -f ."
          cd - >/dev/null
          return 1
        fi
      fi
      ok "$rel_dir 拉取完成（远程分支 ${branch}）"
      cd - >/dev/null
      return 0
    fi

    if remote_branch_exists "$repo_url" "$branch"; then
      info "$rel_dir 首次拉取：从远程分支 $branch 初始化 ..."
      mkdir -p "$intro"
      cd "$intro"
      git init -q
      git remote add origin "$repo_url"
      git fetch origin "$branch"
      git checkout -b "$branch" "origin/$branch"
      ok "$rel_dir 已检出远程分支 $branch"
      cd - >/dev/null
      return 0
    fi

    info "$rel_dir 本地为空，远程也无分支 $branch，跳过"
    return 0
  fi

  if [ ! -d "$intro/.git" ]; then
    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      info "$rel_dir 首次推送：将本地内容纳入版本管理 ..."
      mkdir -p "$intro"
      cd "$intro"
      git init -q
      if git remote | grep -q '^origin$'; then
        git remote set-url origin "$repo_url"
      else
        git remote add origin "$repo_url"
      fi
      if git fetch origin "$branch" 2>/dev/null && git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        git checkout -b "$branch" "origin/$branch"
        info "$rel_dir 已跟踪远程分支 $branch"
      else
        git checkout -b "$branch"
        info "$rel_dir 新建本地分支 $branch"
      fi
    else
      info "$rel_dir 不存在或为空，跳过"
      return 0
    fi
  fi

  cd "$intro"

  if ! git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -qx "$branch"; then
    switch_to_branch "$intro" "$branch" track
  fi

  if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
    err "未配置 git 用户信息，无法提交"
    err "请运行（可替换为你的信息）："
    err "  git config --global user.name 'Your Name'"
    err "  git config --global user.email 'you@example.com'"
    err "或在 $rel_dir 内只用局部配置："
    err "  cd $intro && git config user.name '...' && git config user.email '...'"
    cd - >/dev/null
    return 1
  fi

  local has_changes=0
  git diff --quiet || has_changes=1
  git diff --cached --quiet || has_changes=1
  if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    has_changes=1
  fi

  if [ "$has_changes" -eq 0 ]; then
    ok "$rel_dir 无变更，无需推送"
    cd - >/dev/null
    return 0
  fi

  git add -A
  local timestamp project_name
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  project_name=$(basename "$project_dir")
  git commit -m "docs($project_branch): sync $rel_dir

自动同步于 $timestamp
项目: $project_name"

  info "推送 $rel_dir 到远程 (branch: $branch) ..."
  if git push -u origin "$branch"; then
    ok "$rel_dir 推送完成！远程: $repo_url (branch: $branch)"
    cd - >/dev/null
    return 0
  else
    err "$rel_dir 推送失败，远程有更新的提交未合并"
    err "请先运行 pull 合并远程变更，再重新 push"
    cd - >/dev/null
    return 1
  fi
}

# ============================ pull ============================ #

do_pull() {
  local project_dir="$1" project_branch="$2" repo_url="$3"
  local rc=0
  for dir in "${SYNC_DIRS[@]}"; do
    sync_single_dir pull "$project_dir" "$project_branch" "$repo_url" "$dir" || rc=1
  done
  return "$rc"
}

# ============================ push ============================ #

do_push() {
  local project_dir="$1" project_branch="$2" repo_url="$3"
  local rc=0
  for dir in "${SYNC_DIRS[@]}"; do
    sync_single_dir push "$project_dir" "$project_branch" "$repo_url" "$dir" || rc=1
  done
  return "$rc"
}

# ============================ diagnose ============================ #

do_diagnose() {
  local project_dir="$1" project_branch="$2"
  local branch="docs/$project_branch"
  local cache_conf="$project_dir/ .agents/.cache/docs-sync.conf"

  echo "--- sync-project-memory 诊断 ---"
  echo "项目目录: $project_dir"
  echo "分支 slug: ${project_branch:-（未确定）}"

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

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "[$rel_dir]"
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
  done

  if [ -z "$(git config user.name 2>/dev/null)" ] || [ -z "$(git config user.email 2>/dev/null)" ]; then
    echo "git 用户信息: 未配置（push 会失败）"
  else
    echo "git 用户信息: 已配置"
  fi

  echo "--- 诊断结束 ---"
}

# ============================ info ============================ #

do_info() {
  local project_dir="$1" project_branch="$2" repo_url="$3"
  local branch="docs/$project_branch"

  echo "--- sync-project-memory 状态 ---"
  echo "分支 slug: ${project_branch:-（未确定）}"

  if [ -n "$repo_url" ]; then
    echo "项目记忆仓库 URL: $repo_url"
  else
    echo "项目记忆仓库 URL: （未配置）"
  fi

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "[$rel_dir]"
    if [ ! -d "$intro/.git" ]; then
      if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        echo "本地仓库: 未初始化（目录有内容但未纳入版本管理）"
      else
        echo "本地仓库: 未初始化（目录为空或不存在）"
      fi
      echo "（需先 pull 初始化，或 push 把本地内容纳入版本管理）"
      continue
    fi

    cd "$intro" || continue
    echo "当前分支: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"

    local local_changes
    local_changes=$(git status --short 2>/dev/null | head -20)
    if [ -n "$local_changes" ]; then
      echo "本地未提交变更: 有"
      echo "$local_changes" | sed 's/^/  /'
    else
      echo "本地未提交变更: 无"
    fi

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

    echo "最近提交:"
    git log --oneline -3 2>/dev/null || echo "  （暂无提交）"
    cd - >/dev/null
  done

  echo "--- 状态结束 ---"
}

# ============================ status ============================ #

do_status() {
  local project_dir="$1" project_branch="$2"
  local branch="docs/$project_branch"

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "=== $rel_dir 仓库状态 ==="
    if [ ! -d "$intro/.git" ]; then
      err "$rel_dir 尚未初始化为 git 仓库"
      warn "请先运行: bash $(basename "$0") pull"
      continue
    fi
    cd "$intro"
    echo "分支 slug: $project_branch"
    echo "分支:      $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')"
    echo "远程:      $(git remote get-url origin 2>/dev/null || echo '未配置')"
    if [ -n "$(git status --short 2>/dev/null)" ]; then
      git status --short
    else
      echo "工作区干净，无未提交变更"
    fi
    git fetch origin "$branch" 2>/dev/null || true
    local ahead behind
    ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "?")
    behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo "?")
    echo "领先远程: $ahead 个提交  |  落后远程: $behind 个提交"
    echo ""
    echo "--- 最近提交 ---"
    git log --oneline -5 2>/dev/null || echo "(暂无提交)"
    cd - >/dev/null
  done
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
      local _project_branch _repo_url _main_url
      _main_url=$(detect_main_repo_url "$_project_dir" 2>/dev/null || echo "")
      _project_branch=$(detect_project_branch "$_project_dir" 2>/dev/null || echo "")
      _repo_url=$(detect_remote_repo "$_project_dir")
      echo "--- 当前配置状态 ---"
      echo "主仓库 origin: ${_main_url:-（未配置）}"
      echo "分支 slug: ${_project_branch:-（未确定）}"
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
    echo "  /sync-project-memory pull     从远程拉取项目记忆到本地"
    echo "  /sync-project-memory push     把本地项目记忆推送到远程"
    echo "  /sync-project-memory info     查看项目记忆同步状态"
    echo "  bash $(basename "$0") config <url> 配置项目记忆仓库 URL"
    exit 2
  fi

  echo "=== sync-project-memory ($op) ==="

  local project_dir
  project_dir="$(cd "$(dirname "$0")/../../../../" && pwd)"
  echo "项目目录: $project_dir"

  # config 子命令：写入 URL 后退出（不需要项目标识）
  if [ "$op" = "config" ]; then
    local url="${2:-}"
    if [ -z "$url" ]; then
      err "用法: bash $(basename "$0") config <url>"
      err "示例: bash $(basename "$0") config https://github.com/youruser/codex-project-docs.git"
      exit 1
    fi
    local conf_path
    if ! conf_path=$(write_remote_repo "$project_dir" "$url"); then
      exit 1
    fi
    ok "已写入项目记忆仓库 URL: $url"
    info "配置文件: $conf_path"
    info "现在可以运行 pull / push 同步项目记忆了"
    exit 0
  fi

  # diagnose：只输出摘要，不做 URL 检测 / 可达性预检，永远 0 退出
  if [ "$op" = "diagnose" ]; then
    local project_branch_for_diag
    project_branch_for_diag=$(detect_project_branch "$project_dir" 2>/dev/null || echo "")
    do_diagnose "$project_dir" "$project_branch_for_diag"
    exit 0
  fi

  local project_branch
  project_branch=$(detect_project_branch "$project_dir")
  if [ -z "$project_branch" ]; then
    err "无法从主仓库 origin remote 生成项目标识"
    err "请先在主代码仓库中配置远程，例如："
    err "  git remote add origin https://github.com/youruser/your-code-repo.git"
    exit 1
  fi
  echo "分支: docs/$project_branch"

  local repo_url
  repo_url=$(detect_remote_repo "$project_dir")

  # info：查状态，不做可达性预检，容忍未配置 URL / 远程不可达，永远 0 退出
  if [ "$op" = "info" ]; then
    do_info "$project_dir" "$project_branch" "$repo_url"
    exit 0
  fi

  if [ -z "$repo_url" ]; then
    err "未配置远程项目记忆仓库 URL"
    err "请先在 GitHub 创建一个空仓库（用于存放各项目的项目记忆），然后配置 URL："
    echo ""
    info "运行（把 URL 换成你创建的项目记忆仓库地址）："
    echo "  bash .agents/skills/sync-project-memory/scripts/sync-memory.sh config https://github.com/youruser/codex-project-docs.git"
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
      do_pull "$project_dir" "$project_branch" "$repo_url" || rc=$?
      ;;
    push)
      do_push "$project_dir" "$project_branch" "$repo_url" || rc=$?
      ;;
    status)
      do_status "$project_dir" "$project_branch" || rc=$?
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
