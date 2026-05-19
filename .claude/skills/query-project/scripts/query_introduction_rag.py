#!/usr/bin/env python3
"""Query introduction documents with OpenAI-compatible embeddings and rerank."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

SCHEMA_VERSION = 3
SUPPORTED_EXTENSIONS = {".md", ".markdown", ".txt", ".pdf", ".docx", ".doc"}
DEFAULT_EMBEDDING_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
DEFAULT_RERANK_BASE_URL = "https://dashscope.aliyuncs.com/compatible-api/v1"
DEFAULT_EMBEDDING_MODEL = "text-embedding-v4"
DEFAULT_RERANK_MODEL = "qwen3-rerank"
DEFAULT_RERANK_INSTRUCT = "Given a web search query, retrieve relevant passages that answer the query."
CONFIG_GUIDE_PATH = "references/api-config-guide.md"
RAG_ENABLED_SUFFIX = "(rag已配置)"
RAG_DISABLED_SUFFIX = "(rag未配置)"
REQUIRED_GITIGNORE_ENTRIES = (".claude/settings.local.json", ".claude/.cache/")


class GitignoreError(RuntimeError):
    def __init__(self, missing: list[str]):
        self.missing = missing
        joined = ", ".join(missing)
        super().__init__(
            f"GITIGNORE_ERROR: missing required .gitignore entries: {joined}. Add them before using query-project so local secrets and RAG cache are not committed."
        )


class ConfigError(RuntimeError):
    def __init__(self, scope: str, reason: str):
        self.scope = scope
        self.reason = reason
        super().__init__(
            f"CONFIG_ERROR[{scope}]: {reason}. See {CONFIG_GUIDE_PATH} for setup options, or let me configure the environment variables for you."
        )


@dataclass
class SourceDocument:
    path: Path
    relative_path: str
    text: str
    line_offsets: list[int]
    warnings: list[str]


@dataclass
class Chunk:
    id: str
    path: str
    file_name: str
    title_path: str
    start_line: int
    end_line: int
    text: str
    content_hash: str
    embedding: list[float] | None = None


def env_value(*names: str, default: str | None = None) -> str | None:
    for name in names:
        value = os.getenv(name)
        if value:
            return value
    return default


def normalize_base_url(url: str) -> str:
    return url.rstrip("/")


def strip_rag_suffix(description: str) -> str:
    return description.removesuffix(f" {RAG_ENABLED_SUFFIX}").removesuffix(f" {RAG_DISABLED_SUFFIX}")


def skill_md_path(root: Path) -> Path:
    return root / "skills" / "query-project" / "SKILL.md"


def project_root_from_claude_root(root: Path) -> Path:
    return root.parent if root.name == ".claude" else root


def docs_root_from_project_root(project_root: Path) -> Path:
    return project_root / ".claude_introduction"


def load_local_env(root: Path) -> None:
    project_root = project_root_from_claude_root(root)
    settings_local_path = project_root / ".claude" / "settings.local.json"
    if not settings_local_path.exists():
        return
    try:
        payload = json.loads(settings_local_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise RuntimeError(f"Failed to read {settings_local_path}: {exc}") from exc
    env_map = payload.get("env")
    if not isinstance(env_map, dict):
        return
    for key, value in env_map.items():
        if isinstance(key, str) and isinstance(value, str):
            os.environ.setdefault(key, value)


def check_gitignore(root: Path) -> None:
    project_root = project_root_from_claude_root(root)
    gitignore_path = project_root / ".gitignore"
    if gitignore_path.exists():
        entries = {line.strip().replace("\\", "/") for line in gitignore_path.read_text(encoding="utf-8").splitlines()}
    else:
        entries = set()
    missing = [entry for entry in REQUIRED_GITIGNORE_ENTRIES if entry not in entries]
    if missing:
        raise GitignoreError(missing)


def update_skill_description_status(root: Path, configured: bool) -> None:
    path = skill_md_path(root)
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()
    next_lines: list[str] = []
    description_updated = False
    suffix = RAG_ENABLED_SUFFIX if configured else RAG_DISABLED_SUFFIX

    for line in lines:
        if line.startswith("description:"):
            value = line[len("description:") :].strip()
            value = strip_rag_suffix(value)
            next_lines.append(f"description: {value} {suffix}")
            description_updated = True
        else:
            next_lines.append(line)

    if not description_updated:
        raise RuntimeError(f"description field not found in {path}")

    path.write_text("\n".join(next_lines) + "\n", encoding="utf-8")


def validate_config(args: argparse.Namespace) -> None:
    if not args.embedding_base_url:
        raise ConfigError("embedding", "missing embedding base URL")
    if not args.embedding_api_key:
        raise ConfigError("embedding", "missing embedding API key")
    if not args.embedding_model:
        raise ConfigError("embedding", "missing embedding model ID")
    if not args.no_rerank:
        if not args.rerank_base_url:
            raise ConfigError("rerank", "missing rerank base URL")
        if not args.rerank_api_key:
            raise ConfigError("rerank", "missing rerank API key")
        if not args.rerank_model:
            raise ConfigError("rerank", "missing rerank model ID")


def post_json(base_url: str, path: str, api_key: str, body: dict[str, Any], timeout: int, scope: str) -> dict[str, Any]:
    if not base_url:
        raise ConfigError(scope, f"missing {scope} base URL")
    if not api_key:
        raise ConfigError(scope, f"missing {scope} API key")

    url = f"{normalize_base_url(base_url)}/{path.lstrip('/')}"
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        if exc.code in {401, 403}:
            raise ConfigError(scope, f"invalid {scope} API key or insufficient permission") from exc
        if exc.code == 404:
            raise ConfigError(scope, f"invalid {scope} base URL or endpoint path") from exc
        if exc.code == 400 and any(keyword in detail.lower() for keyword in ("api key", "unauthorized", "authentication", "token", "model", "base_url", "endpoint", "not found")):
            raise ConfigError(scope, f"invalid {scope} configuration: {detail}") from exc
        raise RuntimeError(f"HTTP {exc.code} from {url}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise ConfigError(scope, f"unable to reach {scope} service: {exc.reason}") from exc


def parse_embedding_response(payload: dict[str, Any], expected_count: int) -> list[list[float]]:
    data = payload.get("data")
    if not isinstance(data, list):
        raise RuntimeError("Embedding response missing OpenAI-compatible data array")

    vectors_by_index: dict[int, list[float]] = {}
    fallback: list[list[float]] = []
    for position, item in enumerate(data):
        if not isinstance(item, dict) or "embedding" not in item:
            continue
        embedding = item["embedding"]
        if not isinstance(embedding, list):
            continue
        vector = [float(value) for value in embedding]
        fallback.append(vector)
        index = item.get("index", position)
        if isinstance(index, int):
            vectors_by_index[index] = vector

    vectors = [vectors_by_index.get(index) for index in range(expected_count)]
    if all(vector is not None for vector in vectors):
        return [vector for vector in vectors if vector is not None]
    if len(fallback) == expected_count:
        return fallback
    raise RuntimeError(f"Embedding response returned {len(fallback)} vectors, expected {expected_count}")


def parse_rerank_response(payload: dict[str, Any]) -> list[dict[str, Any]]:
    candidates = payload.get("results")
    if candidates is None:
        candidates = payload.get("data")
    if candidates is None and isinstance(payload.get("output"), dict):
        candidates = payload["output"].get("results")
    if not isinstance(candidates, list):
        raise RuntimeError("Rerank response missing results/data array")

    parsed: list[dict[str, Any]] = []
    for position, item in enumerate(candidates):
        if not isinstance(item, dict):
            continue
        index = item.get("index", position)
        score = item.get("relevance_score", item.get("score", item.get("similarity", 0.0)))
        if not isinstance(index, int):
            continue
        try:
            parsed.append({"index": index, "score": float(score), "raw": item})
        except (TypeError, ValueError):
            parsed.append({"index": index, "score": 0.0, "raw": item})
    return parsed


def embed_texts(texts: list[str], args: argparse.Namespace) -> list[list[float]]:
    if not texts:
        return []
    body: dict[str, Any] = {"model": args.embedding_model, "input": texts}
    if args.embedding_dimensions:
        body["dimensions"] = args.embedding_dimensions
    payload = post_json(args.embedding_base_url, "/embeddings", args.embedding_api_key, body, args.timeout, "embedding")
    return parse_embedding_response(payload, len(texts))


def rerank(query: str, chunks: list[Chunk], args: argparse.Namespace) -> list[tuple[Chunk, float]]:
    if not chunks:
        return []
    body: dict[str, Any] = {
        "model": args.rerank_model,
        "query": query,
        "documents": [chunk.text for chunk in chunks],
        "top_n": min(args.top_k, len(chunks)),
    }
    if args.rerank_instruct:
        body["instruct"] = args.rerank_instruct
    payload = post_json(args.rerank_base_url, "/reranks", args.rerank_api_key, body, args.timeout, "rerank")
    parsed = parse_rerank_response(payload)
    results: list[tuple[Chunk, float]] = []
    for item in parsed:
        index = item["index"]
        if 0 <= index < len(chunks):
            results.append((chunks[index], item["score"]))
    return results[: args.top_k]


def cosine_similarity(left: list[float], right: list[float]) -> float:
    numerator = sum(a * b for a, b in zip(left, right))
    left_norm = math.sqrt(sum(a * a for a in left))
    right_norm = math.sqrt(sum(b * b for b in right))
    if not left_norm or not right_norm:
        return 0.0
    return numerator / (left_norm * right_norm)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def read_text_file(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-8", "gb18030", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def extract_pdf(path: Path) -> tuple[str, list[str]]:
    warnings: list[str] = []
    reader_cls = None
    try:
        from pypdf import PdfReader  # type: ignore

        reader_cls = PdfReader
    except Exception:
        try:
            from PyPDF2 import PdfReader  # type: ignore

            reader_cls = PdfReader
        except Exception:
            warnings.append(f"Skipped PDF (missing pypdf or PyPDF2): {path}")
            return "", warnings

    try:
        reader = reader_cls(str(path))
        pages = []
        for index, page in enumerate(reader.pages, start=1):
            text = page.extract_text() or ""
            if text.strip():
                pages.append(f"# Page {index}\n{text}")
        return "\n\n".join(pages), warnings
    except Exception as exc:
        warnings.append(f"Skipped PDF (parse failed): {path}: {exc}")
        return "", warnings


def extract_docx(path: Path) -> tuple[str, list[str]]:
    warnings: list[str] = []
    try:
        with zipfile.ZipFile(path) as archive:
            xml_bytes = archive.read("word/document.xml")
    except Exception as exc:
        warnings.append(f"Skipped Word document (read failed): {path}: {exc}")
        return "", warnings

    try:
        root = ElementTree.fromstring(xml_bytes)
    except ElementTree.ParseError as exc:
        warnings.append(f"Skipped Word document (XML parse failed): {path}: {exc}")
        return "", warnings

    lines: list[str] = []
    for paragraph in root.iter("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p"):
        parts = [node.text for node in paragraph.iter("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}t") if node.text]
        line = "".join(parts).strip()
        if line:
            lines.append(line)
    return "\n".join(lines), warnings


def extract_doc(path: Path) -> tuple[str, list[str]]:
    warnings = [f"Skipped legacy .doc file. Convert to .docx or .txt first: {path}"]
    return "", warnings


def line_offsets(text: str) -> list[int]:
    offsets = [0]
    for match in re.finditer("\n", text):
        offsets.append(match.end())
    return offsets


def offset_to_line(offsets: list[int], offset: int) -> int:
    low, high = 0, len(offsets)
    while low < high:
        mid = (low + high) // 2
        if offsets[mid] <= offset:
            low = mid + 1
        else:
            high = mid
    return max(1, low)


def read_source_document(path: Path, project_root: Path) -> SourceDocument:
    suffix = path.suffix.lower()
    warnings: list[str] = []
    if suffix in {".md", ".markdown", ".txt"}:
        text = read_text_file(path)
    elif suffix == ".pdf":
        text, warnings = extract_pdf(path)
    elif suffix == ".docx":
        text, warnings = extract_docx(path)
    elif suffix == ".doc":
        text, warnings = extract_doc(path)
    else:
        text = ""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return SourceDocument(
        path=path,
        relative_path=path.relative_to(project_root).as_posix(),
        text=text,
        line_offsets=line_offsets(text),
        warnings=warnings,
    )


def should_exclude(relative_path: str, args: argparse.Namespace) -> bool:
    patterns = list(args.exclude or [])
    if args.exclude_todo:
        patterns.append(f"{args.docs_root.name}/TODO/**")
    for pattern in patterns:
        normalized = pattern.replace("\\", "/")
        if fnmatch.fnmatch(relative_path, normalized):
            return True
    return False


def discover_documents(project_root: Path, args: argparse.Namespace) -> tuple[list[SourceDocument], list[str]]:
    docs_root = args.docs_root
    if not docs_root.exists():
        raise RuntimeError(f"Introduction directory not found: {docs_root}")

    documents: list[SourceDocument] = []
    warnings: list[str] = []
    for path in sorted(docs_root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            continue
        relative_path = path.relative_to(project_root).as_posix()
        if should_exclude(relative_path, args):
            continue
        document = read_source_document(path, project_root)
        warnings.extend(document.warnings)
        if document.text.strip():
            documents.append(document)
    return documents, warnings


def split_long_text(text: str, max_chars: int, overlap_chars: int) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    start = 0
    length = len(text)
    while start < length:
        target_end = min(length, start + max_chars)
        if target_end < length:
            candidates = [text.rfind(separator, start, target_end) for separator in ("\n\n", "\n", "。", ".", " ")]
            split_at = max(candidates)
            if split_at > start + max_chars // 2:
                target_end = split_at + 1
        while target_end < length and target_end > start and not text[target_end - 1].strip():
            target_end -= 1
        if target_end <= start:
            target_end = min(length, start + max_chars)
        spans.append((start, target_end))
        if target_end >= length:
            break
        start = max(target_end - overlap_chars, start + 1)
    return spans


def markdown_sections(text: str) -> list[tuple[str, int, int]]:
    matches = list(re.finditer(r"^(#{1,6})\s+(.+?)\s*$", text, flags=re.MULTILINE))
    if not matches:
        return [("", 0, len(text))]

    sections: list[tuple[str, int, int]] = []
    stack: list[tuple[int, str]] = []
    first_heading_start = matches[0].start()
    if first_heading_start > 0 and text[:first_heading_start].strip():
        sections.append(("", 0, first_heading_start))

    for index, match in enumerate(matches):
        level = len(match.group(1))
        title = match.group(2).strip()
        while stack and stack[-1][0] >= level:
            stack.pop()
        stack.append((level, title))
        next_start = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        title_path = " > ".join(item[1] for item in stack)
        sections.append((title_path, match.start(), next_start))
    return sections


def chunk_document(document: SourceDocument, args: argparse.Namespace) -> list[Chunk]:
    sections = markdown_sections(document.text) if document.path.suffix.lower() in {".md", ".markdown"} else [("", 0, len(document.text))]
    chunks: list[Chunk] = []
    for title_path, section_start, section_end in sections:
        section_text = document.text[section_start:section_end].strip()
        if not section_text:
            continue
        for local_start, local_end in split_long_text(section_text, args.chunk_max_chars, args.chunk_overlap_chars):
            absolute_start = section_start + local_start
            absolute_end = section_start + local_end
            chunk_text = document.text[absolute_start:absolute_end].strip()
            if not chunk_text:
                continue
            content_hash = sha256_text(f"{document.relative_path}\n{title_path}\n{chunk_text}")
            chunks.append(
                Chunk(
                    id=content_hash[:16],
                    path=document.relative_path,
                    file_name=document.path.name,
                    title_path=title_path,
                    start_line=offset_to_line(document.line_offsets, absolute_start),
                    end_line=offset_to_line(document.line_offsets, absolute_end),
                    text=chunk_text,
                    content_hash=content_hash,
                )
            )
    return chunks


def build_chunks(documents: list[SourceDocument], args: argparse.Namespace) -> list[Chunk]:
    chunks: list[Chunk] = []
    for document in documents:
        chunks.extend(chunk_document(document, args))
    return chunks


def cache_path(root: Path) -> Path:
    return root / ".cache" / "query-project" / "introduction_rag.json"


def load_cache(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": SCHEMA_VERSION, "chunks": {}}
    try:
        with path.open("r", encoding="utf-8") as file:
            payload = json.load(file)
        if payload.get("schema_version") != SCHEMA_VERSION:
            return {"schema_version": SCHEMA_VERSION, "chunks": {}}
        return payload
    except Exception:
        return {"schema_version": SCHEMA_VERSION, "chunks": {}}


def save_cache(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)


def hydrate_embeddings(chunks: list[Chunk], args: argparse.Namespace) -> None:
    path = cache_path(args.root_path)
    cache = load_cache(path)
    cache_key = f"{args.embedding_base_url}|{args.embedding_model}|{args.embedding_dimensions or ''}|{args.chunk_max_chars}|{args.chunk_overlap_chars}"
    cached_chunks = cache.get("chunks", {}) if cache.get("cache_key") == cache_key else {}

    missing: list[Chunk] = []
    for chunk in chunks:
        cached = cached_chunks.get(chunk.content_hash)
        if isinstance(cached, dict) and isinstance(cached.get("embedding"), list):
            chunk.embedding = [float(value) for value in cached["embedding"]]
        else:
            missing.append(chunk)

    if missing and args.no_update:
        raise RuntimeError(f"Index is missing {len(missing)} chunks; remove --no-update or use --rebuild")

    for start in range(0, len(missing), args.embedding_batch_size):
        batch = missing[start : start + args.embedding_batch_size]
        vectors = embed_texts([chunk.text for chunk in batch], args)
        for chunk, vector in zip(batch, vectors):
            chunk.embedding = vector

    next_cache = {
        "schema_version": SCHEMA_VERSION,
        "cache_key": cache_key,
        "updated_at": int(time.time()),
        "chunks": {
            chunk.content_hash: {
                "path": chunk.path,
                "title_path": chunk.title_path,
                "start_line": chunk.start_line,
                "end_line": chunk.end_line,
                "embedding": chunk.embedding,
            }
            for chunk in chunks
            if chunk.embedding is not None
        },
    }
    if not args.no_update:
        save_cache(path, next_cache)


def vector_recall(query: str, chunks: list[Chunk], args: argparse.Namespace) -> list[tuple[Chunk, float]]:
    query_embedding = embed_texts([query], args)[0]
    scored = [(chunk, cosine_similarity(query_embedding, chunk.embedding or [])) for chunk in chunks]
    scored.sort(key=lambda item: item[1], reverse=True)
    return scored[: args.candidate_k]


def refresh_index(args: argparse.Namespace) -> tuple[int, int, list[str]]:
    check_gitignore(args.root_path)
    validate_config(args)
    documents, warnings = discover_documents(args.project_root, args)
    chunks = build_chunks(documents, args)
    if not chunks:
        raise RuntimeError(f"No searchable document chunks found under {args.docs_root.as_posix()}/")
    hydrate_embeddings(chunks, args)
    return len(documents), len(chunks), warnings


def sync_config_status(args: argparse.Namespace) -> bool:
    try:
        check_gitignore(args.root_path)
        validate_config(args)
        update_skill_description_status(args.root_path, configured=True)
        return True
    except ConfigError:
        update_skill_description_status(args.root_path, configured=False)
        return False


def format_result(chunk: Chunk, score: float, args: argparse.Namespace) -> dict[str, Any]:
    snippet = chunk.text if args.show_content else chunk.text[: args.max_snippet_chars]
    if not args.show_content and len(chunk.text) > args.max_snippet_chars:
        snippet = snippet.rstrip() + "…"
    return {
        "path": chunk.path,
        "file_name": chunk.file_name,
        "title_path": chunk.title_path,
        "start_line": chunk.start_line,
        "end_line": chunk.end_line,
        "score": score,
        "content": snippet,
    }


def print_markdown(results: list[dict[str, Any]], warnings: list[str]) -> None:
    if warnings:
        print("## Warnings")
        for warning in warnings:
            print(f"- {warning}")
        print()
    print("## Results")
    if not results:
        print("No relevant document chunks found.")
        return
    for index, item in enumerate(results, start=1):
        title = item["title_path"] or item["file_name"]
        print(f"### {index}. {title}")
        print(f"- Path: `{item['path']}`")
        print(f"- Lines: {item['start_line']}-{item['end_line']}")
        print(f"- Score: {item['score']:.6f}")
        print()
        print(item["content"])
        print()


def resolve_api_key(primary_name: str, scoped_fallback_name: str) -> str | None:
    return env_value(primary_name, scoped_fallback_name, "RAG_API_KEY", "OPENAI_API_KEY", "DASHSCOPE_API_KEY")


def build_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    args = parser.parse_args()
    args.root_path = Path(args.root).resolve()
    args.project_root = project_root_from_claude_root(args.root_path)
    args.docs_root = Path(args.docs_root).resolve() if args.docs_root else docs_root_from_project_root(args.project_root)
    load_local_env(args.root_path)
    args.embedding_api_key = resolve_api_key("RAG_EMBEDDING_API_KEY", "EMBEDDING_API_KEY")
    args.rerank_api_key = resolve_api_key("RAG_RERANK_API_KEY", "RERANK_API_KEY")
    if args.rebuild:
        path = cache_path(args.root_path)
        if path.exists():
            path.unlink()
    args.candidate_k = max(args.top_k, args.candidate_k)
    return args


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Query introduction documents with OpenAI-compatible RAG.")
    parser.add_argument("--query", default="")
    parser.add_argument("--root", default=".claude")
    parser.add_argument("--docs-root", default="")
    parser.add_argument("--rebuild", action="store_true")
    parser.add_argument("--no-update", action="store_true")
    parser.add_argument("--top-k", type=int, default=8)
    parser.add_argument("--candidate-k", type=int, default=40)
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--max-snippet-chars", type=int, default=800)
    parser.add_argument("--show-content", action="store_true")
    parser.add_argument("--chunk-max-chars", type=int, default=1800)
    parser.add_argument("--chunk-overlap-chars", type=int, default=200)
    parser.add_argument("--exclude-todo", action="store_true")
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--embedding-model", default=env_value("RAG_EMBEDDING_MODEL", default=DEFAULT_EMBEDDING_MODEL))
    parser.add_argument("--rerank-model", default=env_value("RAG_RERANK_MODEL", default=DEFAULT_RERANK_MODEL))
    parser.add_argument("--embedding-base-url", default=env_value("RAG_EMBEDDING_BASE_URL", "OPENAI_BASE_URL", default=DEFAULT_EMBEDDING_BASE_URL))
    parser.add_argument("--rerank-base-url", default=env_value("RAG_RERANK_BASE_URL", "OPENAI_BASE_URL", default=DEFAULT_RERANK_BASE_URL))
    parser.add_argument("--embedding-dimensions", type=int, default=None)
    parser.add_argument("--embedding-batch-size", type=int, default=10)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--no-rerank", action="store_true")
    parser.add_argument("--rerank-instruct", default=env_value("RAG_RERANK_INSTRUCT", default=DEFAULT_RERANK_INSTRUCT))
    parser.add_argument("--sync-config-status", action="store_true")
    parser.add_argument("--refresh-index", action="store_true")
    return parser


def parse_args() -> argparse.Namespace:
    args = build_args(build_parser())
    return args


def main() -> int:
    try:
        args = parse_args()
        if args.sync_config_status:
            configured = sync_config_status(args)
            print(json.dumps({"configured": configured, "description_suffix": RAG_ENABLED_SUFFIX if configured else RAG_DISABLED_SUFFIX}, ensure_ascii=False))
            return 0

        if args.refresh_index:
            document_count, chunk_count, warnings = refresh_index(args)
            print(json.dumps({"refreshed": True, "documents": document_count, "chunks": chunk_count, "warnings": warnings}, ensure_ascii=False, indent=2))
            return 0

        if not args.query:
            raise RuntimeError("Missing query input. Pass --query, or use --sync-config-status / --refresh-index")

        validate_config(args)
        check_gitignore(args.root_path)
        documents, warnings = discover_documents(args.project_root, args)
        chunks = build_chunks(documents, args)
        if not chunks:
            raise RuntimeError(f"No searchable document chunks found under {args.docs_root.as_posix()}/")
        hydrate_embeddings(chunks, args)
        recalled = vector_recall(args.query, chunks, args)
        candidates = [chunk for chunk, _ in recalled]
        if args.no_rerank:
            final = recalled[: args.top_k]
        else:
            final = rerank(args.query, candidates, args)
        results = [format_result(chunk, score, args) for chunk, score in final]
        if args.format == "json":
            print(json.dumps({"warnings": warnings, "results": results}, ensure_ascii=False, indent=2))
        else:
            print_markdown(results, warnings)
        return 0
    except Exception as exc:
        print(f"query-project failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    stderr_reconfigure = getattr(sys.stderr, "reconfigure", None)
    stdout_reconfigure = getattr(sys.stdout, "reconfigure", None)
    try:
        if callable(stderr_reconfigure):
            stderr_reconfigure(encoding="utf-8")
        if callable(stdout_reconfigure):
            stdout_reconfigure(encoding="utf-8")
    except Exception:
        pass
    raise SystemExit(main())
