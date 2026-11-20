#!/usr/bin/env python3
"""Write docs/content.js from content/items.json so the web app ships the same items as iOS."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KEYS = ("id", "category", "budget", "kind", "title", "detail", "reveal")


def main() -> None:
    items = json.loads((ROOT / "content/items.json").read_text())
    slim = [{k: i[k] for k in KEYS if k in i} for i in items]
    body = json.dumps(slim, ensure_ascii=True, separators=(",", ":"))
    (ROOT / "docs/content.js").write_text(f"window.ADVENT_ITEMS={body};\n")
    print(f"docs/content.js: {len(slim)} items")


if __name__ == "__main__":
    main()
