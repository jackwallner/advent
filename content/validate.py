#!/usr/bin/env python3
import json, os, re, sys
from collections import Counter

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "items.json")
CATS = ["selfcare", "family", "fitness", "music", "puzzles", "food", "humor", "books"]
BUDGETS = ["none", "low", "medium", "high"]
KINDS = {"do", "read", "think"}
MINS = {"none": 24, "low": 10, "medium": 6, "high": 4}
KEYS = {"id", "category", "budget", "kind", "title", "detail", "reveal"}
REQUIRED = KEYS - {"reveal"}
errors = []

def err(m):
    errors.append(m)

raw = open(PATH, encoding="utf-8").read()
try:
    items = json.loads(raw)
except Exception as e:
    sys.exit("INVALID JSON: %s" % e)
if not isinstance(items, list):
    sys.exit("top level must be an array")

ids, titles = set(), set()
counts = Counter()
seq = {c: 0 for c in CATS}
for n, it in enumerate(items):
    if not isinstance(it, dict):
        err("item %d not an object" % n)
        continue
    iid = it.get("id", "?%d" % n)
    ks = set(it)
    if ks - KEYS: err("%s extra keys %s" % (iid, sorted(ks - KEYS)))
    if REQUIRED - ks: err("%s missing keys %s" % (iid, sorted(REQUIRED - ks)))
    if not all(isinstance(it.get(k), str) and it.get(k) for k in ks & KEYS):
        err("%s has non-string or empty field" % iid)
        continue
    cat, bud, kind = it["category"], it["budget"], it["kind"]
    if cat not in CATS: err("%s bad category" % iid)
    if bud not in BUDGETS: err("%s bad budget" % iid)
    if kind not in KINDS: err("%s bad kind" % iid)
    m = re.fullmatch(r"([a-z]+)-(\d\d)", iid)
    if not m or m.group(1) != cat:
        err("%s id pattern/category mismatch" % iid)
    elif cat in seq:
        seq[cat] += 1
        if int(m.group(2)) != seq[cat]: err("%s not sequential (expected %02d)" % (iid, seq[cat]))
    if iid in ids: err("duplicate id %s" % iid)
    ids.add(iid)
    if len(it["title"]) > 42: err("%s title %d chars" % (iid, len(it["title"])))
    if len(it["detail"]) > 170: err("%s detail %d chars" % (iid, len(it["detail"])))
    if "reveal" in it and len(it["reveal"]) > 120: err("%s reveal %d chars" % (iid, len(it["reveal"])))
    if it["title"].endswith("."): err("%s title trailing period" % iid)
    t = it["title"].lower()
    if t in titles: err("duplicate title %r" % it["title"])
    titles.add(t)
    counts[(cat, bud)] += 1

for ch in raw:
    if ord(ch) > 127 and ch != "\n":
        err("non-ASCII char U+%04X" % ord(ch)); break
for bad in ("—", "–"):
    if bad in raw: err("dash char present")
if re.search(r"\\u20(13|14)", raw): err("escaped dash present")
low = raw.lower()
for w in ("magical", "festive"):
    if low.count(w) > 3: err("'%s' used %d times" % (w, low.count(w)))

for c in CATS:
    for b in BUDGETS:
        if counts[(c, b)] < MINS[b]:
            err("%s/%s has %d, needs %d" % (c, b, counts[(c, b)], MINS[b]))

print("%-9s" % "category", *["%6s" % b for b in BUDGETS], "%6s" % "total")
for c in CATS:
    print("%-9s" % c, *["%6d" % counts[(c, b)] for b in BUDGETS], "%6d" % sum(counts[(c, b)] for b in BUDGETS))
print("%-9s" % "all", *["%6d" % sum(counts[(c, b)] for c in CATS) for b in BUDGETS], "%6d" % len(items))
if errors:
    print("\nFAIL (%d errors)" % len(errors))
    for e in errors: print(" -", e)
    sys.exit(1)
print("\nPASS")
