#!/usr/bin/env bash
# sync-memory.sh — manage .project-memory/ project memory through git branches
#
# How it works: every project owns a dedicated branch in the remote repository, and
#               the branch name is derived uniquely from the main repo origin remote URL.
#               pull/push use standard git semantics, so real merges and conflict
#               handling are supported.
#
# Usage:
#   sync-memory.sh pull   — fetch/merge project memory from the remote
#   sync-memory.sh push   — push local project memory to the remote
#   sync-memory.sh status — show project memory repository status

set -euo pipefail

SYNC_DIRS=(".project-memory")

info()  { printf "\033[36m[info]\033[0m %s\n" "$*"; }
ok()    { printf "\033[32m[  OK]\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m[warn]\033[0m %s\n" "$*" >&2; }
err()   { printf "\033[31m[error]\033[0m %s\n" "$*" >&2; }

# ============================ Project identity detection ============================ #
#
# Unique identity = origin remote URL of the main code repository.
# Branch name = docs/<URL slug> (SSH/HTTPS converted into a flat slug so that the same
#               repo always maps to the same branch and different repos never collide).
# When origin is not configured this errors out instead of falling back to a directory
# name or a locally defined id.

detect_main_repo_url() {
  local project_dir="$1"
  if command -v git &>/dev/null; then
    local url
    url=$(cd "$project_dir" && git remote get-url origin 2>/dev/null | head -1 | tr -d '[:space:]')
    [ -n "$url" ] && { echo "$url"; return; }
  fi
  echo ""
}

# Convert a remote URL into a stable branch slug:
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

  # Edge case where the slug comes out empty: fall back to a sha1 prefix of the URL
  # so uniqueness is preserved.
  slug=$(printf '%s' "$url" | shasum -a 1 2>/dev/null | cut -c1-12)
  [ -n "$slug" ] && { printf 'url-%s' "$slug"; return; }

  echo ""
}

# ============================ Remote memory repo URL detection ============================ #
#
# Single configuration location: .agents/.cache/docs-sync.conf (one plain-text URL line)
# Written through the config subcommand, not tracked by git, so each device needs its own
# one-time setup.

detect_remote_repo() {
  local project_dir="$1"
  local cache_conf="$project_dir/.agents/.cache/docs-sync.conf"

  if [ -f "$cache_conf" ]; then
    local url
    url=$(head -1 "$cache_conf" | tr -d '[:space:]')
    [ -n "$url" ] && { echo "$url"; return; }
  fi

  echo ""
}

# Write the URL into .agents/.cache/docs-sync.conf
write_remote_repo() {
  local project_dir="$1" url="$2"
  local cache_dir="$project_dir/.agents/.cache"
  if ! mkdir -p "$cache_dir" 2>/dev/null; then
    err "Failed to create: $cache_dir"
    err "Make sure the .agents/.cache directory exists and is writable by the current user"
    return 1
  fi
  if ! printf '%s\n' "$url" > "$cache_dir/docs-sync.conf" 2>/dev/null; then
    err "Failed to write: $cache_dir/docs-sync.conf"
    err "Make sure the .agents/.cache directory exists and is writable by the current user"
    return 1
  fi
  echo "$cache_dir/docs-sync.conf"
}

# ============================ .gitignore check ============================ #

check_gitignore() {
  local project_dir="$1"
  local gitignore="$project_dir/.gitignore"

  for entry in "${SYNC_DIRS[@]}/"; do
    if [ -f "$gitignore" ] && grep -q "^$entry" "$gitignore" 2>/dev/null; then
      continue
    fi

    if cd "$project_dir" && git ls-files --error-unmatch "$entry" >/dev/null 2>&1; then
      warn "$entry is currently tracked by the main project git repository"
      info "Consider untracking it so local memory does not couple with main project code:"
      info "  git rm -r --cached $entry"
      info "  echo '$entry' >> .gitignore"
      info "  git add .gitignore && git commit -m 'chore: untrack $entry'"
      continue
    fi

    warn "$entry is not listed in .gitignore"
    info "Consider adding the following line to .gitignore:"
    info "  $entry"
  done
}

# ============================ Branch switching (safe across devices) ============================ #

switch_to_branch() {
  local intro="$1"
  local branch="$2"
  local mode="${3:-track}"

  cd "$intro" || { err "Cannot enter $intro"; return 1; }

  local current
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
  [ "$current" = "$branch" ] && { cd - >/dev/null; return 0; }

  # Local branch already exists
  if git rev-parse --verify "$branch" >/dev/null 2>&1; then
    git checkout "$branch" || { err "checkout $branch failed"; cd - >/dev/null; return 1; }
    cd - >/dev/null
    return 0
  fi

  # Branch already exists on the remote
  if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
    git checkout -b "$branch" "origin/$branch" || { err "checkout -b $branch failed"; cd - >/dev/null; return 1; }
    cd - >/dev/null
    return 0
  fi

  # Does not exist yet → create it according to mode
  if [ "$mode" = "orphan" ]; then
    warn "Branch $branch exists neither locally nor remotely, creating an orphan branch"
    git checkout --orphan "$branch" || { err "checkout --orphan $branch failed"; cd - >/dev/null; return 1; }
    git rm -rf --cached . 2>/dev/null || true
  else
    # track mode: create a new branch from the current HEAD, keeping the working tree
    git checkout -b "$branch" || { err "checkout -b $branch failed"; cd - >/dev/null; return 1; }
  fi

  cd - >/dev/null
  return 0
}

# ============================ Remote reachability / branch existence ============================ #

# Verify the remote repository is reachable and authentication works.
# Distinguishes three states:
#   0 = reachable (including "repository exists but is empty")
#   1 = repository missing / authentication failure / network problem
# Determined by whether git wrote anything to stderr: an empty repo exits 2 with no
# stderr, a missing repo exits 128 with stderr output.
verify_remote_access() {
  local repo_url="$1"
  local err_out
  err_out=$(git ls-remote "$repo_url" HEAD 2>&1 >/dev/null) || true
  # Repository missing / no permission → git reports the error on stderr
  if [ -n "$err_out" ]; then
    return 1
  fi
  return 0
}

# Detect whether a remote branch exists (requires a prior fetch, or uses ls-remote).
# Returns 0 when it exists; 1 when it does not.
remote_branch_exists() {
  local repo_url="$1" branch="$2"
  git ls-remote --exit-code --heads "$repo_url" "$branch" &>/dev/null
}

# ============================ Single-directory sync core ============================ #

sync_single_dir() {
  local op="$1" project_dir="$2" project_branch="$3" repo_url="$4" rel_dir="$5"
  local branch="docs/$project_branch"
  local intro="$project_dir/$rel_dir"

  if [ "$op" = "pull" ]; then
    if [ -d "$intro/.git" ]; then
      cd "$intro"
      if ! remote_branch_exists "$repo_url" "$branch"; then
        warn "$rel_dir has no remote branch $branch yet, nothing to pull"
        info "Hint: if you have local content, run push first to create the remote branch"
        cd - >/dev/null
        return 0
      fi
      switch_to_branch "$intro" "$branch" track
      info "Pulling $rel_dir from remote branch $branch ..."
      if git pull --no-rebase origin "$branch"; then
        ok "$rel_dir pull complete"
        cd - >/dev/null
        return 0
      else
        err "$rel_dir hit a merge conflict, resolve it manually and finish the merge:"
        err "  1. Edit the conflicting files and resolve the <<<<<<< / ======= / >>>>>>> markers"
        err "  2. git add -A"
        err "  3. git commit -m 'merge: resolve conflicts'"
        err ""
        err "To cancel this merge:"
        err "  git merge --abort"
        cd - >/dev/null
        return 1
      fi
    fi

    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      info "$rel_dir has local content but is not under version control, initializing ..."
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
        info "$rel_dir has no remote branch $branch yet, local content is now versioned"
        info "Run push to create the remote branch"
        cd - >/dev/null
        return 0
      fi

      git fetch origin "$branch"

      if [ -z "$(git config user.name)" ]; then
        git config user.email "docs-sync@local"
        git config user.name "docs-sync"
      fi

      git add -A
      git commit -q -m "chore: bring $rel_dir local content under version control" 2>/dev/null || true
      local local_commit
      local_commit=$(git rev-parse HEAD 2>/dev/null)

      git checkout -b "$branch" "origin/$branch" -q 2>/dev/null || git checkout "$branch" -q 2>/dev/null

      if [ -n "$local_commit" ]; then
        if git merge "$local_commit" --allow-unrelated-histories --no-edit -q 2>/dev/null; then
          ok "$rel_dir merged local content into remote branch ${branch}"
        else
          warn "$rel_dir hit a content conflict while merging (same file on both sides), resolve manually:"
          git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  conflicting file: /'
          err "Edit the files above to resolve the conflict, then:"
          err "  cd $intro && git add -A && git commit -m 'merge: resolve conflicts'"
          err "Or discard local content and overwrite with the remote: cd $intro && git merge --abort && git checkout -f ."
          cd - >/dev/null
          return 1
        fi
      fi
      ok "$rel_dir pull complete (remote branch ${branch})"
      cd - >/dev/null
      return 0
    fi

    if remote_branch_exists "$repo_url" "$branch"; then
      info "$rel_dir first pull: initializing from remote branch $branch ..."
      mkdir -p "$intro"
      cd "$intro"
      git init -q
      git remote add origin "$repo_url"
      git fetch origin "$branch"
      git checkout -b "$branch" "origin/$branch"
      ok "$rel_dir checked out remote branch $branch"
      cd - >/dev/null
      return 0
    fi

    info "$rel_dir is empty locally and branch $branch does not exist remotely, skipping"
    return 0
  fi

  if [ ! -d "$intro/.git" ]; then
    if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
      info "$rel_dir first push: bringing local content under version control ..."
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
        info "$rel_dir now tracks remote branch $branch"
      else
        git checkout -b "$branch"
        info "$rel_dir created local branch $branch"
      fi
    else
      info "$rel_dir does not exist or is empty, skipping"
      return 0
    fi
  fi

  cd "$intro"

  if ! git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -qx "$branch"; then
    switch_to_branch "$intro" "$branch" track
  fi

  if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
    err "git user identity is not configured, cannot commit"
    err "Run this (replace with your own details):"
    err "  git config --global user.name 'Your Name'"
    err "  git config --global user.email 'you@example.com'"
    err "Or configure it locally inside $rel_dir only:"
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
    ok "$rel_dir has no changes, nothing to push"
    cd - >/dev/null
    return 0
  fi

  git add -A
  local timestamp project_name
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  project_name=$(basename "$project_dir")
  git commit -m "docs($project_branch): sync $rel_dir

Auto-synced at $timestamp
Project: $project_name"

  info "Pushing $rel_dir to the remote (branch: $branch) ..."
  if git push -u origin "$branch"; then
    ok "$rel_dir push complete! remote: $repo_url (branch: $branch)"
    cd - >/dev/null
    return 0
  else
    err "$rel_dir push failed, the remote has newer commits that are not merged"
    err "Run pull to merge the remote changes first, then push again"
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
  local cache_conf="$project_dir/.agents/.cache/docs-sync.conf"

  echo "--- sync-project-memory diagnose ---"
  echo "Project directory: $project_dir"
  echo "Branch slug: ${project_branch:-(undetermined)}"

  local url=""
  if [ -f "$cache_conf" ]; then
    url=$(head -1 "$cache_conf" | tr -d '[:space:]')
  fi
  if [ -n "$url" ]; then
    echo "Memory repository URL: $url"
    echo "URL configured: yes"
  else
    echo "Memory repository URL: (not configured)"
    echo "URL configured: no"
  fi

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "[$rel_dir]"
    if [ -d "$intro/.git" ]; then
      echo "Local repository initialized: yes"
      (cd "$intro" && \
        echo "Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)" && \
        local_changes=$(git status --short 2>/dev/null | head -20) && \
        if [ -n "$local_changes" ]; then
          echo "Uncommitted local changes: yes"
          echo "$local_changes" | sed 's/^/  /'
        else
          echo "Uncommitted local changes: no"
        fi && \
        ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || true) && \
        behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || true) && \
        if [ -z "$ahead" ] && [ -z "$behind" ]; then
          echo "Sync status: no upstream branch yet (never synced with the remote, run pull first)"
        else
          echo "Ahead of remote: ${ahead:-0} commits (local commits not pushed)"
          echo "Behind remote: ${behind:-0} commits (remote updates not pulled)"
          if [ "${ahead:-0}" = "0" ] && [ "${behind:-0}" = "0" ]; then
            echo "In sync with remote: yes"
          else
            echo "In sync with remote: no"
          fi
        fi)
    else
      if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        echo "Local repository initialized: no (directory has content but is not versioned)"
      else
        echo "Local repository initialized: no (directory is empty or missing)"
      fi
    fi
  done

  if [ -z "$(git config user.name 2>/dev/null)" ] || [ -z "$(git config user.email 2>/dev/null)" ]; then
    echo "git user identity: not configured (push will fail)"
  else
    echo "git user identity: configured"
  fi

  echo "--- diagnose complete ---"
}

# ============================ info ============================ #

do_info() {
  local project_dir="$1" project_branch="$2" repo_url="$3"
  local branch="docs/$project_branch"

  echo "--- sync-project-memory status ---"
  echo "Branch slug: ${project_branch:-(undetermined)}"

  if [ -n "$repo_url" ]; then
    echo "Memory repository URL: $repo_url"
  else
    echo "Memory repository URL: (not configured)"
  fi

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "[$rel_dir]"
    if [ ! -d "$intro/.git" ]; then
      if [ -e "$intro" ] && [ -n "$(find "$intro" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        echo "Local repository: not initialized (directory has content but is not versioned)"
      else
        echo "Local repository: not initialized (directory is empty or missing)"
      fi
      echo "(Run pull to initialize, or push to bring local content under version control)"
      continue
    fi

    cd "$intro" || continue
    echo "Current branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"

    local local_changes
    local_changes=$(git status --short 2>/dev/null | head -20)
    if [ -n "$local_changes" ]; then
      echo "Uncommitted local changes: yes"
      echo "$local_changes" | sed 's/^/  /'
    else
      echo "Uncommitted local changes: no"
    fi

    if [ -n "$repo_url" ]; then
      git fetch origin "$branch" 2>/dev/null || true
      local ahead behind
      ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || true)
      behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || true)
      if [ -z "$ahead" ] && [ -z "$behind" ]; then
        echo "Remote sync status: no upstream branch yet (never synced with the remote)"
      else
        echo "Ahead of remote: ${ahead:-0} commits (not pushed)"
        echo "Behind remote: ${behind:-0} commits (remote updates not pulled)"
        if [ "${ahead:-0}" = "0" ] && [ "${behind:-0}" = "0" ]; then
          echo "Remote sync status: in sync"
        fi
      fi
    else
      echo "Remote sync status: URL not configured, cannot compare"
    fi

    echo "Recent commits:"
    git log --oneline -3 2>/dev/null || echo "  (no commits yet)"
    cd - >/dev/null
  done

  echo "--- status complete ---"
}

# ============================ status ============================ #

do_status() {
  local project_dir="$1" project_branch="$2"
  local branch="docs/$project_branch"

  for rel_dir in "${SYNC_DIRS[@]}"; do
    local intro="$project_dir/$rel_dir"
    echo "=== $rel_dir repository status ==="
    if [ ! -d "$intro/.git" ]; then
      err "$rel_dir is not initialized as a git repository yet"
      warn "Run this first: bash $(basename "$0") pull"
      continue
    fi
    cd "$intro"
    echo "Branch slug:  $project_branch"
    echo "Branch:       $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'none')"
    echo "Remote:       $(git remote get-url origin 2>/dev/null || echo 'not configured')"
    if [ -n "$(git status --short 2>/dev/null)" ]; then
      git status --short
    else
      echo "Working tree is clean, no uncommitted changes"
    fi
    git fetch origin "$branch" 2>/dev/null || true
    local ahead behind
    ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo "?")
    behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo "?")
    echo "Ahead of remote: $ahead commits  |  Behind remote: $behind commits"
    echo ""
    echo "--- recent commits ---"
    git log --oneline -5 2>/dev/null || echo "(no commits yet)"
    cd - >/dev/null
  done
}

# ============================ main ============================ #

main() {
  local op="${1:-}"

  # Direction validation: only pull / push / info / status / config / diagnose are accepted.
  # Invalid or empty → structured error (meant to be read by the model), exits 2 to
  # distinguish it from a normal non-zero failure.
  # With no argument, print the diagnose state (URL / initialization) first so the model
  # can see at a glance whether configuration is ready.
  if [ "$op" != "push" ] && [ "$op" != "pull" ] && [ "$op" != "info" ] && [ "$op" != "status" ] && [ "$op" != "config" ] && [ "$op" != "diagnose" ]; then
    # Empty argument → print the current state first to help the model decide whether the
    # URL still needs to be configured.
    if [ -z "$op" ]; then
      local _project_dir
      _project_dir="$(cd "$(dirname "$0")/../../../../" && pwd)"
      local _project_branch _repo_url _main_url
      _main_url=$(detect_main_repo_url "$_project_dir" 2>/dev/null || echo "")
      _project_branch=$(detect_project_branch "$_project_dir" 2>/dev/null || echo "")
      _repo_url=$(detect_remote_repo "$_project_dir")
      echo "--- current configuration state ---"
      echo "Main repo origin: ${_main_url:-(not configured)}"
      echo "Branch slug: ${_project_branch:-(undetermined)}"
      if [ -n "$_repo_url" ]; then
        echo "Memory repository URL: $_repo_url"
        echo "URL configured: yes"
      else
        echo "Memory repository URL: (not configured)"
        echo "URL configured: no"
      fi
      echo "-------------------"
    fi
    echo "[SYNC_ERROR] Argument validation failed"
    if [ -z "$op" ]; then
      echo "Reason: no direction given (argument is empty)"
    else
      echo "Reason: direction must be pull / push / info, received: $op"
    fi
    echo "Fix: usage is as follows"
    echo "  /sync-project-memory pull     fetch project memory from the remote"
    echo "  /sync-project-memory push     push local project memory to the remote"
    echo "  /sync-project-memory info     show project memory sync status"
    echo "  bash $(basename "$0") config <url>  configure the memory repository URL"
    exit 2
  fi

  echo "=== sync-project-memory ($op) ==="

  local project_dir
  project_dir="$(cd "$(dirname "$0")/../../../../" && pwd)"
  echo "Project directory: $project_dir"

  # config subcommand: write the URL and exit (no project identity needed)
  if [ "$op" = "config" ]; then
    local url="${2:-}"
    if [ -z "$url" ]; then
      err "Usage: bash $(basename "$0") config <url>"
      err "Example: bash $(basename "$0") config https://github.com/youruser/codex-project-docs.git"
      exit 1
    fi
    local conf_path
    if ! conf_path=$(write_remote_repo "$project_dir" "$url"); then
      exit 1
    fi
    ok "Wrote memory repository URL: $url"
    info "Config file: $conf_path"
    info "You can now run pull / push to sync project memory"
    exit 0
  fi

  # diagnose: print a summary only, no URL detection or reachability pre-check, always
  # exits 0.
  if [ "$op" = "diagnose" ]; then
    local project_branch_for_diag
    project_branch_for_diag=$(detect_project_branch "$project_dir" 2>/dev/null || echo "")
    do_diagnose "$project_dir" "$project_branch_for_diag"
    exit 0
  fi

  local project_branch
  project_branch=$(detect_project_branch "$project_dir")
  if [ -z "$project_branch" ]; then
    err "Cannot derive a project identity from the main repo origin remote"
    err "Configure a remote on the main code repository first, for example:"
    err "  git remote add origin https://github.com/youruser/your-code-repo.git"
    exit 1
  fi
  echo "Branch: docs/$project_branch"

  local repo_url
  repo_url=$(detect_remote_repo "$project_dir")

  # info: query status only, no reachability pre-check, tolerates a missing URL or an
  # unreachable remote, always exits 0.
  if [ "$op" = "info" ]; then
    do_info "$project_dir" "$project_branch" "$repo_url"
    exit 0
  fi

  if [ -z "$repo_url" ]; then
    err "Remote memory repository URL is not configured"
    err "Create an empty repository on GitHub first (dedicated to project memory), then set its URL:"
    echo ""
    info "Run this (replace the URL with the memory repository you created):"
    echo "  bash .agents/skills/sync-project-memory/scripts/sync-memory.sh config https://github.com/youruser/codex-project-docs.git"
    echo ""
    err "After configuring, run pull / push / status again"
    exit 1
  fi
  echo "Memory repository: $repo_url"
  echo ""

  # Remote reachability / authentication pre-check
  info "Verifying remote memory repository reachability ..."
  if ! verify_remote_access "$repo_url"; then
    err "Remote memory repository is not reachable: $repo_url"
    err "Possible causes:"
    err "  1. The memory repository does not exist (create the empty repo on GitHub/GitLab first)"
    err "  2. Authentication failed (check your SSH key or HTTPS token / credentials)"
    err "  3. Network problem"
    exit 1
  fi

  # .gitignore / parent git tracking check (reported for both pull and push)
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
    echo "=== done (with errors, exit code ${rc}) ==="
  else
    echo "=== done ==="
  fi
  exit "$rc"
}

main "$@"
