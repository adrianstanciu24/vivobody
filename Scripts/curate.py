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
#  Only exercises listed in CURATION ship. To add an exercise, author it in all
#  three tracked sources. Every output record is built fresh, so obsolete keys
#  or deleted records cannot survive from the previous catalog. Everything is
#  validated against the app enums, so a typo'd muscle, equipment, movement
#  direction, or other contract value fails loudly.
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
    "Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                      aliases=["BP", "Flat Bench", "Barbell Bench"]),
    "Benchpress Dumbbells": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=50, reps=8,
                               prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                               aliases=["Dumbbell Bench Press", "DB Bench", "DB Press", "Dumbbell Chest Press"]),
    "Incline Dumbbell Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=40, reps=8,
                                 prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                 aliases=["Incline DB Press", "Incline Bench Press - Dumbbell", "Incline Chest Press DB"]),
    "Decline Bench Press Barbell": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                      aliases=["Decline Bench Press"]),
    "Dips": ex("chest", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=8, bw=0.95,
               prime=["pectorals", "triceps"], minor=["deltoids"],
               aliases=["Dip", "Chest Dip"]),

    # ---- Back ----
    "Deadlifts": ex("back", "barbell", "compound", "hinge", weight=225, reps=5, weight_kg=100,
                    prime=["gluteMax", "hamstrings", "lowerBack"],
                    major=["traps", "forearms"], minor=["lats", "quads"],
                    aliases=["Deadlift", "Conventional Deadlift", "DL"]),
    "Bent Over Rowing": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, weight_kg=50,
                           prime=["lats", "rhomboids"], major=["traps", "biceps"],
                           minor=["teresMajor", "lowerBack"],
                           aliases=["Barbell Row", "Bent-Over Row", "BB Row"]),
    "Pull-ups": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                   prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                   aliases=["Pull-up", "Pullup", "Pull Ups", "Speed Pull Ups", "Weighted Pull Ups"]),
    "Chin-ups": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                   prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                   aliases=["Chin-up", "Chinup", "Chin Up"]),
    "Lat Pull Down": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                        prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                        aliases=["Lat Pulldown", "Pulldown"]),
    "Seated Cable Rows": ex("back", "cable", "compound", "pull", direction="horizontal", weight=100, reps=10,
                            prime=["lats", "rhomboids"], major=["biceps"],
                            minor=["traps", "teresMajor"], aliases=["Seated Row", "Cable Row", "Seated Cable Row"]),
    "T-Bar row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=90, reps=8,
                    prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                    aliases=["T-Bar Row", "Rowing, T-bar"]),
    "One Arm Bent Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=60, reps=10,
                           lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                           minor=["traps", "teresMajor"],
                           aliases=["Single-Arm Dumbbell Row", "One-Arm Row", "DB Row", "Single Arm Bent Over Row"]),

    # ---- Shoulders ----
    "Shoulder Press, Dumbbells": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=8,
                                    prime=["deltoids"], major=["triceps"], minor=["traps"],
                                    aliases=["Dumbbell Shoulder Press", "DB Shoulder Press", "DB OHP"]),
    "Arnold Shoulder Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10,
                                prime=["deltoids"], major=["triceps"], minor=["traps"],
                                aliases=["Arnold Press"]),
    "Clean and Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=5,
                          prime=["deltoids"], major=["triceps", "quads"],
                          minor=["traps", "gluteMax"], aliases=["Barbell Clean and Press"]),
    "Power Clean": ex("back", "barbell", "compound", "hinge", weight=135, reps=3,
                      prime=["traps", "gluteMax", "hamstrings"], major=["quads", "deltoids"],
                      minor=["lowerBack", "forearms"]),

    # ---- Legs ----
    "Squats": ex("legs", "barbell", "compound", "squat", weight=185, reps=8,
                 prime=["quads", "gluteMax"], major=["hamstrings"],
                 minor=["lowerBack", "adductors"],
                 aliases=["Back Squat", "Barbell Squat", "High-Bar Squat"]),
    "Front Squats": ex("legs", "barbell", "compound", "squat", weight=135, reps=8,
                       prime=["quads"], major=["gluteMax"], minor=["lowerBack", "abs"],
                       aliases=["Front Squat"]),
    "Leg Press": ex("legs", "machine", "compound", "squat", weight=270, reps=10,
                    prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Hack Squats": ex("legs", "machine", "compound", "squat", weight=180, reps=10,
                      prime=["quads"], minor=["gluteMax"], aliases=["Hack Squat"]),
    "Sumo Deadlift": ex("legs", "barbell", "compound", "hinge", weight=225, reps=5,
                        prime=["gluteMax", "adductors", "quads"], major=["lowerBack"],
                        minor=["hamstrings", "traps"], aliases=["Sumo DL"]),
    "Glute Bridge": ex("legs", "barbell", "compound", "hinge", weight=135, reps=12,
                       prime=["gluteMax"], minor=["hamstrings"]),
    "Lunges": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, bw=0.5,
                 lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                 minor=["adductors"], aliases=["Lunge"]),
    "Leg Extension": ex("legs", "machine", "isolation", None, weight=80, reps=12,
                        prime=["quads"], aliases=["Quad Extension"]),

    # ---- Core ----
    "Plank": ex("core", "bodyweight", "isolation", "core", weight=0, reps=1,
                tracking="duration", duration=60, bw=0.6,
                prime=["abs"], major=["obliques"], minor=["lowerBack"],
                aliases=["Front Plank"]),

    # ===================== Batch 2: common variants + key isolation =====================

    # ---- Chest ----
    "Incline Bench Press - Barbell": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=95, reps=8,
                                        prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                        aliases=["Incline Bench Press", "Incline Barbell Press"]),
    "Close-Grip Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=115, reps=8,
                                 prime=["triceps"], major=["pectorals"], minor=["deltoids"],
                                 aliases=["CGBP", "Close Grip Bench Press", "Bench Press Narrow Grip"]),
    "Decline Bench Press Dumbbell": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=8,
                                       prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                       aliases=["Decline Dumbbell Press"]),
    "Fly With Dumbbells": ex("chest", "dumbbell", "isolation", None, weight=25, reps=12,
                             prime=["pectorals"], minor=["deltoids"],
                             aliases=["Dumbbell Fly", "Chest Fly", "DB Fly"]),
    "Wide Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"],
                       aliases=["Wide-Grip Push-Up"]),

    # ---- Shoulders ----
    "Lateral Raises": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                         prime=["deltoids"], minor=["traps"],
                         aliases=["Lateral Raise", "Side Raise", "DB Lateral Raise"]),
    "Front Plate Raise": ex("shoulders", "other", "isolation", None, weight=25, reps=12,
                            prime=["deltoids"], minor=["serratus"],
                            aliases=["Plate Front Raise"]),
    "Upright Row w/ Dumbbells": ex("shoulders", "dumbbell", "compound", "pull", direction="vertical", weight=25, reps=12,
                                   prime=["deltoids", "traps"], minor=["biceps"],
                                   aliases=["Dumbbell Upright Row"]),
    "Facepull": ex("shoulders", "cable", "compound", "pull", direction="horizontal", weight=50, reps=15,
                   prime=["deltoids"], major=["traps", "rhomboids"], minor=["teresMajor"],
                   aliases=["Face Pull"]),

    # ---- Arms ----
    "Biceps Curls With Barbell": ex("arms", "barbell", "isolation", None, weight=65, reps=10,
                                    prime=["biceps"], minor=["forearms"],
                                    aliases=["Barbell Curl", "BB Curl"]),
    "Seated Dumbbell Curls": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                prime=["biceps"], minor=["forearms"],
                                aliases=["Dumbbell Curl", "DB Curl"]),
    "Hammer Curls": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                       prime=["biceps"], major=["forearms"],
                       aliases=["Hammer Curl", "DB Hammer Curl"]),
    "Preacher Curls": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                         prime=["biceps"], minor=["forearms"], aliases=["Preacher Curl"]),
    "Dumbbell Concentration Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12,
                                      lat="unilateral", prime=["biceps"],
                                      aliases=["Concentration Curl"]),
    "Cable Curls": ex("arms", "cable", "isolation", None, weight=50, reps=12,
                      prime=["biceps"], minor=["forearms"], aliases=["Cable Curl"]),
    "Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12,
                           prime=["triceps"],
                           aliases=["Tricep Pushdown", "Pushdown", "Cable Pushdown"]),
    "Skullcrusher SZ-bar": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                              prime=["triceps"],
                              aliases=["Skull Crusher", "Lying Triceps Extension", "EZ-Bar Skullcrusher"]),
    "Overhead Triceps Extension": ex("arms", "cable", "isolation", None, weight=40, reps=12,
                                     prime=["triceps"], aliases=["Overhead Tricep Extension"]),
    "Shrugs, Barbells": ex("arms", "barbell", "isolation", None, weight=185, reps=12,
                           prime=["traps"], minor=["forearms"], aliases=["Barbell Shrug", "Shrugs"]),

    # ---- Legs ----
    "Lying Leg Curl": ex("legs", "machine", "isolation", None, weight=70, reps=12,
                             prime=["hamstrings"], minor=["calves"],
                             aliases=["Lying Leg Curl", "Leg Curl", "Hamstring Curl"]),
    "Leg Curls (sitting)": ex("legs", "machine", "isolation", None, weight=80, reps=12,
                              prime=["hamstrings"], minor=["calves"], aliases=["Seated Leg Curl"]),
    "Double Leg Calf Raise": ex("legs", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.85,
                                prime=["calves"], aliases=["Calf Raise", "Standing Calf Raise"]),
    "Seated Dumbbell Calf Raise": ex("legs", "dumbbell", "isolation", None, weight=45, reps=15,
                                     prime=["calves"], aliases=["Seated Calf Raise"]),
    "Bulgarian Squat with Dumbbells": ex("legs", "dumbbell", "compound", "lunge", weight=40, reps=10,
                                         lat="unilateral", prime=["quads", "gluteMax"],
                                         major=["hamstrings"], minor=["adductors"],
                                         aliases=["Bulgarian Split Squat", "Rear-Foot Elevated Split Squat"]),
    "Dumbbell Goblet Squat": ex("legs", "dumbbell", "compound", "squat", weight=50, reps=12,
                                prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"],
                                aliases=["Goblet Squat"]),
    "Good Mornings": ex("legs", "barbell", "compound", "hinge", weight=95, reps=10,
                        prime=["hamstrings", "lowerBack"], major=["gluteMax"], aliases=["Good Morning"]),
    "Seated Hip Adduction": ex("legs", "machine", "isolation", None, weight=90, reps=15,
                               prime=["adductors"], aliases=["Hip Adduction", "Adductor Machine"]),
    "Machine Hip Abduction": ex("legs", "machine", "isolation", None, weight=90, reps=15,
                                prime=["gluteMax"],
                                aliases=["Hip Abduction", "Abductor Machine", "Seated Hip Abduction"]),

    # ---- Back ----
    "Hyperextensions": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.5,
                          prime=["lowerBack"], major=["gluteMax", "hamstrings"],
                          aliases=["Back Extension", "Hyperextension"]),

    # ---- Core ----
    "Abdominal Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.3,
                           prime=["abs"], major=["obliques"], minor=["hipFlexors"],
                           aliases=["Crunch", "3008 Abdominal Crunch", "Crunches HD", "Levitation Crunch", "Negative Crunches"]),
    "Sit-ups": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                  prime=["abs"], minor=["hipFlexors"], aliases=["Sit-up"]),
    "Hanging Leg Raises": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                             prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                             aliases=["Hanging Leg Raise", "Straight-Leg Hanging Leg Raise"]),
    "Lying Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                          prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                          aliases=["Leg Raise", "Lying Leg Raises", "Leg Raises, Lying"]),
    "Russian Twist": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                        prime=["obliques"], major=["abs"],
                        aliases=["Russian Twists", "Core Rotation", "Russian Twists with Med Ball"]),
    "Ab wheel": ex("core", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.4,
                   prime=["abs"], minor=["obliques", "lowerBack"],
                   aliases=["Ab Wheel Rollout", "Ab Roller"]),
    "Side Plank": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                     tracking="duration", duration=45, bw=0.5,
                     prime=["obliques"], minor=["abs"], aliases=["Side Plank Hold", "Lateral Isometric Hold", "Lateral Isometric Holds"]),
    "Mountain climbers": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                            prime=["abs"], minor=["obliques", "hipFlexors"],
                            aliases=["Mountain Climber"]),

    # ===================== Batch 3: long-tail variants (parallel droid pass) =====================

    # ---- Chest ----
    "Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=20, bw=0.64,
                  prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"],
                  aliases=["Pushup", "Press-up", "Standard Push-Up"]),
    "Close-grip Press-ups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                               prime=["pectorals", "triceps"], minor=["deltoids"],
                               aliases=["Close-Grip Push-Up", "Narrow Push-Up"]),
    "Diamond push ups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                           prime=["triceps"], major=["pectorals"], minor=["deltoids"],
                           aliases=["Diamond Push-Up", "Triangle Push-Up"]),
    "Clap Push-UP": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=10, bw=0.64,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                       aliases=["Clap Push-Up", "Plyometric Push-Up", "Explosive Push-Up"]),
    "Incline Push up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.5,
                          prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                          aliases=["Incline Push-Up", "Hands-Elevated Push-Up", "Push-Ups | Incline"]),
    "Decline Pushups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.7,
                          prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                          aliases=["Decline Push-Up", "Feet-Elevated Push-Up"]),
    "Weighted push-ups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=25, reps=12, bw=0.64,
                            prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                            aliases=["Weighted Push-Up"]),
    "Push-Ups | Parallettes": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64,
                                 prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                 aliases=["Parallette Push-Up", "Deep Push-Up"]),
    "Machine Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10,
                              prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                              aliases=["Machine Press", "Seated Chest Press", "Seated Machine Press",
                                       "Machine Chest Press Exercise", "Flat Machine Press"]),
    "Hammerstrength Decline Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=110, reps=10,
                                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                             aliases=["Decline Machine Press", "Hammer Strength Decline Press"]),
    "Incline Smith Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=95, reps=8,
                              prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                              aliases=["Incline Smith Machine Press"]),
    "Pin Bench Press BB": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=6,
                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                             aliases=["Pin Press", "Dead Bench Press"]),
    "Larsen Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=8,
                       prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Pause Bench": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=135, reps=5,
                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                      aliases=["Paused Bench Press"]),
    "Reverse Grip Bench Press": ex("chest", "barbell", "compound", "push", direction="horizontal", weight=115, reps=8,
                                   prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                   aliases=["Underhand Bench Press", "Supinated Bench Press"]),
    "Dumbbell Floor Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=8,
                               prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                               aliases=["DB Floor Press"]),
    "Dumbbell Hex Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10,
                             prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                             aliases=["Hex Press", "Squeeze Press", "Crush Press"]),
    "Cable Chest Press - Incline": ex("chest", "cable", "compound", "push", direction="horizontal", weight=60, reps=10,
                                      prime=["pectorals"], major=["deltoids"], minor=["triceps"],
                                      aliases=["Incline Cable Press"]),
    "Cable Chest Press - Decline": ex("chest", "cable", "compound", "push", direction="horizontal", weight=60, reps=10,
                                      prime=["pectorals"], major=["triceps"], minor=["deltoids"],
                                      aliases=["Decline Cable Press"]),
    "Cable Fly": ex("chest", "cable", "isolation", None, weight=25, reps=12,
                    prime=["pectorals"], minor=["deltoids"],
                    aliases=["Standing Cable Fly", "Cable Crossover"]),
    "Low Pulley Cable Fly": ex("chest", "cable", "isolation", None, weight=20, reps=12,
                               prime=["pectorals"], minor=["deltoids"],
                               aliases=["Low Cable Fly", "Low-to-High Cable Fly"]),
    "Cable Fly Lower Chest": ex("chest", "cable", "isolation", None, weight=25, reps=12,
                                prime=["pectorals"], minor=["deltoids"],
                                aliases=["High-to-Low Cable Fly", "High Cable Fly"]),
    "Machine Chest Fly": ex("chest", "machine", "isolation", None, weight=80, reps=12,
                             prime=["pectorals"], minor=["deltoids"],
                             aliases=["Pec Deck", "Pec Deck Fly", "Butterfly", "Chest Fly Machine", "Machine Fly",
                                      "Narrow-Grip Machine Chest Fly"]),
    "Incline Dumbbell Fly": ex("chest", "dumbbell", "isolation", None, weight=20, reps=12,
                               prime=["pectorals"], minor=["deltoids"], aliases=["Incline DB Fly"]),
    "Fly With Dumbbells, Decline Bench": ex("chest", "dumbbell", "isolation", None, weight=25, reps=12,
                                            prime=["pectorals"], minor=["deltoids"],
                                            aliases=["Decline Dumbbell Fly", "Decline DB Fly"]),
    "Cross-Bench Dumbbell Pullovers": ex("chest", "dumbbell", "isolation", None, weight=35, reps=12,
                                         prime=["pectorals"], major=["lats"], minor=["serratus", "triceps"],
                                         aliases=["Dumbbell Pullover", "Cross-Bench Pullover"]),

    # ---- Back ----
    "Bent Over Dumbbell Rows": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=50, reps=10,
                                  prime=["lats", "rhomboids"], major=["biceps", "traps"],
                                  minor=["teresMajor", "lowerBack"],
                                  aliases=["Bent-Over Dumbbell Row", "Two-Arm DB Row"]),
    "Bent Over Rowing Reverse": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8,
                                   prime=["lats", "rhomboids"], major=["biceps"],
                                   minor=["traps", "teresMajor", "lowerBack"],
                                   aliases=["Underhand Barbell Row", "Yates Row", "Reverse-Grip Row"]),
    "Pendlay Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=135, reps=6,
                        prime=["lats", "rhomboids"], major=["traps", "biceps"],
                        minor=["teresMajor", "lowerBack"], aliases=["Pendlay Row"]),
    "Meadows Row": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=70, reps=10,
                      lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"],
                      minor=["teresMajor", "forearms"], aliases=["Landmine Meadows Row"]),
    "Kroc Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=80, reps=12,
                   lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"],
                   minor=["teresMajor", "forearms"], aliases=["Heavy Dumbbell Row"]),
    "Helms Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=45, reps=12,
                    prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                    aliases=["Chest-Supported Helms Row"]),
    "Renegade Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=35, reps=10,
                       lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                       minor=["abs", "obliques", "traps"], aliases=["Plank Row"]),
    "Seated Row (Machine)": ex("back", "machine", "compound", "pull", direction="horizontal", weight=120, reps=10,
                               prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                               aliases=["Machine Row", "Seated Machine Row"]),
    "Unilateral Cable row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=60, reps=12,
                               lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"],
                               minor=["traps", "teresMajor"], aliases=["Single-Arm Cable Row"]),
    "Leverage Machine Iso Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=90, reps=10,
                                   prime=["lats", "rhomboids"], major=["biceps", "traps"],
                                   minor=["teresMajor"], aliases=["Iso-Lateral Row", "Hammer Strength Row"]),
    "Rowing, Lying on Bench": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=95, reps=10,
                                 prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                                 aliases=["Chest-Supported Barbell Row"]),
    "Seated V-Grip Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=110, reps=10,
                            prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"],
                            aliases=["V-Bar Seated Row"]),
    "Close-grip Lat Pull Down": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                                   prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                                   aliases=["Close-Grip Pulldown"]),
    "Wide-grip Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10,
                             prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "traps"],
                             aliases=["Wide-Grip Lat Pulldown"]),
    "Underhand Lat Pull Down": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10,
                                  prime=["lats", "biceps"], minor=["teresMajor", "rhomboids"],
                                  aliases=["Reverse-Grip Pulldown", "Supinated Pulldown"]),
    "Neutral Grip Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=105, reps=10,
                                    prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                                    aliases=["Neutral-Grip Pulldown", "V-Grip Pulldown"]),
    "Straight-Arm Pulldown (Cable)": ex("back", "cable", "isolation", None, weight=50, reps=15,
                                        prime=["lats"], minor=["teresMajor", "triceps"],
                                        aliases=["Straight-Arm Pushdown", "Lat Pushdown"]),
    "Pullover Machine": ex("back", "machine", "isolation", None, weight=90, reps=12,
                           prime=["lats"], minor=["teresMajor", "pectorals"],
                           aliases=["Machine Pullover", "Nautilus Pullover"]),
    "Dumbbell Pullover": ex("back", "dumbbell", "isolation", None, weight=50, reps=12,
                            prime=["lats"], minor=["pectorals", "teresMajor", "triceps"],
                            aliases=["DB Pullover", "Lat Pullover", "Pullover"]),
    "Lat Pulldown - Cross Body Single Arm": ex("back", "cable", "compound", "pull", direction="vertical", weight=50, reps=12,
                                               lat="unilateral", prime=["lats"], major=["biceps"],
                                               minor=["teresMajor", "rhomboids"],
                                               aliases=["Single-Arm Lat Pulldown", "Cross-Body Pulldown"]),
    "V-Bar Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10,
                         prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"],
                         aliases=["Close Neutral-Grip Pulldown"]),
    "Pull-Ups (Wide Grip)": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                               prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                               aliases=["Wide-Grip Pull-up", "Wide Pull Up"]),
    "Pull-Ups (Neutral Grip)": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0,
                                  prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"],
                                  aliases=["Neutral-Grip Pull-up", "Hammer-Grip Pull-up"]),
    "Archer Pull Up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=6, bw=1.0,
                         lat="unilateral", prime=["lats"], major=["biceps"],
                         minor=["teresMajor", "rhomboids", "forearms"], aliases=["Archer Pull-up"]),
    "Muscle up": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=5, bw=1.0,
                    prime=["lats"], major=["biceps", "triceps"],
                    minor=["pectorals", "deltoids", "forearms"], aliases=["Muscle-up", "Bar Muscle-up"]),
    "Scapula Pulls": ex("back", "bodyweight", "isolation", None, weight=0, reps=12, bw=1.0,
                        prime=["lats", "traps"], minor=["rhomboids", "forearms"],
                        aliases=["Scapular Pull-up", "Scap Pulls"]),
    "Deficit Deadlift": ex("back", "barbell", "compound", "hinge", weight=205, reps=5,
                           prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"],
                           minor=["lats", "quads"], aliases=["Deficit Pull"]),
    "Rack Deadlift": ex("back", "barbell", "compound", "hinge", weight=275, reps=5,
                        prime=["gluteMax", "lowerBack", "traps"], major=["hamstrings", "forearms"],
                        minor=["lats"], aliases=["Rack Pull", "Block Pull"]),
    "Dumbbell Hang Power Cleans": ex("back", "dumbbell", "compound", "hinge", weight=40, reps=5,
                                     prime=["traps", "gluteMax", "hamstrings"], major=["deltoids", "quads"],
                                     minor=["lowerBack", "forearms"],
                                     aliases=["DB Hang Power Clean", "Dumbbell Power Clean"]),
    "Kettlebell deadlifts": ex("back", "kettlebell", "compound", "hinge", weight=53, reps=10,
                               prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"],
                               minor=["lats", "quads"], aliases=["Kettlebell Deadlift", "KB Deadlift"]),
    "Kettlebell sumo high pull": ex("back", "kettlebell", "compound", "pull", direction="vertical", weight=53, reps=10,
                                    prime=["traps", "gluteMax"], major=["hamstrings", "deltoids"],
                                    minor=["quads", "biceps", "lowerBack"], aliases=["KB Sumo High Pull"]),
    "Snatch OL": ex("back", "barbell", "compound", "hinge", weight=95, reps=3,
                    prime=["traps", "gluteMax", "hamstrings"], major=["deltoids", "quads"],
                    minor=["lowerBack", "lats", "forearms"], aliases=["Snatch", "Olympic Snatch"]),
    "Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4,
                   prime=["lowerBack"], major=["gluteMax"], minor=["hamstrings", "traps"],
                   aliases=["Superman Hold", "Prone Back Extension"]),
    "Quadriped Arm and Leg Raise": ex("back", "bodyweight", "isolation", None, weight=0, reps=12,
                                      lat="unilateral", prime=["lowerBack"], major=["gluteMax"],
                                      minor=["traps", "deltoids", "abs"],
                                      aliases=["Bird Dog", "Quadruped Arm and Leg Raise"]),
    "Dumbbell Bent Over Face Pull": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=15, reps=15,
                                       prime=["deltoids"], major=["traps", "rhomboids"],
                                       minor=["teresMajor"], aliases=["Bent-Over Face Pull", "DB Face Pull"]),
    "Incline Bench Reverse Fly": ex("back", "dumbbell", "isolation", None, weight=15, reps=15,
                                    prime=["deltoids"], major=["rhomboids"], minor=["traps", "teresMajor"],
                                    aliases=["Incline Reverse Fly", "Prone Rear Delt Fly"]),

    # ---- Shoulders ----
    "Front Raises": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=12,
                       plane="frontal", prime=["deltoids"], minor=["serratus"],
                       aliases=["Front Raise", "Dumbbell Front Raise"]),
    "Front Raise (Cable)": ex("shoulders", "cable", "isolation", None, weight=25, reps=12,
                              plane="frontal", prime=["deltoids"], minor=["serratus"],
                              aliases=["Cable Front Raise"]),
    "45° lateral raises": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                             plane="frontal", prime=["deltoids"], minor=["traps"],
                             aliases=["45 Degree Lateral Raise", "Incline Lateral Raise"]),
    "Machine Side Lateral Raises": ex("shoulders", "machine", "isolation", None, weight=50, reps=15,
                                      plane="frontal", prime=["deltoids"], minor=["traps"],
                                      aliases=["Machine Lateral Raise"]),
    "Behind the Back Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                              plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Cable Lateral Raises (Single Arm)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                            plane="frontal", lat="unilateral", prime=["deltoids"],
                                            minor=["traps"], aliases=["Single-Arm Cable Lateral Raise"]),
    "High-Cable Lateral Raise": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                   plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Bent-over Lateral Raises": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                   plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                                   aliases=["Bent-Over Lateral Raise", "Rear Delt Fly", "Rear Delt Raise",
                                            "Rear Delt Raises", "Reverse Fly"]),
    "Cable Rear Delt Fly": ex("shoulders", "cable", "isolation", None, weight=20, reps=15,
                              plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                              aliases=["Cable Reverse Fly"]),
    "Chest-Supported Rear Delt Raise": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                          plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                                          aliases=["Chest-Supported Reverse Fly"]),
    "Butterfly Reverse": ex("shoulders", "machine", "isolation", None, weight=70, reps=15,
                            plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"],
                            aliases=["Reverse Pec Deck", "Rear Delt Machine", "Pec Deck Rear Delt Fly"]),
    "Dumbbell rear delt row": ex("shoulders", "dumbbell", "compound", "pull", direction="horizontal", weight=30, reps=12,
                                 plane="transverse", prime=["deltoids"], major=["rhomboids", "traps"],
                                 minor=["biceps"], aliases=["Rear Delt Row"]),
    "Dumbbell Scaption": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                            plane="frontal", prime=["deltoids"], minor=["traps", "serratus"],
                            aliases=["Scaption Raise"]),
    "Incline DB Y-Raise": ex("shoulders", "dumbbell", "isolation", None, weight=10, reps=15,
                             plane="frontal", prime=["deltoids"], minor=["traps", "serratus"],
                             aliases=["Y-Raise", "Incline Y Raise"]),
    "Dumbbell Bradford press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=12,
                                  prime=["deltoids"], major=["triceps"], minor=["traps"],
                                  aliases=["Bradford Press"]),
    "Push Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=115, reps=5,
                     prime=["deltoids"], major=["triceps"], minor=["traps", "quads", "gluteMax"]),
    "Landmine press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=45, reps=10,
                         lat="unilateral", prime=["deltoids"], major=["triceps"],
                         minor=["pectorals", "serratus"], aliases=["Landmine Press", "Landmine Shoulder Press"]),
    "Smith Press": ex("shoulders", "machine", "compound", "push", direction="vertical", weight=65, reps=8,
                      prime=["deltoids"], major=["triceps"], minor=["traps"],
                      aliases=["Smith Machine Shoulder Press"]),
    "Shoulder Press, on Machine": ex("shoulders", "machine", "compound", "push", direction="vertical", weight=70, reps=10,
                                     prime=["deltoids"], major=["triceps"], minor=["traps"],
                                     aliases=["Machine Shoulder Press"]),
    "Single-arm dumbbell shoulder press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=10,
                                             lat="unilateral", prime=["deltoids"], major=["triceps"],
                                             minor=["traps", "abs"], aliases=["Single-Arm DB Shoulder Press"]),
    "Upright Row, SZ-bar": ex("shoulders", "barbell", "compound", "pull", direction="vertical", weight=65, reps=12,
                              prime=["deltoids", "traps"], minor=["biceps"],
                              aliases=["EZ-Bar Upright Row"]),
    "High Pull": ex("shoulders", "barbell", "compound", "pull", direction="vertical", weight=115, reps=6,
                    prime=["traps", "deltoids"], minor=["biceps", "forearms"],
                    aliases=["Barbell High Pull"]),
    "Bent High Pulls": ex("shoulders", "dumbbell", "compound", "pull", direction="vertical", weight=30, reps=10,
                          prime=["deltoids", "traps"], minor=["biceps", "rhomboids"]),
    "Handstand Push Up": ex("shoulders", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=6, bw=0.9,
                            prime=["deltoids", "triceps"], minor=["pectorals", "traps"],
                            aliases=["HSPU", "Handstand Pushup"]),
    "Hindu Pushups": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6,
                        prime=["deltoids", "pectorals"], minor=["triceps", "abs"],
                        aliases=["Hindu Push-up", "Dive Bomber Push-up"]),
    "Pseudo Planche Push-up": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=10, bw=0.7,
                                 prime=["deltoids"], major=["pectorals"], minor=["triceps", "serratus", "abs"],
                                 aliases=["Pseudo Planche Pushup"]),
    "Devil’s Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=8,
                        prime=["deltoids"], major=["gluteMax", "pectorals"],
                        minor=["triceps", "hamstrings", "quads", "lats"],
                        aliases=["Devils Press", "Devil Press"]),
    "Diagonal Shoulder Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=10,
                                  prime=["deltoids"], major=["triceps"], minor=["pectorals", "traps"]),

    # ---- Arms ----
    "Biceps Curls With Dumbbell": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                     prime=["biceps"], minor=["forearms"]),
    "Biceps Curls With SZ-bar": ex("arms", "barbell", "isolation", None, weight=55, reps=10,
                                   prime=["biceps"], minor=["forearms"]),
    "Dumbbell Incline Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10,
                                prime=["biceps"], minor=["forearms"]),
    "Spider Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12,
                      prime=["biceps"], minor=["forearms"]),
    "Cable Concentration Curl": ex("arms", "cable", "isolation", None, weight=25, reps=12,
                                   lat="unilateral", prime=["biceps"]),
    "Straight Bar Cable Curls": ex("arms", "cable", "isolation", None, weight=50, reps=12,
                                   prime=["biceps"], minor=["forearms"]),
    "Alternating Biceps Curls With Dumbbell": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                                 lat="unilateral", prime=["biceps"], minor=["forearms"],
                                                 aliases=["Alternating Bicep Curls"]),
    "Hammercurls on Cable": ex("arms", "cable", "isolation", None, weight=50, reps=12,
                               prime=["biceps"], major=["forearms"]),
    "Zottman curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10,
                       prime=["biceps"], major=["forearms"]),
    "Reverse Preacher Curl (Close Grip)": ex("arms", "barbell", "isolation", None, weight=45, reps=10,
                                             prime=["biceps"], major=["forearms"]),
    "Biceps Curl Machine": ex("arms", "machine", "isolation", None, weight=50, reps=12, prime=["biceps"]),
    "Bayesian Curl": ex("arms", "cable", "isolation", None, weight=30, reps=12,
                        lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "DB Cross Body Hammer Curls": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10,
                                     lat="unilateral", prime=["biceps"], major=["forearms"]),
    "one-handed kettlebell curls": ex("arms", "kettlebell", "isolation", None, weight=25, reps=10,
                                      lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Single-arm cable pushdown": ex("arms", "cable", "isolation", None, weight=25, reps=12,
                                    lat="unilateral", prime=["triceps"]),
    "Triceps on Machine": ex("arms", "machine", "isolation", None, weight=80, reps=12, prime=["triceps"]),
    "Triceps Overhead (Dumbbell)": ex("arms", "dumbbell", "isolation", None, weight=35, reps=12, prime=["triceps"]),
    "Ring Dips": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=8, bw=0.95,
                    prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Dips Between Two Benches": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.45,
                                   prime=["triceps"], minor=["pectorals", "deltoids"]),
    "Dumbell Tate Press": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["triceps"]),
    "JM Press": ex("arms", "barbell", "isolation", None, weight=95, reps=8,
                   prime=["triceps"], minor=["pectorals"]),
    "Smith Machine Close-grip Bench Press": ex("arms", "machine", "compound", "push", direction="horizontal", weight=115, reps=8,
                                               prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Dumbbell close grip bench press": ex("arms", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10,
                                          prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Wrist curl, dumbbells": ex("arms", "dumbbell", "isolation", None, weight=25, reps=15, prime=["forearms"]),
    "Barbell Wrist Curl": ex("arms", "barbell", "isolation", None, weight=65, reps=15, prime=["forearms"]),
    "Barbell Reverse Wrist Curl": ex("arms", "barbell", "isolation", None, weight=35, reps=15, prime=["forearms"]),
    "Wrist curl, cable": ex("arms", "cable", "isolation", None, weight=40, reps=15, prime=["forearms"]),

    # ---- Legs ----
    "Barbell Full Squat": ex("legs", "barbell", "compound", "squat", weight=185, reps=8,
                             prime=["quads", "gluteMax"], major=["hamstrings"],
                             minor=["lowerBack", "adductors"]),
    "Dumbbell Front Squat": ex("legs", "dumbbell", "compound", "squat", weight=50, reps=10,
                               prime=["quads"], major=["gluteMax"], minor=["abs", "adductors"]),
    "Overhead Squat": ex("legs", "barbell", "compound", "squat", weight=95, reps=6,
                         prime=["quads", "gluteMax"], major=["hamstrings"],
                         minor=["deltoids", "lowerBack", "abs"]),
    "Pin Squat": ex("legs", "barbell", "compound", "squat", weight=155, reps=5,
                    prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Smith machine squat": ex("legs", "machine", "compound", "squat", weight=185, reps=10,
                              prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Trap Bar Squat": ex("legs", "barbell", "compound", "squat", weight=225, reps=8,
                         prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack", "traps"]),
    "Sumo Squats": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.65,
                      prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Pistol Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8,
                       lat="unilateral", bw=0.9, prime=["quads", "gluteMax"],
                       major=["hamstrings"], minor=["adductors", "abs"]),
    "Cossack squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=10,
                        plane="frontal", lat="unilateral", bw=0.7, prime=["quads", "gluteMax"],
                        major=["adductors"], minor=["hamstrings"]),
    "Thruster": ex("legs", "barbell", "compound", "squat", weight=95, reps=8,
                   prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "traps", "abs"]),
    "Dumbbell Thruster": ex("legs", "dumbbell", "compound", "squat", weight=35, reps=10,
                            prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Wall-sit": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=1,
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
    "Stiff-legged Deadlifts": ex("legs", "barbell", "compound", "hinge", weight=135, reps=8,
                                 prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Dumbbell sumo deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=70, reps=10,
                                 prime=["gluteMax", "adductors"], major=["quads", "hamstrings"],
                                 minor=["lowerBack"]),
    "kettlebell sumo deadlift": ex("legs", "kettlebell", "compound", "hinge", weight=53, reps=10,
                                   prime=["gluteMax", "adductors"], major=["quads", "hamstrings"],
                                   minor=["lowerBack"]),
    "Kettlebell Swings": ex("legs", "kettlebell", "compound", "hinge", weight=35, reps=15,
                            prime=["gluteMax", "hamstrings"], major=["lowerBack"], minor=["quads", "deltoids"],
                            aliases=["Kettlebell Swing", "2 Handed Kettlebell Swing", "Two-Handed Kettlebell Swing"]),
    "Single Leg RDL": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=10,
                         lat="unilateral", bw=0.5, prime=["hamstrings", "gluteMax"], minor=["lowerBack"]),
    "Single-Leg Deadlift with Dumbbell": ex("legs", "dumbbell", "compound", "hinge", weight=35, reps=10,
                                            lat="unilateral", prime=["hamstrings", "gluteMax"],
                                            major=["lowerBack"], minor=["forearms"]),
    "Reverse Hyperextension": ex("legs", "machine", "compound", "hinge", weight=90, reps=15,
                                 prime=["gluteMax", "hamstrings"], major=["lowerBack"]),
    "Cable pull through": ex("legs", "cable", "compound", "hinge", weight=70, reps=15,
                             prime=["gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Single Leg Glute Bridge": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=15,
                                  lat="unilateral", bw=0.5, prime=["gluteMax"], minor=["hamstrings"]),
    "Clean": ex("legs", "barbell", "compound", "hinge", weight=135, reps=3,
                prime=["quads", "gluteMax", "hamstrings"], major=["traps", "deltoids"],
                minor=["lowerBack", "forearms"]),
    "Dumbbell Rear Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10,
                              lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                              minor=["adductors"]),
    "Dumbbell Split Squat": ex("legs", "dumbbell", "compound", "lunge", weight=40, reps=10,
                               lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                               minor=["adductors"]),
    "Smith Machine Split Squat": ex("legs", "machine", "compound", "lunge", weight=95, reps=10,
                                    lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                    minor=["adductors"]),
    "Barbell Step Back Lunge": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"]),
    "Barbell Lunges Standing": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"]),
    "Dumbbell Lunges Standing": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10,
                                   lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                   minor=["adductors"]),
    "Leg Curls (standing)": ex("legs", "machine", "isolation", None, weight=40, reps=12,
                               lat="unilateral", prime=["hamstrings"], minor=["calves"]),
    "Nordic Curl": ex("legs", "bodyweight", "isolation", None, weight=0, reps=8, bw=0.6,
                      prime=["hamstrings"], minor=["gluteMax", "calves"]),
    "Leg curl with elastic": ex("legs", "band", "isolation", None, weight=0, reps=15,
                                prime=["hamstrings"], minor=["calves"]),
    "Single Leg Extension": ex("legs", "machine", "isolation", None, weight=50, reps=12,
                               lat="unilateral", prime=["quads"]),
    "Reverse Nordic Curl": ex("legs", "bodyweight", "isolation", None, weight=0, reps=10, bw=0.5,
                              prime=["quads"], minor=["hipFlexors"]),
    "Standing Calf Raises": ex("legs", "machine", "isolation", None, weight=150, reps=15, prime=["calves"]),
    "Sitting Calf Raises": ex("legs", "machine", "isolation", None, weight=90, reps=15, prime=["calves"]),
    "Calf raises, one legged": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                                  lat="unilateral", bw=0.9, prime=["calves"]),
    "Copenhagen Adduction Exercise": ex("legs", "bodyweight", "isolation", None, weight=0, reps=10,
                                        plane="frontal", lat="unilateral", bw=0.5,
                                        prime=["adductors"], minor=["obliques", "abs"]),
    "Standing Adduction (Cable)": ex("legs", "cable", "isolation", None, weight=40, reps=15,
                                     plane="frontal", lat="unilateral", prime=["adductors"]),
    "Side Lying Hip Abduction": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                                   plane="frontal", lat="unilateral", bw=0.2, prime=["gluteMax"]),
    "Glute Kickback (Machine)": ex("legs", "machine", "isolation", None, weight=50, reps=15,
                                   lat="unilateral", prime=["gluteMax"], minor=["hamstrings"]),
    "Kneeling kickbacks": ex("legs", "bodyweight", "isolation", None, weight=0, reps=15,
                             lat="unilateral", bw=0.25, prime=["gluteMax"], minor=["hamstrings"]),

    # ---- Core ----
    "Bird Dog": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                   prime=["abs"], minor=["lowerBack", "gluteMax", "obliques"]),
    "Deadbug": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                  prime=["abs"], minor=["hipFlexors", "obliques"]),
    "Hollow Hold": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                      tracking="duration", duration=30, bw=0.55,
                      prime=["abs"], minor=["obliques", "hipFlexors"],
                      aliases=["Supine Core Holds"]),
    "Flutter Kicks": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                        prime=["abs"], major=["hipFlexors"], minor=["obliques"],
                        aliases=["Scissors"]),
    "Reverse crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                         prime=["abs"], minor=["hipFlexors", "obliques"]),
    "bicycle crunches": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                           plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Cable Woodchoppers": ex("core", "cable", "isolation", None, weight=30, reps=15,
                             plane="transverse", lat="unilateral",
                             prime=["obliques"], major=["abs"], minor=["lats"]),
    "Trunk Rotation With Cable": ex("core", "cable", "isolation", None, weight=30, reps=15,
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
    "Standing Side Crunches": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                                 plane="frontal", prime=["obliques"], minor=["abs"]),
    "Dumbbell Crunches": ex("core", "dumbbell", "isolation", None, weight=25, reps=15,
                            prime=["abs"], minor=["obliques"]),
    "Crunches With Cable": ex("core", "cable", "isolation", None, weight=80, reps=15,
                              prime=["abs"], minor=["obliques"]),
    "Crunches on Machine": ex("core", "machine", "isolation", None, weight=80, reps=15,
                              prime=["abs"], minor=["obliques"]),
    "Decline Bench Leg Raise": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                                  prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Incline Crunches": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], minor=["obliques"]),
    "Knee Raises": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                      prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Leg Raises, Standing": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                               prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Reverse Plank": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                        tracking="duration", duration=40, bw=0.5,
                        prime=["abs"], minor=["gluteMax", "lowerBack"]),
    "Plank Shoulder Taps": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                              plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"]),
    "Plank Jacks": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                      prime=["abs"], minor=["obliques", "gluteMax"]),
    "L-sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1,
                tracking="duration", duration=20, bw=0.6,
                prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Dragon-flag": ex("core", "bodyweight", "isolation", None, weight=0, reps=8,
                      prime=["abs"], major=["obliques"], minor=["lowerBack", "lats"]),
    "Toe Taps": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                   prime=["abs"], minor=["obliques", "hipFlexors"]),
    "Heel Touches": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                       plane="frontal", prime=["obliques"], minor=["abs"]),
    "Seated Knee Tuck": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], major=["hipFlexors"], minor=["obliques"]),
    "Windshield Wipers": ex("core", "bodyweight", "isolation", None, weight=0, reps=12,
                            plane="transverse", prime=["obliques"], major=["abs"], minor=["hipFlexors"]),
    "Medicine ball twist": ex("core", "other", "isolation", None, weight=10, reps=20,
                              plane="transverse", prime=["obliques"], major=["abs"]),
    "Suitcase Carry": ex("core", "dumbbell", "compound", "carry", weight=50, reps=1,
                         plane="frontal", lat="unilateral", tracking="duration", duration=40,
                         prime=["obliques"], major=["abs"], minor=["traps", "forearms", "gluteMax"],
                         aliases=["Uni-Lateral Farmer Walks", "Unilateral Farmer Walk"]),
    "Butterfly Sit Up": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                           prime=["abs"], minor=["obliques", "hipFlexors"]),
    "Crunches With Legs Up": ex("core", "bodyweight", "isolation", None, weight=0, reps=20,
                                prime=["abs"], minor=["obliques"]),
    "Roman Chair Crunch": ex("core", "bodyweight", "isolation", None, weight=0, reps=15,
                             prime=["abs"], minor=["obliques"]),
    "Rotary Torso Machine": ex("core", "machine", "isolation", None, weight=70, reps=15,
                               plane="transverse", prime=["obliques"], minor=["abs"]),
    "Toes to bar": ex("core", "bodyweight", "isolation", None, weight=0, reps=10,
                      prime=["abs"], major=["hipFlexors"], minor=["obliques", "lats"]),
    "Barbell Ab Rollout": ex("core", "barbell", "isolation", None, weight=0, reps=10,
                             prime=["abs"], minor=["obliques", "lowerBack"]),
    "Ball Slams": ex("core", "other", "isolation", None, weight=20, reps=15,
                     prime=["abs"], major=["obliques", "lats"], minor=["deltoids", "gluteMax"],
                     aliases=["Medicine Ball Slams", "Kneeling Med Ball Slams"]),

    # ===================== Batch 4: deep long-tail pass (parallel droids, round 2) =====================

    # ---- Chest ----
    "Bent over Cable Flye": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Burpees": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps", "quads", "gluteMax"], minor=["deltoids", "abs"]),
    "Cable Fly Middle Chest": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Cable Fly Upper Chest": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Cable Press Around": ex("chest", "cable", "compound", "push", direction="horizontal", weight=30, reps=12, lat="unilateral", prime=["pectorals"], major=["triceps"], minor=["deltoids", "serratus"]),
    "DB Underhand bench press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=40, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Deficit Push ups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Dumbbell Push-Up": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "High plank": ex("chest", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=45, bw=0.6, prime=["abs"], minor=["pectorals", "deltoids", "serratus"]),
    "High-Incline Smith Machine Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=85, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Incline Bench Press - MP": ex("chest", "machine", "compound", "push", direction="horizontal", weight=90, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Incline Shoulder Press Up": ex("chest", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["serratus"], minor=["deltoids", "pectorals"]),
    "Incline Static Hold": ex("chest", "dumbbell", "isolation", None, weight=30, reps=1, tracking="duration", duration=30, prime=["pectorals"], minor=["deltoids"]),
    "Push-Up Wipers": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps"], minor=["deltoids", "abs"]),
    "Legend Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Legend Incline Bench Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=90, reps=10, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Leverage Machine Chest Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=100, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Low-Cable Cross-Over - NB": ex("chest", "cable", "isolation", None, weight=20, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "No Leg Drive Dumbbell Chest Press": ex("chest", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "No push-up burpees": ex("chest", "bodyweight", "compound", "squat", weight=0, reps=12, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["deltoids", "abs"], trace=["pectorals"]),
    "Omni Cable Cross-over": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Ring Support Hold": ex("chest", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, bw=0.95, prime=["pectorals", "triceps"], major=["deltoids"], minor=["serratus", "abs"]),
    "Smith Machine Slight Incline Press": ex("chest", "machine", "compound", "push", direction="horizontal", weight=95, reps=8, prime=["pectorals"], major=["deltoids"], minor=["triceps"]),
    "Seated Cable chest fly": ex("chest", "cable", "isolation", None, weight=25, reps=12, prime=["pectorals"], minor=["deltoids"]),
    "Side to Side Push Ups": ex("chest", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "obliques"]),

    # ---- Back ----
    "1-Arm Half-Kneeling Lat Pulldown": ex("back", "cable", "compound", "pull", direction="vertical", weight=50, reps=12, lat="unilateral", prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"], aliases=["Half-Kneeling Single-Arm Pulldown"]),
    "Alternating High Cable Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=80, reps=12, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Alternating Cable High Row"]),
    "Alternative DB Gorilla rows": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=70, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor", "forearms"], aliases=["Gorilla Row", "Dumbbell Gorilla Row"]),
    "Back Lever": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=15, bw=1.0, prime=["lats", "lowerBack"], minor=["abs", "biceps", "teresMajor"], aliases=["Back Lever Hold"]),
    "Band pull-aparts": ex("back", "band", "isolation", None, weight=0, reps=20, plane="transverse", prime=["rhomboids", "deltoids"], minor=["traps", "teresMajor"], aliases=["Band Pull-Apart"]),
    "Banded Scapular Retraction": ex("back", "band", "isolation", None, weight=0, reps=15, prime=["rhomboids", "traps"], minor=["teresMajor", "deltoids"], aliases=["Banded Scap Retraction"]),
    "Barbell Romanian Deadlift (RDL)": ex("back", "barbell", "compound", "hinge", weight=155, reps=8, prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"], aliases=["Barbell RDL", "Romanian Deadlift", "RDL"]),
    "Barbell Row (Overhand)": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, prime=["lats", "rhomboids"], major=["traps", "biceps"], minor=["teresMajor", "lowerBack"], aliases=["Pronated Barbell Row", "Overhand Bent-Over Row"]),
    "Barbell Row (Underhand)": ex("back", "barbell", "compound", "pull", direction="horizontal", weight=115, reps=8, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor", "lowerBack"], aliases=["Supinated Barbell Row", "Underhand Bent-Over Row"]),
    "Bent over row to external rotation": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=15, reps=12, plane="transverse", prime=["rhomboids", "deltoids"], major=["traps"], minor=["lats", "teresMajor"], aliases=["Row to External Rotation"]),
    "Butterfly Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["lowerBack"], major=["gluteMax"], minor=["rhomboids", "traps", "hamstrings"], aliases=["Superman Butterfly"]),
    "Cross-Body Cable Y-Raise": ex("back", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], major=["traps"], minor=["rhomboids"], aliases=["Cross-Body Y Raise"]),
    "Face pulls with yellow/green band": ex("back", "band", "compound", "pull", direction="horizontal", weight=0, reps=20, prime=["deltoids"], major=["traps", "rhomboids"], minor=["teresMajor"], aliases=["Band Face Pull"]),
    "Front lever tuck": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.7, prime=["lats", "abs"], minor=["lowerBack", "biceps", "teresMajor"], aliases=["Tuck Front Lever"]),
    "High Row": ex("back", "machine", "compound", "pull", direction="horizontal", weight=110, reps=10, prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor"], aliases=["Machine High Row"]),
    "Hip Raise, Lying": ex("back", "bodyweight", "compound", "hinge", weight=0, reps=1, tracking="duration", duration=30, bw=0.5, prime=["gluteMax"], major=["hamstrings"], minor=["lowerBack"], aliases=["Lying Hip Raise"]),
    "Incline Chest-Supported Dumbbell Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=45, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Chest-Supported Incline DB Row", "Dumbbell Prone Row"]),
    "Kneeling Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, lat="unilateral", prime=["lowerBack"], major=["gluteMax"], minor=["traps", "deltoids", "abs"], aliases=["Quadruped Superman"]),
    "Lat Pull Down (Leaning Back)": ex("back", "cable", "compound", "pull", direction="vertical", weight=110, reps=10, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "traps"], aliases=["Leaning-Back Lat Pulldown"]),
    "Lat Pull Down (Straight Back)": ex("back", "cable", "compound", "pull", direction="vertical", weight=100, reps=10, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids"], aliases=["Straight-Back Lat Pulldown"]),
    "Long-Pulley (low Row)": ex("back", "cable", "compound", "pull", direction="horizontal", weight=110, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"], aliases=["Low Cable Row", "Long Pulley Row"]),
    "One-Arm Heavy Row": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=80, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps", "traps"], minor=["teresMajor", "forearms"], aliases=["Heavy One-Arm Dumbbell Row"]),
    "Prone Scapular Retraction - Arms at Side": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.2, prime=["rhomboids", "traps"], minor=["teresMajor", "deltoids"], aliases=["Prone Scap Retraction"]),
    "Pull-up Isometric Hold": ex("back", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=1.0, prime=["lats", "biceps"], minor=["teresMajor", "rhomboids", "forearms"], aliases=["Pull-up Hold", "Flexed-Arm Hang"]),
    "Reverse Cable Flye": ex("back", "cable", "isolation", None, weight=20, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"], aliases=["Reverse Cable Fly"]),
    "Reverse Snow Angel": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.2, prime=["traps", "rhomboids"], minor=["deltoids", "lowerBack"], aliases=["Prone Snow Angel"]),
    "Seated Cable Mid Trap Shrug": ex("back", "cable", "isolation", None, weight=60, reps=15, prime=["traps"], major=["rhomboids"], minor=["teresMajor"], aliases=["Seated Cable Mid-Trap Shrug"]),
    "Seated rear delt rise": ex("back", "dumbbell", "isolation", None, weight=15, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps"], aliases=["Seated Rear Delt Raise"]),
    "Shotgun Row": ex("back", "cable", "compound", "pull", direction="horizontal", weight=50, reps=12, plane="transverse", lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"], minor=["teresMajor", "obliques"], aliases=["Single-Arm Shotgun Row"]),
    "Side Straight-Arm Pulldown (Cable)": ex("back", "cable", "isolation", None, weight=30, reps=15, lat="unilateral", prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Single-Arm Straight-Arm Pulldown"]),
    "Single Arm Plank to Row": ex("back", "kettlebell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["lats", "rhomboids"], major=["biceps"], minor=["abs", "obliques", "deltoids"], aliases=["Plank to Row"]),
    "Skydiver with arms in T-position": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.3, prime=["lowerBack"], major=["traps", "rhomboids"], minor=["gluteMax", "deltoids"], aliases=["Prone T Raise", "Skydiver"]),
    "Straight-arm Pull Down (bar Attachment)": ex("back", "cable", "isolation", None, weight=50, reps=15, prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Straight-Arm Pulldown (Bar)"]),
    "Straight-arm Pull Down (rope Attachment)": ex("back", "cable", "isolation", None, weight=45, reps=15, prime=["lats"], minor=["teresMajor", "triceps"], aliases=["Straight-Arm Pulldown (Rope)"]),
    "Towel Superman": ex("back", "bodyweight", "isolation", None, weight=0, reps=15, bw=0.4, prime=["lowerBack"], major=["gluteMax", "traps"], minor=["rhomboids", "hamstrings"], aliases=["Superman with Towel"]),
    "Trap-3 Raise": ex("back", "dumbbell", "isolation", None, weight=10, reps=15, plane="frontal", lat="unilateral", prime=["traps"], minor=["deltoids", "rhomboids"], aliases=["Lower Trap Raise", "Trap 3 Raise"]),
    "Typewriter Pull-ups": ex("back", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=6, bw=1.0, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "forearms"], aliases=["Typewriter Pull-up"]),

    # ---- Shoulders ----
    "Bus Drivers": ex("shoulders", "other", "isolation", None, weight=25, reps=15, plane="frontal", prime=["deltoids"], minor=["serratus", "traps"]),
    "Band pull-apart with external rotation": ex("shoulders", "band", "isolation", None, weight=0, reps=15, plane="transverse", prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"]),
    "Barbell Silverback Shrug": ex("shoulders", "barbell", "isolation", None, weight=135, reps=12, prime=["traps"], minor=["rhomboids", "deltoids"]),
    "Cable External Rotation": ex("shoulders", "cable", "isolation", None, weight=15, reps=15,
                                   plane="transverse", lat="unilateral",
                                   prime=["deltoids"], minor=["teresMajor"],
                                   aliases=["Shoulder External Rotation (Cable)"]),
    "Cable Rear-Delt Fly (single arm)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["rhomboids", "traps"]),
    "Cable Shrug-In": ex("shoulders", "cable", "isolation", None, weight=80, reps=15, prime=["traps"], minor=["rhomboids"]),
    "Chair dips": ex("shoulders", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.45, prime=["triceps"], minor=["pectorals", "deltoids"]),
    "Clean and Jerk OL": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=135, reps=2, prime=["deltoids"], major=["quads", "gluteMax", "triceps"], minor=["hamstrings", "traps"]),
    "Dumbbell Shrug": ex("shoulders", "dumbbell", "isolation", None, weight=60, reps=12,
                          prime=["traps"], minor=["forearms"], aliases=["Shoulder Shrug"]),
    "Incline OHP DB": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=30, reps=8, prime=["deltoids"], major=["triceps"], minor=["traps"]),
    "Jerk OL": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=135, reps=2, prime=["deltoids"], major=["triceps", "quads", "gluteMax"], minor=["traps"]),
    "Overhead Barbell Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=8,
                                  prime=["deltoids"], major=["triceps"], minor=["traps"],
                                  aliases=["OHP", "Standing Press", "Strict Press", "Barbell Shoulder Press"]),
    "Perpendicular Unilateral Landmine Row": ex("shoulders", "barbell", "compound", "pull", direction="horizontal", weight=60, reps=10, lat="unilateral", prime=["deltoids"], major=["traps"], minor=["rhomboids", "biceps"]),
    "Pin OHP": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=95, reps=5, prime=["deltoids"], major=["triceps"], minor=["traps"]),
    "Seated Dumbbell Side Lateral": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15, plane="frontal", prime=["deltoids"], minor=["traps"]),
    "Shoulder Internal Rotation (Cable)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["pectorals"]),
    "Shoulder Press, on Multi Press": ex("shoulders", "machine", "compound", "push", direction="vertical", weight=70, reps=10, prime=["deltoids"], major=["triceps"], minor=["traps"]),
    "Shoulder Y-pull cable": ex("shoulders", "cable", "compound", "pull", direction="vertical", weight=30, reps=15, prime=["deltoids"], major=["traps"], minor=["rhomboids"]),
    "Shrugs on Multipress": ex("shoulders", "machine", "isolation", None, weight=185, reps=12, prime=["traps"], minor=["forearms"]),
    "Side lateral raise - Back (Cable)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], minor=["traps"]),
    "Side lateral raise - Front (Cable)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=["deltoids"], minor=["traps"]),
    "Side-Lying Dumbbell Internal Rotation": ex("shoulders", "dumbbell", "isolation", None, weight=8, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["pectorals"]),
    "Side-lying External Rotation": ex("shoulders", "dumbbell", "isolation", None, weight=10, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["teresMajor"]),
    "Straight Bar Cable Front Raise": ex("shoulders", "cable", "isolation", None, weight=30, reps=12,
                                          plane="frontal", prime=["deltoids"], minor=["serratus"],
                                          aliases=["Cable Front Raise with a small bar"]),
    "Supine Serratus Punch": ex("shoulders", "dumbbell", "isolation", None, weight=15, reps=15,
                                 plane="transverse", prime=["serratus"],
                                 trace=["deltoids", "triceps"],
                                 aliases=["Dumbbell Serratus Punch", "Serratus Punch"]),
    "Upright Row, on Multi Press": ex("shoulders", "machine", "compound", "pull", direction="vertical", weight=65, reps=12, prime=["deltoids", "traps"], minor=["biceps"]),
    "unilateral cross body cable pull down": ex("shoulders", "cable", "isolation", None, weight=20, reps=15, plane="transverse", lat="unilateral", prime=["deltoids"], minor=["lats", "teresMajor"]),

    # ---- Arms ----
    "Alternating dumbbell hammer curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, lat="unilateral", prime=["biceps"], major=["forearms"]),
    "Barbell Triceps Extension": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "Biceps Curl With Cable": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["biceps"], minor=["forearms"]),
    "Bodyweight Biceps Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.4, prime=["biceps"], minor=["forearms"]),
    "Cable Tri Extension - Internal Rotation": ex("arms", "cable", "isolation", None, weight=40, reps=12, prime=["triceps"]),
    "Cable Tricep Kickback": ex("arms", "cable", "isolation", None, weight=20, reps=15, prime=["triceps"]),
    "Cable Triceps Press": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Curl with kettlebell two hands": ex("arms", "kettlebell", "isolation", None, weight=35, reps=12, prime=["biceps"], minor=["forearms"]),
    "DB Wrist Extension": ex("arms", "dumbbell", "isolation", None, weight=20, reps=15, prime=["forearms"]),
    "Double Kettlebell Clean and Press": ex("arms", "kettlebell", "compound", "push", direction="vertical", weight=35, reps=6, prime=["deltoids"], major=["triceps", "quads"], minor=["traps", "gluteMax"]),
    "Drag Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Dumbbell Cheat Curl": ex("arms", "dumbbell", "isolation", None, weight=40, reps=8, prime=["biceps"], minor=["forearms"]),
    "Dumbbell Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, prime=["biceps"], minor=["forearms"]),
    "Dumbbell Triceps Extension": ex("arms", "dumbbell", "isolation", None, weight=35, reps=12, prime=["triceps"]),
    "Dumbbell Underhand Dead Row": ex("arms", "dumbbell", "compound", "pull", direction="horizontal", weight=50, reps=10, prime=["lats", "rhomboids"], major=["biceps"], minor=["traps", "teresMajor"]),
    "Dumbbell bicep curl to press": ex("arms", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10, prime=["biceps", "deltoids"], major=["triceps"], minor=["traps"]),
    "Dumbbell drag curls": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, prime=["biceps"], minor=["forearms"]),
    "Dumbbell wide bicep curls": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"]),
    "Dumbbells on Scott Machine": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Elbows Tucked DB Bench Press": ex("arms", "dumbbell", "compound", "push", direction="horizontal", weight=45, reps=10, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Finger Pushup": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "forearms"]),
    "Floor Skull Crusher": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "Floor dips": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12,
                      bw=0.45, prime=["triceps"], minor=["pectorals", "deltoids"],
                      aliases=["Bench Dips On Floor HD"]),
    "Forearm Curls (underhand grip)": ex("arms", "dumbbell", "isolation", None, weight=25, reps=15, prime=["forearms"]),
    "High-Cable Cross Tricep Extention - NB": ex("arms", "cable", "isolation", None, weight=30, reps=12, prime=["triceps"]),
    "Incline Close Grip Barbell Bench Press": ex("arms", "barbell", "compound", "push", direction="horizontal", weight=95, reps=8, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "Incline Skull Crush": ex("arms", "barbell", "isolation", None, weight=55, reps=10, prime=["triceps"]),
    "L-Sit Pull-ups": ex("arms", "bodyweight", "compound", "pull", direction="vertical", weight=0, reps=8, bw=1.0, prime=["lats"], major=["biceps"], minor=["teresMajor", "rhomboids", "abs", "hipFlexors"]),
    "Lying Dumbbell Curls": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Lying Triceps Kickback": ex("arms", "dumbbell", "isolation", None, weight=20, reps=12, prime=["triceps"]),
    "One Arm Overhead Cable Tricep Extension": ex("arms", "cable", "isolation", None, weight=25, reps=12, lat="unilateral", prime=["triceps"]),
    "Overhead Cable Tricep Extension": ex("arms", "cable", "isolation", None, weight=40, reps=12, prime=["triceps"]),
    "Pike Push Ups": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=12, bw=0.6, prime=["deltoids"], major=["triceps"], minor=["pectorals"]),
    "Preacher Curl - Externally Rotated": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Preacher Curl - Internally Rotated": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["biceps"], minor=["forearms"]),
    "Push-up rotations": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids", "obliques", "abs"]),
    "Reverse Bar Curl": ex("arms", "barbell", "isolation", None, weight=45, reps=12,
                            prime=["biceps"], major=["forearms"], aliases=["Reverse Curl"]),
    "Reverse EZ Bar Cable Curls": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["biceps"], major=["forearms"]),
    "Reverse Grip Barbell Curls": ex("arms", "barbell", "isolation", None, weight=45, reps=12, prime=["biceps"], major=["forearms"]),
    "Rocking Triceps Pushdown": ex("arms", "cable", "isolation", None, weight=60, reps=12, prime=["triceps"]),
    "Seated Triceps Press": ex("arms", "dumbbell", "isolation", None, weight=35, reps=12, prime=["triceps"]),
    "Seated W Curl": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"]),
    "Shoulder width three-point push-up": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=12, bw=0.6, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "Single-arm Preacher Curl": ex("arms", "dumbbell", "isolation", None, weight=20, reps=10, lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Skullcrusher Dumbbells": ex("arms", "dumbbell", "isolation", None, weight=25, reps=10, prime=["triceps"]),
    "Standing Bicep Curl": ex("arms", "dumbbell", "isolation", None, weight=30, reps=10, prime=["biceps"], minor=["forearms"]),
    "Standing Rope Forearm": ex("arms", "cable", "isolation", None, weight=40, reps=15, prime=["forearms"]),
    "TRX Tricep Extension": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["triceps"]),
    "TRX dips": ex("arms", "bodyweight", "compound", "push", direction="vertical", weight=0, reps=10, bw=0.9, prime=["triceps"], major=["pectorals"], minor=["deltoids"]),
    "TRX gorilla biceps curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["biceps"], minor=["forearms"]),
    "TRX hammer curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=12, bw=0.5, prime=["biceps"], major=["forearms"]),
    "Tricep Rope Pushdowns": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=["triceps"]),
    "Triceps Extensions on Cable With Bar": ex("arms", "cable", "isolation", None, weight=55, reps=12, prime=["triceps"]),
    "Trx Single Arm Bicep Curl": ex("arms", "bodyweight", "isolation", None, weight=0, reps=10, bw=0.5, lat="unilateral", prime=["biceps"], minor=["forearms"]),
    "Wall Pushup": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.3, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),
    "knee push-ups": ex("arms", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=15, bw=0.5, prime=["pectorals"], major=["triceps"], minor=["deltoids"]),

    # ---- Legs ----
    "1 Leg Box Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8, lat="unilateral", bw=0.85, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Barbell Hack Squats": ex("legs", "barbell", "compound", "squat", weight=185, reps=8, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["lowerBack"]),
    "Belt Squat": ex("legs", "machine", "compound", "squat", weight=180, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Bodyweight Squat HD": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Braced Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=15, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Double Kettlebell Front Squat": ex("legs", "kettlebell", "compound", "squat", weight=70, reps=8, prime=["quads"], major=["gluteMax"], minor=["abs", "adductors"]),
    "Hindu Squats": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=25, bw=0.6, prime=["quads", "gluteMax"], minor=["calves", "hamstrings"]),
    "Isometric Squat to Failure": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=1, tracking="duration", duration=60, bw=0.6, prime=["quads", "gluteMax"], minor=["adductors"]),
    "Landmine Squat to Press": ex("legs", "barbell", "compound", "squat", weight=65, reps=10, prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Leg Press on Hackenschmidt Machine": ex("legs", "machine", "compound", "squat", weight=270, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Leg Presses (narrow)": ex("legs", "machine", "compound", "squat", weight=270, reps=12, prime=["quads"], major=["gluteMax"], minor=["hamstrings"]),
    "Leg Presses (wide)": ex("legs", "machine", "compound", "squat", weight=270, reps=12, prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Low Box Squat - Wide Stance": ex("legs", "barbell", "compound", "squat", weight=185, reps=6, prime=["quads", "gluteMax"], major=["hamstrings", "adductors"], minor=["lowerBack"]),
    "Pause Hack Squats": ex("legs", "machine", "compound", "squat", weight=160, reps=10, prime=["quads"], major=["gluteMax"], minor=["hamstrings"]),
    "Pendulum Squat": ex("legs", "machine", "compound", "squat", weight=180, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Prisoner Squat": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=20, bw=0.6, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Shrimp Squad": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=8, lat="unilateral", bw=0.85, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Squat Jumps": ex("legs", "bodyweight", "compound", "squat", weight=0, reps=15, bw=0.6, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings"]),
    "Wall balls": ex("legs", "other", "compound", "squat", weight=20, reps=15, prime=["quads", "gluteMax"], major=["deltoids"], minor=["triceps", "abs"]),
    "Dumbbell Deadlift": ex("legs", "dumbbell", "compound", "hinge", weight=70, reps=10, prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["quads", "forearms"]),
    "Dumbbell Frog Pump": ex("legs", "dumbbell", "compound", "hinge", weight=45, reps=15, prime=["gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Glute Drive": ex("legs", "machine", "compound", "hinge", weight=180, reps=12, prime=["gluteMax"], major=["hamstrings"], minor=["quads"]),
    "Hip Bridge": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=20, bw=0.4, prime=["gluteMax"], minor=["hamstrings"]),
    "Kettlebell One Legged Deadlift": ex("legs", "kettlebell", "compound", "hinge", weight=35, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Kickstand RDL": ex("legs", "dumbbell", "compound", "hinge", weight=45, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["forearms"]),
    "Speed Deadlift": ex("legs", "barbell", "compound", "hinge", weight=185, reps=3, prime=["gluteMax", "hamstrings", "lowerBack"], major=["traps", "forearms"], minor=["quads", "lats"]),
    "Unilateral Hip Thrust": ex("legs", "bodyweight", "compound", "hinge", weight=0, reps=15, lat="unilateral", bw=0.5, prime=["gluteMax"], major=["hamstrings"], minor=["quads"]),
    "dumbbell snatch": ex("legs", "dumbbell", "compound", "hinge", weight=40, reps=8, lat="unilateral", prime=["gluteMax", "hamstrings"], major=["deltoids", "quads"], minor=["traps", "lowerBack", "forearms"]),
    "Barbell Lunges Walking": ex("legs", "barbell", "compound", "lunge", weight=95, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Dumbbell Lunges Walking": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=12,
                                  lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"],
                                  minor=["adductors"], aliases=["Walking Lunges", "Walking Lunge"]),
    "Dumbbell Side Squat": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=10, plane="frontal", lat="unilateral", prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Reverse lunges": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, lat="unilateral", bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Single-Leg Lunge with Kettlebell": ex("legs", "kettlebell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors"]),
    "Sliding Lateral Lunge": ex("legs", "bodyweight", "compound", "lunge", weight=0, reps=12, plane="frontal", lat="unilateral", prime=["quads", "gluteMax"], major=["adductors"], minor=["hamstrings"]),
    "Dumbbell farmer's carry": ex("legs", "dumbbell", "compound", "carry", weight=60, reps=1, tracking="duration", duration=40, prime=["forearms", "traps"], major=["gluteMax", "quads"], minor=["abs", "obliques"]),
    "Calf Press Using Leg Press Machine": ex("legs", "machine", "isolation", None, weight=200, reps=15, prime=["calves"]),
    "Exercise Band Plantarflexion": ex("legs", "band", "isolation", None, weight=0, reps=20, prime=["calves"]),
    "Exercise Band Dorsiflexion": ex("legs", "band", "isolation", None, weight=0, reps=20, prime=["shins"]),
    "Tibialis raises": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20, prime=["shins"]),
    "Abduction while standing": ex("legs", "cable", "isolation", None, weight=30, reps=15, plane="frontal", lat="unilateral", prime=["gluteMax"]),
    "Supine Hip Abduction": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20, plane="frontal", bw=0.15, prime=["gluteMax"]),
    "Single-leg side glute press": ex("legs", "machine", "isolation", None, weight=50, reps=15, lat="unilateral", prime=["gluteMax"], minor=["adductors"]),
    "rubber band glute kickback": ex("legs", "band", "isolation", None, weight=0, reps=15, lat="unilateral", prime=["gluteMax"], minor=["hamstrings"]),

    # ---- Core ----
    "Bag training": ex("core", "other", "isolation", None, weight=0, reps=1, tracking="duration", duration=120, prime=["deltoids"], major=["pectorals", "obliques"], minor=["abs", "triceps", "lats"]),
    "Ball crunches": ex("core", "other", "isolation", None, weight=0, reps=20, prime=["abs"], minor=["obliques"]),
    "Battle Ropes": ex("core", "other", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, prime=["deltoids", "abs"], major=["forearms", "obliques"], minor=["lats", "biceps", "traps"]),
    "Bear crawl pull through": ex("core", "dumbbell", "isolation", None, weight=25, reps=12, plane="transverse", prime=["abs"], major=["obliques", "deltoids"], minor=["gluteMax", "quads"]),
    "Black Widow Knee Slides": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Clamshell": ex("legs", "bodyweight", "isolation", None, weight=0, reps=20,
                     plane="transverse", lat="unilateral", bw=0.15,
                     prime=["gluteMed"], minor=["gluteMax"], trace=["abs"]),
    "Side-Plank Clamshell": ex("core", "bodyweight", "compound", "core", weight=0, reps=12,
                                plane="frontal", lat="unilateral", bw=0.5,
                                prime=["obliques", "gluteMed"],
                                minor=["abs", "gluteMax", "deltoids", "serratus"],
                                trace=["lowerBack", "triceps"]),
    "Double-Leg Abdominal Press": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, prime=["abs"], minor=["hipFlexors", "obliques"]),
    "Plank In-and-Out Jump": ex("core", "bodyweight", "compound", "core", weight=0, reps=12,
                                  bw=0.6, prime=["abs"], major=["hipFlexors", "quads"],
                                  minor=["deltoids", "serratus", "gluteMax"]),
    "Kettlebell Suitcase Hold with March": ex("core", "kettlebell", "compound", "carry", weight=20,
                                                reps=1, tracking="duration", duration=30,
                                                plane="frontal", lat="unilateral",
                                                prime=["obliques"], minor=["abs", "lowerBack", "gluteMed"],
                                                trace=["forearms", "deltoids"]),
    "Frog stand": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.6, prime=["abs"], major=["deltoids"], minor=["forearms", "biceps"]),
    "Front Lever": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=10, bw=1.0, prime=["abs", "lats"], minor=["obliques", "forearms"]),
    "Front lever pull-up": ex("core", "bodyweight", "compound", "pull", direction="horizontal", weight=0, reps=5, bw=1.0, prime=["lats"], major=["abs", "biceps"], minor=["deltoids", "forearms"]),
    "Full Sit Outs": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["abs"], major=["obliques"], minor=["gluteMax", "deltoids"]),
    "High Knee Jumps": ex("core", "bodyweight", "compound", "squat", weight=0, reps=8, prime=["hipFlexors", "quads"], major=["calves"], minor=["abs"]),
    "High knees": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, aliases=["Running in place"], prime=["hipFlexors"], major=["quads", "calves"], minor=["abs"]),
    "Incline Plank With Alternate Floor Touch": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"]),
    "Jump rope: basic jumps": ex("core", "other", "isolation", None, weight=0, reps=1, tracking="duration", duration=60, prime=["calves"], minor=["quads", "abs", "forearms"]),
    "L-Sit (Foot Supported)": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Landmine Rotation": ex("core", "barbell", "isolation", None, weight=25, reps=12, plane="transverse", prime=["obliques"], major=["abs"], minor=["deltoids"], aliases=["Landmine Rotations"]),
    "One armed push-ups": ex("core", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=6, bw=0.7, lat="unilateral", prime=["pectorals", "triceps"], major=["abs", "obliques"], minor=["deltoids"]),
    "Plank Reach": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, plane="transverse", prime=["abs"], major=["obliques"], minor=["deltoids"], aliases=["Plank with Arm Reach"]),
    "Plank-to-Elbow Extension": ex("core", "bodyweight", "isolation", None, weight=0, reps=16, prime=["abs"], major=["obliques"], minor=["deltoids", "triceps"]),
    "Seated Corkscrew": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["hipFlexors"]),
    "Side Bends on Machine": ex("core", "machine", "isolation", None, weight=70, reps=15, plane="frontal", prime=["obliques"], minor=["abs"]),
    "Sit Up Elbow Thrust": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Sled Push": ex("core", "other", "compound", "squat", weight=90, reps=1, tracking="duration", duration=30, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings", "deltoids"]),
    "Splinter Sit-ups": ex("core", "bodyweight", "isolation", None, weight=0, reps=15, plane="transverse", prime=["abs"], major=["obliques"], minor=["hipFlexors"]),
    "Step Jack": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=30, plane="frontal", aliases=["Side Step Jack", "Low Impact Jumping Jack"], prime=["quads"], major=["gluteMax"], minor=["abs", "deltoids", "calves"]),
    "Straddle L-Sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["quads", "triceps"]),
    "Torso Twist": ex("core", "bodyweight", "isolation", None, weight=0, reps=20, plane="transverse", prime=["obliques"], major=["abs"]),
    "TRX Obliques": ex("core", "other", "isolation", None, weight=0, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["serratus", "deltoids"]),
    "Tuck L-sit": ex("core", "bodyweight", "isolation", None, weight=0, reps=1, tracking="duration", duration=20, bw=0.5, prime=["abs"], major=["hipFlexors"], minor=["triceps"]),
    "Turkish Get-Up": ex("core", "dumbbell", "compound", "core", weight=35, reps=5, lat="unilateral", prime=["deltoids"], major=["gluteMax", "obliques"], minor=["abs", "quads", "triceps"]),
    "box jumps": ex("core", "bodyweight", "compound", "squat", weight=0, reps=10, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings"]),

    # ===================== Batch 5: residual real lifts (parallel droids, round 3) =====================
    # (Stretches, cardio, non-English duplicates, and junk deliberately left as fallbacks.)

    "Inverted Rows": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=10, bw=0.6, aliases=["Bodyweight Row", "Australian Pullup", "Supine Row"], prime=("lats",), major=("rhomboids", "traps", "biceps"), minor=("deltoids", "forearms"), trace=("abs",)),

    "Back bridge": ex("legs", "bodyweight", "compound", "hinge", reps=1, bw=0.5, tracking="duration", duration=30, prime=("gluteMax",), major=("lowerBack", "hamstrings"), minor=("quads",), trace=("deltoids",)),
    "Front Wood Chop": ex("core", "cable", "compound", "core", weight=30, reps=14, plane="transverse", lat="unilateral", prime=("obliques",), major=("abs",), minor=("deltoids", "lats"), trace=("serratus",)),
    "Lat Pull DB": ex("back", "dumbbell", "compound", "pull", direction="vertical", weight=45, reps=12, prime=("lats",), major=("teresMajor",), minor=("pectorals", "triceps"), trace=("serratus",), aliases=["Dumbbell Lat Pullover"]),
    "Reverse Wood Chops": ex("core", "cable", "compound", "core", weight=30, reps=14, plane="transverse", lat="unilateral", prime=("obliques",), major=("abs",), minor=("deltoids", "gluteMax"), trace=("lats",)),
    "Side Lateral Raise (Cable)": ex("shoulders", "cable", "isolation", None, weight=15, reps=15, plane="frontal", lat="unilateral", prime=("deltoids",), trace=("traps", "serratus")),
    "Upper Back": ex("back", "machine", "compound", "pull", direction="horizontal", weight=70, reps=12, plane="transverse", prime=("rhomboids",), major=("traps", "teresMajor"), minor=("deltoids", "lats"), trace=("biceps",)),

    "Kreis Press DB": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=35, reps=10, aliases=["Circle Press"], prime=("deltoids",), major=("triceps",), minor=("traps",), trace=("serratus",)),
    "Codman Pendulum": ex("shoulders", "other", "isolation", None, reps=15,
                           lat="unilateral", aliases=["Codman Exercise", "Shoulder Pendulum"],
                           trace=("deltoids", "externalRotators")),
    "Tuck planche": ex("shoulders", "bodyweight", "compound", "push", direction="horizontal", weight=0, reps=1, bw=0.7, tracking="duration", duration=15, aliases=["Tuck Planche Hold"], prime=("deltoids",), major=("abs", "serratus"), minor=("pectorals", "triceps"), trace=("forearms", "lowerBack")),

    "Curl  - With Shoulder Elevated": ex("arms", "dumbbell", "isolation", None, weight=25, reps=12, prime=["biceps"], minor=["forearms"], aliases=["Shoulder-Elevated Curl", "Shoulder Flexed Curl"]),
    "Glute Bridge Single-Arm Press": ex("core", "dumbbell", "compound", "push", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["pectorals", "triceps"], major=["gluteMax"], minor=["deltoids", "abs"], aliases=["Glute Bridge Floor Press", "Single-Arm Bridge Press"]),

    "Calf Raises on Hackenschmitt Machine": ex("legs", "machine", "isolation", None, weight=150, reps=15,
                                                prime=("calves",), aliases=["Calf Raise using Hack Squat Machine"]),
    "Dragon squat": ex("legs", "bodyweight", "compound", "squat", reps=8, lat="unilateral", bw=0.6, prime=("quads", "gluteMax"), major=("hamstrings", "adductors"), minor=("calves",), trace=("abs",)),
    "Hamstring Kicks": ex("legs", "bodyweight", "isolation", None, reps=15, lat="unilateral", prime=("hamstrings",), minor=("gluteMax", "calves")),
    "Hip hinge": ex("legs", "bodyweight", "compound", "hinge", reps=15, bw=0.5, prime=("hamstrings", "gluteMax"), major=("lowerBack",), trace=("abs",)),
    "Horse Stance (Side Splits)": ex("legs", "bodyweight", "compound", "squat", reps=1, tracking="duration", duration=30, bw=0.6, prime=("quads", "adductors"), major=("gluteMax",), minor=("calves",), trace=("abs",)),
    "Jumping Jacks": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, plane="frontal", prime=("calves",), major=("deltoids", "gluteMax"), minor=("quads",), trace=("abs",)),
    "Lateral Push Off": ex("legs", "bodyweight", "compound", "lunge", reps=12, plane="frontal", lat="unilateral", bw=0.5, prime=("quads", "gluteMax"), major=("adductors", "calves"), minor=("hamstrings",), trace=("abs",)),
    "Leg Curl": ex("legs", "machine", "isolation", None, weight=70, reps=12, prime=("hamstrings",), minor=("calves",)),
    "Leg Raise": ex("core", "bodyweight", "compound", "core", reps=15, bw=0.3, prime=("abs",), major=("hipFlexors",), minor=("obliques",)),
    "Marching High Knees": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, prime=("hipFlexors",), major=("quads", "calves"), minor=("gluteMax", "abs")),
    "Plank with Alternating Leg Lift": ex("core", "bodyweight", "compound", "core", reps=12, lat="unilateral", bw=0.6, prime=("abs",), major=("gluteMax",), minor=("obliques", "lowerBack"), trace=("deltoids", "hipFlexors")),
    "Side Slides + Squats": ex("legs", "bodyweight", "compound", "squat", reps=12, plane="frontal", bw=0.5, prime=("quads", "gluteMax"), major=("adductors", "hamstrings"), minor=("calves",), trace=("abs",)),
    "Slow Squat": ex("legs", "bodyweight", "compound", "squat", reps=12, bw=0.6, prime=("quads", "gluteMax"), major=("hamstrings",), minor=("adductors", "calves"), trace=("abs",)),
    "Squat Thrust": ex("legs", "bodyweight", "compound", "squat", reps=15, bw=0.5, prime=("quads", "gluteMax"), major=("hipFlexors", "abs"), minor=("hamstrings", "deltoids", "calves")),
    "Squats on Multipress": ex("legs", "machine", "compound", "squat", weight=135, reps=8, aliases=["Smith Machine Squat"], prime=("quads", "gluteMax"), major=("hamstrings",), minor=("adductors", "calves"), trace=("lowerBack", "abs")),
    "Weighted Step-ups": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=12, lat="unilateral", prime=("quads", "gluteMax"), major=("hamstrings",), minor=("calves", "adductors"), trace=("abs",)),

    "Box squat": ex("legs", "barbell", "compound", "squat", weight=135, reps=6, prime=("quads", "gluteMax"), major=("hamstrings",), minor=("adductors", "lowerBack"), trace=("abs", "calves"), aliases=["Box Squat"]),
    "High Knee Skips HD": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, prime=("hipFlexors", "calves"), major=("quads",), minor=("gluteMax", "hamstrings"), trace=("abs",), aliases=["High Knee Skips"]),
    "commando pull-ups": ex("back", "bodyweight", "compound", "pull", direction="vertical", reps=8, bw=1.0, prime=("lats",), major=("biceps", "rhomboids"), minor=("traps", "teresMajor", "forearms"), trace=("abs",), aliases=["Commando Pull-Up", "Alternating Grip Pull-Up"]),
    "TRX Rows": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=12, bw=0.6, prime=("lats", "rhomboids"), major=("biceps", "traps"), minor=("teresMajor", "deltoids"), trace=("forearms", "abs"), aliases=["TRX Inverted Row"]),
    "Horizontal traction isometry": ex("back", "bodyweight", "compound", "pull", direction="horizontal", reps=1, bw=0.6, tracking="duration", duration=30, prime=("lats", "rhomboids"), major=("biceps", "traps"), minor=("teresMajor", "deltoids"), trace=("forearms", "abs"), aliases=["Isometric Row Hold"]),
    "Suspended crossess": ex("chest", "bodyweight", "isolation", None, reps=12, bw=0.5, prime=("pectorals",), minor=("deltoids",), trace=("biceps", "serratus", "abs"), aliases=["TRX Chest Fly", "Suspended Crossover"]),
    "Biceps with TRX": ex("arms", "bodyweight", "isolation", None, reps=12, bw=0.5, prime=("biceps",), minor=("forearms",), trace=("deltoids",), aliases=["TRX Biceps Curl"]),
    "Overhand Cable Curl": ex("arms", "cable", "isolation", None, weight=50, reps=12, prime=("biceps", "forearms"), trace=("deltoids",), aliases=["Cable Reverse Curl"]),
    "Weighted Crunch": ex("core", "dumbbell", "isolation", None, weight=25, reps=12, prime=("abs",), minor=("obliques",), trace=("hipFlexors",)),
    "Medicine ball booklet crunch": ex("core", "other", "compound", "core", weight=10, reps=12, prime=("abs", "hipFlexors"), minor=("obliques",), trace=("quads",), aliases=["Weighted V-Up", "Jackknife Crunch"]),

    # ===================== Batch 6: genuine grip / forearm isometric holds =====================
    "Deadhang": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=30, prime=("forearms",), major=("lats",), minor=("teresMajor",), trace=("biceps", "deltoids"), aliases=["Dead Hang", "Bar Hang"]),
    "Hand Grip": ex("arms", "other", "isolation", None, reps=15, prime=("forearms",), aliases=["Gripper", "Hand Gripper", "Grip Trainer"]),
    "Plate Pinch Hold": ex("arms", "other", "isolation", None, weight=25, reps=1, tracking="duration", duration=30, prime=("forearms",), aliases=["Pinch Grip Hold", "Plate Pinch"]),
    "Fingerboard 20 mm edge": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=10, prime=("forearms",), minor=("lats", "biceps", "teresMajor"), aliases=["Hangboard 20mm Edge", "Fingerboard Hang"]),
    "Sloper hanging": ex("arms", "bodyweight", "isolation", None, reps=1, bw=1.0, tracking="duration", duration=15, prime=("forearms",), minor=("lats", "biceps"), aliases=["Sloper Hang", "Hangboard Sloper"]),
    "Pullup on fingerboard": ex("back", "bodyweight", "compound", "pull", direction="vertical", reps=5, bw=1.0, prime=("lats",), major=("biceps", "forearms"), minor=("teresMajor", "rhomboids"), trace=("traps",), aliases=["Hangboard Pull-up", "Fingerboard Pull-up"]),

    # ===================== Batch 8: activation =====================
    # App-authored activation drills. Activation work loads and primes
    # the muscle, so it credits its muscles by set count like any other
    # strength move. Iso holds use duration tracking. Each drill is
    # filed under the muscle group it primarily trains.
    "Banded Side Clams": ex("legs", "band", "isolation", None, reps=15, plane="frontal", lat="unilateral", prime=["gluteMax"], minor=["adductors"], aliases=["Banded Clamshell"]),
    "Hinge with Broomstick": ex("legs", "bodyweight", "compound", "hinge", reps=10, bw=0.3, prime=["hamstrings", "gluteMax"], minor=["lowerBack"], trace=["abs"]),
    "Single Leg Clockface": ex("legs", "bodyweight", "compound", None, reps=8, lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Banded 1.5 Squats": ex("legs", "band", "compound", "squat", reps=10, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs", "lowerBack"]),
    "Prone Banded Press": ex("shoulders", "band", "isolation", None, reps=15, prime=["deltoids"], minor=["rhomboids", "traps", "teresMajor"]),
    "Quadruped Hip Extensions": ex("legs", "bodyweight", "isolation", None, reps=15, lat="unilateral", bw=0.3, prime=["gluteMax"], minor=["hamstrings", "lowerBack"]),
    "Fire Hydrants": ex("legs", "bodyweight", "isolation", None, plane="frontal", reps=15, lat="unilateral", bw=0.2, prime=["gluteMax"], minor=["adductors"]),
    "Prisoner Squats with Overhead Reach": ex("legs", "bodyweight", "compound", "squat", reps=12, bw=0.5, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["deltoids", "adductors"], trace=["abs", "calves"]),
    "Banded Side Walks": ex("legs", "band", "isolation", None, plane="frontal", reps=15, prime=["gluteMax"], minor=["adductors", "quads"], aliases=["Lateral Walk", "Banded Lateral Walk", "Monster Walk"]),
    "Banded External Rotations": ex("shoulders", "band", "isolation", None, plane="transverse", reps=15, prime=["teresMajor"], minor=["deltoids"], trace=["rhomboids"]),
    "Banded Shadow Box": ex("shoulders", "band", "compound", "push", direction="horizontal", reps=1, tracking="duration", duration=30, plane="transverse", prime=["deltoids"], major=["pectorals", "triceps"], minor=["serratus", "obliques"], trace=["forearms"]),
    "Standing Plate Rotations": ex("core", "other", "compound", "core", weight=10, reps=15, plane="transverse", prime=["obliques"], major=["abs"], minor=["lowerBack"], trace=["deltoids"]),

    # ===================== Batch 9: plyometrics / fight circuit =====================
    # Explosive jump / bound / footwork work. The muscle model is load-
    # and velocity-agnostic, so these credit their muscles by set count
    # exactly like any bodyweight strength move. Footwork drills with no
    # countable rep are logged as timed holds. CMJ = counter-movement jump.
    "Ice Skaters": ex("legs", "bodyweight", "compound", "lunge", reps=20, plane="frontal", lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["hamstrings"], trace=["abs"], aliases=["Skater Hops", "Speed Skaters"]),
    "Altitude Landings": ex("legs", "bodyweight", "compound", "squat", reps=10, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Drop Landing", "Depth Drop"]),
    "Altitude Landings to Jump": ex("legs", "bodyweight", "compound", "squat", reps=10, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Depth Jump", "Drop Jump"]),
    "Altitude Landings to Lateral Shuffle": ex("legs", "bodyweight", "compound", "lunge", reps=10, plane="frontal", lat="unilateral", bw=0.6, prime=["quads", "gluteMax"], major=["adductors", "calves"], minor=["hamstrings"], trace=["abs"]),
    "Hop + Hold": ex("legs", "bodyweight", "compound", "squat", reps=10, lat="unilateral", bw=0.5, prime=["quads", "gluteMax"], major=["calves"], minor=["hamstrings", "adductors"], trace=["abs"], aliases=["Stick the Landing", "Jump and Stick"]),
    "Pogos": ex("legs", "bodyweight", "compound", "squat", reps=20, bw=0.4, prime=["calves"], major=["quads"], minor=["gluteMax", "hamstrings"], trace=["shins", "abs"], aliases=["Pogo Hops", "Ankle Hops"]),
    "Dumbbell CMJ (2 kg each hand)": ex("legs", "dumbbell", "compound", "squat", weight=5, reps=8, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["deltoids"], trace=["abs"], aliases=["Dumbbell Countermovement Jump", "Loaded CMJ", "Dumbbell CMJ"]),
    "Falling CMJ": ex("legs", "bodyweight", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Falling Countermovement Jump"]),
    "Banded Accentuated CMJ": ex("legs", "band", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Banded Countermovement Jump"]),
    "CMJ with Hands on Hips": ex("legs", "bodyweight", "compound", "squat", reps=8, bw=0.6, prime=["quads", "gluteMax"], major=["calves", "hamstrings"], minor=["adductors"], trace=["abs"], aliases=["Countermovement Jump", "Vertical Jump"]),
    "Ice Skaters to Vertical Hop": ex("legs", "bodyweight", "compound", "lunge", reps=16, plane="frontal", lat="unilateral", bw=0.5, prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["hamstrings"], trace=["abs"]),
    "Ice Skaters with Medicine Ball": ex("legs", "other", "compound", "lunge", weight=10, reps=16, plane="frontal", lat="unilateral", prime=["gluteMax", "quads"], major=["adductors", "calves"], minor=["deltoids", "hamstrings"], trace=["abs"]),
    "Criss Cross Jump": ex("legs", "bodyweight", "compound", "squat", reps=20, plane="frontal", bw=0.4, prime=["calves", "quads"], major=["adductors", "gluteMax"], minor=["hamstrings"], trace=["abs"], aliases=["Crossover Jacks", "Cross Jacks"]),
    "Ali Shuffle": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, bw=0.3, prime=["calves"], major=["quads", "hipFlexors"], minor=["gluteMax"], trace=["abs"]),
    "Slow Hands, Fast Feet": ex("legs", "bodyweight", "compound", None, reps=1, tracking="duration", duration=30, bw=0.3, prime=["calves"], major=["quads", "hipFlexors"], minor=["deltoids", "gluteMax"], trace=["abs"]),

    # ===================== Batch 10: key strength exercises =====================
    # Loaded primary lifts and their implement / stance variants
    # (goblet, landmine, half-kneeling, banded). Landmine work uses the
    # barbell equipment (the bar in a pivot), matching the existing
    # landmine entries. Throws and explosive derivatives are classified as
    # power below; static wall holds are classified as isometric strength.
    # — Lower body —
    "Goblet Squat to Press": ex("legs", "dumbbell", "compound", "squat", weight=40, reps=10, prime=["quads", "gluteMax"], major=["deltoids", "hamstrings"], minor=["triceps", "abs"], trace=["calves", "adductors"], aliases=["Goblet Thruster"]),
    "Goblet Split Squat": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Goblet Reverse Lunge": ex("legs", "dumbbell", "compound", "lunge", weight=35, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "calves"], trace=["abs"]),
    "Goblet Reverse Lunge with Knee Raise": ex("legs", "dumbbell", "compound", "lunge", weight=30, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings", "hipFlexors"], minor=["adductors", "calves"], trace=["abs"]),
    "Landmine Squat": ex("legs", "barbell", "compound", "squat", weight=70, reps=10, prime=["quads", "gluteMax"], major=["hamstrings"], minor=["adductors", "lowerBack"], trace=["abs", "calves"]),
    "Landmine Reverse Lunge with Knee Raise": ex("legs", "barbell", "compound", "lunge", weight=50, reps=10, lat="unilateral", prime=["quads", "gluteMax"], major=["hamstrings", "hipFlexors"], minor=["adductors"], trace=["abs", "deltoids"]),
    "Landmine Single Leg RDL": ex("legs", "barbell", "compound", "hinge", weight=50, reps=10, lat="unilateral", prime=["hamstrings", "gluteMax"], major=["lowerBack"], minor=["adductors", "forearms"], trace=["abs"]),
    "Trap Bar Deadlift": ex("legs", "barbell", "compound", "hinge", weight=225, reps=6, weight_kg=100, prime=["gluteMax", "quads"], major=["hamstrings", "lowerBack"], minor=["traps", "forearms"], trace=["abs"], aliases=["Hex Bar Deadlift"]),
    "Banded Single Leg Hip Thrusts": ex("legs", "band", "compound", "hinge", reps=12, lat="unilateral", bw=0.4, prime=["gluteMax"], major=["hamstrings"], minor=["abs"], trace=["quads"]),
    # — Upper body push —
    "½ Kneeling Dumbbell Press": ex("shoulders", "dumbbell", "compound", "push", direction="vertical", weight=25, reps=10, lat="unilateral", prime=["deltoids"], major=["triceps"], minor=["traps", "abs"], trace=["obliques"], aliases=["Half-Kneeling Dumbbell Press", "Half Kneeling DB Press"]),
    "½ Kneeling Landmine Press": ex("shoulders", "barbell", "compound", "push", direction="vertical", weight=45, reps=10, lat="unilateral", prime=["deltoids"], major=["triceps", "pectorals"], minor=["serratus", "abs"], trace=["obliques"], aliases=["Half-Kneeling Landmine Press"]),
    "KB Press-Ups with Bands": ex("chest", "band", "compound", "push", direction="horizontal", reps=10, bw=0.64, prime=["pectorals"], major=["triceps"], minor=["deltoids"], trace=["serratus", "abs"], aliases=["Banded Push-Up", "Band-Resisted Push-Up"]),
    "Landmine Punch": ex("shoulders", "barbell", "compound", "push", direction="horizontal", weight=45, reps=10, lat="unilateral", plane="transverse", prime=["deltoids"], major=["pectorals", "serratus"], minor=["triceps", "obliques"], trace=["abs"], aliases=["Landmine Press-Out"]),
    "Medicine Ball Punch Throw": ex("chest", "other", "compound", "push", direction="horizontal", weight=8, reps=10, lat="unilateral", prime=["pectorals"], major=["deltoids", "triceps"], minor=["serratus", "obliques"], trace=["abs"], aliases=["Med Ball Punch", "Med Ball Press Throw"]),
    "Isometric 3-Sec Wall Holds": ex("chest", "bodyweight", "compound", "push", direction="horizontal", reps=1, tracking="duration", duration=30, prime=["pectorals"], major=["deltoids", "triceps"], minor=["serratus"], trace=["abs"], aliases=["Isometric Wall Press"]),
    # — Upper body pull —
    "Kettlebell Row and Rotate": ex("back", "kettlebell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", plane="transverse", prime=["lats"], major=["rhomboids", "biceps"], minor=["obliques", "traps"], trace=["teresMajor", "forearms"], aliases=["KB Row and Rotate", "Row to Rotation"]),
    "KB/DB Drags": ex("back", "dumbbell", "compound", "pull", direction="horizontal", weight=35, reps=10, lat="unilateral", prime=["lats"], major=["rhomboids", "biceps"], minor=["abs", "traps"], trace=["teresMajor", "forearms"], aliases=["Drag Row", "Kettlebell Drag", "Dumbbell Drag"]),
    "Lateral Plank Walk": ex("core", "bodyweight", "compound", "core", reps=12, bw=0.6, prime=["abs"], major=["deltoids", "obliques"], minor=["pectorals", "serratus"], trace=["triceps"], aliases=["Lateral Plank Walkout", "Plank Walk", "Lateral Plank Walks"]),
    # — Rotational / anti-rotation —
    "Pallof Wall Iso Holds": ex("core", "band", "compound", "core", reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax"], aliases=["Pallof Iso Hold", "Wall Pallof Hold", "Pallof Max Effort Iso Holds", "Pallof Max Effort Iso Holds (3-Secs)", "Palloff Iso Holds (20s E.S.)"]),
    "Kneeling Pallof Iso Holds": ex("core", "band", "compound", "core", reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax", "hipFlexors"], aliases=["Kneeling Pallof Hold"]),
    "Banded Rotations": ex("core", "band", "compound", "core", reps=15, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["lowerBack"], aliases=["Banded Trunk Rotation", "Band Woodchop"]),
    "Supine Med Ball Chest Pass": ex("chest", "other", "compound", "push", direction="horizontal", weight=8, reps=12, prime=["pectorals"], major=["triceps", "deltoids"], minor=["serratus"], trace=["abs"], aliases=["Lying Med Ball Chest Pass"]),
    "Split Stance Rotational Throws": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "pectorals"], trace=["triceps", "quads"], aliases=["Split Stance Med Ball Throw", "Rotational Med Ball Throw"]),
    "Lateral Shuffle to MB Throw": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "quads", "calves"], trace=["pectorals"], aliases=["Shuffle to Med Ball Throw"]),

    # ===================== Batch 11: core exercises =====================
    # Anti-extension / anti-rotation trunk work and loaded core variants.
    # Weighted, tempo, and position variants are kept as their own entries
    # (per program design); throws become power and holds become isometric
    # strength in the audited classification pass below.
    "Weighted Leg Lowers": ex("core", "dumbbell", "isolation", None, weight=10, reps=12, prime=["abs"], major=["hipFlexors"], minor=["quads"], trace=["obliques"], aliases=["Weighted Lying Leg Lowers"]),
    "Leg Lowers with 2-Sec Pause": ex("core", "bodyweight", "isolation", None, reps=10, bw=0.3, prime=["abs"], major=["hipFlexors"], minor=["quads"], trace=["obliques"], aliases=["Tempo Leg Lowers", "Paused Leg Lowers"]),
    "Plank Holds with Elevated Hands": ex("core", "bodyweight", "isolation", None, reps=1, tracking="duration", duration=45, bw=0.5, prime=["abs"], major=["obliques"], minor=["deltoids"], trace=["gluteMax"], aliases=["Incline Plank Hold", "Hands-Elevated Plank"]),
    "Supine Core Holds with Weight": ex("core", "other", "isolation", None, weight=10, reps=1, tracking="duration", duration=30, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["quads"], aliases=["Weighted Hollow Hold", "Weighted Supine Core Hold"]),
    "Swiss Ball Plank Circles": ex("core", "other", "isolation", None, reps=10, bw=0.5, plane="transverse", prime=["abs"], major=["obliques", "deltoids"], minor=["serratus"], trace=["gluteMax"], aliases=["Stability Ball Plank Circles", "Swiss Ball Stir-the-Pot"]),
    "Rotational Plank": ex("core", "bodyweight", "compound", "core", reps=12, bw=0.5, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["gluteMax"], aliases=["Plank Rotation", "Thread the Needle Plank"]),
    "Straight Arm Straight Leg Sit Ups": ex("core", "bodyweight", "isolation", None, reps=12, bw=0.3, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["quads"], aliases=["Long-Arm Sit-Up", "Straight-Leg Sit-Up"]),
    "Straight Leg Sit Ups with Med Ball": ex("core", "other", "isolation", None, weight=8, reps=12, prime=["abs"], major=["hipFlexors"], minor=["obliques"], trace=["deltoids"], aliases=["Med Ball Straight-Leg Sit-Up"]),
    "TRX Rollouts": ex("core", "other", "isolation", None, reps=10, bw=0.5, prime=["abs"], major=["obliques", "lats"], minor=["deltoids", "serratus"], trace=["lowerBack"], aliases=["TRX Rollout", "Suspension Rollout", "TRX Ab Rollout"]),
    "Banded Pallof Split Jerks": ex("core", "band", "compound", "core", reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "quads"], trace=["triceps"], aliases=["Pallof Split Jerk", "Banded Pallof Jerk"]),
    "½ Kneeling Rotational Med Ball Throws": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["gluteMax", "pectorals"], trace=["triceps"], aliases=["Half-Kneeling Rotational Med Ball Throw"]),
    "Kneeling Rotational Throws": ex("core", "other", "compound", "core", weight=8, reps=10, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs", "deltoids"], minor=["pectorals"], trace=["triceps", "gluteMax"], aliases=["Kneeling Rotational Med Ball Throw"]),
    "Single Arm MB Holds": ex("core", "other", "isolation", None, weight=8, reps=1, tracking="duration", duration=30, plane="transverse", lat="unilateral", prime=["obliques"], major=["abs"], minor=["deltoids"], trace=["forearms"], aliases=["Single Arm Med Ball Hold", "Offset Med Ball Hold"]),
}


# Objective corrections from the biomechanics audit. Keeping these separate
# from the seed calls makes the audited contract easy to scan and test.
TRANSVERSE_PLANE = {
    "Bent over Cable Flye", "Cable Fly",
    "Cable Fly Lower Chest", "Cable Fly Middle Chest", "Cable Fly Upper Chest",
    "Fly With Dumbbells", "Fly With Dumbbells, Decline Bench",
    "Incline Dumbbell Fly", "Low Pulley Cable Fly", "Machine Chest Fly",
    "Seated Cable chest fly", "Dumbbell Bent Over Face Pull",
    "Face pulls with yellow/green band", "Facepull", "Incline Bench Reverse Fly",
    "Russian Twist", "Push-up rotations", "Low-Cable Cross-Over - NB",
    "Omni Cable Cross-over", "Suspended crossess", "Supine Serratus Punch",
    "Incline Shoulder Press Up", "Bus Drivers",
    "Prone Scapular Retraction - Arms at Side",
}

FRONTAL_PLANE = {
    "Lateral Raises", "Upright Row w/ Dumbbells", "Upright Row, SZ-bar",
    "Upright Row, on Multi Press", "Machine Hip Abduction",
    "Seated Hip Adduction", "Side Plank", "Lateral Plank Walk", "Plank Jacks",
    "Reverse Snow Angel",
}

SAGITTAL_PLANE = {
    "Front Raise (Cable)", "Front Raises",
    "Straight Bar Cable Front Raise", "Plank Reach",
}

GROUP_OVERRIDES = {
    "Back bridge": "back",
    "Barbell Silverback Shrug": "back",
    "Cable Shrug-In": "back",
    "Chair dips": "arms",
    "Close-Grip Bench Press": "arms",
    "Close-grip Press-ups": "arms",
    "Cross-Bench Dumbbell Pullovers": "back",
    "Diamond push ups": "arms",
    "Double Kettlebell Clean and Press": "shoulders",
    "Dumbbell Bent Over Face Pull": "shoulders",
    "Dumbbell farmer's carry": "arms",
    "Dumbbell Hang Power Cleans": "legs",
    "Dumbbell Shrug": "back",
    "Dumbbell Underhand Dead Row": "back",
    "Elbows Tucked DB Bench Press": "chest",
    "Face pulls with yellow/green band": "shoulders",
    "Finger Pushup": "chest",
    "Front lever pull-up": "back",
    "Glute Bridge Single-Arm Press": "chest",
    "High plank": "core",
    "Hip Raise, Lying": "legs",
    "Incline Bench Reverse Fly": "shoulders",
    "Kettlebell deadlifts": "legs",
    "L-Sit Pull-ups": "back",
    "No push-up burpees": "legs",
    "One armed push-ups": "chest",
    "Pike Push Ups": "shoulders",
    "Power Clean": "legs",
    "Push-up rotations": "chest",
    "Reverse Cable Flye": "shoulders",
    "Reverse Plank": "back",
    "Ring Support Hold": "arms",
    "Seated rear delt rise": "shoulders",
    "Shoulder width three-point push-up": "chest",
    "Shoulder Y-pull cable": "back",
    "Shrugs, Barbells": "back",
    "Shrugs on Multipress": "back",
    "Sled Push": "legs",
    "Snatch OL": "legs",
    "Supine Serratus Punch": "chest",
    "Turkish Get-Up": "shoulders",
    "Wall Pushup": "chest",
    "Burpees": "legs",
    "Barbell Romanian Deadlift (RDL)": "legs",
    "box jumps": "legs",
    "High Knee Jumps": "legs",
    "High knees": "legs",
    "Jump rope: basic jumps": "legs",
    "knee push-ups": "chest",
    "Step Jack": "legs",
}

UNILATERAL_EXERCISES = {
    "Alternating High Cable Row",
    "Behind the Back Cable Lateral Raise",
    "Cable Chest Press - Decline",
    "Cable Chest Press - Incline",
    "Cable Tri Extension - Internal Rotation",
    "Cable Triceps Press",
    "Cable External Rotation",
    "Bird Dog",
    "Black Widow Knee Slides",
    "Deadbug",
    "High Row",
    "Incline Plank With Alternate Floor Touch",
    "Plank Reach",
    "Plank Shoulder Taps",
    "Preacher Curl - Externally Rotated",
    "Preacher Curl - Internally Rotated",
    "Side Crunch",
    "Side Plank",
    "Standing Side Crunches",
    "Supine Hip Abduction",
    "TRX Obliques",
    "bicycle crunches",
    "Mountain climbers",
}

LOCOMOTION_EXERCISES = {
    "Ali Shuffle", "High Knee Skips HD", "High knees",
    "Jump rope: basic jumps", "Jumping Jacks",
    "Marching High Knees", "Slow Hands, Fast Feet", "Step Jack",
}

CONDITIONING_EXERCISES = LOCOMOTION_EXERCISES | {
    "Bag training", "Banded Shadow Box", "Battle Ropes", "Burpees",
    "Devil’s Press", "Mountain climbers", "No push-up burpees",
    "Plank In-and-Out Jump", "Plank Jacks", "Sled Push", "Squat Thrust",
}

MOBILITY_EXERCISES = {"Codman Pendulum", "Hamstring Kicks"}

# Explosive efforts are intentionally distinct from both strength-repetition
# work and cyclical conditioning. Loaded Olympic derivatives with external
# resistance retain their raw implement load and may earn direct load/reps
# records and tonnage, but power never earns hard-set credit or estimated 1RM.
# Jumps and throws remain non-comparable below because height, velocity,
# distance, and implement characteristics are missing from the log.
POWER_EXERCISES = {
    "Altitude Landings", "Altitude Landings to Jump",
    "Altitude Landings to Lateral Shuffle", "Ball Slams",
    "Banded Accentuated CMJ", "Banded Pallof Split Jerks", "box jumps",
    "Clap Push-UP", "Clean", "Clean and Jerk OL", "Clean and Press",
    "CMJ with Hands on Hips", "Criss Cross Jump",
    "Double Kettlebell Clean and Press", "Dumbbell CMJ (2 kg each hand)",
    "Dumbbell Hang Power Cleans", "Falling CMJ", "High Knee Jumps", "High Pull", "Hop + Hold",
    "Ice Skaters", "Ice Skaters to Vertical Hop", "Ice Skaters with Medicine Ball",
    "Jerk OL", "Kettlebell sumo high pull", "Kettlebell Swings",
    "Kneeling Rotational Throws", "Lateral Push Off",
    "Lateral Shuffle to MB Throw", "Medicine Ball Punch Throw", "Pogos",
    "Power Clean", "Push Press",
    "Snatch OL", "Split Stance Rotational Throws", "Squat Jumps",
    "Supine Med Ball Chest Pass", "Wall balls",
    "½ Kneeling Rotational Med Ball Throws", "dumbbell snatch",
}

# Corrections where the seed roster's broad isolation/compound label obscured
# a coordinated multi-joint trunk or lower-body action.
MECHANIC_PATTERN_OVERRIDES = {
    "Ab wheel": ("compound", "core"),
    "Ball Slams": ("compound", "core"),
    "Barbell Ab Rollout": ("compound", "core"),
    "Bear crawl pull through": ("compound", "core"),
    "Kneeling Superman": ("compound", "core"),
    "Plank Jacks": ("compound", "core"),
    "Single-leg side glute press": ("compound", "squat"),
    "TRX Rollouts": ("compound", "core"),
}

# These movements retain anatomy roles for body-model visualization, but their
# power or conditioning modalities never earn hypertrophy hard-set credit. The
# entered resistance is not a truthful one-dimensional performance axis: jump
# height, landing quality, throw velocity/distance, implement variation, and
# band tension all matter. Applying Epley or tonnage to that entered value would
# fabricate comparability. Band equipment is handled by the same rule below.
NONCOMPARABLE_BALLISTIC_EXERCISES = {
    "Altitude Landings", "Altitude Landings to Jump",
    "Altitude Landings to Lateral Shuffle", "Ball Slams",
    "Banded Accentuated CMJ", "Clap Push-UP", "CMJ with Hands on Hips",
    "Criss Cross Jump", "Devil’s Press", "Dumbbell CMJ (2 kg each hand)",
    "Falling CMJ", "High Knee Jumps", "Hop + Hold", "Ice Skaters",
    "Ice Skaters to Vertical Hop", "Ice Skaters with Medicine Ball",
    "Kneeling Rotational Throws", "Lateral Push Off",
    "Lateral Shuffle to MB Throw", "Medicine Ball Punch Throw",
    "No push-up burpees", "Pogos",
    "Split Stance Rotational Throws", "Squat Jumps", "Squat Thrust",
    "Supine Med Ball Chest Pass", "Wall balls",
    "½ Kneeling Rotational Med Ball Throws",
}

NONCOMPARABLE_LOAD_EXERCISES = NONCOMPARABLE_BALLISTIC_EXERCISES | {
    "Sliding Lateral Lunge",
}

# Deleted duplicate spellings remain discoverable, but every search term has
# one canonical owner. Renamed pre-production records keep their former labels
# as aliases without retaining obsolete catalog identities.
CANONICAL_ALIAS_ADDITIONS = {
    "Inverted Rows": ("Australian pull-ups",),
    "TRX Rows": ("Rowing with TRX band", "TRX Row", "Suspension Row"),
    "Hyperextensions": ("Lower Back Extensions", "Lower Back Extension"),
    "Pendulum Squat": ("Pendular hack", "Pendulum Hack Squat"),
    "Weighted Step-ups": ("Step-ups", "Step-up", "Box Step-up"),
    "Side-lying External Rotation": ("Shoulder External Rotation with Dumbbell",),
    "Decline Pushups": ("Push-Ups | Decline",),
    "Push-Up": ("Strict Press-Ups", "Strict Push-Up", "Strict Push-Ups"),
    "Pull-Ups (Wide Grip)": ("Wide Pull Up",),
    "Incline Chest-Supported Dumbbell Row": (
        "Incline Dumbbell Row", "Incline Chest-Supported Row", "Incline DB Row",
    ),
    "Dumbbell Shrug": ("Shrugs, Dumbbells", "DB Shrug"),
    "Front Plate Raise": ("Front Raises with Plates",),
    "Lying Triceps Kickback": ("Tricep Dumbbell Kickback",),
    "Calf Press Using Leg Press Machine": ("Leg Press Toe Press",),
    "Reverse lunges": ("Alternate back lunges",),
    "Lunges": ("Bodyweight lunge HD", "Unilateral Lunges"),
    "Underhand Lat Pull Down": (
        "Inverted Lat Pull Down", "Biceps Close Grip Pull Down",
        "Reverse-Grip Lat Pulldown", "Supinated Lat Pulldown",
    ),
    "Seated V-Grip Row": (
        "Long-Pulley, Narrow", "Rowing seated, narrow grip",
        "Narrow-Grip Cable Row", "Close-Grip Seated Cable Row", "Narrow-Grip Row",
    ),
    "Single-arm cable pushdown": ("One Arm Triceps Extensions on Cable",),
    "Tricep Rope Pushdowns": ("Tricep Pushdown on Cable",),
    "Triceps Extensions on Cable With Bar": ("Triceps Extensions on Cable",),
    "Skullcrusher SZ-bar": ("Lying Triceps Extensions",),
    "Fire Hydrants": ("Quadruped Hip Abduction",),
    "Pogos": ("Fast Pogos", "Fast Ankle Hops"),
    "One Arm Bent Row": ("Single arm row",),
    "Push Press": ("Push OHP",),
    "Cable Lateral Raises (Single Arm)": ("Lateral Rows on Cable, One Armed",),
    "Lateral Raises": ("Schoulder Raise (Dumbbell)",),
    "Dumbbell Frog Pump": ("Dumbbell Frog Press",),
    "Pendlay Row": ("Pendelay Rows",),
    "Side-Lying Dumbbell Internal Rotation": ("Side-laying interior rotation",),
    "Lying Leg Curl": ("Leg Curls (laying)",),
    "Single-Leg Lunge with Kettlebell": ("Single-Leg Lunge with Kettlebell:",),
    "Push-Up Wipers": ("Isometric Wipers",),
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


INVOLVEMENT_OVERRIDES = {
    "Supine Serratus Punch": role_involvement(
        primary=("serratus",), stabilizer=("deltoids", "triceps")
    ),
    "Clamshell": role_involvement(
        primary=("gluteMed",), secondary=("gluteMax",), stabilizer=("abs",)
    ),
    "Side-Plank Clamshell": role_involvement(
        primary=("obliques", "gluteMed"),
        secondary=("abs", "gluteMax", "deltoids", "serratus"),
        stabilizer=("lowerBack", "triceps"),
    ),
    "Plank In-and-Out Jump": role_involvement(
        primary=("abs",), secondary=("hipFlexors", "quads", "deltoids", "serratus", "gluteMax")
    ),
    "Kettlebell Suitcase Hold with March": role_involvement(
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
    "Side Slides + Squats": role_involvement(
        primary=("gluteMed", "quads"),
        secondary=("gluteMax", "adductors", "hamstrings"),
        stabilizer=("calves", "abs", "obliques")
    ),
    "Jumping Jacks": role_involvement(
        primary=("gluteMed", "deltoids"),
        secondary=("calves", "quads", "gluteMax", "adductors"),
        stabilizer=("hamstrings", "abs", "obliques", "shins")
    ),
    "Prisoner Squats with Overhead Reach": role_involvement(
        primary=("quads",),
        secondary=("gluteMax", "adductors", "hamstrings", "deltoids"),
        stabilizer=("calves", "abs", "obliques", "lowerBack", "shins", "serratus", "traps")
    ),
    "Shoulder Internal Rotation (Cable)": role_involvement(
        primary=("subscapularis",), secondary=("pectorals", "lats", "teresMajor"),
        stabilizer=("deltoids",)
    ),
    "Side-Lying Dumbbell Internal Rotation": role_involvement(
        primary=("subscapularis",), secondary=("pectorals", "lats", "teresMajor"),
        stabilizer=("deltoids",)
    ),
    "Cable Tri Extension - Internal Rotation": role_involvement(
        primary=("triceps",), secondary=("subscapularis", "pectorals"),
        stabilizer=("forearms", "abs")
    ),
    "Bent over row to external rotation": role_involvement(
        primary=("rhomboids", "externalRotators"),
        secondary=("deltoids", "traps", "lats", "biceps"),
        stabilizer=("forearms",)
    ),
    "Burpees": role_involvement(
        primary=("quads", "gluteMax"),
        secondary=("pectorals", "triceps", "deltoids", "calves", "hamstrings"),
        stabilizer=("abs", "obliques", "serratus")
    ),
    "Bag training": role_involvement(
        primary=("obliques",),
        secondary=("deltoids", "pectorals", "abs", "triceps", "lats"),
        stabilizer=("calves", "gluteMed")
    ),
    "Banded Shadow Box": role_involvement(
        primary=("deltoids",), secondary=("pectorals", "triceps", "serratus", "obliques"),
        stabilizer=("abs", "biceps")
    ),
}

EXTERNAL_ROTATION_EXERCISES = {
    "Banded External Rotations", "Cable External Rotation",
    "Side-lying External Rotation",
}

EXTERNAL_ROTATION_HYBRIDS = {
    "Band pull-apart with external rotation",
    "Bent over row to external rotation",
    "Dumbbell Bent Over Face Pull",
    "Face pulls with yellow/green band",
    "Facepull",
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
    if name == "Single Leg Clockface":
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
    if name == "High Row":
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
