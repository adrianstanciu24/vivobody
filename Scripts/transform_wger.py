#!/usr/bin/env python3
#
#  transform_wger.py
#  vivobody
#
#  RETIRED: the one-time wger bootstrap is kept only as historical reference.
#  It is hard-disabled below and cannot write catalog.json. The reviewed
#  family sources under specs/catalog-v2 are now the only catalog inputs, and
#  Scripts/catalog_v2.py is the sole canonical compiler.
#

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, ".wger-data")
OUT_CATALOG = os.path.join(ROOT, "vivobody", "Resources", "catalog.json")
OUT_REFERENCE = os.path.join(RAW_DIR, "reference.json")

ENGLISH = 2

# wger category name -> app MuscleGroup. wger's "Cardio" has no home in
# our six groups; we park it in core and fix per-exercise during curation.
CATEGORY_TO_GROUP = {
    "Abs": "core",
    "Arms": "arms",
    "Back": "back",
    "Calves": "legs",
    "Cardio": "core",
    "Chest": "chest",
    "Legs": "legs",
    "Shoulders": "shoulders",
}


def load(name):
    with open(os.path.join(RAW_DIR, name), encoding="utf-8") as f:
        return json.load(f)


def english_translation(ex):
    for t in ex.get("translations", []):
        if t.get("language") == ENGLISH and (t.get("name") or "").strip():
            return t
    return None


def strip_html(text):
    if not text:
        return ""
    import re
    return re.sub(r"<[^>]+>", " ", text).replace("&nbsp;", " ").strip()


def main():
    raise SystemExit(
        "Scripts/transform_wger.py is retired and cannot write catalog.json; "
        "use `python3 Scripts/catalog_v2.py --emit-runtime`."
    )

    # Historical implementation retained below for provenance only. This code
    # is deliberately unreachable so raw wger data cannot become runtime input.
    if not os.path.isdir(RAW_DIR):
        raise SystemExit(f"Missing {RAW_DIR}. Run Scripts/fetch_wger.py first.")
    exercises = load("exerciseinfo.json")

    roster = []
    reference = {}
    seen = set()
    dupes = 0
    for ex in exercises:
        tr = english_translation(ex)
        if tr is None:
            continue
        name = tr["name"].strip()
        key = name.lower()
        if key in seen:
            dupes += 1
            continue
        seen.add(key)

        category = (ex.get("category") or {}).get("name", "")
        group = CATEGORY_TO_GROUP.get(category, "core")

        roster.append({"name": name, "group": group})
        reference[name] = {
            "wgerCategory": category,
            "group": group,
            "equipment": [e["name"] for e in ex.get("equipment", [])],
            "muscles": [m["name"] for m in ex.get("muscles", [])],
            "muscles_secondary": [m["name"] for m in ex.get("muscles_secondary", [])],
            "aliases": [a["alias"] for a in tr.get("aliases", []) if a.get("alias")],
            "description": strip_html(tr.get("description", ""))[:400],
        }

    roster.sort(key=lambda r: (r["group"], r["name"].lower()))

    os.makedirs(os.path.dirname(OUT_CATALOG), exist_ok=True)
    with open(OUT_CATALOG, "w", encoding="utf-8") as f:
        json.dump(roster, f, ensure_ascii=False, indent=2)
    with open(OUT_REFERENCE, "w", encoding="utf-8") as f:
        json.dump(reference, f, ensure_ascii=False, indent=2)

    print(f"Wrote {len(roster)} names -> {OUT_CATALOG}")
    print(f"Curation reference ({len(reference)} entries) -> {OUT_REFERENCE}")
    print(f"Duplicates dropped: {dupes}")


if __name__ == "__main__":
    main()
