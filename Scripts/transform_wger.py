#!/usr/bin/env python3
#
#  transform_wger.py
#  vivobody
#
#  Phase 2 of the wger import, deliberately minimal. We take ONLY the
#  exercise names (plus the muscle group, which wger gets right and the
#  picker needs) from the raw snapshot in .wger-data/, and ship that as
#  the catalog roster. All the real per-exercise data — graded muscle
#  involvement, mechanic/pattern/plane/laterality, defaults, bodyweight
#  fraction — is authored by us afterwards, one exercise at a time,
#  directly in catalog.json (every other field is optional there).
#
#  Output:
#      vivobody/Resources/catalog.json   – [{ "name", "group" }, …]
#                                          the bundled roster (sorted).
#      .wger-data/reference.json         – dev-only: wger's own raw
#                                          muscles / equipment / aliases /
#                                          description per exercise, kept
#                                          as a reference while we author.
#                                          NOT shipped.
#
#  Stdlib only. Re-runnable: python3 Scripts/transform_wger.py
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
