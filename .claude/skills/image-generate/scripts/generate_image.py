#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

MODEL = "gpt-image-2"
DEFAULT_SIZE = "2048x2048"
VALID_SIZES = {
    "1024x1024",
    "2048x2048",
    "1536x1024",
    "1024x1536",
    "3840x2160",
    "2160x3840",
}


def project_root() -> Path:
    return Path(__file__).resolve().parents[4]


def default_output_dir() -> Path:
    return project_root() / ".claude_introduction" / "IMAGE"


def default_metadata_dir() -> Path:
    return project_root() / ".claude" / ".cache" / "image"


def safe_slug(text: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", text.strip().lower()).strip("-")
    return slug[:48] or "image"


def normalize_base_url(value: str | None) -> str:
    if not value or not value.strip():
        raise RuntimeError("CONFIG_ERROR: OPENAI_IMAGE_URL is not configured")
    return value.strip().rstrip("/")


def get_api_key(value: str | None) -> str:
    if not value or not value.strip():
        raise RuntimeError("CONFIG_ERROR: OPENAI_IMAGE_API_KEY is not configured")
    return value.strip()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate an image with an OpenAI Images compatible API")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--size", default=DEFAULT_SIZE, choices=sorted(VALID_SIZES))
    parser.add_argument("--n", type=int, default=1)
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--output-dir", default=str(default_output_dir()))
    parser.add_argument("--metadata-dir", default=str(default_metadata_dir()))
    return parser.parse_args()


def post_json(url: str, api_key: str, payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"API_ERROR: HTTP {error.code}: {body[:1000]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"API_ERROR: {error.reason}") from error
    return json.loads(body)


def download_file(url: str, path: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "claude-code-generate-image/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            path.write_bytes(response.read())
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"DOWNLOAD_ERROR: HTTP {error.code}: {body[:1000]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"DOWNLOAD_ERROR: {error.reason}") from error


def save_images(
    data: dict[str, Any],
    output_dir: Path,
    metadata_dir: Path,
    prompt: str,
    size: str,
) -> tuple[list[Path], Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)
    created = int(data.get("created") or time.time())
    prefix = f"{created}-{safe_slug(prompt)}-{size}"
    saved: list[Path] = []

    for index, item in enumerate(data.get("data") or [], start=1):
        if not isinstance(item, dict):
            continue
        suffix = f"-{index}" if len(data.get("data") or []) > 1 else ""
        if item.get("b64_json"):
            image_path = output_dir / f"{prefix}{suffix}.png"
            image_path.write_bytes(base64.b64decode(item["b64_json"]))
            saved.append(image_path)
        elif item.get("url"):
            image_path = output_dir / f"{prefix}{suffix}.png"
            download_file(item["url"], image_path)
            saved.append(image_path)

    metadata_path = metadata_dir / f"{prefix}.json"
    metadata_path.write_text(
        json.dumps(
            {
                "prompt": prompt,
                "size": size,
                "created": created,
                "saved_files": [str(path) for path in saved],
                "response": data,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return saved, metadata_path


def main() -> int:
    args = parse_args()
    if args.n < 1:
        print("ARGUMENT_ERROR: --n must be at least 1", file=sys.stderr)
        return 2

    try:
        base_url = normalize_base_url(os.environ.get("OPENAI_IMAGE_URL"))
        api_key = get_api_key(os.environ.get("OPENAI_IMAGE_API_KEY"))
        payload = {
            "model": args.model,
            "prompt": args.prompt,
            "size": args.size,
            "n": args.n,
        }
        result = post_json(f"{base_url}/v1/images/generations", api_key, payload)
        saved, metadata_path = save_images(
            result,
            Path(args.output_dir),
            Path(args.metadata_dir),
            args.prompt,
            args.size,
        )
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1

    if not saved:
        print("API_ERROR: response did not contain data[].url or data[].b64_json", file=sys.stderr)
        return 1

    print(
        json.dumps(
            {
                "saved_files": [str(path) for path in saved],
                "metadata_file": str(metadata_path),
                "size": args.size,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
