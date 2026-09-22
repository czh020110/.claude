#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

PLATFORM_ARG="${1:-}"
WORKBUDDY_VARIANT="international"
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
  codebuddy|CodeBuddy|--codebuddy)
    PLATFORM="codebuddy"
    ;;
  workbuddy|WorkBuddy|--workbuddy|workbuddy-ai|WorkBuddyAI|--workbuddy-ai)
    PLATFORM="workbuddy"
    WORKBUDDY_VARIANT="international"
    ;;
  workbuddy-cn|WorkBuddyCN|--workbuddy-cn|workbuddy-domestic|WorkBuddyDomestic|--workbuddy-domestic)
    PLATFORM="workbuddy"
    WORKBUDDY_VARIANT="domestic"
    ;;
  opencode|OpenCode|--opencode)
    PLATFORM="opencode"
    ;;
  *)
    echo "Usage: ${0##*/} codex|zcode|claude|codebuddy|workbuddy|workbuddy-cn|opencode" >&2
    exit 2
    ;;
esac

# codebuddy targets the domestic CodeBuddy client (~/.codebuddy/skills, project .codebuddy/).
# workbuddy targets the international WorkBuddy client (~/.workbuddy-ai/skills).
# workbuddy-cn targets the domestic WorkBuddy client (~/.workbuddy/skills).
# They are separate platforms because the clients scan different directories.
if [ "$PLATFORM" = "codebuddy" ] || [ "$PLATFORM" = "workbuddy" ]; then
  REPO_URL="${PROJECT_CONFIG_REPO_URL:-${CODEBUDDY_CONFIG_REPO_URL:-${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}}}"
else
  REPO_URL="${PROJECT_CONFIG_REPO_URL:-${CODEX_CONFIG_REPO_URL:-https://github.com/czh020110/.claude.git}}"
fi

PROJECT_DIR="$(pwd)"

# Self-update of the global skill: on first launch, clone the remote template,
# overwrite sync-project-config in the project root, then exec the fresh script.
# The temporary clone directory is handed to the second run via an environment
# variable so the repository is not cloned twice.
if [ "${SYNC_PROJECT_CONFIG_BOOTSTRAPPED:-0}" != "1" ]; then
  BOOTSTRAP_TMP="$(mktemp -d)"
  trap 'rm -rf "$BOOTSTRAP_TMP"' EXIT
  echo "[bootstrap] Fetching the latest remote sync-project-config..."
  if ! git clone --depth 1 "$REPO_URL" "$BOOTSTRAP_TMP" 2>&1; then
    echo "Error: unable to clone the config source, project sync aborted" >&2
    exit 1
  fi
  if [ ! -d "$BOOTSTRAP_TMP/sync-project-config" ]; then
    echo "Error: remote template is missing sync-project-config/ at the repo root" >&2
    exit 1
  fi
  rm -rf "$PROJECT_DIR/sync-project-config"
  cp -R "$BOOTSTRAP_TMP/sync-project-config" "$PROJECT_DIR/sync-project-config"
  echo "[bootstrap] Updated sync-project-config in the project root, re-running the latest script"
  exec env SYNC_PROJECT_CONFIG_BOOTSTRAPPED=1 SYNC_PROJECT_CONFIG_REMOTE_DIR="$BOOTSTRAP_TMP" \
    bash "$PROJECT_DIR/sync-project-config/scripts/sync.sh" "$@"
fi

TMP_DIR="${SYNC_PROJECT_CONFIG_REMOTE_DIR:?}"
trap 'rm -rf "$TMP_DIR"' EXIT

SKILL_NAME="sync-project-config"
# Canonical install location: one real copy shared by every platform.
CANONICAL_SKILL_DIR="${CODEX_GLOBAL_SKILL_DIR:-$HOME/.agents/skills}"
# Per-platform skill directories are link targets rather than second copies: clients that
# do not read .agents/skills natively get a symlink back to the canonical copy.
if [ "$PLATFORM" = "opencode" ]; then
  # OpenCode reads ~/.agents/skills/ natively, so the canonical copy needs no symlink.
  GLOBAL_SKILL_DIR="${OPENCODE_GLOBAL_SKILL_DIR:-$CANONICAL_SKILL_DIR}"
elif [ "$PLATFORM" = "workbuddy" ]; then
  if [ "$WORKBUDDY_VARIANT" = "domestic" ]; then
    WORKBUDDY_DEFAULT_SKILL_DIR="$HOME/.workbuddy/skills"
  else
    WORKBUDDY_DEFAULT_SKILL_DIR="$HOME/.workbuddy-ai/skills"
  fi
  GLOBAL_SKILL_DIR="${WORKBUDDY_GLOBAL_SKILL_DIR:-$WORKBUDDY_DEFAULT_SKILL_DIR}"
elif [ "$PLATFORM" = "codebuddy" ]; then
  GLOBAL_SKILL_DIR="${CODEBUDDY_GLOBAL_SKILL_DIR:-$HOME/.codebuddy/skills}"
elif [ "$PLATFORM" = "claude" ]; then
  GLOBAL_SKILL_DIR="${CLAUDE_GLOBAL_SKILL_DIR:-$HOME/.claude/skills}"
else
  GLOBAL_SKILL_DIR="$CANONICAL_SKILL_DIR"
fi

# Protocol marker: splits AGENTS.md into the managed section (everything strictly
# above the marker) and the project's custom prompts (the marker and everything
# below). Matched byte for byte, so it is deliberately language-neutral and must
# never be translated, reworded or edited.
CUSTOM_MARKER='<!-- sync-project-config:custom-prompts -->'

# True when a file already carries the custom-prompt marker. A file without one is
# taken to be the project's own prompts: the sync moves all of it below the marker
# instead of overwriting it (see sync_agents_md / sync_claude_md).
has_custom_marker() {
  [ -f "$1" ] || return 1
  grep -qxF "$CUSTOM_MARKER" "$1"
}

# AGENTS.md is authored against Codex's tool names. Select the equivalent names
# before generating a platform-specific copy.
PLAN_TOOL="update_plan"
QUESTION_TOOL="request_user_input"
case "$PLATFORM" in
  claude|zcode|codebuddy|workbuddy)
    PLAN_TOOL="TodoWrite"
    QUESTION_TOOL="AskUserQuestion"
    ;;
  opencode)
    PLAN_TOOL="todowrite"
    QUESTION_TOOL="question"
    ;;
esac

echo "=== sync-project-config ($PLATFORM) ==="
echo "Project directory: $PROJECT_DIR"
echo "Remote repository: $REPO_URL"
echo ""

echo "[1/7] Using the updated remote config source: $TMP_DIR"
echo ""

copy_tree() {
  local src="$1"
  local dest="$2"
  [ -d "$src" ] || return 0

  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      .cache/*|settings.local.json|*.local.json|*.secret*|*.key|.DS_Store|CODEBUDDY.local.md|__pycache__/*|*.pyc)
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
    echo "  ✓ synced: ${dest_file#"$PROJECT_DIR/"}"
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
    echo "  + added: ${dest_file#"$PROJECT_DIR/"}"
  done < <(cd "$src" && find . -type f -print0)
}

# Refresh only the first-line title of existing .project-memory files. The title is
# managed and comes from the template; everything below it is what the project has
# accumulated and is never touched. A file that has no title yet gets one inserted
# above its current first line.
sync_memory_titles() {
  local src="$1"
  local dest="$2"
  [ -d "$src" ] || return 0

  while IFS= read -r -d '' rel_path; do
    rel_path="${rel_path#./}"
    case "$rel_path" in
      *.md) ;;
      *) continue ;;
    esac
    local src_file="$src/$rel_path"
    local dest_file="$dest/$rel_path"
    if [ ! -f "$dest_file" ]; then
      continue
    fi

    local src_title=""
    IFS= read -r src_title < "$src_file" || src_title=""
    case "$src_title" in
      "# "*) ;;
      *) continue ;;
    esac

    local dest_title=""
    IFS= read -r dest_title < "$dest_file" || dest_title=""
    if [ "$dest_title" = "$src_title" ]; then
      continue
    fi

    local tmp="$dest_file.tmp"
    case "$dest_title" in
      "# "*)
        # Replace the title line, keep every following line as it is.
        printf '%s\n' "$src_title" > "$tmp"
        tail -n +2 "$dest_file" >> "$tmp"
        ;;
      *)
        # No title yet: insert one above the existing content.
        printf '%s\n\n' "$src_title" > "$tmp"
        cat "$dest_file" >> "$tmp"
        ;;
    esac
    mv "$tmp" "$dest_file"
    echo "  ~ title: ${dest_file#"$PROJECT_DIR/"}"
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
      */agents/openai.yaml|*/agents/*.yaml|.DS_Store|__pycache__/*|*.pyc)
        continue
        ;;
    esac
    local src_file="$src/$rel_path"
    local dest_file="$dest/$rel_path"
    mkdir -p "$(dirname "$dest_file")"
      if [[ "$rel_path" == */SKILL.md ]]; then
        python3 - "$src_file" "$dest_file" "$target_platform" "$PLAN_TOOL" "$QUESTION_TOOL" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
platform = sys.argv[3]
plan_tool = sys.argv[4]
question_tool = sys.argv[5]
text = source.read_text(encoding="utf-8")
# Skill bodies are authored against Codex's tool names, exactly like AGENTS.md,
# so they are renamed per platform here too.
text = text.replace("update_plan", plan_tool).replace("request_user_input", question_tool)
if not text.startswith("---\n"):
    target.write_text(text, encoding="utf-8")
    raise SystemExit

end = text.find("\n---\n", 4)
if end < 0:
    target.write_text(text, encoding="utf-8")
    raise SystemExit

front = text[4:end].splitlines()
body = text[end + len("\n---\n"):]
if platform in {"claude", "codebuddy", "workbuddy"} and not any(line.startswith("user-invocable:") for line in front):
    front.append("user-invocable: true")
target.write_text("---\n" + "\n".join(front) + "\n---\n" + body, encoding="utf-8")
PY
    elif [[ "$rel_path" == sync-project-memory/scripts/sync-memory.sh && "$target_platform" != "zcode" ]]; then
      python3 - "$src_file" "$dest_file" "$target_platform" <<'PY'
import sys
from pathlib import Path

source, target, platform = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
text = source.read_text(encoding="utf-8")
prefix = {"claude": ".claude", "codebuddy": ".codebuddy", "workbuddy": ".codebuddy", "opencode": ".opencode"}[platform]
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
    "docs_research": "haiku",
}
codebuddy_tools = {
    "collect_update_memory": ("Read, Grep, Glob, Bash, Write, Edit", ""),
    "docs_research": ("Read, Grep, Glob, Bash, WebFetch", "Edit, Write"),
}

for source in sorted(source_dir.glob("*.toml")):
    text = source.read_text(encoding="utf-8")
    name_match = re.search(r'^name\s*=\s*"([^"]+)"', text, re.MULTILINE)
    desc_match = re.search(r'^description\s*=\s*"([^"]*)"', text, re.MULTILINE)
    body_match = re.search(r'developer_instructions\s*=\s*"""\n(.*?)\n"""', text, re.DOTALL)
    if not (name_match and desc_match and body_match):
        raise SystemExit(f"Unable to parse Codex agent: {source}")

    source_name = name_match.group(1)
    target_name = source_name.replace("_", "-")
    description = desc_match.group(1)
    body = body_match.group(1)
    lines = ["---"]
    # OpenCode derives the agent name from the file name, so no `name:` key is emitted.
    if platform != "opencode":
        lines.append(f"name: {target_name}")
    lines.append(f"description: {json.dumps(description, ensure_ascii=False)}")
    if platform == "claude" and source_name in claude_models:
        lines.append(f"model: {claude_models[source_name]}")
    elif platform == "zcode":
        lines.append("model: glm-5.3-flash")
    elif platform in ("codebuddy", "workbuddy"):
        tools, disallowed = codebuddy_tools.get(source_name, ("", ""))
        if tools:
            lines.append(f"tools: {tools}")
        if disallowed:
            lines.append(f"disallowedTools: {disallowed}")
    elif platform == "opencode":
        lines.append("mode: subagent")
    lines += ["---", body, ""]
    (target_dir / f"{target_name}.md").write_text("\n".join(lines), encoding="utf-8")
PY

  echo "  ✓ Agent: $dest"
}

adapt_agent_tools() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import sys
from pathlib import Path

path, marker, from1, to1, from2, to2 = sys.argv[1:7]
text = Path(path).read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
rule_end = len(lines)
for i, line in enumerate(lines):
    if line.rstrip("\n") == marker:
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

  # A source without a marker cannot be split, and a project with no AGENTS.md yet
  # has nothing to preserve, so both are copied whole.
  if ! grep -qxF "$CUSTOM_MARKER" "$remote" || [ ! -f "$local_file" ]; then
    cp "$remote" "$local_file"
  elif has_custom_marker "$local_file"; then
    local remote_end local_start
    remote_end=$(grep -n -xF "$CUSTOM_MARKER" "$remote" | head -1 | cut -d: -f1)
    local_start=$(grep -n -xF "$CUSTOM_MARKER" "$local_file" | head -1 | cut -d: -f1)
    # Everything strictly above the marker is managed and comes from the source;
    # the marker and everything below it come from the local file.
    head -n "$((remote_end - 1))" "$remote" > "$local_file.tmp"
    printf '%s\n' "$CUSTOM_MARKER" >> "$local_file.tmp"
    tail -n +"$((local_start + 1))" "$local_file" >> "$local_file.tmp"
    mv "$local_file.tmp" "$local_file"
  else
    # No marker: the whole file is the project's own prompts. Keep all of it by
    # moving it below the marker, under the source's custom-prompt note.
    local remote_end
    remote_end=$(grep -n -xF "$CUSTOM_MARKER" "$remote" | head -1 | cut -d: -f1)
    head -n "$((remote_end - 1))" "$remote" > "$local_file.tmp"
    printf '%s\n' "$CUSTOM_MARKER" >> "$local_file.tmp"
    tail -n +"$((remote_end + 1))" "$remote" >> "$local_file.tmp"
    cat "$local_file" >> "$local_file.tmp"
    mv "$local_file.tmp" "$local_file"
    echo "  + adopted: AGENTS.md had no marker, its content was moved below the marker"
  fi

  if [ "$PLAN_TOOL" != "update_plan" ] || [ "$QUESTION_TOOL" != "request_user_input" ]; then
    adapt_agent_tools "$local_file" "$CUSTOM_MARKER" update_plan "$PLAN_TOOL" request_user_input "$QUESTION_TOOL"
  fi
}

sync_claude_md() {
  [ "$PLATFORM" = "claude" ] || return 0
  local remote="$TMP_DIR/AGENTS.md"
  [ -f "$remote" ] || return 0
  local target="$PROJECT_DIR/CLAUDE.md"
  local tmp="$PROJECT_DIR/CLAUDE.md.tmp"
  if ! grep -qxF "$CUSTOM_MARKER" "$remote"; then
    cp "$remote" "$target"
    return 0
  fi
  local remote_end
  remote_end=$(grep -n -xF "$CUSTOM_MARKER" "$remote" | head -1 | cut -d: -f1)
  head -n "$((remote_end - 1))" "$remote" > "$tmp"
  adapt_agent_tools "$tmp" "$CUSTOM_MARKER" update_plan "$PLAN_TOOL" request_user_input "$QUESTION_TOOL"
  if [ ! -f "$target" ]; then
    tail -n +"$remote_end" "$remote" >> "$tmp"
  elif has_custom_marker "$target"; then
    local custom_start
    custom_start=$(grep -n -xF "$CUSTOM_MARKER" "$target" | head -1 | cut -d: -f1)
    printf '%s\n' "$CUSTOM_MARKER" >> "$tmp"
    tail -n +"$((custom_start + 1))" "$target" >> "$tmp"
  else
    # No marker: the whole file is the project's own prompts. Keep all of it by
    # moving it below the marker, under the source's custom-prompt note.
    printf '%s\n' "$CUSTOM_MARKER" >> "$tmp"
    tail -n +"$((remote_end + 1))" "$remote" >> "$tmp"
    cat "$target" >> "$tmp"
    echo "  + adopted: CLAUDE.md had no marker, its content was moved below the marker"
  fi
  mv "$tmp" "$target"
}

sync_platform() {
  case "$PLATFORM" in
    codex)
      copy_tree "$TMP_DIR/.codex" "$PROJECT_DIR/.codex"
      copy_tree "$TMP_DIR/.agents" "$PROJECT_DIR/.agents"
      ;;
    zcode)
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
      ;;
    workbuddy)
      # WorkBuddy reuses CodeBuddy Code's workspace layout, so its project-level
      # config lives in `.codebuddy/` even though its user-level directory is
      # ~/.workbuddy-ai (international) or ~/.workbuddy (domestic).
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.codebuddy/agents" workbuddy
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.codebuddy/skills" workbuddy
      ;;
    opencode)
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.opencode/agents" opencode
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.opencode/skills" opencode
      ;;
  esac
}

# Link a platform skill directory back to the canonical copy. Only replaces an existing
# symlink; a real directory is left untouched so user data is never deleted.
link_skill_into() {
  local target="$1"
  local link_dir="$2"
  [ -d "$target" ] || return 0
  [ -d "$(dirname "$link_dir")" ] || return 0
  mkdir -p "$link_dir" || return 0
  local dest="$link_dir/$SKILL_NAME"
  if [ -L "$dest" ]; then
    rm -f "$dest"
  elif [ -e "$dest" ]; then
    echo "  ! left untouched (not a symlink): $dest"
    return 0
  fi
  ln -s "$target" "$dest"
  echo "  ✓ linked: $dest -> $target"
}

sync_global_skill() {
  # The freshly fetched remote is authoritative; the project-root copy is only a
  # fallback for a run that was started without a bootstrap clone.
  local source=""
  for candidate in "$TMP_DIR/$SKILL_NAME" "$PROJECT_DIR/$SKILL_NAME"; do
    if [ -d "$candidate" ]; then
      source="$candidate"
      break
    fi
  done
  [ -n "$source" ] || return 0

  mkdir -p "$CANONICAL_SKILL_DIR"
  rm -rf "$CANONICAL_SKILL_DIR/$SKILL_NAME"
  cp -R "$source" "$CANONICAL_SKILL_DIR/$SKILL_NAME"
  echo "  ✓ Global skill: $CANONICAL_SKILL_DIR/$SKILL_NAME"

  local canonical_target="$CANONICAL_SKILL_DIR/$SKILL_NAME"
  case "$PLATFORM" in
    claude|codebuddy)
      [ "$GLOBAL_SKILL_DIR" = "$CANONICAL_SKILL_DIR" ] || link_skill_into "$canonical_target" "$GLOBAL_SKILL_DIR"
      ;;
    workbuddy)
      local link_dirs="${WORKBUDDY_SKILL_LINK_DIRS:-$GLOBAL_SKILL_DIR}"
      local dir
      local IFS=:
      for dir in $link_dirs; do
        unset IFS
        [ "$dir" = "$CANONICAL_SKILL_DIR" ] || link_skill_into "$canonical_target" "$dir"
      done
      ;;
    zcode)
      if [ -d "$HOME/.zcode/skills" ]; then
        link_skill_into "$canonical_target" "$HOME/.zcode/skills"
      fi
      ;;
  esac
}

echo "[2/7] Syncing AGENTS.md and the global skill..."
sync_agents_md
sync_claude_md
sync_global_skill
echo ""

echo "[3/7] Generating platform agents and skills..."
sync_platform
echo ""

echo "[4/7] Syncing project memory templates..."
copy_missing_tree "$TMP_DIR/.project-memory" "$PROJECT_DIR/.project-memory"
sync_memory_titles "$TMP_DIR/.project-memory" "$PROJECT_DIR/.project-memory"
echo ""

echo "[5/7] Syncing project verification templates..."
copy_missing_tree "$TMP_DIR/.project-script" "$PROJECT_DIR/.project-script"
echo ""

echo "[6/7] Checking .gitignore..."
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ "$PLATFORM" = "opencode" ]; then
  ENTRIES=( ".project-memory/" ".project-script/" ".opencode/" "sync-project-config/" )
  HEADER="# OpenCode / project-local config"
  elif [ "$PLATFORM" = "workbuddy" ]; then
    ENTRIES=( ".project-memory/" ".project-script/" "sync-project-config/" ".codebuddy/" )
    if [ "$WORKBUDDY_VARIANT" = "domestic" ]; then
      HEADER="# WorkBuddy domestic / project-local config"
    else
      HEADER="# WorkBuddy international / project-local config"
    fi
  elif [ "$PLATFORM" = "codebuddy" ]; then
    ENTRIES=( ".project-memory/" ".project-script/" "sync-project-config/" ".codebuddy/" )
    HEADER="# CodeBuddy / project-local config"
else
  ENTRIES=( ".codex/" ".zcode/" ".claude/" ".agents/" ".project-memory/" ".project-script/" "sync-project-config/" "AGENTS.md" "CLAUDE.md" )
  HEADER="# Agent / project-local config"
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

echo "[7/7] Sync complete"
