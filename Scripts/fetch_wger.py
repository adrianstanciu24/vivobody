#!/usr/bin/env python3
#
#  fetch_wger.py
#  vivobody
#
#  Phase 1 of the wger import: pull the public, read-only exercise
#  corpus from wger.de and dump it RAW to .wger-data/ (gitignored).
#  No transformation happens here — this just gives us a reviewable,
#  offline snapshot to map into ExerciseCatalogItem.Seed later
#  (Phase 2). English only.
#
#  wger exercise/ingredient data is Creative Commons licensed; keep
#  attribution when shipping anything derived from it.
#
#  Usage:
#      python3 Scripts/fetch_wger.py
#
#  Output (all under .wger-data/):
#      exercisecategory.json   – category lookup (Arms/Legs/…)
#      muscle.json             – anatomical muscle lookup
#      equipment.json          – equipment lookup
#      exerciseinfo-NNN.json   – one file per API page (raw)
#      exerciseinfo.json       – all pages merged into one results list
#      meta.json               – fetch timestamp, counts, source URLs
#
#  Stdlib only (urllib) — no pip install needed.
#

import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

BASE = "https://wger.de/api/v2"
ENGLISH_LANGUAGE_ID = 2          # wger language id for English
PAGE_SIZE = 100
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    ".wger-data",
)
USER_AGENT = "vivobody-fetch/1.0 (one-off exercise catalog import)"
MAX_RETRIES = 4


def get_json(url):
    """GET a URL and parse JSON, with a few retries on transient errors."""
    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as err:
            last_err = err
            wait = 2 ** attempt
            print(f"  ! {err} — retry {attempt}/{MAX_RETRIES} in {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise SystemExit(f"Failed after {MAX_RETRIES} retries: {url}\n{last_err}")


def write_json(name, data):
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return path


def fetch_lookup(endpoint):
    """Small single-shot lookup tables (categories, muscles, equipment)."""
    url = f"{BASE}/{endpoint}/?limit=200&format=json"
    print(f"-> {endpoint}")
    data = get_json(url)
    results = data.get("results", [])
    write_json(f"{endpoint}.json", results)
    print(f"   {len(results)} rows")
    return results


def fetch_exercises():
    """Page through exerciseinfo (rich, nested) for English exercises."""
    url = (
        f"{BASE}/exerciseinfo/"
        f"?language={ENGLISH_LANGUAGE_ID}&limit={PAGE_SIZE}&format=json"
    )
    all_results = []
    page = 0
    total = None
    while url:
        print(f"-> exerciseinfo page {page}")
        data = get_json(url)
        if total is None:
            total = data.get("count")
            print(f"   total exercises reported: {total}")
        write_json(f"exerciseinfo-{page:03d}.json", data)
        all_results.extend(data.get("results", []))
        url = data.get("next")
        page += 1
        time.sleep(0.3)  # be polite to the public API
    write_json("exerciseinfo.json", all_results)
    print(f"   fetched {len(all_results)} exercises across {page} pages")
    return all_results, total


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Writing raw wger snapshot to: {OUT_DIR}\n")

    categories = fetch_lookup("exercisecategory")
    muscles = fetch_lookup("muscle")
    equipment = fetch_lookup("equipment")
    exercises, reported_total = fetch_exercises()

    write_json("meta.json", {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "source": BASE,
        "language_id": ENGLISH_LANGUAGE_ID,
        "license": "Creative Commons (see individual entries); attribution required",
        "counts": {
            "categories": len(categories),
            "muscles": len(muscles),
            "equipment": len(equipment),
            "exercises_fetched": len(exercises),
            "exercises_reported": reported_total,
        },
    })

    print("\nDone. Review the snapshot under .wger-data/ before Phase 2.")


if __name__ == "__main__":
    main()
