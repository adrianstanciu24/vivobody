#!/usr/bin/env python3
#
#  curate.py
#  vivobody
#
#  Self-contained compiler for the shipped exercise catalog.
#
#  CURATION below owns the canonical exercise roster plus classification and
#  defaults. specs/exercise-anatomy-review.csv owns reviewed categorical muscle
#  roles. specs/exercise-definitions.csv owns immutable IDs, exact-name movement
#  definitions, and definition provenance. Together these tracked files are the
#  complete source; generation never imports or decodes an external roster.
#
#  The pipeline is:
#      python3 Scripts/curate.py           # rebuild catalog.json from scratch
#      python3 Scripts/curate.py --check   # verify the checked-in output is current
#
#  CURATION is normalized by the explicit duplicate-merge and canonical-rename
#  tables below before anything ships. To add an exercise, author its final
#  canonical name in all three tracked sources. Every output record is built
#  fresh, so obsolete keys or deleted records cannot survive from the previous
#  catalog. Everything is validated against the app enums, so a typo'd muscle,
#  equipment, movement direction, or other contract value fails loudly.
#

import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "vivobody", "Resources", "catalog.json")
ANATOMY_REVIEW = os.path.join(ROOT, "specs", "exercise-anatomy-review.csv")
DEFINITIONS = os.path.join(ROOT, "specs", "exercise-definitions.csv")

# Allowed enum values — mirror the Swift enums; curation is checked against these.
GROUPS = {"chest", "back", "shoulders", "legs", "arms", "core"}
EQUIPMENT = {"barbell", "dumbbell", "cable", "machine", "bodyweight", "kettlebell", "band", "other"}
MECHANICS = {"compound", "isolation"}
PATTERNS = {"push", "pull", "squat", "hinge", "lunge", "carry", "core", "locomotion"}
DIRECTIONS = {"horizontal", "vertical"}
PLANES = {"sagittal", "frontal", "transverse"}
LATERALITIES = {"bilateral", "unilateral"}
TRACKING = {"reps", "duration"}
MODALITIES = {"dynamicStrength", "isometricStrength", "power", "conditioning", "mobility"}
LOAD_MODES = {"external", "bodyweightAdded", "assistanceSubtracted", "nonComparable"}
MUSCLE_ROLES = {"primary", "secondary", "stabilizer"}
MUSCLES = {
    "pectorals", "serratus", "lats", "traps", "rhomboids", "teresMajor",
    "externalRotators", "subscapularis", "lowerBack",
    "deltoids", "biceps", "triceps", "forearms", "abs", "obliques", "quads",
    "hamstrings", "gluteMax", "gluteMed", "calves", "adductors", "hipFlexors", "shins",
}
MUSCLE_GROUPS = {
    "pectorals": "chest", "serratus": "chest",
    "lats": "back", "traps": "back", "rhomboids": "back",
    "teresMajor": "back", "lowerBack": "back",
    "deltoids": "shoulders", "externalRotators": "shoulders",
    "subscapularis": "shoulders",
    "biceps": "arms", "triceps": "arms", "forearms": "arms",
    "abs": "core", "obliques": "core",
    "quads": "legs", "hamstrings": "legs", "gluteMax": "legs",
    "gluteMed": "legs", "calves": "legs", "adductors": "legs",
    "hipFlexors": "legs", "shins": "legs",
}

# Historical seed tiers. They remain shorthand in the large curation roster,
# but `load_reviewed_involvement()` replaces them with categorical roles before
# any record is validated or written. Runtime data never contains these values.
PRIME, MAJOR, MINOR, TRACE = 1.0, 0.7, 0.4, 0.2

# kg seed defaults. The app stores weight canonically in lb, but a kg
# user's scrubber steps by 2.5 kg, so an lb default converted straight
# to kg (135 lb -> 61.2 kg) lands off-grid and reads unnaturally. We
# ship a native kg default per loaded lift, snapped to the 2.5 kg
# detent, so a kg user starts on a clean, plate-achievable number.
KG_PER_LB = 0.45359237
KG_STEP = 2.5


def kg_seed(weight_lb):
    """Gym-natural kg default for an lb weight, snapped to the kg
    scrubber's 2.5 kg step. Never drops a loaded lift below one step."""
    if weight_lb <= 0:
        return 0.0
    snapped = round(weight_lb * KG_PER_LB / KG_STEP) * KG_STEP
    return max(KG_STEP, snapped)


def ex(group, equipment, mechanic, pattern, *, weight=0, reps=8,
       weight_kg=None, direction=None, plane="sagittal", lat="bilateral", bw=0.0,
       tracking="reps", duration=0,
       aliases=None, prime=(), major=(), minor=(), trace=()):
    """Build one curated record body (everything except the name).

    `weight_kg` overrides the auto-snapped kg default for lifts whose
    natural kg number differs from the rounded conversion (e.g. a
    100 kg deadlift rather than 102.5)."""
    inv = ([{"muscle": m, "weight": PRIME} for m in prime]
           + [{"muscle": m, "weight": MAJOR} for m in major]
           + [{"muscle": m, "weight": MINOR} for m in minor]
           + [{"muscle": m, "weight": TRACE} for m in trace])
    rec = {
        "group": group,
        "defaultWeight": weight,
        "reps": reps,
        "equipment": equipment,
        "mechanic": mechanic,
        "plane": plane,
        "laterality": lat,
        "bodyweightFraction": bw,
        "involvement": inv,
    }
    if weight > 0:
        rec["defaultWeightKg"] = weight_kg if weight_kg is not None else kg_seed(weight)
    if mechanic == "compound" and pattern:
        rec["pattern"] = pattern
    if direction:
        rec["direction"] = direction
    if tracking != "reps":
        rec["trackingMode"] = tracking
        rec["defaultDuration"] = duration
    if aliases:
        rec["aliases"] = aliases
    return rec


# Keyed by the exact canonical exercise name. The tier arguments are an authoring
# shorthand only; `load_reviewed_involvement()` replaces them with reviewed,
# gluteMax/gluteMed-aware categorical roles before output is constructed.
# Batch 1: common / compound lifts.
CURATION = {
    # ---- Chest ----
    "Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                      aliases=["BP", "Flat Bench", "Barbell Bench"]),
    "Dumbbell Bench Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=50, reps=8,
                               prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                               aliases=["Dumbbell Bench Press", "DB Bench", "DB Press", "Dumbbell Chest Press"]),
    "Incline Dumbbell Bench Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=40, reps=8,
                                 prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                 aliases=["Incline DB Press", "Incline Bench Press - Dumbbell", "Incline Chest Press DB"]),
    "Decline Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                      aliases=["Decline Bench Press"]),
    "Chest Dip": ex("chest", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=8, bw=0.95,
               prime=["pectorals", "triceps"], minor=["deltoids"],
               aliases=["Dip", "Chest Dip"]),

    # ---- Back ----
    "Barbell Deadlift": ex("back", "barbell", "compound", "hinge", weight=225, reps=5, weight_kg=100,
                    prime=["gluteMax", "hamstrings", "lowerBack"],
                    major=["traps", "forearms"], minor=["lats", "quads"],
                    aliases=["Deadlift", "Conventional Deadlift", "DL"]),
    "Barbell Bent-Over Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, weight_kg=50,
                           prime=["lats", "rhomboids"], major=["traps", "biceps"],
                           minor=["teresMajor", "lowerBack"],
                           aliases=["Barbell Row", "Bent-Over Row", "BB Row"]),
    "Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                   prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                   aliases=["Pull-up", "Pullup", "Pull Ups", "Speed Pull Ups", "Weighted Pull Ups"]),
    "Chin-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                   prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                   aliases=["Chin-up", "Chinup", "Chin Up"]),
    "Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                        prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                        aliases=["Lat Pulldown", "Pulldown"]),
    "Seated Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=100, reps=10,
                            prime=["lats", "rhomboids"], major=["biceps"],
                            minor=["traps", "teresMajor"], aliases=["Seated Row", "Cable Row", "Seated Cable Row"]),
    "T-Bar Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=90, reps=8,
                    prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                    aliases=["T-Bar Row", "Rowing, T-bar"]),
    "Single-Arm Dumbbell Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=60, reps=10,
                           lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                           minor=["traps", "teresMajor"],
                           aliases=["Single-Arm Dumbbell Row", "One-Arm Row", "DB Row", "Single Arm Bent Over Row"]),

    # ---- Shoulders ----
    "Dumbbell Shoulder Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=8,
                                    prime=["deltoids"], major=["triceps"], minor=["traps"],
                                    aliases=["Dumbbell Shoulder Press", "DB Shoulder Press", "DB OHP"]),
    "Dumbbell Arnold Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10,
                                prime=["deltoids"], major=["triceps"], minor=["traps"],
                                aliases=["Arnold Press"]),
    "Barbell Clean and Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=5,
                          prime=["deltoids"], major=["triceps", "quads"],
                          minor=["traps", "gluteMax"], aliases=["Barbell Clean and Press"]),
    "Barbell Power Clean": ex("back", "barbell", "compound", "hinge", weight=135, reps=3,
                      prime=["traps", "gluteMax", "hamstrings"], major=["quads", "deltoids"],
                      minor=["lowerBack", "forearms"]),

    # ---- Legs ----
    "Barbell Back Squat": ex("legs", "barbell", "compound", "squat", weight=185, reps=8,
                 prime=["quads", "gluteMax"], major=["hamstrings"],
                 minor=["lowerBack", "adductors"],
                 aliases=["Back Squat", "Barbell Squat", "High-Bar Squat"]),
    "Barbell Front Squat": ex("legs", "barbell", "compound", "squat", weight=135, reps=8,
                       prime=["quads"], major=["gluteMax"], minor=["lowerBack", "abs"],
                       aliases=["Front Squat"]),
    "Machine Leg Press": ex("legs", "machine", "compound", "squat", weight=270, reps=10,
                    prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Machine Hack Squat": ex("legs", "machine", "compound", "squat", weight=180, reps=10,
                      prime=["quads"], minor=["gluteMax"], aliases=["Hack Squat"]),
    "Barbell Sumo Deadlift": ex("legs", "barbell", "compound", "hinge", weight=225, reps=5,
                        prime=["gluteMax", "adductors", "quads"], major=["lowerBack"],
                        minor=["hamstrings", "traps"], aliases=["Sumo DL"]),
    "Barbell Glute Bridge": ex("legs", "barbell", "compound", "hinge", weight=135, reps=12,
                       prime=["gluteMax"], minor=["hamstrings"]),
    "Bodyweight Lunge": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, bw=0.5,
                 lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                 minor=["adductors"], aliases=["Lunge"]),
    "Machine Leg Extension": ex("legs", "machine", "isolation", None, weight=80, reps=12,
                        prime=["quads"], aliases=["Quad Extension"]),

    # ---- Core ----
    "Plank": ex("core", "bodyweight", "isolation", "core", weight=0, reps=1,
                tracking="duration", duration=60, bw=0.6,
                prime=["abs"], major=["obliques"], minor=["lowerBack"],
                aliases=["Front Plank"]),

    # ===================== Batch 2: common variants + key isolation =====================

    # ---- Chest ----
    "Incline Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=95, reps=8,
                                        prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                        aliases=["Incline Bench Press", "Incline Barbell Press"]),
    "Close-Grip Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=115, reps=8,
                                 prime=["triceps"], major=["pectorals"], minor=["deltoids"],
                                 aliases=["CGBP", "Close Grip Bench Press", "Bench Press Narrow Grip"]),
    "Decline Dumbbell Bench Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=8,
                                       prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                       aliases=["Decline Dumbbell Press"]),
    "Dumbbell Chest Fly": ex("chest", "dumbbell", "isolation", None, weight=25, reps=12,
                             prime=["pectorals"], minor=["deltoids"],
                             aliases=["Dumbbell Fly", "Chest Fly", "DB Fly"]),
    "Wide-Grip Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"],
                       aliases=["Wide-Grip Push-Up"]),

    # ---- Shoulders ----
    "Dumbbell Lateral Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                         prime=["deltoids"], minor=["traps"],
                         aliases=["Lateral Raise", "Side Raise", "DB Lateral Raise"]),
    "Plate Front Raise": ex("shoulders", "other", "isolation", None, weight=25, reps=12,
                            prime=["deltoids"], minor=["serratus"],
                            aliases=["Plate Front Raise"]),
    "Dumbbell Upright Row": ex("shoulders", "dumbbell", "compound", "pull", direction="vertical", weight=25, reps=12,
                                   prime=["deltoids", "traps"], minor=["biceps"],
                                   aliases=["Dumbbell Upright Row"]),
    "Cable Face Pull": ex("shoulders", "cable", "compound", "pull", direction="horizontal", weight=50, reps=15,
                   prime=["deltoids"], major=["traps", "rhomboids"], minor=["teresMajor"],
                   aliases=["Face Pull"]),

    # ---- Arms ----
    "Barbell Biceps Curl": ex("arms", "barbell", "isolation", None, weight=65, reps=10,
                                    prime=["biceps"], minor=["forearms"],
                                    aliases=["Barbell Curl", "BB Curl"]),
    "Seated Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                prime=["biceps"], minor=["forearms"],
                                aliases=["Seated DB Curl"]),
    "Dumbbell Hammer Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                       prime=["biceps"], major=["forearms"],
                       aliases=["Hammer Curl", "DB Hammer Curl"]),
    "Barbell Preacher Curl": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                         prime=["biceps"], minor=["forearms"], aliases=["Preacher Curl"]),
    "Dumbbell Concentration Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12,
                                      lat="unilateral", prime=["biceps"],
                                      aliases=["Concentration Curl"]),
    "Cable Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12,
                           prime=["triceps"],
                           aliases=["Tricep Pushdown", "Pushdown", "Cable Pushdown"]),
    "EZ-Bar Skull Crusher": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                              prime=["triceps"],
                              aliases=["Skull Crusher", "Lying Triceps Extension", "EZ-Bar Skullcrusher"]),
    "Overhead Cable Triceps Extension": ex("arms", "cable", "isolation", None, weight=40, reps=12,
                                     prime=["triceps"], aliases=["Overhead Tricep Extension"]),
    "Barbell Shrug": ex("arms", "barbell", "isolation", None, weight=185, reps=12,
                           prime=["traps"], minor=["forearms"], aliases=["Barbell Shrug", "Shrugs"]),

    # ---- Legs ----
    "Lying Machine Leg Curl": ex("legs", "machine", "isolation", None, weight=70, reps=12,
                             prime=["hamstrings"], minor=["calves"],
                             aliases=["Lying Machine Leg Curl", "Machine Leg Curl", "Hamstring Curl"]),
    "Seated Machine Leg Curl": ex("legs", "machine", "isolation", None, weight=80, reps=12,
                              prime=["hamstrings"], minor=["calves"], aliases=["Seated Leg Curl"]),
    "Double-Leg Calf Raise": ex("legs", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.85,
                                prime=["calves"], aliases=["Calf Raise", "Standing Calf Raise"]),
    "Seated Dumbbell Calf Raise": ex("legs", "dumbbell", "isolation", None, weight=45, reps=15,
                                     prime=["calves"], aliases=["Seated Calf Raise"]),
    "Dumbbell Bulgarian Split Squat": ex("legs", "dumbbell", "compound", "lunge", weight=40, reps=10,
                                         lat="unilateral", prime=["quads", "gluteMax"],
                                         major=["hamstrings"], minor=["adductors"],
                                         aliases=["Bulgarian Split Squat", "Rear-Foot Elevated Split Squat"]),
    "Dumbbell Goblet Squat": ex("legs", "dumbbell", "compound", "squat", weight=50, reps=12,
                                prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"],
                                aliases=["Goblet Squat"]),
    "Barbell Good Morning": ex("legs", "barbell", "compound", "hinge", weight=95, reps=10,
                        prime=["hamstrings", "lowerBack"], major=["gluteMax"], aliases=["Good Morning"]),
    "Machine Hip Adduction": ex("legs", "machine", "isolation", None, weight=90, reps=15,
                               prime=["adductors"], aliases=["Hip Adduction", "Adductor Machine"]),
    "Machine Hip Abduction": ex("legs", "machine", "isolation", None, weight=90, reps=15,
                                prime=["gluteMax"],
                                aliases=["Hip Abduction", "Abductor Machine", "Seated Hip Abduction"]),

    # ---- Back ----
    "Hyperextension": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.5,
                          prime=["lowerBack"], major=["gluteMax", "hamstrings"],
                          aliases=["Back Extension", "Hyperextension"]),

    # ---- Core ----
    "Abdominal Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.3,
                           prime=["abs"], major=["obliques"], minor=["hipFlexors"],
                           aliases=["Crunch", "3008 Abdominal Crunch", "Crunches HD", "Levitation Crunch", "Negative Crunches"]),
    "Sit-Up": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                  prime=["abs"], minor=["hipFlexors"], aliases=["Sit-up"]),
    "Hanging Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                             prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                             aliases=["Hanging Leg Raise", "Straight-Leg Hanging Leg Raise"]),
    "Lying Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                          prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                          aliases=["Leg Raise", "Lying Leg Raises", "Leg Raises, Lying"]),
    "Russian Twist": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                        prime=["obliques"], major=["abs"],
                        aliases=["Russian Twists", "Core Rotation", "Russian Twists with Med Ball"]),
    "Ab Wheel Rollout": ex("core", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.4,
                   prime=["abs"], minor=["obliques", "lowerBack"],
                   aliases=["Ab Wheel Rollout", "Ab Roller"]),
    "Side Plank": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                     tracking="duration", duration=45, bw=0.5,
                     prime=["obliques"], minor=["abs"], aliases=["Side Plank Hold", "Lateral Isometric Hold", "Lateral Isometric Holds"]),
    "Mountain Climber": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                            prime=["abs"], minor=["obliques", "hipFlexors"],
                            aliases=["Mountain Climber"]),

    # ===================== Batch 3: long-tail variants (parallel droid pass) =====================

    # ---- Chest ----
    "Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=20, bw=0.64,
                  prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"],
                  aliases=["Pushup", "Press-up", "Standard Push-Up"]),
    "Close-Grip Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                               prime=["pectorals", "triceps"], minor=["deltoids"],
                               aliases=["Close-Grip Push-Up", "Narrow Push-Up"]),
    "Diamond Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                           prime=["triceps"], major=["pectorals"], minor=["deltoids"],
                           aliases=["Diamond Push-Up", "Triangle Push-Up"]),
    "Clap Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=10, bw=0.64,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                       aliases=["Clap Push-Up", "Plyometric Push-Up", "Explosive Push-Up"]),
    "Incline Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.5,
                          prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                          aliases=["Incline Push-Up", "Hands-Elevated Push-Up", "Push-Ups | Incline"]),
    "Decline Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.7,
                          prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                          aliases=["Decline Push-Up", "Feet-Elevated Push-Up"]),
    "Weighted Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=25, reps=12, bw=0.64,
                            prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                            aliases=["Weighted Push-Up"]),
    "Parallette Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                                 prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                 aliases=["Parallette Push-Up", "Deep Push-Up"]),
    "Machine Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10,
                              prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                              aliases=["Machine Press", "Seated Chest Press", "Seated Machine Press",
                                       "Machine Chest Press Exercise", "Flat Machine Press"]),
    "Hammer Strength Decline Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=110, reps=10,
                                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                             aliases=["Decline Machine Press", "Hammer Strength Decline Press"]),
    "Incline Smith Machine Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=95, reps=8,
                              prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                              aliases=["Incline Smith Machine Press"]),
    "Pin Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=6,
                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                             aliases=["Pin Press", "Dead Bench Press"]),
    "Barbell Larsen Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Paused Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=5,
                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                      aliases=["Paused Bench Press"]),
    "Reverse-Grip Barbell Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=115, reps=8,
                                   prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                   aliases=["Underhand Bench Press", "Supinated Bench Press"]),
    "Dumbbell Floor Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=8,
                               prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                               aliases=["DB Floor Press"]),
    "Dumbbell Hex Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10,
                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                             aliases=["Hex Press", "Squeeze Press", "Crush Press"]),
    "Single-Arm Incline Cable Chest Press": ex("chest", "cable", "compound", "push", direction="horizontal", weight=60, reps=10,
                                      prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                      aliases=["Incline Cable Press"]),
    "Single-Arm Decline Cable Chest Press": ex("chest", "cable", "compound", "push", direction="horizontal", weight=60, reps=10,
                                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                      aliases=["Decline Cable Press"]),
    "Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=25, reps=12,
                    prime=["pectorals"], minor=["deltoids"],
                    aliases=["Standing Cable Fly", "Cable Crossover"]),
    "Low-Pulley Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=20, reps=12,
                               prime=["pectorals"], minor=["deltoids"],
                               aliases=["Low Cable Fly", "Low-to-High Cable Fly"]),
    "High-to-Low Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=25, reps=12,
                                prime=["pectorals"], minor=["deltoids"],
                                aliases=["High-to-Low Cable Fly", "High Cable Fly"]),
    "Machine Chest Fly": ex("chest", "machine", "isolation", None, weight=80, reps=12,
                             prime=["pectorals"], minor=["deltoids"],
                             aliases=["Pec Deck", "Pec Deck Fly", "Butterfly", "Chest Fly Machine", "Machine Fly",
                                      "Narrow-Grip Machine Chest Fly"]),
    "Incline Dumbbell Chest Fly": ex("chest", "dumbbell", "isolation", None, weight=20, reps=12,
                               prime=["pectorals"], minor=["deltoids"], aliases=["Incline DB Fly"]),
    "Decline Dumbbell Chest Fly": ex("chest", "dumbbell", "isolation", None, weight=25, reps=12,
                                            prime=["pectorals"], minor=["deltoids"],
                                            aliases=["Decline Dumbbell Fly", "Decline DB Fly"]),
    "Cross-Bench Dumbbell Pullover": ex("chest", "dumbbell", "isolation", None, weight=35, reps=12,
                                         prime=["pectorals"], major=["lats"], minor=["serratus", "triceps"],
                                         aliases=["Dumbbell Pullover", "Cross-Bench Pullover"]),

    # ---- Back ----
    "Bent-Over Dumbbell Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=50, reps=10,
                                  prime=["lats", "rhomboids"], major=["biceps", "traps"],
                                  minor=["teresMajor", "lowerBack"],
                                  aliases=["Bent-Over Dumbbell Row", "Two-Arm DB Row"]),
    "Pendlay Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=135, reps=6,
                        prime=["lats", "rhomboids"], major=["traps", "biceps"],
                        minor=["teresMajor", "lowerBack"], aliases=["Pendlay Row"]),
    "Meadows Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=70, reps=10,
                      lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"],
                      minor=["teresMajor", "forearms"], aliases=["Landmine Meadows Row"]),
    "Kroc Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=80, reps=12,
                   lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"],
                   minor=["teresMajor", "forearms"], aliases=["Heavy Dumbbell Row"]),
    "Renegade Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=35, reps=10,
                       lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                       minor=["abs", "obliques", "traps"], aliases=["Plank Row"]),
    "Seated Machine Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=120, reps=10,
                               prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                               aliases=["Machine Row", "Seated Machine Row"]),
    "Single-Arm Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=60, reps=12,
                               lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                               minor=["traps", "teresMajor"], aliases=["Single-Arm Cable Row"]),
    "Iso-Lateral Machine Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=90, reps=10,
                                   prime=["lats", "rhomboids"], major=["biceps", "traps"],
                                   minor=["teresMajor"], aliases=["Iso-Lateral Row", "Hammer Strength Row"]),
    "Chest-Supported Barbell Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=95, reps=10,
                                 prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                                 aliases=["Chest-Supported Barbell Row"]),
    "Seated V-Grip Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=110, reps=10,
                            prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                            aliases=["V-Bar Seated Row"]),
    "Close-Grip Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                                   prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                                   aliases=["Close-Grip Pulldown"]),
    "Wide-Grip Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10,
                             prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "traps"],
                             aliases=["Wide-Grip Lat Pulldown"]),
    "Underhand Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                                  prime=["lats", "biceps"], minor=["teresMajor", "rhomboids"],
                                  aliases=["Reverse-Grip Pulldown", "Supinated Pulldown"]),
    "Neutral-Grip Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=105, reps=10,
                                    prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                                    aliases=["Neutral-Grip Pulldown", "V-Grip Pulldown"]),
    "Straight-Arm Cable Pulldown": ex("back", "cable", "isolation", None, weight=50, reps=15,
                                        prime=["lats"], minor=["teresMajor", "triceps"],
                                        aliases=["Straight-Arm Pushdown", "Lat Pushdown"]),
    "Machine Pullover": ex("back", "machine", "isolation", None, weight=90, reps=12,
                           prime=["lats"], minor=["teresMajor", "pectorals"],
                           aliases=["Machine Pullover", "Nautilus Pullover"]),
    "Dumbbell Pullover": ex("back", "dumbbell", "isolation", None, weight=50, reps=12,
                            prime=["lats"], minor=["pectorals", "teresMajor", "triceps"],
                            aliases=["DB Pullover", "Lat Pullover", "Pullover"]),
    "Single-Arm Cross-Body Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=50, reps=12,
                                               lat="unilateral", prime=["lats"], major=["biceps"],
                                               minor=["teresMajor", "rhomboids"],
                                               aliases=["Single-Arm Lat Pulldown", "Cross-Body Pulldown"]),
    "V-Bar Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10,
                         prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                         aliases=["Close Neutral-Grip Pulldown"]),
    "Wide-Grip Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                               prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                               aliases=["Wide-Grip Pull-up", "Wide Pull Up"]),
    "Neutral-Grip Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                                  prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                                  aliases=["Neutral-Grip Pull-up", "Hammer-Grip Pull-up"]),
    "Archer Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=6, bw=1.0,
                         lat="unilateral", prime=["lats"], major=["biceps"],
                         minor=["teresMajor", "rhomboids", "forearms"], aliases=["Archer Pull-up"]),
    "Muscle-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=5, bw=1.0,
                    prime=["lats"], major=["biceps", "triceps"],
                    minor=["pectorals", "deltoids", "forearms"], aliases=["Muscle-up", "Bar Muscle-up"]),
    "Scapular Pull-Up": ex("back", "bodyweight", "isolation", None, weight=0, reps=12, bw=1.0,
                        prime=["lats", "traps"], minor=["rhomboids", "forearms"],
                        aliases=["Scapular Pull-up", "Scap Pulls"]),
    "Barbell Deficit Deadlift": ex("back", "barbell", "compound", "hinge", weight=205, reps=5,
                           prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"],
                           minor=["lats", "quads"], aliases=["Deficit Pull"]),
    "Barbell Rack Pull": ex("back", "barbell", "compound", "hinge", weight=275, reps=5,
                        prime=["gluteMax", "lowerBack", "traps"], major=["hamstrings", "forearms"],
                        minor=["lats"], aliases=["Rack Pull", "Block Pull"]),
    "Dumbbell Hang Power Clean": ex("back", "dumbbell", "compound", "hinge", weight=40, reps=5,
                                     prime=["traps", "gluteMax", "hamstrings"], major=["deltoids", "quads"],
                                     minor=["lowerBack", "forearms"],
                                     aliases=["DB Hang Power Clean", "Dumbbell Power Clean"]),
    "Kettlebell Deadlift": ex("back", "kettlebell", "compound", "hinge", weight=53, reps=10,
                               prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"],
                               minor=["lats", "quads"], aliases=["Kettlebell Deadlift", "KB Deadlift"]),
    "Kettlebell Sumo High Pull": ex("back", "kettlebell", "compound", "pull", direction="vertical", weight=53, reps=10,
                                    prime=["traps", "gluteMax"], major=["hamstrings", "deltoids"],
                                    minor=["quads", "biceps", "lowerBack"], aliases=["KB Sumo High Pull"]),
    "Barbell Snatch": ex("back", "barbell", "compound", "hinge", weight=95, reps=3,
                    prime=["traps", "gluteMax", "hamstrings"], major=["deltoids", "quads"],
                    minor=["lowerBack", "lats", "forearms"], aliases=["Snatch", "Olympic Snatch"]),
    "Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4,
                   prime=["lowerBack"], major=["gluteMax"], minor=["hamstrings", "traps"],
                   aliases=["Superman Hold", "Prone Back Extension"]),
    "Bent-Over Dumbbell Face Pull": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=15, reps=15,
                                       prime=["deltoids"], major=["traps", "rhomboids"],
                                       minor=["teresMajor"], aliases=["Bent-Over Face Pull", "DB Face Pull"]),
    "Incline Dumbbell Reverse Fly": ex("back", "dumbbell", "isolation", None, weight=15, reps=15,
                                    prime=["deltoids"], major=["rhomboids"], minor=["traps", "teresMajor"],
                                    aliases=["Incline Reverse Fly", "Prone Rear Delt Fly"]),

    # ---- Shoulders ----
    "Dumbbell Front Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=12,
                       plane="frontal", prime=["deltoids"], minor=["serratus"],
                       aliases=["Front Raise", "Dumbbell Front Raise"]),
    "Cable Front Raise": ex("shoulders", "cable", "isolation", None, weight=25, reps=12,
                              plane="frontal", prime=["deltoids"], minor=["serratus"],
                              aliases=["Cable Front Raise"]),
    "45-Degree Dumbbell Lateral Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                             plane="frontal", prime=["deltoids"], minor=["traps"],
                             aliases=["45 Degree Lateral Raise", "Incline Lateral Raise"]),
    "Machine Lateral Raise": ex("shoulders", "machine", "isolation", None, weight=50, reps=15,
                                      plane="frontal", prime=["deltoids"], minor=["traps"],
                                      aliases=["Machine Lateral Raise"]),
    "Behind-the-Back Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                              plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Single-Arm Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                            plane="frontal", lat="unilateral", prime=["deltoids"],
                                            minor=["traps"], aliases=["Single-Arm Cable Lateral Raise"]),
    "High Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                   plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Bent-Over Dumbbell Lateral Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                   plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                                   aliases=["Bent-Over Lateral Raise", "Rear Delt Fly", "Rear Delt Raise",
                                            "Rear Delt Raises", "Reverse Fly"]),
    "Cable Rear Delt Fly": ex("shoulders", "cable", "isolation", None, weight=20, reps=15,
                              plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                              aliases=["Cable Reverse Fly"]),
    "Chest-Supported Dumbbell Rear Delt Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                          plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                                          aliases=["Chest-Supported Reverse Fly"]),
    "Machine Reverse Fly": ex("shoulders", "machine", "isolation", None, weight=70, reps=15,
                            plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                            aliases=["Reverse Pec Deck", "Rear Delt Machine", "Pec Deck Rear Delt Fly"]),
    "Dumbbell Rear Delt Row": ex("shoulders", "dumbbell", "compound", "pull", direction="horizontal", weight=30, reps=12,
                                 plane="transverse", prime=["deltoids"], major=["rhomboids", "traps"],
                                 minor=["biceps"], aliases=["Rear Delt Row"]),
    "Dumbbell Scaption": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                            plane="frontal", prime=["deltoids"], minor=["traps", "serratus"],
                            aliases=["Scaption Raise"]),
    "Incline Dumbbell Y-Raise": ex("shoulders", "dumbbell", "isolation", None, weight=10, reps=15,
                             plane="frontal", prime=["deltoids"], minor=["traps", "serratus"],
                             aliases=["Y-Raise", "Incline Y Raise"]),
    "Dumbbell Bradford Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=12,
                                  prime=["deltoids"], major=["triceps"], minor=["traps"],
                                  aliases=["Bradford Press"]),
    "Barbell Push Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=115, reps=5,
                     prime=["deltoids"], major=["triceps"], minor=["traps", "quads", "gluteMax"]),
    "Landmine Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=45, reps=10,
                         lat="unilateral", prime=["deltoids"], major=["triceps"],
                         minor=["pectorals", "serratus"], aliases=["Landmine Press", "Landmine Shoulder Press"]),
    "Smith Machine Shoulder Press": ex("shoulders", "machine", "compound", "push", direction="vertical", weight=65, reps=8,
                      prime=["deltoids"], major=["triceps"], minor=["traps"],
                      aliases=["Smith Machine Shoulder Press"]),
    "Machine Shoulder Press": ex("shoulders", "machine", "compound", "push", direction="vertical", weight=70, reps=10,
                                     prime=["deltoids"], major=["triceps"], minor=["traps"],
                                     aliases=["Machine Shoulder Press"]),
    "Single-Arm Dumbbell Shoulder Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=10,
                                             lat="unilateral", prime=["deltoids"], major=["triceps"],
                                             minor=["traps", "abs"], aliases=["Single-Arm DB Shoulder Press"]),
    "EZ-Bar Upright Row": ex("shoulders", "barbell", "compound", "pull", direction="vertical", weight=65, reps=12,
                              prime=["deltoids", "traps"], minor=["biceps"],
                              aliases=["EZ-Bar Upright Row"]),
    "Barbell High Pull": ex("shoulders", "barbell", "compound", "pull", direction="vertical", weight=115, reps=6,
                    prime=["traps", "deltoids"], minor=["biceps", "forearms"],
                    aliases=["Barbell High Pull"]),
    "Bent-Over Dumbbell High Pull": ex("shoulders", "dumbbell", "compound", "pull", direction="vertical", weight=30, reps=10,
                          prime=["deltoids", "traps"], minor=["biceps", "rhomboids"]),
    "Handstand Push-Up": ex("shoulders", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=6, bw=0.9,
                            prime=["deltoids", "triceps"], minor=["pectorals", "traps"],
                            aliases=["HSPU", "Handstand Pushup"]),
    "Hindu Push-Up": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6,
                        prime=["deltoids", "pectorals"], minor=["triceps", "abs"],
                        aliases=["Hindu Push-up", "Dive Bomber Push-up"]),
    "Pseudo Planche Push-Up": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=10, bw=0.7,
                                 prime=["deltoids"], major=["pectorals"], minor=["triceps", "serratus", "abs"],
                                 aliases=["Pseudo Planche Pushup"]),
    "Dumbbell Devil's Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=8,
                        prime=["deltoids"], major=["gluteMax", "pectorals"],
                        minor=["triceps", "hamstrings", "quads", "lats"],
                        aliases=["Devils Press", "Devil Press"]),
    "Dumbbell Diagonal Shoulder Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=10,
                                  prime=["deltoids"], major=["triceps"], minor=["pectorals", "traps"]),

    # ---- Arms ----
    "Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                     prime=["biceps"], minor=["forearms"]),
    "EZ-Bar Biceps Curl": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                                   prime=["biceps"], minor=["forearms"]),
    "Incline Dumbbell Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10,
                                prime=["biceps"], minor=["forearms"]),
    "Dumbbell Spider Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12,
                      prime=["biceps"], minor=["forearms"]),
    "Cable Concentration Curl": ex("arms", "cable", "isolation", None, weight=25, reps=12,
                                   lat="unilateral", prime=["biceps"]),
    "Straight-Bar Cable Biceps Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12,
                                   prime=["biceps"], minor=["forearms"]),
    "Alternating Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                                 lat="unilateral", prime=["biceps"], minor=["forearms"],
                                                 aliases=["Alternating Bicep Curls"]),
    "Cable Hammer Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12,
                               prime=["biceps"], major=["forearms"]),
    "Zottman Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10,
                       prime=["biceps"], major=["forearms"]),
    "Close-Grip Reverse Barbell Preacher Curl": ex("arms", "barbell", "isolation", None, weight=45, reps=10,
                                             prime=["biceps"], major=["forearms"]),
    "Machine Biceps Curl": ex("arms", "machine", "isolation", None, weight=50, reps=12, prime=["biceps"]),
    "Bayesian Cable Curl": ex("arms", "cable", "isolation", None, weight=30, reps=12,
                        lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Cross-Body Dumbbell Hammer Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                     lat="unilateral", prime=["biceps"], major=["forearms"]),
    "Single-Arm Kettlebell Biceps Curl": ex("arms", "kettlebell", "isolation", None, weight=25, reps=10,
                                      lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Single-Arm Cable Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=25, reps=12,
                                    lat="unilateral", prime=["triceps"]),
    "Machine Triceps Extension": ex("arms", "machine", "isolation", None, weight=80, reps=12, prime=["triceps"]),
    "Dumbbell Overhead Triceps Extension": ex("arms", "dumbbell", "isolation", None, weight=35, reps=12, prime=["triceps"]),
    "Ring Dip": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=8, bw=0.95,
                    prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Two-Bench Dip": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.45,
                                   prime=["triceps"], minor=["pectorals", "deltoids"]),
    "Dumbbell Tate Press": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["triceps"]),
    "JM Press": ex("arms", "barbell", "isolation", None, weight=95, reps=8,
                   prime=["triceps"], minor=["pectorals"]),
    "Close-Grip Smith Machine Bench Press": ex("arms", "machine", "compound", "push", direction="horizontal", weight=115, reps=8,
                                               prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Close-Grip Dumbbell Bench Press": ex("arms", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10,
                                          prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Dumbbell Wrist Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=15, prime=["forearms"]),
    "Barbell Wrist Curl": ex("arms", "barbell", "isolation", None, weight=65, reps=15, prime=["forearms"]),
    "Barbell Reverse Wrist Curl": ex("arms", "barbell", "isolation", None, weight=35, reps=15, prime=["forearms"]),
    "Cable Wrist Curl": ex("arms", "cable", "isolation", None, weight=40, reps=15, prime=["forearms"]),

    # ---- Legs ----
    "Barbell Full Squat": ex("legs", "barbell", "compound", "squat", weight=185, reps=8,
                             prime=["quads", "gluteMax"], major=["hamstrings"],
                             minor=["lowerBack", "adductors"]),
    "Dumbbell Front Squat": ex("legs", "dumbbell", "compound", "squat", weight=50, reps=10,
                               prime=["quads"], major=["gluteMax"], minor=["abs", "adductors"]),
    "Barbell Overhead Squat": ex("legs", "barbell", "compound", "squat", weight=95, reps=6,
                         prime=["quads", "gluteMax"], major=["hamstrings"],
                         minor=["deltoids", "lowerBack", "abs"]),
    "Barbell Pin Squat": ex("legs", "barbell", "compound", "squat", weight=155, reps=5,
                    prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Smith Machine Squat": ex("legs", "machine", "compound", "squat", weight=185, reps=10,
                              prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Trap Bar Squat": ex("legs", "barbell", "compound", "squat", weight=225, reps=8,
                         prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack", "traps"]),
    "Bodyweight Sumo Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.65,
                      prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Pistol Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8,
                       lat="unilateral", bw=0.9, prime=["quads", "gluteMax"],
                       major=["hamstrings"], minor=["adductors", "abs"]),
    "Cossack Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=10,
                        plane="frontal", lat="unilateral", bw=0.7, prime=["quads", "gluteMax"],
                        major=["adductors"], minor=["hamstrings"]),
    "Barbell Thruster": ex("legs", "barbell", "compound", "squat", weight=95, reps=8,
                   prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "traps", "abs"]),
    "Dumbbell Thruster": ex("legs", "dumbbell", "compound", "squat", weight=35, reps=10,
                            prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Wall Sit": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=1,
                   tracking="duration", duration=60, bw=0.6, prime=["quads"],
                   major=["gluteMax"], minor=["adductors"],
                   aliases=["Wall Squat"]),
    "Barbell Hip Thrust": ex("legs", "barbell", "compound", "hinge", weight=185, reps=10,
                             prime=["gluteMax"], major=["hamstrings"], minor=["quads"],
                             aliases=["Hip Thrust"]),
    "Dumbbell Hip Thrust": ex("legs", "dumbbell", "compound", "hinge", weight=60, reps=12,
                              prime=["gluteMax"], major=["hamstrings"], minor=["quads"]),
    "Dumbbell Romanian Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=50, reps=10,
                                     prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Barbell Stiff-Legged Deadlift": ex("legs", "barbell", "compound", "hinge", weight=135, reps=8,
                                 prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Dumbbell Sumo Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=70, reps=10,
                                 prime=["gluteMax", "adductors"], major=["quads", "hamstrings"],
                                 minor=["lowerBack"]),
    "Kettlebell Sumo Deadlift": ex("legs", "kettlebell", "compound", "hinge", weight=53, reps=10,
                                   prime=["gluteMax", "adductors"], major=["quads", "hamstrings"],
                                   minor=["lowerBack"]),
    "Kettlebell Swing": ex("legs", "kettlebell", "compound", "hinge", weight=35, reps=15,
                            prime=["gluteMax", "hamstrings"], major=["lowerBack"], minor=["quads", "deltoids"],
                            aliases=["Kettlebell Swing", "2 Handed Kettlebell Swing", "Two-Handed Kettlebell Swing"]),
    "Single-Leg Romanian Deadlift": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=10,
                         lat="unilateral", bw=0.5, prime=["hamstrings", "gluteMax"], minor=["lowerBack"]),
    "Single-Leg Dumbbell Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=35, reps=10,
                                            lat="unilateral", prime=["hamstrings", "gluteMax"],
                                            major=["lowerBack"], minor=["forearms"]),
    "Machine Reverse Hyperextension": ex("legs", "machine", "compound", "hinge", weight=90, reps=15,
                                 prime=["gluteMax", "hamstrings"], major=["lowerBack"]),
    "Cable Pull-Through": ex("legs", "cable", "compound", "hinge", weight=70, reps=15,
                             prime=["gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Single-Leg Glute Bridge": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=15,
                                  lat="unilateral", bw=0.5, prime=["gluteMax"], minor=["hamstrings"]),
    "Barbell Clean": ex("legs", "barbell", "compound", "hinge", weight=135, reps=3,
                prime=["quads", "gluteMax", "hamstrings"], major=["traps", "deltoids"],
                minor=["lowerBack", "forearms"]),
    "Dumbbell Reverse Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10,
                              lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                              minor=["adductors"]),
    "Dumbbell Split Squat": ex("legs", "dumbbell", "compound", "lunge", weight=40, reps=10,
                               lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                               minor=["adductors"]),
    "Smith Machine Split Squat": ex("legs", "machine", "compound", "lunge", weight=95, reps=10,
                                    lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                    minor=["adductors"]),
    "Barbell Step-Back Lunge": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"]),
    "Standing Barbell Lunge": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"]),
    "Standing Dumbbell Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10,
                                   lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                   minor=["adductors"]),
    "Standing Machine Leg Curl": ex("legs", "machine", "isolation", None, weight=40, reps=12,
                               lat="unilateral", prime=["hamstrings"], minor=["calves"]),
    "Nordic Hamstring Curl": ex("legs", "bodyweight", "isolation", None, weight=0, reps=8, bw=0.6,
                      prime=["hamstrings"], minor=["gluteMax", "calves"]),
    "Banded Leg Curl": ex("legs", "band", "isolation", None, weight=0, reps=15,
                                prime=["hamstrings"], minor=["calves"]),
    "Single-Leg Machine Leg Extension": ex("legs", "machine", "isolation", None, weight=50, reps=12,
                               lat="unilateral", prime=["quads"]),
    "Reverse Nordic Curl": ex("legs", "bodyweight", "isolation", None, weight=0, reps=10, bw=0.5,
                              prime=["quads"], minor=["hipFlexors"]),
    "Standing Machine Calf Raise": ex("legs", "machine", "isolation", None, weight=150, reps=15, prime=["calves"]),
    "Seated Machine Calf Raise": ex("legs", "machine", "isolation", None, weight=90, reps=15, prime=["calves"]),
    "Single-Leg Calf Raise": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                                  lat="unilateral", bw=0.9, prime=["calves"]),
    "Copenhagen Hip Adduction": ex("legs", "bodyweight", "isolation", None, weight=0, reps=10,
                                        plane="frontal", lat="unilateral", bw=0.5,
                                        prime=["adductors"], minor=["obliques", "abs"]),
    "Standing Cable Hip Adduction": ex("legs", "cable", "isolation", None, weight=40, reps=15,
                                     plane="frontal", lat="unilateral", prime=["adductors"]),
    "Side-Lying Hip Abduction": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                                   plane="frontal", lat="unilateral", bw=0.2, prime=["gluteMax"]),
    "Machine Glute Kickback": ex("legs", "machine", "isolation", None, weight=50, reps=15,
                                   lat="unilateral", prime=["gluteMax"], minor=["hamstrings"]),
    "Kneeling Glute Kickback": ex("legs", "bodyweight", "isolation", None, weight=0, reps=15,
                             lat="unilateral", bw=0.25, prime=["gluteMax"], minor=["hamstrings"]),

    # ---- Core ----
    "Bird Dog": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                   prime=["abs"], minor=["lowerBack", "gluteMax", "obliques"]),
    "Dead Bug": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                  prime=["abs"], minor=["hipFlexors", "obliques"]),
    "Hollow Hold": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                      tracking="duration", duration=30, bw=0.55,
                      prime=["abs"], minor=["obliques", "hipFlexors"],
                      aliases=["Supine Core Holds"]),
    "Flutter Kick": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                        prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                        aliases=["Scissors"]),
    "Reverse Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                         prime=["abs"], minor=["hipFlexors", "obliques"]),
    "Bicycle Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                           plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Cable Woodchop": ex("core", "cable", "isolation", None, weight=30, reps=15,
                             plane="transverse", lat="unilateral",
                             prime=["obliques"], major=["abs"], minor=["lats"]),
    "Cable Trunk Rotation": ex("core", "cable", "isolation", None, weight=30, reps=15,
                                    plane="transverse", lat="unilateral",
                                    prime=["obliques"], major=["abs"], minor=["lats"]),
    "Pallof Press": ex("core", "cable", "isolation", None, weight=25, reps=12,
                       plane="transverse", lat="unilateral",
                       prime=["obliques"], major=["abs"], minor=["deltoids"]),
    "Dumbbell Side Bend": ex("core", "dumbbell", "isolation", None, weight=35, reps=15,
                             plane="frontal", lat="unilateral", prime=["obliques"], minor=["abs"],
                             aliases=["Side Dumbbell Trunk Flexion"]),
    "Side Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                      plane="frontal", prime=["obliques"], minor=["abs"]),
    "Standing Side Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                                 plane="frontal", prime=["obliques"], minor=["abs"]),
    "Dumbbell Crunch": ex("core", "dumbbell", "isolation", None, weight=25, reps=15,
                            prime=["abs"], minor=["obliques"]),
    "Cable Crunch": ex("core", "cable", "isolation", None, weight=80, reps=15,
                              prime=["abs"], minor=["obliques"]),
    "Machine Crunch": ex("core", "machine", "isolation", None, weight=80, reps=15,
                              prime=["abs"], minor=["obliques"]),
    "Decline Bench Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                                  prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Incline Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], minor=["obliques"]),
    "Knee Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                      prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Captain's Chair Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                               prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Reverse Plank": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                        tracking="duration", duration=40, bw=0.5,
                        prime=["abs"], minor=["gluteMax", "lowerBack"]),
    "Plank Shoulder Tap": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                              plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"]),
    "Plank Jack": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                      prime=["abs"], minor=["obliques", "gluteMax"]),
    "L-Sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                tracking="duration", duration=20, bw=0.6,
                prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Dragon Flag": ex("core", "bodyweight", "isolation", None, weight=0, reps=8,
                      prime=["abs"], major=["obliques"], minor=["lowerBack", "lats"]),
    "Toe Tap": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                   prime=["abs"], minor=["obliques", "hipFlexors"]),
    "Heel Touch": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                       plane="frontal", prime=["obliques"], minor=["abs"]),
    "Seated Knee Tuck": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Windshield Wiper": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                            plane="transverse", prime=["obliques"], major=["abs"], minor=["hipFlexors"]),
    "Medicine Ball Russian Twist": ex("core", "other", "isolation", None, weight=10, reps=20,
                              plane="transverse", prime=["obliques"], major=["abs"]),
    "Dumbbell Suitcase Carry": ex("core", "dumbbell", "compound", "carry", weight=50, reps=1,
                         plane="frontal", lat="unilateral", tracking="duration", duration=40,
                         prime=["obliques"], major=["abs"], minor=["traps", "forearms", "gluteMax"],
                         aliases=["Uni-Lateral Farmer Walks", "Unilateral Farmer Walk"]),
    "Butterfly Sit-Up": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], minor=["obliques", "hipFlexors"]),
    "Legs-Up Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                                prime=["abs"], minor=["obliques"]),
    "Roman Chair Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                             prime=["abs"], minor=["obliques"]),
    "Rotary Torso Machine": ex("core", "machine", "isolation", None, weight=70, reps=15,
                               plane="transverse", prime=["obliques"], minor=["abs"]),
    "Toes-to-Bar": ex("core", "bodyweight", "isolation", None, weight=0, reps=10,
                      prime=["abs"], major=["hipFlexors"], minor=["obliques", "lats"]),
    "Barbell Ab Rollout": ex("core", "barbell", "isolation", None, weight=0, reps=10,
                             prime=["abs"], minor=["obliques", "lowerBack"]),
    "Medicine Ball Slam": ex("core", "other", "isolation", None, weight=20, reps=15,
                     prime=["abs"], major=["obliques", "lats"], minor=["deltoids", "gluteMax"],
                     aliases=["Medicine Ball Slams", "Kneeling Med Ball Slams"]),

    # ===================== Batch 4: deep long-tail pass (parallel droids, round 2) =====================

    # ---- Chest ----
    "Bent-Over Cable Fly": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Burpee": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps", "quads", "gluteMax"], minor=["deltoids", "abs"]),
    "Mid-Height Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Low-to-High Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Cable Press-Around": ex("chest", "cable", "compound", "push", direction="horizontal", weight=30, reps=12, lat="unilateral", prime=["pectorals"], major=["triceps"], minor=["deltoids", "serratus"]),
    "Underhand-Grip Dumbbell Bench Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=40, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Deficit Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Dumbbell Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "High Plank": ex("chest", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=45, bw=0.6, prime=["abs"], minor=["pectorals", "deltoids", "serratus"]),
    "High-Incline Smith Machine Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=85, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Incline Multipress Bench Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=90, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Incline Scapular Push-Up": ex("chest", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["serratus"], minor=["deltoids", "pectorals"]),
    "Incline Dumbbell Press Hold": ex("chest", "dumbbell", "isolation", None, weight=30, reps=1, tracking="duration", duration=30, prime=["pectorals"], minor=["deltoids"]),
    "Push-Up Wiper": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"]),
    "Legend Machine Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Legend Machine Incline Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=90, reps=10, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Leverage Machine Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Low-to-High Cable Crossover": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "No-Leg-Drive Dumbbell Bench Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "No-Push-Up Burpee": ex("chest", "bodyweight", "compound", "squat", weight=0, reps=12, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["deltoids", "abs"], trace=["pectorals"]),
    "Omni Cable Crossover": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Ring Support Hold": ex("chest", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, bw=0.95, prime=["pectorals", "triceps"], major=["deltoids"], minor=["serratus", "abs"]),
    "Slight-Incline Smith Machine Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=95, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Seated Cable Chest Fly": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Side-to-Side Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "obliques"]),

    # ---- Back ----
    "Half-Kneeling Single-Arm Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=50, reps=12, lat="unilateral", prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"], aliases=["Half-Kneeling Single-Arm Pulldown"]),
    "Alternating High Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=80, reps=12, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Alternating Cable High Row"]),
    "Alternating Dumbbell Gorilla Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=70, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor", "forearms"], aliases=["Gorilla Row", "Dumbbell Gorilla Row"]),
    "Back Lever": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=15, bw=1.0, prime=["lats", "lowerBack"], minor=["abs", "biceps", "teresMajor"], aliases=["Back Lever Hold"]),
    "Band Pull-Apart": ex("back", "band", "isolation", None, weight=0, reps=20, plane="transverse", prime=["rhomboids", "deltoids"], minor=["traps", "teresMajor"], aliases=["Band Pull-Apart"]),
    "Banded Scapular Retraction": ex("back", "band", "isolation", None, weight=0, reps=15, prime=["rhomboids", "traps"], minor=["teresMajor", "deltoids"], aliases=["Banded Scap Retraction"]),
    "Barbell Romanian Deadlift": ex("back", "barbell", "compound", "hinge", weight=155, reps=8, prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"], aliases=["Barbell RDL", "Romanian Deadlift", "RDL"]),
    "Overhand Barbell Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, prime=["lats", "rhomboids"], major=["traps", "biceps"], minor=["teresMajor", "lowerBack"], aliases=["Pronated Barbell Row", "Overhand Bent-Over Row"]),
    "Underhand Barbell Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor", "lowerBack"], aliases=["Supinated Barbell Row", "Underhand Bent-Over Row"]),
    "Bent-Over Dumbbell Row to External Rotation": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=15, reps=12, plane="transverse", prime=["rhomboids", "deltoids"], major=["traps"], minor=["lats", "teresMajor"], aliases=["Row to External Rotation"]),
    "Butterfly Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["lowerBack"], major=["gluteMax"], minor=["rhomboids", "traps", "hamstrings"], aliases=["Superman Butterfly"]),
    "Cross-Body Cable Y-Raise": ex("back", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], major=["traps"], minor=["rhomboids"], aliases=["Cross-Body Y Raise"]),
    "Band Face Pull": ex("back", "band", "compound", "pull", direction="horizontal", weight=0, reps=20, prime=["deltoids"], major=["traps", "rhomboids"], minor=["teresMajor"], aliases=["Band Face Pull"]),
    "Front Lever Tuck": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.7, prime=["lats", "abs"], minor=["lowerBack", "biceps", "teresMajor"], aliases=["Tuck Front Lever"]),
    "Half-Kneeling Single-Arm Cable High Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=110, reps=10, prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor"], aliases=["Machine High Row"]),
    "Lying Hip Raise": ex("back", "bodyweight", "compound", "hinge", weight=0, reps=1, tracking="duration", duration=30, bw=0.5, prime=["gluteMax"], major=["hamstrings"], minor=["lowerBack"], aliases=["Lying Hip Raise"]),
    "Incline Chest-Supported Dumbbell Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=45, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Chest-Supported Incline DB Row", "Dumbbell Prone Row"]),
    "Kneeling Superman Hold": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, lat="unilateral", prime=["lowerBack"], major=["gluteMax"], minor=["traps", "deltoids", "abs"], aliases=["Quadruped Superman"]),
    "Leaning-Back Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "traps"], aliases=["Leaning-Back Lat Pulldown"]),
    "Upright Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"], aliases=["Straight-Back Lat Pulldown"]),
    "Low Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=110, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Low Cable Row", "Long Pulley Row"]),
    "Heavy Single-Arm Dumbbell Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=80, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor", "forearms"], aliases=["Heavy One-Arm Dumbbell Row"]),
    "Prone Scapular Retraction with Arms at Sides": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.2, prime=["rhomboids", "traps"], minor=["teresMajor", "deltoids"], aliases=["Prone Scap Retraction"]),
    "Isometric Pull-Up Hold": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=1.0, prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"], aliases=["Pull-up Hold", "Flexed-Arm Hang"]),
    "Cable Reverse Fly": ex("back", "cable", "isolation", None, weight=20, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"], aliases=["Reverse Cable Fly"]),
    "Reverse Snow Angel": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.2, prime=["traps", "rhomboids"], minor=["deltoids", "lowerBack"], aliases=["Prone Snow Angel"]),
    "Seated Cable Mid-Trap Shrug": ex("back", "cable", "isolation", None, weight=60, reps=15, prime=["traps"], major=["rhomboids"], minor=["teresMajor"], aliases=["Seated Cable Mid-Trap Shrug"]),
    "Seated Dumbbell Rear Delt Raise": ex("back", "dumbbell", "isolation", None, weight=15, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"], aliases=["Seated Rear Delt Raise"]),
    "Shotgun Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=50, reps=12, plane="transverse", lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"], minor=["teresMajor", "obliques"], aliases=["Single-Arm Shotgun Row"]),
    "Side Straight-Arm Cable Pulldown": ex("back", "cable", "isolation", None, weight=30, reps=15, lat="unilateral", prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Single-Arm Straight-Arm Pulldown"]),
    "Single-Arm Kettlebell Plank Row": ex("back", "kettlebell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"], minor=["abs", "obliques", "deltoids"], aliases=["Plank to Row"]),
    "Prone T Raise": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.3, prime=["lowerBack"], major=["traps", "rhomboids"], minor=["gluteMax", "deltoids"], aliases=["Prone T Raise", "Skydiver"]),
    "Straight-Arm Cable Pulldown with Bar": ex("back", "cable", "isolation", None, weight=50, reps=15, prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Straight-Arm Pulldown (Bar)"]),
    "Straight-Arm Cable Pulldown with Rope": ex("back", "cable", "isolation", None, weight=45, reps=15, prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Straight-Arm Pulldown (Rope)"]),
    "Towel Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["lowerBack"], major=["gluteMax", "traps"], minor=["rhomboids", "hamstrings"], aliases=["Superman with Towel"]),
    "Trap-3 Raise": ex("back", "dumbbell", "isolation", None, weight=10, reps=15, plane="frontal", lat="unilateral", prime=["traps"], minor=["deltoids", "rhomboids"], aliases=["Lower Trap Raise", "Trap 3 Raise"]),
    "Typewriter Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=6, bw=1.0, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"], aliases=["Typewriter Pull-up"]),

    # ---- Shoulders ----
    "Plate Bus Driver": ex("shoulders", "other", "isolation", None, weight=25, reps=15, plane="frontal", prime=["deltoids"], minor=["serratus", "traps"]),
    "Band Pull-Apart with External Rotation": ex("shoulders", "band", "isolation", None, weight=0, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"]),
    "Barbell Silverback Shrug": ex("shoulders", "barbell", "isolation", None, weight=135, reps=12, prime=["traps"], minor=["rhomboids", "deltoids"]),
    "Cable External Rotation": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                   plane="transverse", lat="unilateral",
                                   prime=["deltoids"], minor=["teresMajor"],
                                   aliases=["Shoulder External Rotation (Cable)"]),
    "Single-Arm Cable Rear Delt Fly": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["rhomboids", "traps"]),
    "Cable Shrug-In": ex("shoulders", "cable", "isolation", None, weight=80, reps=15, prime=["traps"], minor=["rhomboids"]),
    "Chair Dip": ex("shoulders", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.45, prime=["triceps"], minor=["pectorals", "deltoids"]),
    "Barbell Clean and Jerk": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=135, reps=2, prime=["deltoids"], major=["quads", "gluteMax", "triceps"], minor=["hamstrings", "traps"]),
    "Dumbbell Shrug": ex("shoulders", "dumbbell", "isolation", None, weight=60, reps=12,
                          prime=["traps"], minor=["forearms"], aliases=["Shoulder Shrug"]),
    "Incline Dumbbell Overhead Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=8, prime=["deltoids"], major=["triceps"], minor=["traps"]),
    "Barbell Jerk": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=135, reps=2, prime=["deltoids"], major=["triceps", "quads", "gluteMax"], minor=["traps"]),
    "Barbell Overhead Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=8,
                                  prime=["deltoids"], major=["triceps"], minor=["traps"],
                                  aliases=["OHP", "Standing Press", "Strict Press", "Barbell Shoulder Press"]),
    "Single-Arm Perpendicular Landmine Row": ex("shoulders", "barbell", "compound", "pull", direction="horizontal", weight=60, reps=10, lat="unilateral", prime=["deltoids"], major=["traps"], minor=["rhomboids", "biceps"]),
    "Barbell Pin Overhead Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=5, prime=["deltoids"], major=["triceps"], minor=["traps"]),
    "Seated Dumbbell Lateral Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15, plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Cable Shoulder Internal Rotation": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["pectorals"]),
    "Cable Shoulder Y-Pull": ex("shoulders", "cable", "compound", "pull", direction="vertical", weight=30, reps=15, prime=["deltoids"], major=["traps"], minor=["rhomboids"]),
    "Smith Machine Shrug": ex("shoulders", "machine", "isolation", None, weight=185, reps=12, prime=["traps"], minor=["forearms"]),
    "Behind-the-Body Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], minor=["traps"]),
    "Front-of-Body Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], minor=["traps"]),
    "Side-Lying Dumbbell Internal Rotation": ex("shoulders", "dumbbell", "isolation", None, weight=8, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["pectorals"]),
    "Side-Lying Dumbbell External Rotation": ex("shoulders", "dumbbell", "isolation", None, weight=10, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["teresMajor"]),
    "Straight-Bar Cable Front Raise": ex("shoulders", "cable", "isolation", None, weight=30, reps=12,
                                          plane="frontal", prime=["deltoids"], minor=["serratus"],
                                          aliases=["Cable Front Raise with a small bar"]),
    "Supine Dumbbell Serratus Punch": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                 plane="transverse", prime=["serratus"],
                                 trace=["deltoids", "triceps"],
                                 aliases=["Dumbbell Serratus Punch", "Serratus Punch"]),
    "Smith Machine Upright Row": ex("shoulders", "machine", "compound", "pull", direction="vertical", weight=65, reps=12, prime=["deltoids", "traps"], minor=["biceps"]),
    "Single-Arm Cross-Body Cable Pulldown": ex("shoulders", "cable", "isolation", None, weight=20, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["lats", "teresMajor"]),

    # ---- Arms ----
    "Alternating Dumbbell Hammer Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, lat="unilateral", prime=["biceps"], major=["forearms"]),
    "Barbell Triceps Extension": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "Cable Biceps Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["biceps"], minor=["forearms"]),
    "Bodyweight Biceps Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.4, prime=["biceps"], minor=["forearms"]),
    "Single-Arm Cable Triceps Extension with Internal Rotation": ex("arms", "cable", "isolation", None, weight=40, reps=12, prime=["triceps"]),
    "Cable Triceps Kickback": ex("arms", "cable", "isolation", None, weight=20, reps=15, prime=["triceps"]),
    "Single-Arm Cable Triceps Press": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Two-Handed Kettlebell Curl": ex("arms", "kettlebell", "isolation", None, weight=35, reps=12, prime=["biceps"], minor=["forearms"]),
    "Dumbbell Wrist Extension": ex("arms", "dumbbell", "isolation", None, weight=20, reps=15, prime=["forearms"]),
    "Double-Kettlebell Clean and Press": ex("arms", "kettlebell", "compound", "push", direction="vertical", weight=35, reps=6, prime=["deltoids"], major=["triceps", "quads"], minor=["traps", "gluteMax"]),
    "Cable Drag Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Dumbbell Cheat Curl": ex("arms", "dumbbell", "isolation", None, weight=40, reps=8, prime=["biceps"], minor=["forearms"]),
    "Underhand Dumbbell Dead Row": ex("arms", "dumbbell", "compound", "pull", direction="horizontal", weight=50, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"]),
    "Dumbbell Biceps Curl to Press": ex("arms", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10, prime=["biceps", "deltoids"], major=["triceps"], minor=["traps"]),
    "Dumbbell Drag Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, prime=["biceps"], minor=["forearms"]),
    "Wide-Grip Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"]),
    "Dumbbell Preacher Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Elbows-Tucked Dumbbell Bench Press": ex("arms", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Fingertip Push-Up": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "forearms"]),
    "Barbell Floor Skull Crusher": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "Floor Dip": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12,
                      bw=0.45, prime=["triceps"], minor=["pectorals", "deltoids"],
                      aliases=["Bench Dips On Floor HD"]),
    "Underhand-Grip Dumbbell Wrist Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=15, prime=["forearms"]),
    "High-Cable Cross-Body Triceps Extension": ex("arms", "cable", "isolation", None, weight=30, reps=12, prime=["triceps"]),
    "Incline Close-Grip Barbell Bench Press": ex("arms", "barbell", "compound", "push", direction="horizontal", weight=95, reps=8, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Incline Dumbbell Skull Crusher": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "L-Sit Pull-Up": ex("arms", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "abs", "hipFlexors"]),
    "Lying Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Prone Incline Dumbbell Triceps Kickback": ex("arms", "dumbbell", "isolation", None, weight=20, reps=12, prime=["triceps"]),
    "Single-Arm Overhead Cable Triceps Extension": ex("arms", "cable", "isolation", None, weight=25, reps=12, lat="unilateral", prime=["triceps"]),
    "Pike Push-Up": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.6, prime=["deltoids"], major=["triceps"], minor=["pectorals"]),
    "Externally Rotated Single-Arm Dumbbell Preacher Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Internally Rotated Single-Arm Dumbbell Preacher Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Push-Up Rotation": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "obliques", "abs"]),
    "Reverse-Grip Barbell Biceps Curl": ex("arms", "barbell", "isolation", None, weight=45, reps=12,
                            prime=["biceps"], major=["forearms"], aliases=["Reverse Curl"]),
    "Reverse-Grip EZ-Bar Cable Biceps Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["biceps"], major=["forearms"]),
    "Rocking Cable Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Seated Dumbbell Overhead Triceps Extension": ex("arms", "dumbbell", "isolation", None, weight=35, reps=12, prime=["triceps"]),
    "Seated Dumbbell W Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"]),
    "Shoulder-Width Three-Point Push-Up": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Single-Arm Dumbbell Preacher Curl": ex("arms", "dumbbell", "isolation", None, weight=20, reps=10, lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Dumbbell Skull Crusher": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["triceps"]),
    "Standing Dumbbell Biceps Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, prime=["biceps"], minor=["forearms"]),
    "Standing Wrist Roller": ex("arms", "cable", "isolation", None, weight=40, reps=15, prime=["forearms"]),
    "TRX Triceps Extension": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["triceps"]),
    "TRX Dip": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=10, bw=0.9, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "TRX Gorilla Biceps Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["biceps"], minor=["forearms"]),
    "TRX Hammer Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["biceps"], major=["forearms"]),
    "Rope Cable Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["triceps"]),
    "Straight-Bar Cable Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=55, reps=12, prime=["triceps"]),
    "Single-Arm TRX Biceps Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=10, bw=0.5, lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Wall Push-Up": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.3, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Knee Push-Up": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.5, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),

    # ---- Legs ----
    "Single-Leg Box Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8, lat="unilateral", bw=0.85, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Barbell Hack Squat": ex("legs", "barbell", "compound", "squat", weight=185, reps=8, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Belt Squat": ex("legs", "machine", "compound", "squat", weight=180, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Bodyweight Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Braced Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=15, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Double-Kettlebell Front Squat": ex("legs", "kettlebell", "compound", "squat", weight=70, reps=8, prime=["quads"], major=["gluteMax"], minor=["abs", "adductors"]),
    "Hindu Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=25, bw=0.6, prime=["quads", "gluteMax"], minor=["calves", "hamstrings"]),
    "Isometric Squat to Failure": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=1, tracking="duration", duration=60, bw=0.6, prime=["quads", "gluteMax"], minor=["adductors"]),
    "Landmine Squat to Press": ex("legs", "barbell", "compound", "squat", weight=65, reps=10, prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Hack Squat Machine Leg Press": ex("legs", "machine", "compound", "squat", weight=270, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Narrow-Stance Machine Leg Press": ex("legs", "machine", "compound", "squat", weight=270, reps=12, prime=["quads"], major=["gluteMax"], minor=["hamstrings"]),
    "Wide-Stance Machine Leg Press": ex("legs", "machine", "compound", "squat", weight=270, reps=12, prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Wide-Stance Low Box Squat": ex("legs", "barbell", "compound", "squat", weight=185, reps=6, prime=["quads", "gluteMax"], major=["hamstrings", "adductors"], minor=["lowerBack"]),
    "Paused Machine Hack Squat": ex("legs", "machine", "compound", "squat", weight=160, reps=10, prime=["quads"], major=["gluteMax"], minor=["hamstrings"]),
    "Machine Pendulum Squat": ex("legs", "machine", "compound", "squat", weight=180, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Prisoner Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Shrimp Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8, lat="unilateral", bw=0.85, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Squat Jump": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=15, bw=0.6, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings"]),
    "Wall Ball": ex("legs", "other", "compound", "squat", weight=20, reps=15, prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Dumbbell Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=70, reps=10, prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["quads", "forearms"]),
    "Dumbbell Frog Pump": ex("legs", "dumbbell", "compound", "hinge", weight=45, reps=15, prime=["gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Machine Glute Drive": ex("legs", "machine", "compound", "hinge", weight=180, reps=12, prime=["gluteMax"], major=["hamstrings"], minor=["quads"]),
    "Bodyweight Glute Bridge": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=20, bw=0.4, prime=["gluteMax"], minor=["hamstrings"]),
    "Single-Leg Kettlebell Deadlift": ex("legs", "kettlebell", "compound", "hinge", weight=35, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Dumbbell Kickstand Romanian Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=45, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Barbell Speed Deadlift": ex("legs", "barbell", "compound", "hinge", weight=185, reps=3, prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"], minor=["quads", "lats"]),
    "Single-Leg Hip Thrust": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=15, lat="unilateral", bw=0.5, prime=["gluteMax"], major=["hamstrings"], minor=["quads"]),
    "Dumbbell Snatch": ex("legs", "dumbbell", "compound", "hinge", weight=40, reps=8, lat="unilateral", prime=["gluteMax", "hamstrings"], major=["deltoids", "quads"], minor=["traps", "lowerBack", "forearms"]),
    "Walking Barbell Lunge": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Walking Dumbbell Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=12,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"], aliases=["Walking Lunges", "Walking Lunge"]),
    "Dumbbell Lateral Squat": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=10, plane="frontal", lat="unilateral", prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Bodyweight Reverse Lunge": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, lat="unilateral", bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Single-Leg Kettlebell Lunge": ex("legs", "kettlebell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Sliding Lateral Lunge": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, plane="frontal", lat="unilateral", prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Dumbbell Farmer's Carry": ex("legs", "dumbbell", "compound", "carry", weight=60, reps=1, tracking="duration", duration=40, prime=["forearms", "traps"], major=["gluteMax", "quads"], minor=["abs", "obliques"]),
    "Leg Press Calf Raise": ex("legs", "machine", "isolation", None, weight=200, reps=15, prime=["calves"]),
    "Banded Ankle Plantar Flexion": ex("legs", "band", "isolation", None, weight=0, reps=20, prime=["calves"]),
    "Banded Ankle Dorsiflexion": ex("legs", "band", "isolation", None, weight=0, reps=20, prime=["shins"]),
    "Tibialis Raise": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20, prime=["shins"]),
    "Standing Cable Hip Abduction": ex("legs", "cable", "isolation", None, weight=30, reps=15, plane="frontal", lat="unilateral", prime=["gluteMax"]),
    "Supine Hip Abduction": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20, plane="frontal", bw=0.15, prime=["gluteMax"]),
    "Single-Leg Machine Side Glute Press": ex("legs", "machine", "isolation", None, weight=50, reps=15, lat="unilateral", prime=["gluteMax"], minor=["adductors"]),
    "Banded Glute Kickback": ex("legs", "band", "isolation", None, weight=0, reps=15, lat="unilateral", prime=["gluteMax"], minor=["hamstrings"]),

    # ---- Core ----
    "Stability Ball Crunch": ex("core", "other", "isolation", None, weight=0, reps=20, prime=["abs"], minor=["obliques"]),
    "Alternating Battle Rope Wave": ex("core", "other", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, prime=["deltoids", "abs"], major=["forearms", "obliques"], minor=["lats", "biceps", "traps"]),
    "Bear Crawl Pull-Through": ex("core", "dumbbell", "isolation", None, weight=25, reps=12, plane="transverse", prime=["abs"], major=["obliques", "deltoids"], minor=["gluteMax", "quads"]),
    "Black Widow Knee Slide": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Clamshell": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                     plane="transverse", lat="unilateral", bw=0.15,
                     prime=["gluteMed"], minor=["gluteMax"], trace=["abs"]),
    "Side Plank Clamshell": ex("core", "bodyweight", "compound", "core", weight=0, reps=12,
                                plane="frontal", lat="unilateral", bw=0.5,
                                prime=["obliques", "gluteMed"],
                                minor=["abs", "gluteMax", "deltoids", "serratus"],
                                trace=["lowerBack", "triceps"]),
    "Double-Leg Abdominal Press": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, prime=["abs"], minor=["hipFlexors", "obliques"]),
    "Plank In-and-Out Jump": ex("core", "bodyweight", "compound", "core", weight=0, reps=12,
                                  bw=0.6, prime=["abs"], major=["hipFlexors", "quads"],
                                  minor=["deltoids", "serratus", "gluteMax"]),
    "Kettlebell Suitcase March": ex("core", "kettlebell", "compound", "carry", weight=20,
                                                reps=1, tracking="duration", duration=30,
                                                plane="frontal", lat="unilateral",
                                                prime=["obliques"], minor=["abs", "lowerBack", "gluteMed"],
                                                trace=["forearms", "deltoids"]),
    "Frog Stand": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.6, prime=["abs"], major=["deltoids"], minor=["forearms", "biceps"]),
    "Front Lever": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=10, bw=1.0, prime=["abs", "lats"], minor=["obliques", "forearms"]),
    "Front Lever Pull-Up": ex("core", "bodyweight", "compound", "pull", direction="horizontal", weight=0, reps=5, bw=1.0, prime=["lats"], major=["abs", "biceps"], minor=["deltoids", "forearms"]),
    "Full Sit-Out": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["abs"], major=["obliques"], minor=["gluteMax", "deltoids"]),
    "High-Knee Jump": ex("core", "bodyweight", "compound", "squat", weight=0, reps=8, prime=["hipFlexors", "quads"], major=["calves"], minor=["abs"]),
    "High Knees": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, aliases=["Running in place"], prime=["hipFlexors"], major=["quads", "calves"], minor=["abs"]),
    "Incline Plank with Alternating Floor Touch": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"]),
    "Basic Jump Rope": ex("core", "other", "isolation", None, weight=0, reps=1, tracking="duration", duration=60, prime=["calves"], minor=["quads", "abs", "forearms"]),
    "Foot-Supported L-Sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Landmine Rotation": ex("core", "barbell", "isolation", None, weight=25, reps=12, plane="transverse", prime=["obliques"], major=["abs"], minor=["deltoids"], aliases=["Landmine Rotations"]),
    "Single-Arm Push-Up": ex("core", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=6, bw=0.7, lat="unilateral", prime=["pectorals", "triceps"], major=["abs", "obliques"], minor=["deltoids"]),
    "Plank Reach": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"], aliases=["Plank with Arm Reach"]),
    "Plank-to-Elbow Extension": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, prime=["abs"], major=["obliques"], minor=["deltoids", "triceps"]),
    "Seated Corkscrew": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["hipFlexors"]),
    "Machine Side Bend": ex("core", "machine", "isolation", None, weight=70, reps=15, plane="frontal", prime=["obliques"], minor=["abs"]),
    "Sit-Up with Elbow Thrust": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Sled Push": ex("core", "other", "compound", "squat", weight=90, reps=1, tracking="duration", duration=30, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings", "deltoids"]),
    "Splinter Sit-Up": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Step Jack": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, plane="frontal", aliases=["Side Step Jack", "Low Impact Jumping Jack"], prime=["quads"], major=["gluteMax"], minor=["abs", "deltoids", "calves"]),
    "Straddle L-Sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Torso Twist": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["obliques"], major=["abs"]),
    "TRX Oblique Knee Tuck": ex("core", "other", "isolation", None, weight=0, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["serratus", "deltoids"]),
    "Tuck L-Sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["triceps"]),
    "Dumbbell Turkish Get-Up": ex("core", "dumbbell", "compound", "core", weight=35, reps=5, lat="unilateral", prime=["deltoids"], major=["gluteMax", "obliques"], minor=["abs", "quads", "triceps"]),
    "Box Jump": ex("core", "bodyweight", "compound", "squat", weight=0, reps=10, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings"]),

    # ===================== Batch 5: residual real lifts (parallel droids, round 3) =====================
    # (Stretches, cardio, non-English duplicates, and junk deliberately left as fallbacks.)

    "Inverted Row": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=10, bw=0.6, aliases=["Bodyweight Row", "Australian Pullup", "Supine Row"], prime=("lats",), major=("rhomboids", "traps", "biceps"), minor=("deltoids", "forearms"), trace=("abs",)),

    "Back Bridge": ex("legs", "bodyweight", "compound", "hinge", reps=1, bw=0.5, tracking="duration", duration=30, prime=("gluteMax",), major=("lowerBack", "hamstrings"), minor=("quads",), trace=("deltoids",)),
    "Cable Front Woodchop": ex("core", "cable", "compound", "core", weight=30, reps=14, plane="transverse", lat="unilateral", prime=("obliques",), major=("abs",), minor=("deltoids", "lats"), trace=("serratus",)),
    "Bent-Over Dumbbell Lat Pull": ex("back", "dumbbell", "compound", "pull", direction="vertical", weight=45, reps=12, prime=("lats",), major=("teresMajor",), minor=("pectorals", "triceps"), trace=("serratus",), aliases=["Dumbbell Lat Pullover"]),
    "Reverse Cable Woodchop": ex("core", "cable", "compound", "core", weight=30, reps=14, plane="transverse", lat="unilateral", prime=("obliques",), major=("abs",), minor=("deltoids", "gluteMax"), trace=("lats",)),
    "Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=("deltoids",), trace=("traps", "serratus")),
    "Machine Upper-Back Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=70, reps=12, plane="transverse", prime=("rhomboids",), major=("traps", "teresMajor"), minor=("deltoids", "lats"), trace=("biceps",)),

    "Dumbbell Kreis Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=10, aliases=["Circle Press"], prime=("deltoids",), major=("triceps",), minor=("traps",), trace=("serratus",)),
    "Codman Pendulum": ex("shoulders", "other", "isolation", None, reps=15,
                           lat="unilateral", aliases=["Codman Exercise", "Shoulder Pendulum"],
                           trace=("deltoids", "externalRotators")),
    "Tuck Planche": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=1, bw=0.7, tracking="duration", duration=15, aliases=["Tuck Planche Hold"], prime=("deltoids",), major=("abs", "serratus"), minor=("pectorals", "triceps"), trace=("forearms", "lowerBack")),

    "Shoulder-Elevated Dumbbell Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"], aliases=["Shoulder-Elevated Curl", "Shoulder Flexed Curl"]),
    "Single-Arm Dumbbell Glute Bridge Press": ex("core", "dumbbell", "compound", "push", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["pectorals", "triceps"], major=["gluteMax"], minor=["deltoids", "abs"], aliases=["Glute Bridge Floor Press", "Single-Arm Bridge Press"]),

    "Hack Squat Machine Calf Raise": ex("legs", "machine", "isolation", None, weight=150, reps=15,
                                                prime=("calves",), aliases=["Calf Raise using Hack Squat Machine"]),
    "Dragon Squat": ex("legs", "bodyweight", "compound", "squat", reps=8, lat="unilateral", bw=0.6, prime=("quads", "gluteMax"), major=("hamstrings", "adductors"), minor=("calves",), trace=("abs",)),
    "Hamstring Kick": ex("legs", "bodyweight", "isolation", None, reps=15, lat="unilateral", prime=("hamstrings",), minor=("gluteMax", "calves")),
    "Hip Hinge": ex("legs", "bodyweight", "compound", "hinge", reps=15, bw=0.5, prime=("hamstrings", "gluteMax"), major=("lowerBack",), trace=("abs",)),
    "Horse Stance Side Split": ex("legs", "bodyweight", "compound", "squat", reps=1, tracking="duration", duration=30, bw=0.6, prime=("quads", "adductors"), major=("gluteMax",), minor=("calves",), trace=("abs",)),
    "Jumping Jack": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, plane="frontal", prime=("calves",), major=("deltoids", "gluteMax"), minor=("quads",), trace=("abs",)),
    "Lateral Push-Off": ex("legs", "bodyweight", "compound", "lunge", reps=12, plane="frontal", lat="unilateral", bw=0.5, prime=("quads", "gluteMax"), major=("adductors", "calves"), minor=("hamstrings",), trace=("abs",)),
    "Machine Leg Curl": ex("legs", "machine", "isolation", None, weight=70, reps=12, prime=("hamstrings",), minor=("calves",)),
    "Leg Raise": ex("core", "bodyweight", "compound", "core", reps=15, bw=0.3, prime=("abs",), major=("hipFlexors",), minor=("obliques",)),
    "Marching High Knees": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, prime=("hipFlexors",), major=("quads", "calves"), minor=("gluteMax", "abs")),
    "Plank with Alternating Leg Lift": ex("core", "bodyweight", "compound", "core", reps=12, lat="unilateral", bw=0.6, prime=("abs",), major=("gluteMax",), minor=("obliques", "lowerBack"), trace=("deltoids", "hipFlexors")),
    "Bodyweight Lateral Step to Squat": ex("legs", "bodyweight", "compound", "squat", reps=12, plane="frontal", bw=0.5, prime=("quads", "gluteMax"), major=("adductors", "hamstrings"), minor=("calves",), trace=("abs",)),
    "Slow Squat": ex("legs", "bodyweight", "compound", "squat", reps=12, bw=0.6, prime=("quads", "gluteMax"), major=("hamstrings",), minor=("adductors", "calves"), trace=("abs",)),
    "Squat Thrust": ex("legs", "bodyweight", "compound", "squat", reps=15, bw=0.5, prime=("quads", "gluteMax"), major=("hipFlexors", "abs"), minor=("hamstrings", "deltoids", "calves")),
    "Dumbbell Step-Up": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=12, lat="unilateral", prime=("quads", "gluteMax"), major=("hamstrings",), minor=("calves", "adductors"), trace=("abs",)),

    "Barbell Box Squat": ex("legs", "barbell", "compound", "squat", weight=135, reps=6, prime=("quads", "gluteMax"), major=("hamstrings",), minor=("adductors", "lowerBack"), trace=("abs", "calves"), aliases=["Box Squat"]),
    "High-Knee Skip": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, prime=("hipFlexors", "calves"), major=("quads",), minor=("gluteMax", "hamstrings"), trace=("abs",), aliases=["High Knee Skips"]),
    "Commando Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", reps=8, bw=1.0, prime=("lats",), major=("biceps", "rhomboids"), minor=("traps", "teresMajor", "forearms"), trace=("abs",), aliases=["Commando Pull-Up", "Alternating Grip Pull-Up"]),
    "TRX Row": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=12, bw=0.6, prime=("lats", "rhomboids"), major=("biceps", "traps"), minor=("teresMajor", "deltoids"), trace=("forearms", "abs"), aliases=["TRX Inverted Row"]),
    "Isometric Inverted Row Hold": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=1, bw=0.6, tracking="duration", duration=30, prime=("lats", "rhomboids"), major=("biceps", "traps"), minor=("teresMajor", "deltoids"), trace=("forearms", "abs"), aliases=["Isometric Row Hold"]),
    "Suspension Chest Fly": ex("chest", "bodyweight", "isolation", None, reps=12, bw=0.5, prime=("pectorals",), minor=("deltoids",), trace=("biceps", "serratus", "abs"), aliases=["TRX Chest Fly", "Suspended Crossover"]),
    "TRX Biceps Curl": ex("arms", "bodyweight", "isolation", None, reps=12, bw=0.5, prime=("biceps",), minor=("forearms",), trace=("deltoids",), aliases=["TRX Biceps Curl"]),
    "Overhand-Grip Cable Biceps Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=("biceps", "forearms"), trace=("deltoids",), aliases=["Cable Reverse Curl"]),
    "Medicine Ball V-Up": ex("core", "other", "compound", "core", weight=10, reps=12, prime=("abs", "hipFlexors"), minor=("obliques",), trace=("quads",), aliases=["Weighted V-Up", "Jackknife Crunch"]),

    # ===================== Batch 6: genuine grip / forearm isometric holds =====================
    "Dead Hang": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=30, prime=("forearms",), major=("lats",), minor=("teresMajor",), trace=("biceps", "deltoids"), aliases=["Dead Hang", "Bar Hang"]),
    "Hand Gripper Squeeze": ex("arms", "other", "isolation", None, reps=15, prime=("forearms",), aliases=["Gripper", "Hand Gripper", "Grip Trainer"]),
    "Plate Pinch Hold": ex("arms", "other", "isolation", None, weight=25, reps=1, tracking="duration", duration=30, prime=("forearms",), aliases=["Pinch Grip Hold", "Plate Pinch"]),
    "20 mm Fingerboard Hang": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=10, prime=("forearms",), minor=("lats", "biceps", "teresMajor"), aliases=["Hangboard 20mm Edge", "Fingerboard Hang"]),
    "Fingerboard Sloper Hang": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=15, prime=("forearms",), minor=("lats", "biceps"), aliases=["Sloper Hang", "Hangboard Sloper"]),
    "Fingerboard Pull-Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", reps=5, bw=1.0, prime=("lats",), major=("biceps", "forearms"), minor=("teresMajor", "rhomboids"), trace=("traps",), aliases=["Hangboard Pull-up", "Fingerboard Pull-up"]),

    # ===================== Batch 8: activation =====================
    # App-authored activation drills. Activation work loads and primes
    # the muscle, so it credits its muscles by set count like any other
    # strength move. Iso holds use duration tracking. Each drill is
    # filed under the muscle group it primarily trains.
    "Banded Clamshell": ex("legs", "band", "isolation", None, reps=15, plane="frontal", lat="unilateral", prime=["gluteMax"], minor=["adductors"], aliases=["Banded Clamshell"]),
    "Broomstick Hip Hinge": ex("legs", "bodyweight", "compound", "hinge", reps=10, bw=0.3, prime=["hamstrings", "gluteMax"], minor=["lowerBack"], trace=["abs"]),
    "Single-Leg Clock Reach": ex("legs", "bodyweight", "compound", None, reps=8, lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Banded 1.5 Squat": ex("legs", "band", "compound", "squat", reps=10, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs", "lowerBack"]),
    "Prone Banded Press": ex("shoulders", "band", "isolation", None, reps=15, prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"]),
    "Quadruped Hip Extension": ex("legs", "bodyweight", "isolation", None, reps=15, lat="unilateral", bw=0.3, prime=["gluteMax"], minor=["hamstrings", "lowerBack"]),
    "Fire Hydrant": ex("legs", "bodyweight", "isolation", None, plane="frontal", reps=15, lat="unilateral", bw=0.2, prime=["gluteMax"], minor=["adductors"]),
    "Prisoner Squat with Overhead Reach": ex("legs", "bodyweight", "compound", "squat", reps=12, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["deltoids", "adductors"], trace=["abs", "calves"]),
    "Banded Lateral Walk": ex("legs", "band", "isolation", None, plane="frontal", reps=15, prime=["gluteMax"], minor=["adductors", "quads"], aliases=["Lateral Walk", "Banded Lateral Walk", "Monster Walk"]),
    "Banded External Rotation": ex("shoulders", "band", "isolation", None, plane="transverse", reps=15, prime=["teresMajor"], minor=["deltoids"], trace=["rhomboids"]),
    "Standing Plate Rotation": ex("core", "other", "compound", "core", weight=10, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["lowerBack"], trace=["deltoids"]),

    # ===================== Batch 9: gym plyometrics =====================
    # Explosive jump and landing work. The muscle model is load-
    # and velocity-agnostic, so these credit their muscles by set count
    # exactly like any bodyweight strength move. CMJ = counter-movement jump.
    "Ice Skater": ex("legs", "bodyweight", "compound", "lunge", reps=20, plane="frontal", lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["hamstrings"], trace=["abs"], aliases=["Skater Hops", "Speed Skaters"]),
    "Altitude Landing": ex("legs", "bodyweight", "compound", "squat", reps=10, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Drop Landing", "Depth Drop"]),
    "Altitude Landing to Jump": ex("legs", "bodyweight", "compound", "squat", reps=10, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Depth Jump", "Drop Jump"]),
    "Hop and Hold": ex("legs", "bodyweight", "compound", "squat", reps=10, lat="unilateral", bw=0.5, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings", "adductors"], trace=["abs"], aliases=["Stick the Landing", "Jump and Stick"]),
    "Pogo Jump": ex("legs", "bodyweight", "compound", "squat", reps=20, bw=0.4, prime=["calves"], major=["quads"], minor=["gluteMax", "hamstrings"], trace=["shins", "abs"], aliases=["Pogo Hops", "Ankle Hops"]),
    "2 kg Dumbbell Countermovement Jump": ex("legs", "dumbbell", "compound", "squat", weight=5, reps=8, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["deltoids"], trace=["abs"], aliases=["Dumbbell Countermovement Jump", "Loaded CMJ", "Dumbbell CMJ"]),
    "Falling Countermovement Jump": ex("legs", "bodyweight", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Falling Countermovement Jump"]),
    "Banded Accentuated Countermovement Jump": ex("legs", "band", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Banded Countermovement Jump"]),
    "Hands-on-Hips Countermovement Jump": ex("legs", "bodyweight", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Countermovement Jump", "Vertical Jump"]),
    "Ice Skater to Vertical Hop": ex("legs", "bodyweight", "compound", "lunge", reps=16, plane="frontal", lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["hamstrings"], trace=["abs"]),
    "Medicine Ball Ice Skater": ex("legs", "other", "compound", "lunge", weight=10, reps=16, plane="frontal", lat="unilateral", prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["deltoids", "hamstrings"], trace=["abs"]),
    "Criss-Cross Jump": ex("legs", "bodyweight", "compound", "squat", reps=20, plane="frontal", bw=0.4, prime=["calves", "quads"], major=["adductors", "gluteMax"], minor=["hamstrings"], trace=["abs"], aliases=["Crossover Jacks", "Cross Jacks"]),

    # ===================== Batch 10: key strength exercises =====================
    # Loaded primary lifts and their implement / stance variants
    # (goblet, landmine, half-kneeling, banded). Landmine work uses the
    # barbell equipment (the bar in a pivot), matching the existing
    # landmine entries. Throws and explosive derivatives are classified as
    # power below; static wall holds are classified as isometric strength.
    # — Lower body —
    "Dumbbell Goblet Squat to Press": ex("legs", "dumbbell", "compound", "squat", weight=40, reps=10, prime=["quads", "gluteMax"], major=["deltoids", "hamstrings"], minor=["triceps", "abs"], trace=["calves", "adductors"], aliases=["Goblet Thruster"]),
    "Dumbbell Goblet Split Squat": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Dumbbell Goblet Reverse Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Dumbbell Goblet Reverse Lunge with Knee Raise": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings", "hipFlexors"], minor=["adductors", "calves"], trace=["abs"]),
    "Landmine Squat": ex("legs", "barbell", "compound", "squat", weight=70, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "lowerBack"], trace=["abs", "calves"]),
    "Landmine Reverse Lunge with Knee Raise": ex("legs", "barbell", "compound", "lunge", weight=50, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings", "hipFlexors"], minor=["adductors"], trace=["abs", "deltoids"]),
    "Single-Leg Landmine Romanian Deadlift": ex("legs", "barbell", "compound", "hinge", weight=50, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["adductors", "forearms"], trace=["abs"]),
    "Trap Bar Deadlift": ex("legs", "barbell", "compound", "hinge", weight=225, reps=6, weight_kg=100, prime=["gluteMax", "quads"], major=["hamstrings", "lowerBack"], minor=["traps", "forearms"], trace=["abs"], aliases=["Hex Bar Deadlift"]),
    "Banded Single-Leg Hip Thrust": ex("legs", "band", "compound", "hinge", reps=12, lat="unilateral", bw=0.4, prime=["gluteMax"], major=["hamstrings"], minor=["abs"], trace=["quads"]),
    # — Upper body push —
    "Half-Kneeling Dumbbell Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10, lat="unilateral", prime=["deltoids"], major=["triceps"], minor=["traps", "abs"], trace=["obliques"], aliases=["Half-Kneeling Dumbbell Press", "Half Kneeling DB Press"]),
    "Half-Kneeling Landmine Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=45, reps=10, lat="unilateral", prime=["deltoids"], major=["triceps", "pectorals"], minor=["serratus", "abs"], trace=["obliques"], aliases=["Half-Kneeling Landmine Press"]),
    "Banded Kettlebell Push-Up": ex("chest", "band", "compound", "push", direction="horizontal", reps=10, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"], trace=["serratus", "abs"], aliases=["Banded Push-Up", "Band-Resisted Push-Up"]),
    "Standing Rotational Landmine Press": ex("shoulders", "barbell", "compound", "push", direction="horizontal", weight=45, reps=10, lat="unilateral", plane="transverse", prime=["deltoids"], major=["pectorals", "serratus"], minor=["triceps", "obliques"], trace=["abs"], aliases=["Rotational Landmine Press"]),
    "3-Second Isometric Wall Press": ex("chest", "bodyweight", "compound", "push", direction="horizontal", reps=1, tracking="duration", duration=30, prime=["pectorals"], major=["deltoids", "triceps"], minor=["serratus"], trace=["abs"], aliases=["Isometric Wall Press"]),
    # — Upper body pull —
    "Kettlebell Row to Rotation": ex("back", "kettlebell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", plane="transverse", prime=["lats"], major=["rhomboids", "biceps"], minor=["obliques", "traps"], trace=["teresMajor", "forearms"], aliases=["KB Row and Rotate", "Row to Rotation"]),
    "Dumbbell Plank Drag": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["lats"], major=["rhomboids", "biceps"], minor=["abs", "traps"], trace=["teresMajor", "forearms"], aliases=["Drag Row", "Kettlebell Drag", "Dumbbell Drag"]),
    "Lateral Plank Walk": ex("core", "bodyweight", "compound", "core", reps=12, bw=0.6, prime=["abs"], major=["deltoids", "obliques"], minor=["pectorals", "serratus"], trace=["triceps"], aliases=["Lateral Plank Walkout", "Plank Walk", "Lateral Plank Walks"]),
    # — Rotational / anti-rotation —
    "Banded Pallof Wall Isometric Hold": ex("core", "band", "compound", "core", reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax"], aliases=["Pallof Iso Hold", "Wall Pallof Hold", "Pallof Max Effort Iso Holds", "Pallof Max Effort Iso Holds (3-Secs)", "Palloff Iso Holds (20s E.S.)"]),
    "Banded Kneeling Pallof Isometric Hold": ex("core", "band", "compound", "core", reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax", "hipFlexors"], aliases=["Kneeling Pallof Hold"]),
    "Banded Rotation": ex("core", "band", "compound", "core", reps=15, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["lowerBack"], aliases=["Banded Trunk Rotation", "Band Woodchop"]),
    "Supine Medicine Ball Chest Pass": ex("chest", "other", "compound", "push", direction="horizontal", weight=8, reps=12, prime=["pectorals"], major=["triceps", "deltoids"], minor=["serratus"], trace=["abs"], aliases=["Lying Med Ball Chest Pass"]),
    "Split-Stance Medicine Ball Rotational Throw": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "pectorals"], trace=["triceps", "quads"], aliases=["Split Stance Med Ball Throw", "Rotational Med Ball Throw"]),

    # ===================== Batch 11: core exercises =====================
    # Anti-extension / anti-rotation trunk work and loaded core variants.
    # Weighted, tempo, and position variants are kept as their own entries
    # (per program design); throws become power and holds become isometric
    # strength in the audited classification pass below.
    "Weighted Leg Lower": ex("core", "dumbbell", "isolation", None, weight=10, reps=12, prime=["abs"], major=["hipFlexors"], minor=["quads"], trace=["obliques"], aliases=["Weighted Lying Leg Lowers"]),
    "2-Second Paused Leg Lower": ex("core", "bodyweight", "isolation", None, reps=10, bw=0.3, prime=["abs"], major=["hipFlexors"], minor=["quads"], trace=["obliques"], aliases=["Tempo Leg Lowers", "Paused Leg Lowers"]),
    "Elevated-Hands Plank Hold": ex("core", "bodyweight", "isolation", None, reps=1, tracking="duration", duration=45, bw=0.5, prime=["abs"], major=["obliques"], minor=["deltoids"], trace=["gluteMax"], aliases=["Incline Plank Hold", "Hands-Elevated Plank"]),
    "Weighted Hollow Hold": ex("core", "other", "isolation", None, weight=10, reps=1, tracking="duration", duration=30, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["quads"], aliases=["Weighted Hollow Hold", "Weighted Supine Core Hold"]),
    "Stability Ball Plank Circle": ex("core", "other", "isolation", None, reps=10, bw=0.5, plane="transverse", prime=["abs"], major=["obliques", "deltoids"], minor=["serratus"], trace=["gluteMax"], aliases=["Stability Ball Plank Circles", "Swiss Ball Stir-the-Pot"]),
    "Rotational Plank": ex("core", "bodyweight", "compound", "core", reps=12, bw=0.5, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax"], aliases=["Plank Rotation", "Thread the Needle Plank"]),
    "Straight-Arm Straight-Leg Sit-Up": ex("core", "bodyweight", "isolation", None, reps=12, bw=0.3, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["quads"], aliases=["Long-Arm Sit-Up", "Straight-Leg Sit-Up"]),
    "Straight-Leg Medicine Ball Sit-Up": ex("core", "other", "isolation", None, weight=8, reps=12, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["deltoids"], aliases=["Med Ball Straight-Leg Sit-Up"]),
    "TRX Rollout": ex("core", "other", "isolation", None, reps=10, bw=0.5, prime=["abs"], major=["obliques", "lats"], minor=["deltoids", "serratus"], trace=["lowerBack"], aliases=["TRX Rollout", "Suspension Rollout", "TRX Ab Rollout"]),
    "Banded Pallof Split Jerk": ex("core", "band", "compound", "core", reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "quads"], trace=["triceps"], aliases=["Pallof Split Jerk", "Banded Pallof Jerk"]),
    "Half-Kneeling Medicine Ball Rotational Throw": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "pectorals"], trace=["triceps"], aliases=["Half-Kneeling Rotational Med Ball Throw"]),
    "Kneeling Medicine Ball Rotational Throw": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["pectorals"], trace=["triceps", "gluteMax"], aliases=["Kneeling Rotational Med Ball Throw"]),
    "Single-Arm Medicine Ball Hold": ex("core", "other", "isolation", None, weight=8, reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["forearms"], aliases=["Single Arm Med Ball Hold", "Offset Med Ball Hold"]),
}


# Semantically identical records split history, PRs, prefills, and search even
# when their labels differ. These pre-production merges keep the more precise
# identity, carry every useful old label forward as an alias, and retire the
# redundant ID. There is intentionally no migration table: the app has not
# shipped and therefore has no user data to remap.
DUPLICATE_MERGES = {
    "Low-Pulley Cable Chest Fly": "Low-to-High Cable Chest Fly",
    "Low-to-High Cable Crossover": "Low-to-High Cable Chest Fly",
    "Behind-the-Body Cable Lateral Raise": "Behind-the-Back Cable Lateral Raise",
    "Cable Lateral Raise": "Single-Arm Cable Lateral Raise",
    "High Cable Lateral Raise": "Single-Arm Cable Lateral Raise",
    "Cable Reverse Fly": "Cable Rear Delt Fly",
    "Standing Dumbbell Biceps Curl": "Dumbbell Biceps Curl",
    "Cable Biceps Curl": "Straight-Bar Cable Biceps Curl",
    "Underhand-Grip Dumbbell Wrist Curl": "Dumbbell Wrist Curl",
    "Barbell Full Squat": "Barbell Back Squat",
    "Machine Leg Curl": "Lying Machine Leg Curl",
    "Cable Chest Fly": "Mid-Height Cable Chest Fly",
    "Incline Multipress Bench Press": "Incline Smith Machine Press",
    "45-Degree Dumbbell Lateral Raise": "Dumbbell Scaption",
    "Bent-Over Dumbbell Lateral Raise": "Seated Dumbbell Rear Delt Raise",
    "Incline Dumbbell Reverse Fly": "Chest-Supported Dumbbell Rear Delt Raise",
    "Heavy Single-Arm Dumbbell Row": "Single-Arm Dumbbell Row",
    "V-Bar Lat Pulldown": "Neutral-Grip Lat Pulldown",
    "Weighted Push-Up": "Push-Up",
    "Overhand Barbell Row": "Barbell Bent-Over Row",
    "Cross-Bench Dumbbell Pullover": "Dumbbell Pullover",
    "Cable Woodchop": "Cable Front Woodchop",
    "Leg Raise": "Lying Leg Raise",
    "Straight-Arm Cable Pulldown": "Straight-Arm Cable Pulldown with Bar",
    "Cable Triceps Pushdown": "Straight-Bar Cable Triceps Pushdown",
    "Legend Machine Chest Press": "Leverage Machine Chest Press",
}

# Canonical labels say what is being held, which implement is used, and which
# stance/path distinguishes a variation. The old labels remain searchable.
CANONICAL_RENAMES = {
    "Dumbbell Biceps Curl": "Standing Dumbbell Biceps Curl",
    "Straight-Arm Cable Pulldown with Bar": "Straight-Bar Cable Pulldown",
    "Straight-Arm Cable Pulldown with Rope": "Rope Straight-Arm Cable Pulldown",
    "Incline Smith Machine Press": "Moderate-Incline Smith Machine Press",
    "Machine Chest Press": "Selectorized Machine Chest Press",
    "Leverage Machine Chest Press": "Plate-Loaded Leverage Chest Press",
    "Legend Machine Incline Chest Press": "Plate-Loaded Incline Machine Chest Press",
    "Hammer Strength Decline Chest Press": "Plate-Loaded Decline Machine Chest Press",
    "3-Second Isometric Wall Press": "Isometric Wall Press",
    "2 kg Dumbbell Countermovement Jump": "Dumbbell Countermovement Jump",
    "Double-Leg Abdominal Press": "Double-Leg Abdominal Press Hold",
    "Braced Squat": "Plate-Held Braced Squat",
    "Incline Plank with Alternating Floor Touch": "Stability Ball Plank with Alternating Foot Touch",
    "Horse Stance Side Split": "Horse Stance Hold",
    "Cable Shoulder Y-Pull": "Cross-Cable Upright Row",
    "Knee Raise": "Hanging Knee Raise",
    "Single-Leg Machine Side Glute Press": "Side-Seated Single-Leg Machine Leg Press",
    "Dumbbell Push-Up": "Push-Up on Dumbbells",
    "Barbell Triceps Extension": "Overhead Barbell Triceps Extension",
    "Dumbbell Kreis Press": "Dumbbell Circle Press",
    "Lying Hip Raise": "Bodyweight Glute Bridge Hold",
    "Kneeling Superman Hold": "Bird Dog Hold",
    "Front Lever Tuck": "Tuck Front Lever",
    "Side Straight-Arm Cable Pulldown": "Single-Arm Straight-Arm Cable Pulldown",
    "Cable Shoulder Internal Rotation": "Cable Internal Rotation",
    "Rotary Torso Machine": "Machine Torso Rotation",
    "Hamstring Kick": "Dynamic Straight-Leg Kick",
    "Standing Barbell Lunge": "Barbell Forward Lunge",
    "Standing Dumbbell Lunge": "Dumbbell Forward Lunge",
    "Single-Leg Kettlebell Lunge": "Kettlebell Forward Lunge",
    "Slow Squat": "3-1-1 Bodyweight Tempo Squat",
    "Hyperextension": "Bodyweight Back Extension",
    "20 mm Fingerboard Hang": "20 mm Edge Fingerboard Hang",
    "Banded Kettlebell Push-Up": "Band-Resisted Push-Up on Kettlebells",
    "Externally Rotated Single-Arm Dumbbell Preacher Curl": "Torso-Away Single-Arm Dumbbell Preacher Curl",
    "Internally Rotated Single-Arm Dumbbell Preacher Curl": "Torso-Toward Single-Arm Dumbbell Preacher Curl",
    "Single-Arm Cable Triceps Extension with Internal Rotation": "Cross-Body Single-Arm Cable Triceps Extension",
    "Bent-Over Dumbbell Lat Pull": "Bent-Over Dumbbell Straight-Arm Pullback",
    "Dumbbell Overhead Triceps Extension": "Standing Dumbbell Overhead Triceps Extension",
    "Cable Front Woodchop": "High-to-Low Cable Woodchop",
}


def append_unique_aliases(body, aliases):
    """Append aliases without creating duplicate search vocabulary."""
    existing = {
        " ".join(alias.split()).casefold()
        for alias in body.setdefault("aliases", [])
    }
    for alias in aliases:
        key = " ".join(alias.split()).casefold()
        if key not in existing:
            body["aliases"].append(alias)
            existing.add(key)


for retired_name, survivor_name in DUPLICATE_MERGES.items():
    if retired_name not in CURATION or survivor_name not in CURATION:
        raise RuntimeError(
            f"Invalid duplicate merge: '{retired_name}' -> '{survivor_name}'"
        )
    retired = CURATION.pop(retired_name)
    append_unique_aliases(
        CURATION[survivor_name],
        (retired_name, *retired.get("aliases", [])),
    )

for old_name, new_name in CANONICAL_RENAMES.items():
    if old_name not in CURATION or new_name in CURATION:
        raise RuntimeError(f"Invalid canonical rename: '{old_name}' -> '{new_name}'")
    body = CURATION.pop(old_name)
    append_unique_aliases(body, (old_name,))
    CURATION[new_name] = body

# Objective metadata fixes identified during the semantic audit. Definitions
# in the authored CSV describe the same corrected contract.
CURATION["Incline Dumbbell Skull Crusher"].update(
    equipment="dumbbell",
    defaultWeight=25,
    defaultWeightKg=kg_seed(25),
)
CURATION["Double-Leg Abdominal Press Hold"].update(
    reps=1,
    trackingMode="duration",
    defaultDuration=10,
)
CURATION["Plate-Held Braced Squat"].update(
    equipment="other",
    defaultWeight=25,
    defaultWeightKg=kg_seed(25),
    bodyweightFraction=0.0,
)
CURATION["Standing Wrist Roller"]["equipment"] = "other"
CURATION["Stability Ball Plank with Alternating Foot Touch"]["equipment"] = "other"
CURATION["Bent-Over Dumbbell Straight-Arm Pullback"].update(mechanic="isolation")
CURATION["Bent-Over Dumbbell Straight-Arm Pullback"].pop("pattern", None)
CURATION["Bent-Over Dumbbell Straight-Arm Pullback"].pop("direction", None)
CURATION["Alternating Battle Rope Wave"].update(
    mechanic="compound",
    pattern="core",
    laterality="unilateral",
)

# Remove aliases that promise a different implement or stance than the record.
ALIASES_TO_REMOVE = {
    "Russian Twist": {"Russian Twists with Med Ball"},
    "Dumbbell Plank Drag": {"Kettlebell Drag"},
    "Medicine Ball Slam": {"Kneeling Med Ball Slams"},
    "Half-Kneeling Single-Arm Cable High Row": {"Machine High Row"},
    "Bent-Over Dumbbell Straight-Arm Pullback": {"Dumbbell Lat Pullover"},
}
for name, aliases in ALIASES_TO_REMOVE.items():
    CURATION[name]["aliases"] = [
        alias for alias in CURATION[name].get("aliases", []) if alias not in aliases
    ]


# Objective corrections from the biomechanics audit. Keeping these separate
# from the seed calls makes the audited contract easy to scan and test.
TRANSVERSE_PLANE = {
    "Bent-Over Cable Fly",
    "High-to-Low Cable Chest Fly", "Mid-Height Cable Chest Fly", "Low-to-High Cable Chest Fly",
    "Dumbbell Chest Fly", "Decline Dumbbell Chest Fly",
    "Incline Dumbbell Chest Fly", "Machine Chest Fly",
    "Seated Cable Chest Fly", "Bent-Over Dumbbell Face Pull",
    "Band Face Pull", "Cable Face Pull",
    "Russian Twist", "Push-Up Rotation",
    "Omni Cable Crossover", "Suspension Chest Fly", "Supine Dumbbell Serratus Punch",
    "Incline Scapular Push-Up", "Plate Bus Driver",
    "Prone Scapular Retraction with Arms at Sides",
}

FRONTAL_PLANE = {
    "Cross-Cable Upright Row", "Dumbbell Lateral Raise", "Dumbbell Upright Row", "EZ-Bar Upright Row",
    "Smith Machine Upright Row", "Machine Hip Abduction",
    "Machine Hip Adduction", "Side Plank", "Lateral Plank Walk", "Plank Jack",
    "Reverse Snow Angel",
}

SAGITTAL_PLANE = {
    "Cable Front Raise", "Dumbbell Front Raise",
    "Straight-Bar Cable Front Raise", "Plank Reach",
}

GROUP_OVERRIDES = {
    "Back Bridge": "back",
    "Barbell Silverback Shrug": "back",
    "Cable Shrug-In": "back",
    "Chair Dip": "arms",
    "Close-Grip Barbell Bench Press": "arms",
    "Close-Grip Push-Up": "arms",
    "Diamond Push-Up": "arms",
    "Double-Kettlebell Clean and Press": "shoulders",
    "Bent-Over Dumbbell Face Pull": "shoulders",
    "Dumbbell Farmer's Carry": "arms",
    "Dumbbell Hang Power Clean": "legs",
    "Dumbbell Shrug": "back",
    "Underhand Dumbbell Dead Row": "back",
    "Elbows-Tucked Dumbbell Bench Press": "chest",
    "Band Face Pull": "shoulders",
    "Fingertip Push-Up": "chest",
    "Front Lever Pull-Up": "back",
    "Single-Arm Dumbbell Glute Bridge Press": "chest",
    "High Plank": "core",
    "Bodyweight Glute Bridge Hold": "legs",
    "Kettlebell Deadlift": "legs",
    "L-Sit Pull-Up": "back",
    "No-Push-Up Burpee": "legs",
    "Single-Arm Push-Up": "chest",
    "Pike Push-Up": "shoulders",
    "Barbell Power Clean": "legs",
    "Push-Up Rotation": "chest",
    "Reverse Plank": "back",
    "Ring Support Hold": "arms",
    "Seated Dumbbell Rear Delt Raise": "shoulders",
    "Shoulder-Width Three-Point Push-Up": "chest",
    "Barbell Shrug": "back",
    "Smith Machine Shrug": "back",
    "Sled Push": "legs",
    "Barbell Snatch": "legs",
    "Supine Dumbbell Serratus Punch": "chest",
    "Dumbbell Turkish Get-Up": "shoulders",
    "Wall Push-Up": "chest",
    "Burpee": "legs",
    "Barbell Romanian Deadlift": "legs",
    "Box Jump": "legs",
    "High-Knee Jump": "legs",
    "High Knees": "legs",
    "Basic Jump Rope": "legs",
    "Knee Push-Up": "chest",
    "Step Jack": "legs",
}

UNILATERAL_EXERCISES = {
    "Alternating High Cable Row",
    "Behind-the-Back Cable Lateral Raise",
    "Single-Arm Decline Cable Chest Press",
    "Single-Arm Incline Cable Chest Press",
    "Cross-Body Single-Arm Cable Triceps Extension",
    "Single-Arm Cable Triceps Press",
    "Cable External Rotation",
    "Bird Dog",
    "Black Widow Knee Slide",
    "Dead Bug",
    "Half-Kneeling Single-Arm Cable High Row",
    "Stability Ball Plank with Alternating Foot Touch",
    "Plank Reach",
    "Plank Shoulder Tap",
    "Torso-Away Single-Arm Dumbbell Preacher Curl",
    "Torso-Toward Single-Arm Dumbbell Preacher Curl",
    "Side Crunch",
    "Side Plank",
    "Standing Side Crunch",
    "Supine Hip Abduction",
    "TRX Oblique Knee Tuck",
    "Bicycle Crunch",
    "Mountain Climber",
}

LOCOMOTION_EXERCISES = {
    "Basic Jump Rope", "High-Knee Skip", "High Knees",
    "Jumping Jack", "Marching High Knees", "Step Jack",
}

CONDITIONING_EXERCISES = LOCOMOTION_EXERCISES | {
    "Alternating Battle Rope Wave", "Burpee",
    "Dumbbell Devil's Press", "Mountain Climber", "No-Push-Up Burpee",
    "Plank In-and-Out Jump", "Plank Jack", "Sled Push", "Squat Thrust",
}

MOBILITY_EXERCISES = {"Codman Pendulum", "Dynamic Straight-Leg Kick"}

# Explosive efforts are intentionally distinct from both strength-repetition
# work and cyclical conditioning. Loaded Olympic derivatives with external
# resistance retain their raw implement load and may earn direct load/reps
# records and tonnage, but power never earns hard-set credit or estimated 1RM.
# Jumps and throws remain non-comparable below because height, velocity,
# distance, and implement characteristics are missing from the log.
POWER_EXERCISES = {
    "Altitude Landing", "Altitude Landing to Jump",
    "Medicine Ball Slam",
    "Banded Accentuated Countermovement Jump", "Banded Pallof Split Jerk", "Box Jump",
    "Clap Push-Up", "Barbell Clean", "Barbell Clean and Jerk", "Barbell Clean and Press",
    "Hands-on-Hips Countermovement Jump", "Criss-Cross Jump",
    "Double-Kettlebell Clean and Press", "Dumbbell Countermovement Jump",
    "Dumbbell Hang Power Clean", "Falling Countermovement Jump", "High-Knee Jump", "Barbell High Pull", "Hop and Hold",
    "Ice Skater", "Ice Skater to Vertical Hop", "Medicine Ball Ice Skater",
    "Barbell Jerk", "Kettlebell Sumo High Pull", "Kettlebell Swing",
    "Kneeling Medicine Ball Rotational Throw", "Lateral Push-Off", "Pogo Jump",
    "Barbell Power Clean", "Barbell Push Press",
    "Barbell Snatch", "Split-Stance Medicine Ball Rotational Throw", "Squat Jump",
    "Supine Medicine Ball Chest Pass", "Wall Ball",
    "Half-Kneeling Medicine Ball Rotational Throw", "Dumbbell Snatch",
}

# Corrections where the seed roster's broad isolation/compound label obscured
# a coordinated multi-joint trunk or lower-body action.
MECHANIC_PATTERN_OVERRIDES = {
    "Ab Wheel Rollout": ("compound", "core"),
    "Medicine Ball Slam": ("compound", "core"),
    "Barbell Ab Rollout": ("compound", "core"),
    "Bear Crawl Pull-Through": ("compound", "core"),
    "Bird Dog Hold": ("compound", "core"),
    "Plank Jack": ("compound", "core"),
    "Side-Seated Single-Leg Machine Leg Press": ("compound", "squat"),
    "TRX Rollout": ("compound", "core"),
}

# These movements retain anatomy roles for body-model visualization, but their
# power or conditioning modalities never earn hypertrophy hard-set credit. The
# entered resistance is not a truthful one-dimensional performance axis: jump
# height, landing quality, throw velocity/distance, implement variation, and
# band tension all matter. Applying Epley or tonnage to that entered value would
# fabricate comparability. Band equipment is handled by the same rule below.
NONCOMPARABLE_BALLISTIC_EXERCISES = {
    "Altitude Landing", "Altitude Landing to Jump",
    "Medicine Ball Slam",
    "Banded Accentuated Countermovement Jump", "Clap Push-Up", "Hands-on-Hips Countermovement Jump",
    "Criss-Cross Jump", "Dumbbell Devil's Press", "Dumbbell Countermovement Jump",
    "Falling Countermovement Jump", "High-Knee Jump", "Hop and Hold", "Ice Skater",
    "Ice Skater to Vertical Hop", "Medicine Ball Ice Skater",
    "Kneeling Medicine Ball Rotational Throw", "Lateral Push-Off",
    "No-Push-Up Burpee", "Pogo Jump",
    "Split-Stance Medicine Ball Rotational Throw", "Squat Jump", "Squat Thrust",
    "Supine Medicine Ball Chest Pass", "Wall Ball",
    "Half-Kneeling Medicine Ball Rotational Throw",
}

NONCOMPARABLE_LOAD_EXERCISES = NONCOMPARABLE_BALLISTIC_EXERCISES | {
    "Sliding Lateral Lunge",
}

# Deleted duplicate spellings remain discoverable, but every search term has
# one canonical owner. Renamed pre-production records keep their former labels
# as aliases without retaining obsolete catalog identities.
CANONICAL_ALIAS_ADDITIONS = {
    "Standing Dumbbell Biceps Curl": ("DB Curl",),
    "Straight-Bar Cable Biceps Curl": ("Cable Curl",),
    "Standing Dumbbell Overhead Triceps Extension": ("Dumbbell Triceps Extension",),
    "Overhead Cable Triceps Extension": ("Overhead Cable Tricep Extension",),
    "Reverse-Grip Barbell Biceps Curl": ("Reverse Grip Barbell Curl",),
    "Smith Machine Squat": ("Multipress Squat", "Squats on Multipress"),
    "Smith Machine Shoulder Press": (
        "Multipress Shoulder Press", "Shoulder Press on Multi Press",
    ),
    "Underhand Barbell Row": ("Yates Row", "Reverse-Grip Row"),
    "Bird Dog": ("Quadruped Arm and Leg Raise",),
    "Dumbbell Crunch": ("Weighted Crunch",),
    "Inverted Row": ("Australian pull-ups",),
    "TRX Row": ("Rowing with TRX band", "TRX Row", "Suspension Row"),
    "Bodyweight Back Extension": ("Lower Back Extensions", "Lower Back Extension"),
    "Machine Pendulum Squat": ("Pendular hack", "Pendulum Hack Squat"),
    "Dumbbell Step-Up": ("Step-ups", "Step-up", "Box Step-up"),
    "Side-Lying Dumbbell External Rotation": ("Shoulder External Rotation with Dumbbell",),
    "Decline Push-Up": ("Push-Ups | Decline",),
    "Push-Up": ("Strict Press-Ups", "Strict Push-Up", "Strict Push-Ups"),
    "Wide-Grip Pull-Up": ("Wide Pull Up",),
    "Incline Chest-Supported Dumbbell Row": (
        "Incline Dumbbell Row", "Incline Chest-Supported Row", "Incline DB Row",
        "Helms Row", "Chest-Supported Helms Row",
    ),
    "Dumbbell Shrug": ("Shrugs, Dumbbells", "DB Shrug"),
    "Plate Front Raise": ("Front Raises with Plates",),
    "Prone Incline Dumbbell Triceps Kickback": ("Tricep Dumbbell Kickback",),
    "Leg Press Calf Raise": ("Leg Press Toe Press",),
    "Bodyweight Reverse Lunge": ("Alternate back lunges",),
    "Bodyweight Lunge": ("Bodyweight lunge HD", "Unilateral Lunges"),
    "Underhand Lat Pulldown": (
        "Inverted Lat Pull Down", "Biceps Close Grip Pull Down",
        "Reverse-Grip Lat Pulldown", "Supinated Lat Pulldown",
    ),
    "Seated V-Grip Cable Row": (
        "Long-Pulley, Narrow", "Rowing seated, narrow grip",
        "Narrow-Grip Cable Row", "Close-Grip Seated Cable Row", "Narrow-Grip Row",
    ),
    "Single-Arm Cable Triceps Pushdown": ("One Arm Triceps Extensions on Cable",),
    "Rope Cable Triceps Pushdown": ("Tricep Pushdown on Cable",),
    "Straight-Bar Cable Triceps Pushdown": ("Triceps Extensions on Cable",),
    "EZ-Bar Skull Crusher": ("Lying Triceps Extensions",),
    "Fire Hydrant": ("Quadruped Hip Abduction",),
    "Pogo Jump": ("Fast Pogos", "Fast Ankle Hops"),
    "Single-Arm Dumbbell Row": ("Single arm row",),
    "Barbell Push Press": ("Push OHP",),
    "Single-Arm Cable Lateral Raise": ("Lateral Rows on Cable, One Armed",),
    "Dumbbell Lateral Raise": ("Schoulder Raise (Dumbbell)",),
    "Dumbbell Frog Pump": ("Dumbbell Frog Press",),
    "Pendlay Row": ("Pendelay Rows",),
    "Side-Lying Dumbbell Internal Rotation": ("Side-laying interior rotation",),
    "Lying Machine Leg Curl": ("Leg Curls (laying)",),
    "Kettlebell Forward Lunge": ("Single-Leg Lunge with Kettlebell",),
    "Push-Up Wiper": ("Isometric Wipers",),
}

def role_involvement(*, primary=(), secondary=(), stabilizer=()):
    """Build an ordered, duplicate-free role mapping."""
    result = []
    seen = set()
    for role, muscles in (
        ("primary", primary),
        ("secondary", secondary),
        ("stabilizer", stabilizer),
    ):
        for muscle in muscles:
            if muscle in seen:
                raise ValueError(f"Duplicate muscle '{muscle}' in role mapping")
            seen.add(muscle)
            result.append({"muscle": muscle, "role": role})
    return result


def normalize_search_term(value):
    """Match the app's case-insensitive, whitespace-collapsing vocabulary."""
    return " ".join(value.split()).casefold()


LOWERCASE_CANONICAL_WORDS = {
    "a", "an", "and", "as", "at", "in", "of", "on", "the", "to", "with", "while",
    "kg", "mm",
}
FORBIDDEN_CANONICAL_ABBREVIATIONS = {
    "BB", "DB", "HD", "KB", "MB", "MP", "NB", "OHP", "OL", "SZ",
}


def canonical_name_errors(name):
    """Enforce the catalog's user-facing exercise naming contract."""
    errors = []
    if name != " ".join(name.split()):
        errors.append("has leading, trailing, or repeated whitespace")
    if " - " in name or "|" in name or "/" in name or "(" in name or ")" in name:
        errors.append("uses separator punctuation instead of natural wording")
    if "," in name:
        errors.append("uses comma inversion")
    if name.startswith("½"):
        errors.append("uses a fraction glyph instead of a spelled-out modifier")

    words = name.replace(",", "").split()
    for index, word in enumerate(words):
        segments = word.split("-")
        for segment_index, segment in enumerate(segments):
            if not segment:
                errors.append("has malformed hyphenation")
                continue
            if segment in FORBIDDEN_CANONICAL_ABBREVIATIONS:
                errors.append(f"uses unexplained abbreviation '{segment}'")
                continue
            if segment.casefold() in LOWERCASE_CANONICAL_WORDS:
                if index == 0 and segment_index == 0:
                    errors.append(f"starts with lowercase word '{segment}'")
                continue
            first = segment[0]
            if not (first.isupper() or first.isdigit()):
                errors.append(f"is not Title Case at '{segment}'")
    return errors


def movement_definition_errors(definition):
    """Reject malformed or accidentally machine-like instruction prose."""
    errors = []
    if len(definition) < 24:
        errors.append("movement definition is underspecified")
    if not definition or not definition[0].isupper():
        errors.append("movement definition must start with an uppercase letter")
    if not definition or definition[-1] not in ".!?":
        errors.append("movement definition must end with sentence punctuation")

    words = re.findall(r"[a-z0-9]+(?:['’-][a-z0-9]+)*", definition.casefold())
    repeated = next(
        (word for first, word in zip(words, words[1:]) if first == word),
        None,
    )
    if repeated:
        errors.append(f"movement definition repeats adjacent word '{repeated}'")
    return errors


INVOLVEMENT_OVERRIDES = {
    "Supine Dumbbell Serratus Punch": role_involvement(
        primary=("serratus",), stabilizer=("deltoids", "triceps")
    ),
    "Clamshell": role_involvement(
        primary=("gluteMed",), secondary=("gluteMax",), stabilizer=("abs",)
    ),
    "Side Plank Clamshell": role_involvement(
        primary=("obliques", "gluteMed"),
        secondary=("abs", "gluteMax", "deltoids", "serratus"),
        stabilizer=("lowerBack", "triceps"),
    ),
    "Plank In-and-Out Jump": role_involvement(
        primary=("abs",), secondary=("hipFlexors", "quads", "deltoids", "serratus", "gluteMax")
    ),
    "Kettlebell Suitcase March": role_involvement(
        primary=("obliques",), secondary=("abs", "lowerBack", "gluteMed"),
        stabilizer=("forearms", "deltoids")
    ),
    "Codman Pendulum": role_involvement(
        stabilizer=("deltoids", "externalRotators")
    ),
    "Side Plank": role_involvement(
        primary=("obliques",), secondary=("abs", "gluteMed"),
        stabilizer=("lowerBack", "deltoids", "serratus")
    ),
    "Reverse Plank": role_involvement(
        primary=("gluteMax", "lowerBack"),
        secondary=("hamstrings", "triceps", "deltoids"),
        stabilizer=("abs", "obliques", "serratus")
    ),
    "Bird Dog": role_involvement(
        primary=("lowerBack", "abs", "obliques"), secondary=("gluteMax",),
        stabilizer=("gluteMed", "deltoids", "serratus", "triceps")
    ),
    "Bodyweight Lateral Step to Squat": role_involvement(
        primary=("gluteMed", "quads"),
        secondary=("gluteMax", "adductors", "hamstrings"),
        stabilizer=("calves", "abs", "obliques")
    ),
    "Jumping Jack": role_involvement(
        primary=("gluteMed", "deltoids"),
        secondary=("calves", "quads", "gluteMax", "adductors"),
        stabilizer=("hamstrings", "abs", "obliques", "shins")
    ),
    "Prisoner Squat with Overhead Reach": role_involvement(
        primary=("quads",),
        secondary=("gluteMax", "adductors", "hamstrings", "deltoids"),
        stabilizer=("calves", "abs", "obliques", "lowerBack", "shins", "serratus", "traps")
    ),
    "Cable Internal Rotation": role_involvement(
        primary=("subscapularis",), secondary=("pectorals", "lats", "teresMajor"),
        stabilizer=("deltoids",)
    ),
    "Side-Lying Dumbbell Internal Rotation": role_involvement(
        primary=("subscapularis",), secondary=("pectorals", "lats", "teresMajor"),
        stabilizer=("deltoids",)
    ),
    "Cross-Body Single-Arm Cable Triceps Extension": role_involvement(
        primary=("triceps",),
        stabilizer=("forearms", "abs")
    ),
    "Bent-Over Dumbbell Row to External Rotation": role_involvement(
        primary=("rhomboids", "externalRotators"),
        secondary=("deltoids", "traps", "lats", "biceps"),
        stabilizer=("forearms",)
    ),
    "Burpee": role_involvement(
        primary=("quads", "gluteMax"),
        secondary=("pectorals", "triceps", "deltoids", "calves", "hamstrings"),
        stabilizer=("abs", "obliques", "serratus")
    ),
}

EXTERNAL_ROTATION_EXERCISES = {
    "Banded External Rotation", "Cable External Rotation",
    "Side-Lying Dumbbell External Rotation",
}

EXTERNAL_ROTATION_HYBRIDS = {
    "Band Pull-Apart with External Rotation",
    "Bent-Over Dumbbell Row to External Rotation",
    "Bent-Over Dumbbell Face Pull",
    "Band Face Pull",
    "Cable Face Pull",
}


def apply_biomechanics_corrections(name, body):
    """Apply audited classification, load, identity, and role semantics."""
    if name in TRANSVERSE_PLANE:
        body["plane"] = "transverse"
    elif name in FRONTAL_PLANE:
        body["plane"] = "frontal"
    elif name in SAGITTAL_PLANE:
        body["plane"] = "sagittal"

    if name in GROUP_OVERRIDES:
        body["group"] = GROUP_OVERRIDES[name]
    if name in UNILATERAL_EXERCISES:
        body["laterality"] = "unilateral"

    if name in LOCOMOTION_EXERCISES:
        body["mechanic"] = "compound"
        body["pattern"] = "locomotion"
    if name == "Single-Leg Clock Reach":
        body["mechanic"] = "compound"
        body["pattern"] = "lunge"
    if name in {"Bird Dog", "Reverse Plank", "Side Plank"}:
        body["mechanic"] = "compound"
        body["pattern"] = "core"
    if name in MECHANIC_PATTERN_OVERRIDES:
        mechanic, pattern = MECHANIC_PATTERN_OVERRIDES[name]
        body["mechanic"] = mechanic
        if pattern is None:
            body.pop("pattern", None)
        else:
            body["pattern"] = pattern
    if name == "Half-Kneeling Single-Arm Cable High Row":
        body["equipment"] = "cable"

    if name in MOBILITY_EXERCISES:
        modality = "mobility"
    elif name in CONDITIONING_EXERCISES:
        modality = "conditioning"
    elif name in POWER_EXERCISES:
        modality = "power"
    elif body.get("trackingMode", "reps") == "duration":
        modality = "isometricStrength"
    else:
        modality = "dynamicStrength"
    body["modality"] = modality

    if (
        modality in {"mobility", "conditioning"}
        or body["equipment"] == "band"
        or name in NONCOMPARABLE_LOAD_EXERCISES
    ):
        load_mode = "nonComparable"
    elif body.get("bodyweightFraction", 0) > 0:
        load_mode = "bodyweightAdded"
    elif body["equipment"] in {"barbell", "dumbbell", "cable", "machine", "kettlebell"}:
        load_mode = "external"
    elif body["defaultWeight"] > 0:
        load_mode = "external"
    else:
        load_mode = "nonComparable"
    body["loadMode"] = load_mode
    if load_mode == "nonComparable":
        body["bodyweightFraction"] = 0.0

    body["trackingMode"] = body.get("trackingMode", "reps")
    body["aliases"] = body.get("aliases", [])
    alias_keys = {normalize_search_term(alias) for alias in body["aliases"]}
    for alias in CANONICAL_ALIAS_ADDITIONS.get(name, ()):
        key = normalize_search_term(alias)
        if key not in alias_keys:
            body["aliases"].append(alias)
            alias_keys.add(key)
    converted = []
    for contribution in body["involvement"]:
        converted.append({
            "muscle": contribution["muscle"],
            "role": contribution["role"],
        })
    body["involvement"] = INVOLVEMENT_OVERRIDES.get(name, converted)

    if name in EXTERNAL_ROTATION_EXERCISES:
        body["involvement"] = role_involvement(
            primary=("externalRotators",),
            stabilizer=("deltoids", "rhomboids", "traps"),
        )
    elif name in EXTERNAL_ROTATION_HYBRIDS:
        for contribution in body["involvement"]:
            if contribution["muscle"] == "teresMajor":
                contribution["muscle"] = "externalRotators"


def load_reviewed_involvement():
    """Load the post-review muscle map keyed by exact canonical name.

    The CSV retains the pre-review mapping for audit history and stores the
    final mapping separately in `reviewed_involvement`. Requiring a reviewed
    row for every curated exercise makes regeneration fail closed instead of
    silently falling back to the older seed-call anatomy.
    """
    with open(ANATOMY_REVIEW, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    if not rows or "reviewed_involvement" not in rows[0]:
        raise SystemExit(
            f"Missing reviewed_involvement column in {ANATOMY_REVIEW}"
        )

    reviewed = {}
    for row in rows:
        name = (row.get("exercise_name") or "").strip()
        if not name:
            raise SystemExit(f"Blank exercise_name in {ANATOMY_REVIEW}")
        if name in reviewed:
            raise SystemExit(f"Duplicate anatomy-review row for '{name}'")

        contributions = []
        raw = (row.get("reviewed_involvement") or "").strip()
        for value in raw.split(",") if raw else []:
            try:
                muscle, role = value.strip().split(":", 1)
            except ValueError as error:
                raise SystemExit(
                    f"Invalid reviewed involvement for '{name}': '{value}'"
                ) from error
            if role not in MUSCLE_ROLES:
                raise SystemExit(
                    f"Invalid reviewed role for '{name}': '{value}'"
                )
            contributions.append({"muscle": muscle, "role": role})
        reviewed[name] = contributions

    curated_names = set(CURATION)
    review_names = set(reviewed)
    missing = sorted(curated_names - review_names)
    extra = sorted(review_names - curated_names)
    if missing or extra:
        details = []
        if missing:
            details.append("missing review rows: " + ", ".join(missing))
        if extra:
            details.append("unknown review rows: " + ", ".join(extra))
        raise SystemExit("Anatomy review/catalog mismatch — " + "; ".join(details))

    return reviewed


def load_catalog_metadata():
    """Load immutable IDs and cleaned definitions for every record.

    The raw reference export is intentionally not a runtime dependency. Its
    usable prose was cleaned into this reviewed CSV, with authored definitions
    for native or underspecified source rows.
    """
    with open(DEFINITIONS, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    metadata = {}
    catalog_ids = set()
    for row in rows:
        name = (row.get("exercise_name") or "").strip()
        catalog_id = (row.get("catalog_id") or "").strip()
        definition = (row.get("movement_definition") or "").strip()
        source = (row.get("source") or "").strip()
        if not name or not catalog_id or not definition:
            raise SystemExit(f"Blank catalog metadata row in {DEFINITIONS}")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", catalog_id):
            raise SystemExit(f"Invalid pinned catalogID for '{name}': '{catalog_id}'")
        if catalog_id in catalog_ids:
            raise SystemExit(f"Duplicate pinned catalogID: '{catalog_id}'")
        catalog_ids.add(catalog_id)
        if source not in {"wger-reference", "curated"}:
            raise SystemExit(f"Invalid definition source for '{name}': '{source}'")
        if name in metadata:
            raise SystemExit(f"Duplicate movement definition for '{name}'")
        metadata[name] = (catalog_id, definition)

    curated_names = set(CURATION)
    metadata_names = set(metadata)
    missing = sorted(curated_names - metadata_names)
    extra = sorted(metadata_names - curated_names)
    if missing or extra:
        details = []
        if missing:
            details.append("missing definitions: " + ", ".join(missing))
        if extra:
            details.append("unknown definitions: " + ", ".join(extra))
        raise SystemExit("Definition/catalog mismatch — " + "; ".join(details))

    return {
        name: {"catalogID": catalog_id, "movementDefinition": definition}
        for name, (catalog_id, definition) in metadata.items()
    }


def validate(name, body):
    errs = []
    errs.extend(canonical_name_errors(name))
    required = {
        "catalogID", "group", "defaultWeight", "reps", "trackingMode",
        "equipment", "mechanic", "plane", "laterality", "aliases",
        "bodyweightFraction", "modality", "loadMode", "movementDefinition",
        "involvement",
    }
    missing = required - set(body)
    if missing: errs.append(f"missing fields {sorted(missing)}")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", body.get("catalogID", "")):
        errs.append(f"catalogID '{body.get('catalogID')}'")
    if body["group"] not in GROUPS: errs.append(f"group '{body['group']}'")
    if body["equipment"] not in EQUIPMENT: errs.append(f"equipment '{body['equipment']}'")
    if body["mechanic"] not in MECHANICS: errs.append(f"mechanic '{body['mechanic']}'")
    if "pattern" in body and body["pattern"] not in PATTERNS: errs.append(f"pattern '{body['pattern']}'")
    if body["mechanic"] == "compound" and "pattern" not in body:
        errs.append("compound exercise has no pattern")
    if body["mechanic"] == "isolation" and "pattern" in body:
        errs.append("isolation exercise has a pattern")
    is_push_pull = body.get("pattern") in {"push", "pull"}
    has_direction = body.get("direction") in DIRECTIONS
    if is_push_pull != has_direction: errs.append(f"direction '{body.get('direction')}' for pattern '{body.get('pattern')}'")
    if body["plane"] not in PLANES: errs.append(f"plane '{body['plane']}'")
    if body["laterality"] not in LATERALITIES: errs.append(f"laterality '{body['laterality']}'")
    if not isinstance(body["reps"], int) or body["reps"] < 1:
        errs.append(f"reps '{body['reps']}'")
    if not (0 <= body["bodyweightFraction"] <= 1):
        errs.append(f"bodyweightFraction '{body['bodyweightFraction']}'")
    if "defaultWeightKg" in body:
        kg = body["defaultWeightKg"]
        if kg <= 0 or abs(round(kg / KG_STEP) - kg / KG_STEP) > 0.000_001:
            errs.append(f"defaultWeightKg '{kg}'")
    if body.get("trackingMode") not in TRACKING: errs.append("trackingMode")
    if body.get("trackingMode") == "duration" and body.get("defaultDuration", 0) <= 0:
        errs.append("defaultDuration")
    if body.get("modality") not in MODALITIES: errs.append(f"modality '{body.get('modality')}'")
    if body.get("loadMode") not in LOAD_MODES: errs.append(f"loadMode '{body.get('loadMode')}'")
    if body.get("loadMode") in {"external", "nonComparable"} and body["bodyweightFraction"] != 0:
        errs.append("load mode requires zero bodyweightFraction")
    if body.get("loadMode") in {"bodyweightAdded", "assistanceSubtracted"} and body["bodyweightFraction"] <= 0:
        errs.append("load mode requires positive bodyweightFraction")
    if body.get("equipment") == "band" and body.get("loadMode") != "nonComparable":
        errs.append("band resistance is non-comparable without a calibrated force curve")
    if body.get("modality") == "dynamicStrength" and body.get("trackingMode") != "reps":
        errs.append("dynamic strength must track reps")
    if body.get("modality") == "power" and body.get("trackingMode") != "reps":
        errs.append("power must track reps")
    if body.get("modality") == "isometricStrength" and body.get("trackingMode") != "duration":
        errs.append("isometric strength must track duration")
    if not isinstance(body.get("aliases"), list): errs.append("aliases")
    if not isinstance(body.get("movementDefinition"), str) or not body["movementDefinition"].strip():
        errs.append("movementDefinition")
    else:
        errs.extend(movement_definition_errors(body["movementDefinition"]))
    seen_muscles = set()
    for c in body["involvement"]:
        if c["muscle"] not in MUSCLES: errs.append(f"muscle '{c['muscle']}'")
        if c.get("role") not in MUSCLE_ROLES: errs.append(f"role '{c.get('role')}'")
        if "weight" in c: errs.append("legacy involvement weight")
        if c["muscle"] in seen_muscles: errs.append(f"duplicate muscle '{c['muscle']}'")
        seen_muscles.add(c["muscle"])
    if body.get("modality") in {"dynamicStrength", "isometricStrength", "power"}:
        primary = [c["muscle"] for c in body["involvement"] if c.get("role") == "primary"]
        if not primary:
            errs.append("strength exercise has no primary muscle")
        elif body["group"] not in {MUSCLE_GROUPS[muscle] for muscle in primary}:
            errs.append("group does not match a primary muscle")
    if errs:
        raise SystemExit(f"Invalid curation for '{name}': {', '.join(errs)}")


def main():
    args = set(sys.argv[1:])
    unknown = args - {"--check"}
    if unknown:
        raise SystemExit(f"Unknown argument(s): {', '.join(sorted(unknown))}")

    existing_catalog = None
    if os.path.exists(CATALOG):
        with open(CATALOG, encoding="utf-8") as f:
            existing_catalog = json.load(f)

    reviewed_involvement = load_reviewed_involvement()
    catalog_metadata = load_catalog_metadata()
    for name, body in CURATION.items():
        body["involvement"] = reviewed_involvement[name]
        apply_biomechanics_corrections(name, body)
        body.update(catalog_metadata[name])

    # Build every shipped record fresh from the tracked authored sources so no
    # stale fields or deleted records can survive from a prior catalog.
    curated = []
    for name, body in CURATION.items():
        validate(name, body)
        record = {"name": name}
        record.update(body)
        curated.append(record)

    # Drop aliases that collide with canonical names, then reject aliases that
    # still point to multiple records. Search terms must have one owner.
    canonical_names = [normalize_search_term(r["name"]) for r in curated]
    canonical = set(canonical_names)
    if len(canonical_names) != len(canonical):
        duplicates = sorted({
            value for value in canonical_names if canonical_names.count(value) > 1
        })
        raise SystemExit(f"Duplicate normalized canonical name(s): {', '.join(duplicates)}")
    stripped = 0
    for r in curated:
        kept = [a for a in r["aliases"]
                if normalize_search_term(a) not in canonical]
        stripped += len(r["aliases"]) - len(kept)
        r["aliases"] = kept

    alias_owners = {}
    for record in curated:
        for alias in record["aliases"]:
            key = normalize_search_term(alias)
            if key in alias_owners:
                raise SystemExit(
                    f"Alias '{alias}' belongs to both '{alias_owners[key]}' and "
                    f"'{record['name']}'"
                )
            alias_owners[key] = record["name"]

    ids = [record["catalogID"] for record in curated]
    if len(ids) != len(set(ids)):
        duplicates = sorted({value for value in ids if ids.count(value) > 1})
        raise SystemExit(f"Duplicate catalogID(s): {', '.join(duplicates)}")

    curated.sort(key=lambda r: (r["group"], r["name"].lower()))

    if "--check" in args:
        if existing_catalog is None:
            raise SystemExit(f"catalog.json is missing: {CATALOG}")
        if curated != existing_catalog:
            changed = [
                record["name"]
                for record, existing in zip(curated, existing_catalog)
                if record != existing
            ]
            if len(curated) != len(existing_catalog):
                changed.append(
                    f"record count {len(existing_catalog)} -> {len(curated)}"
                )
            preview = ", ".join(changed[:10])
            suffix = " …" if len(changed) > 10 else ""
            raise SystemExit(f"catalog.json is stale: {preview}{suffix}")
        print(f"catalog.json matches {len(curated)} curated records")
        return

    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(curated, f, ensure_ascii=False, indent=2)

    print(f"Shipped {len(curated)}/{len(CURATION)} curated records into {CATALOG}")
    print(f"Stripped {stripped} alias(es) that collided with a canonical name")


if __name__ == "__main__":
    main()
