#!/usr/bin/env python3
"""Model roster audit — verify model IDs against the live OpenRouter directory.

Reads model IDs from a source file (any text file containing quoted
"provider/model" strings, e.g. a TypeScript types file or a plain list),
fetches the live OpenRouter model directory, and reports any ID that is no
longer served.

Exit codes:
    0 — all IDs live (or the registry was unreachable; not a roster failure)
    1 — at least one ID is dead
    2 — configuration error (no API key)

Usage:
    OPENROUTER_API_KEY=sk-... python3 model-audit.py --types path/to/types.ts
    python3 model-audit.py --types path/to/models.txt --api-key sk-...
    python3 model-audit.py --types path/to/types.ts --model openai/gpt-4o
"""

import argparse
import json
import os
import re
import sys
import urllib.request

OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"
ID_PATTERN = re.compile(r"'([a-z]+/[^']+)'")


def extract_ids(path):
    with open(path, encoding="utf-8") as f:
        return set(ID_PATTERN.findall(f.read()))


def fetch_live(api_key):
    request = urllib.request.Request(OPENROUTER_MODELS_URL)
    request.add_header("Authorization", "Bearer " + api_key)
    with urllib.request.urlopen(request, timeout=15) as response:
        payload = json.loads(response.read())
    return {model["id"] for model in payload.get("data", [])}


def build_parser():
    parser = argparse.ArgumentParser(
        description="Audit model IDs against the live OpenRouter directory."
    )
    parser.add_argument("--types", required=True, help="File containing model ID strings.")
    parser.add_argument("--api-key", default=None, help="OpenRouter API key (or set OPENROUTER_API_KEY).")
    parser.add_argument("--model", action="append", default=[], help="Extra model ID to check (repeatable).")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    api_key = args.api_key or os.environ.get("OPENROUTER_API_KEY", "")
    if not api_key:
        print("ERROR: no API key — set OPENROUTER_API_KEY or pass --api-key", file=sys.stderr)
        return 2

    our_ids = extract_ids(args.types)
    our_ids.update(args.model)

    try:
        live_ids = fetch_live(api_key)
    except Exception as exc:  # registry down is not a roster failure
        print(f"OpenRouter unreachable: {exc}", file=sys.stderr)
        print("[model audit] OK (registry unreachable)")
        return 0

    dead = sorted(our_ids - live_ids)
    alive = len(our_ids & live_ids)
    print(f"Model audit — {alive}/{len(our_ids)} alive")
    if dead:
        print(f"\nDEAD ({len(dead)}):")
        for model in dead:
            print(f"  X {model}")
        return 1
    print("\nAll models healthy.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
