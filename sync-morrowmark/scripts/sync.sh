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
  cursor|Cursor|--cursor)
    PLATFORM="cursor"
    ;;
  copilot|Copilot|github-copilot|GitHubCopilot|--copilot|--github-copilot)
    PLATFORM="github-copilot"
    ;;
  antigravity|Antigravity|--antigravity|antigravity-cli|AntigravityCLI|--antigravity-cli)
    PLATFORM="antigravity"
    ;;
  *)
    echo "Usage: ${0##*/} codex|zcode|claude|codebuddy|workbuddy|workbuddy-cn|opencode|cursor|github-copilot|antigravity" >&2
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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[bootstrap] Fetching the current project configuration source..."
if ! git clone --depth 1 "$REPO_URL" "$TMP_DIR" 2>&1; then
  echo "Error: unable to clone the config source, project sync aborted" >&2
  exit 1
fi
if [ ! -f "$TMP_DIR/AGENTS.md" ] && [ ! -d "$TMP_DIR/.codex" ]; then
  echo "Error: remote repository does not contain project configuration templates" >&2
  exit 1
fi

# Protocol marker: splits AGENTS.md into the managed section (everything strictly
# above the marker) and the project's custom prompts (the marker and everything
# below). Always emit the current marker, but recognize earlier sync-prefixed
# marker names so existing project prompts survive the rename.
CUSTOM_MARKER='<!-- sync-morrowmark:custom-prompts -->'
CUSTOM_MARKER_PATTERN='^<!-- sync-[[:alnum:]-]+:custom-prompts -->$'

# True when a file already carries the custom-prompt marker. A file without one is
# taken to be the project's own prompts: the sync moves all of it below the marker
# instead of overwriting it (see sync_agents_md / sync_claude_md).
has_custom_marker() {
  [ -f "$1" ] || return 1
  grep -Eq "$CUSTOM_MARKER_PATTERN" "$1"
}

custom_marker_line() {
  local line
  line=$(awk -v pattern="$CUSTOM_MARKER_PATTERN" '$0 ~ pattern { print NR; exit }' "$1")
  [ -n "$line" ] || return 1
  printf '%s\n' "$line"
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
  cursor)
    PLAN_TOOL="/plan"
    QUESTION_TOOL="ask the user in chat"
    ;;
  github-copilot)
    PLAN_TOOL="update_todo"
    QUESTION_TOOL="ask_user"
    ;;
  antigravity)
    PLAN_TOOL="/plan"
    QUESTION_TOOL="ask_question"
    ;;
esac

echo "=== sync-morrowmark ($PLATFORM) ==="
echo "Project directory: $PROJECT_DIR"
echo "Remote repository: $REPO_URL"
echo ""

echo "[1/7] Using the current project config source: $TMP_DIR"
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
    if [ "$(basename "$src")" = ".codex" ] && [[ "$rel_path" == agents/*.toml ]] && [ -f "$dest_file" ]; then
      python3 - "$src_file" "$dest_file" <<'PY'
import re
import sys
from pathlib import Path

source, target = (Path(path) for path in sys.argv[1:3])
source_text = source.read_text(encoding="utf-8")
target_text = target.read_text(encoding="utf-8")

def split_agent_header(text):
    match = re.search(r"(?m)^developer_instructions\s*=\s*\"\"\"", text)
    if match is None:
        return text, ""
    return text[:match.start()], text[match.start():]

source_header, source_body = split_agent_header(source_text)
target_header, _ = split_agent_header(target_text)
preserved_settings = []
for setting in ("model", "model_reasoning_effort"):
    target_setting = re.search(rf"(?m)^{setting}\s*=\s*.*$", target_header)
    if target_setting is None:
        continue
    source_setting = re.search(rf"(?m)^{setting}\s*=\s*.*$", source_header)
    if source_setting is not None:
        source_header = source_header[:source_setting.start()] + target_setting.group(0) + source_header[source_setting.end():]
    else:
        source_header = source_header.rstrip("\n") + "\n" + target_setting.group(0) + "\n\n"
    preserved_settings.append(setting)
if preserved_settings:
    print(f"  ✓ preserved target settings ({', '.join(preserved_settings)}): {target}")
target.write_text(source_header + source_body, encoding="utf-8")
PY
    else
      cp -f "$src_file" "$dest_file"
    fi
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
    elif [[ "$rel_path" == sync-project-memory/scripts/sync-memory.sh && ( "$target_platform" == "claude" || "$target_platform" == "codebuddy" || "$target_platform" == "workbuddy" || "$target_platform" == "opencode" ) ]]; then
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
copilot_tools = {
    "collect_update_memory": ["*"],
    "docs_research": ["web"],
}
antigravity_tools = {
    "collect_update_memory": [
        "view_file", "list_dir", "find_by_name", "grep_search", "run_command",
        "write_to_file", "replace_file_content", "multi_replace_file_content",
    ],
    "docs_research": ["search_web", "read_url_content"],
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
    source_header = text[:body_match.start()]
    effort_match = re.search(r'^model_reasoning_effort\s*=\s*"([^"]+)"\s*$', source_header, re.MULTILINE)
    source_effort = effort_match.group(1) if effort_match else None
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
    elif platform == "cursor":
        lines.append("model: inherit")
        if re.search(r'^sandbox_mode\s*=\s*"read-only"\s*$', source_header, re.MULTILINE):
            lines.append("readonly: true")
    elif platform == "github-copilot":
        copilot_tool_list = copilot_tools.get(source_name, ["*"])
        lines.append("tools: " + json.dumps(copilot_tool_list, ensure_ascii=False))
        lines.append("infer: true")
        lines.append(f"include-custom-instructions: {'false' if source_name == 'docs_research' else 'true'}")
    elif platform == "antigravity":
        lines.append("tools:")
        for tool in antigravity_tools.get(source_name, []):
            lines.append(f"  - {tool}")
        lines += ["subagent: true", "mainAgent: true", "model: inherit"]
        command_policy = "off" if source_name == "docs_research" else "sandbox"
        lines.append(f"commandExecutionPolicy: {json.dumps(command_policy)}")

    effort_fields = {
        "claude": ("effort", {"low", "medium", "high", "xhigh", "max"}, ("model", "effort")),
        "zcode": ("thoughtLevel", {"low", "high", "max"}, ("model", "thoughtLevel")),
        # CodeBuddy's project-agent schema documents model, but not per-agent effort.
        "codebuddy": (None, set(), ("model", "effort")),
        # WorkBuddy has no directly documented per-agent model or effort fields.
        "workbuddy": (None, set(), ("model", "effort", "thoughtLevel", "reasoningEffort", "reasoning_effort", "model_reasoning_effort", "reasoningLevel", "reasoning_level", "thinking", "thinkingLevel", "thinking_level")),
        # OpenCode v2 puts provider request overrides under request.body.
        "opencode": (None, set(), ("model", "request", "reasoningEffort", "variant")),
        # Cursor carries model-specific effort in model parameters; no separate effort field.
        "cursor": (None, set(), ("model",)),
        # Copilot CLI supports reasoningEffort; the shared agent schema inherits its model by default.
        "github-copilot": ("reasoningEffort", {"low", "medium", "high"}, ("model", "models", "reasoningEffort")),
        # Antigravity supports model tiers but has no documented per-agent effort field.
        "antigravity": (None, set(), ("model",)),
    }
    reasoning_fields = {
        "claude": {"effort"},
        "zcode": {"thoughtLevel"},
        "codebuddy": set(),
        "workbuddy": {"effort", "thoughtLevel", "reasoningEffort", "reasoning_effort", "model_reasoning_effort", "reasoningLevel", "reasoning_level", "thinking", "thinkingLevel", "thinking_level"},
        "opencode": {"reasoningEffort", "variant"},
        "cursor": set(),
        "github-copilot": {"reasoningEffort"},
        "antigravity": set(),
    }
    default_effort_field, accepted_efforts, preserved_setting_keys = effort_fields[platform]
    if platform == "github-copilot":
        target_file = target_dir / f"{target_name}.agent.md"
    elif platform == "antigravity":
        target_file = target_dir / target_name / "agent.md"
    else:
        target_file = target_dir / f"{target_name}.md"
    existing_setting_lines = []
    existing_setting_keys = set()
    existing_reasoning_keys = set()
    if target_file.is_file():
        old_text = target_file.read_text(encoding="utf-8")
        if old_text.startswith("---\n"):
            old_end = old_text.find("\n---\n", 4)
            if old_end >= 0:
                old_frontmatter = old_text[4:old_end].splitlines()
                old_index = 0
                while old_index < len(old_frontmatter):
                    old_line = old_frontmatter[old_index]
                    key, separator, value = old_line.partition(":")
                    preserve_model_variant = platform == "opencode" and separator and key == "model" and "#" in value
                    preserve_cursor_effort = platform == "cursor" and separator and key == "model" and "[effort=" in value
                    if separator and (key in preserved_setting_keys or preserve_model_variant or preserve_cursor_effort):
                        existing_setting_keys.add(key)
                        if key in reasoning_fields[platform] or preserve_model_variant or preserve_cursor_effort:
                            existing_reasoning_keys.add(key)
                        setting_block = [old_line]
                        old_index += 1
                        while old_index < len(old_frontmatter) and (old_frontmatter[old_index].startswith((" ", "\t")) or not old_frontmatter[old_index].strip()):
                            setting_block.append(old_frontmatter[old_index])
                            old_index += 1
                        existing_setting_lines.extend(setting_block)
                        if platform == "opencode" and key == "request" and any(re.search(r"reasoningEffort\s*:", line) for line in setting_block):
                            existing_reasoning_keys.add("request")
                        continue
                    old_index += 1

    if source_effort and platform == "opencode" and not existing_reasoning_keys:
        if "request" not in existing_setting_keys:
            lines += ["request:", "  body:", f"    reasoningEffort: {json.dumps(source_effort)}"]
        else:
            request_line = next((i for i, line in enumerate(existing_setting_lines) if re.match(r"^request\s*:\s*$", line)), None)
            if request_line is None:
                print(f"  ! skipped OpenCode reasoning effort for {target_name}: preserving a non-block request setting")
            else:
                request_indent = len(existing_setting_lines[request_line]) - len(existing_setting_lines[request_line].lstrip())
                request_end = request_line + 1
                while request_end < len(existing_setting_lines) and (existing_setting_lines[request_end].startswith((" ", "\t")) or not existing_setting_lines[request_end].strip()):
                    request_end += 1
                body_key_line = next((i for i in range(request_line + 1, request_end) if re.match(r"^\s+body\s*:", existing_setting_lines[i])), None)
                if body_key_line is not None and not re.match(r"^\s+body\s*:\s*$", existing_setting_lines[body_key_line]):
                    print(f"  ! skipped OpenCode reasoning effort for {target_name}: preserving an inline request.body value")
                else:
                    if body_key_line is None:
                        body_indent = request_indent + 2
                        existing_setting_lines[request_end:request_end] = [" " * body_indent + "body:", " " * (body_indent + 2) + f"reasoningEffort: {json.dumps(source_effort)}"]
                    else:
                        body_indent = len(existing_setting_lines[body_key_line]) - len(existing_setting_lines[body_key_line].lstrip())
                        existing_setting_lines[body_key_line + 1:body_key_line + 1] = [" " * (body_indent + 2) + f"reasoningEffort: {json.dumps(source_effort)}"]
                    print(f"  ✓ added OpenCode request.body.reasoningEffort: {target_file}")
    elif source_effort and default_effort_field and not (existing_reasoning_keys & reasoning_fields[platform]):
        if source_effort in accepted_efforts:
            lines.append(f"{default_effort_field}: {json.dumps(source_effort)}")
            if platform == "claude" and source_name in claude_models:
                print(f"  ! Claude effort '{source_effort}' may depend on model support for {claude_models[source_name]}")
        else:
            print(f"  ! skipped unsupported {platform} reasoning effort '{source_effort}' for {target_name}")
    elif source_effort and platform in ("codebuddy", "workbuddy"):
        print(f"  ! skipped reasoning effort for {target_name}: no documented per-agent effort field")
    elif source_effort and platform in ("cursor", "antigravity"):
        print(f"  ! no separate per-agent effort field for {platform}; retaining the target model setting or platform default")

    if existing_setting_lines:
        # Keep target model/effort values while replacing the rest of the managed frontmatter.
        lines = [
            line for line in lines
            if not (line and not line.startswith((" ", "\t")) and line.partition(":")[1] and line.partition(":")[0] in existing_setting_keys)
        ]
        lines.extend(existing_setting_lines)
        print(f"  ✓ preserved target model/reasoning settings: {target_file}")

    lines += ["---", body, ""]
    target_file.parent.mkdir(parents=True, exist_ok=True)
    target_file.write_text("\n".join(lines), encoding="utf-8")
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

append_custom_marker() {
  local file="$1"
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
    printf '\n' >> "$file"
  fi
  printf '%s\n' "$CUSTOM_MARKER" >> "$file"
}

sync_agents_md() {
  local remote="$TMP_DIR/AGENTS.md"
  local local_file="$PROJECT_DIR/AGENTS.md"
  [ -f "$remote" ] || return 0

  if [ ! -f "$local_file" ]; then
    cp "$remote" "$local_file"
  elif ! has_custom_marker "$remote"; then
    # Treat the whole source as managed prompts. Add the delimiter after it, then
    # retain the existing project's custom region (or adopt the whole file).
    cat "$remote" > "$local_file.tmp"
    append_custom_marker "$local_file.tmp"
    if has_custom_marker "$local_file"; then
      local local_start
      local_start=$(custom_marker_line "$local_file")
      tail -n +"$((local_start + 1))" "$local_file" >> "$local_file.tmp"
    else
      cat "$local_file" >> "$local_file.tmp"
      echo "  + adopted: AGENTS.md had no marker, its content was moved below the marker"
    fi
    mv "$local_file.tmp" "$local_file"
  elif has_custom_marker "$local_file"; then
    local remote_end local_start
    remote_end=$(custom_marker_line "$remote")
    local_start=$(custom_marker_line "$local_file")
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
    remote_end=$(custom_marker_line "$remote")
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
  if ! has_custom_marker "$remote"; then
    if [ ! -f "$target" ]; then
      cp "$remote" "$target"
    else
      cat "$remote" > "$tmp"
      append_custom_marker "$tmp"
      if has_custom_marker "$target"; then
        local custom_start
        custom_start=$(custom_marker_line "$target")
        tail -n +"$((custom_start + 1))" "$target" >> "$tmp"
      else
        cat "$target" >> "$tmp"
        echo "  + adopted: CLAUDE.md had no marker, its content was moved below the marker"
      fi
      mv "$tmp" "$target"
    fi
    adapt_agent_tools "$target" "$CUSTOM_MARKER" update_plan "$PLAN_TOOL" request_user_input "$QUESTION_TOOL"
    return 0
  fi
  local remote_end
  remote_end=$(custom_marker_line "$remote")
  head -n "$((remote_end - 1))" "$remote" > "$tmp"
  adapt_agent_tools "$tmp" "$CUSTOM_MARKER" update_plan "$PLAN_TOOL" request_user_input "$QUESTION_TOOL"
  if [ ! -f "$target" ]; then
    tail -n +"$remote_end" "$remote" >> "$tmp"
  elif has_custom_marker "$target"; then
    local custom_start
    custom_start=$(custom_marker_line "$target")
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
    cursor)
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.agents/skills" cursor
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.cursor/agents" cursor
      ;;
    github-copilot)
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.agents/skills" github-copilot
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.github/agents" github-copilot
      ;;
    antigravity)
      copy_skill_tree "$TMP_DIR/.agents/skills" "$PROJECT_DIR/.agents/skills" antigravity
      generate_agents "$TMP_DIR/.codex/agents" "$PROJECT_DIR/.agents/agents" antigravity
      ;;
  esac
}

echo "[2/7] Syncing project instruction files..."
sync_agents_md
sync_claude_md
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
ENTRIES=( ".project-memory/" ".project-script/" "AGENTS.md" )
case "$PLATFORM" in
  codex)
    ENTRIES+=( ".codex/" ".agents/" )
    HEADER="# Codex / project-local config"
    ;;
  zcode)
    ENTRIES+=( ".zcode/" ".agents/" )
    HEADER="# ZCode / project-local config"
    ;;
  claude)
    ENTRIES+=( ".claude/" "CLAUDE.md" )
    HEADER="# Claude / project-local config"
    ;;
  codebuddy)
    ENTRIES+=( ".codebuddy/" )
    HEADER="# CodeBuddy / project-local config"
    ;;
  workbuddy)
    ENTRIES+=( ".codebuddy/" )
    if [ "$WORKBUDDY_VARIANT" = "domestic" ]; then
      HEADER="# WorkBuddy domestic / project-local config"
    else
      HEADER="# WorkBuddy international / project-local config"
    fi
    ;;
  opencode)
    ENTRIES+=( ".opencode/" )
    HEADER="# OpenCode / project-local config"
    ;;
  cursor)
    ENTRIES+=( ".agents/" ".cursor/agents/" )
    HEADER="# Cursor / project-local config"
    ;;
  github-copilot)
    ENTRIES+=( ".agents/" ".github/agents/" )
    HEADER="# GitHub Copilot / project-local config"
    ;;
  antigravity)
    ENTRIES+=( ".agents/" )
    HEADER="# Antigravity / project-local config"
    ;;
esac
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
