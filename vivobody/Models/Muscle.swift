//
//  Muscle.swift
//  vivobody
//
//  The trainable-muscle taxonomy that bridges two layers that never
//  spoke before: an exercise knows only a coarse `MuscleGroup`
//  (chest/back/legs/…), while `BodyModel.scn` ships ~240 individually
//  named anatomical meshes (`Pectoralis_Major_L`, `Vastus_Lateralis_R`,
//  …). This file defines the middle layer — ~20 trainable muscle
//  regions — and three things built on top of it:
//
//    1. `Muscle.nodeNames` — which model meshes each region paints.
//    2. `MuscleRole` — primary vs. secondary involvement, with the
//       weight each contributes to the activation score.
//    3. `Muscle.involvement(forExerciseNamed:)` — the default
//       per-exercise muscle map for the seeded catalog. Used to seed
//       the persisted `primaryMuscles` / `secondaryMuscles` fields on
//       catalog items and, as a fallback, to resolve muscles for any
//       exercise whose persisted fields are empty (legacy logs,
//       custom entries that reuse a known name).
//
//  The model node names are exact strings baked into BodyModel.scn,
//  including its spelling quirks (`Adductor_Mangus`, `Biceps_femoris`).
//  Don't "correct" them here — they must match the archive.
//

import Foundation

// MARK: - Muscle role

/// How hard a muscle works in a given exercise. The weight is the
/// multiplier applied to a set's effort when accumulating the
/// all-time activation score (see `MuscleHeatmap`).
enum MuscleRole {
    case primary
    case secondary

    var weight: Double {
        switch self {
        case .primary:   return 1.0
        case .secondary: return 0.5
        }
    }
}

// MARK: - Muscle

/// A trainable muscle region. Coarser than the model's individual
/// meshes (one region paints several `_L`/`_R` nodes) but finer than
/// `MuscleGroup`. Stored as a raw string on exercises so the set can
/// grow without a migration.
enum Muscle: String, Hashable, CaseIterable {
    // Chest
    case pectorals
    case serratus
    // Back
    case lats
    case traps
    case rhomboids
    case teres          // teres major/minor + infraspinatus cluster
    case lowerBack
    // Shoulders
    case deltoids
    // Arms
    case biceps
    case triceps
    case forearms
    // Core
    case abs
    case obliques
    // Legs
    case quads
    case hamstrings
    case glutes
    case calves
    case adductors
    case hipFlexors
    case shins

    var displayName: String {
        switch self {
        case .pectorals:  return "Chest"
        case .serratus:   return "Serratus"
        case .lats:       return "Lats"
        case .traps:      return "Traps"
        case .rhomboids:  return "Rhomboids"
        case .teres:      return "Upper Back"
        case .lowerBack:  return "Lower Back"
        case .deltoids:   return "Shoulders"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .abs:        return "Abs"
        case .obliques:   return "Obliques"
        case .quads:      return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Glutes"
        case .calves:     return "Calves"
        case .adductors:  return "Adductors"
        case .hipFlexors: return "Hip Flexors"
        case .shins:      return "Shins"
        }
    }

    /// The coarse group this region rolls up into. Lets a future
    /// surface (e.g. group-level coverage) bridge back to the
    /// existing `MuscleGroup` vocabulary.
    var group: MuscleGroup {
        switch self {
        case .pectorals, .serratus:                       return .chest
        case .lats, .traps, .rhomboids, .teres, .lowerBack: return .back
        case .deltoids:                                   return .shoulders
        case .biceps, .triceps, .forearms:                return .arms
        case .abs, .obliques:                             return .core
        case .quads, .hamstrings, .glutes, .calves,
             .adductors, .hipFlexors, .shins:             return .legs
        }
    }

    /// Mesh base-names (without the `_L`/`_R` suffix) this region
    /// covers in BodyModel.scn. Exact archive spelling — see file
    /// header.
    private var nodeBaseNames: [String] {
        switch self {
        case .pectorals:
            return ["Pectoralis_Major", "Pectoralis_Minor"]
        case .serratus:
            return ["Serratus_Anterior"]
        case .lats:
            return ["Latissimus_Dorsi"]
        case .traps:
            return ["Trapezius"]
        case .rhomboids:
            return ["Rhomboideus_Major", "Rhomboideus_Minor"]
        case .teres:
            return ["Teres_Major", "Teres_Minor", "Infraspinatus"]
        case .lowerBack:
            return ["Quadratus_Lumborum", "Serratus_Posterior_Inferior", "Serratus_Posterior_Superior"]
        case .deltoids:
            return ["Deltoid"]
        case .biceps:
            return ["Biceps", "Brachialis"]
        case .triceps:
            return ["Triceps"]
        case .forearms:
            return [
                "Brachioradialis",
                "Flexor_Carpi_Radialis", "Flexor_Carpi_Ulnaris",
                "Extensor_Carpi_Radialis_Longus", "Extensor_Carpi_Radialis_Brevis",
                "Extensor_Carpi_Ulnaris",
                "Flexor_Digitorum_Superficialis", "Extensor_Digitorum_Communis"
            ]
        case .abs:
            return ["Rectus_Abdomini"]
        case .obliques:
            return ["External_Oblique", "Internal_Oblique"]
        case .quads:
            return ["Rectus_Femoris", "Vastus_Lateralis", "Vastus_Medialis", "Vastus_Intermedius"]
        case .hamstrings:
            return ["Biceps_femoris", "Semitendinosus", "Semimembranosus"]
        case .glutes:
            return ["Gluteus_Maximus", "Gluteus_Medius"]
        case .calves:
            return ["Gastrocnemius", "Soleus"]
        case .adductors:
            return ["Adductor_Brevis", "Adductor_Longus", "Adductor_Mangus", "Gracilis", "Pectineus"]
        case .hipFlexors:
            return ["Psoas_Major", "Iliacus", "Tensor_Fascia_Latae", "Sartorius"]
        case .shins:
            return ["Tibialis_Anterior", "Peroneus_Longus", "Peroneus_Brevis", "Peroneus_Tertius"]
        }
    }

    /// Full mesh node names this region paints — every base name
    /// expanded to its `_L` and `_R` halves. These match
    /// `SCNNode.name` values in BodyModel.scn.
    var nodeNames: [String] {
        nodeBaseNames.flatMap { ["\($0)_L", "\($0)_R"] }
    }
}

// MARK: - Default exercise → muscle map

extension Muscle {
    /// Primary + secondary muscles for one exercise.
    struct Involvement {
        let primary: [Muscle]
        let secondary: [Muscle]

        static let empty = Involvement(primary: [], secondary: [])
    }

    /// Default muscle involvement for an exercise, resolved by name
    /// (case-insensitive). Covers every entry in the seeded catalog;
    /// returns `.empty` for unknown names. The single source of truth
    /// used both to seed persisted fields and to back-fill any
    /// exercise whose fields are empty.
    static func involvement(forExerciseNamed name: String) -> Involvement {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return defaultMap[key] ?? .empty
    }

    /// Keyed by lowercased exercise name. Mirrors the seed catalog in
    /// `ExerciseCatalogItem.seedItems`.
    private static let defaultMap: [String: Involvement] = {
        func inv(_ p: [Muscle], _ s: [Muscle] = []) -> Involvement {
            Involvement(primary: p, secondary: s)
        }
        let pairs: [(String, Involvement)] = [
            // MARK: Chest
            ("Bench Press",               inv([.pectorals], [.triceps, .deltoids])),
            ("Incline Bench Press",       inv([.pectorals], [.deltoids, .triceps])),
            ("Decline Bench Press",       inv([.pectorals], [.triceps])),
            ("Close-Grip Bench Press",    inv([.triceps, .pectorals], [.deltoids])),
            ("Paused Bench Press",        inv([.pectorals], [.triceps, .deltoids])),
            ("Dumbbell Bench Press",      inv([.pectorals], [.triceps, .deltoids])),
            ("Incline Dumbbell Press",    inv([.pectorals], [.deltoids, .triceps])),
            ("Dumbbell Fly",              inv([.pectorals])),
            ("Cable Fly",                 inv([.pectorals])),
            ("Pec Deck",                  inv([.pectorals])),
            ("Push-Up",                   inv([.pectorals], [.triceps, .deltoids, .abs])),
            ("Dip",                       inv([.pectorals, .triceps], [.deltoids])),

            // MARK: Back
            ("Deadlift",                  inv([.glutes, .hamstrings, .lowerBack], [.traps, .lats, .quads, .forearms])),
            ("Sumo Deadlift",             inv([.glutes, .adductors, .quads], [.hamstrings, .lowerBack, .traps])),
            ("Trap Bar Deadlift",         inv([.quads, .glutes, .hamstrings], [.traps, .lowerBack, .forearms])),
            ("Block Pull",                inv([.glutes, .hamstrings, .lowerBack], [.traps, .lats, .forearms])),
            ("Rack Pull",                 inv([.traps, .lowerBack, .glutes], [.lats, .forearms, .hamstrings])),
            ("Barbell Row",               inv([.lats, .rhomboids], [.traps, .teres, .biceps, .lowerBack])),
            ("Pendlay Row",               inv([.lats, .rhomboids], [.traps, .teres, .biceps])),
            ("T-Bar Row",                 inv([.lats, .rhomboids], [.traps, .biceps, .teres])),
            ("Chest-Supported Row",       inv([.lats, .rhomboids], [.traps, .teres, .biceps])),
            ("Pull-Up",                   inv([.lats], [.biceps, .teres, .rhomboids, .forearms])),
            ("Chin-Up",                   inv([.lats, .biceps], [.teres, .rhomboids, .forearms])),
            ("Neutral-Grip Pull-Up",      inv([.lats], [.biceps, .teres, .forearms])),
            ("Weighted Pull-Up",          inv([.lats], [.biceps, .teres, .rhomboids, .forearms])),
            ("Lat Pulldown",              inv([.lats], [.biceps, .teres, .rhomboids])),
            ("Wide-Grip Lat Pulldown",    inv([.lats], [.teres, .biceps, .rhomboids])),
            ("Seated Cable Row",          inv([.lats, .rhomboids], [.traps, .biceps, .teres])),
            ("Single-Arm Dumbbell Row",   inv([.lats, .rhomboids], [.traps, .biceps, .teres])),
            ("Straight-Arm Pulldown",     inv([.lats], [.teres])),
            ("Shrug",                     inv([.traps], [.forearms])),
            ("Dead Hang",                 inv([.forearms], [.lats, .traps])),

            // MARK: Shoulders
            ("Overhead Press",            inv([.deltoids], [.triceps, .traps])),
            ("Seated Barbell Press",      inv([.deltoids], [.triceps, .traps])),
            ("Push Press",                inv([.deltoids], [.triceps, .traps, .quads])),
            ("Dumbbell Shoulder Press",   inv([.deltoids], [.triceps, .traps])),
            ("Arnold Press",              inv([.deltoids], [.triceps, .traps])),
            ("Landmine Press",            inv([.deltoids], [.triceps, .pectorals])),
            ("Lateral Raise",             inv([.deltoids])),
            ("Cable Lateral Raise",       inv([.deltoids])),
            ("Front Raise",               inv([.deltoids])),
            ("Rear Delt Fly",             inv([.deltoids], [.rhomboids, .teres])),
            ("Face Pull",                 inv([.deltoids], [.rhomboids, .traps, .teres])),
            ("Upright Row",               inv([.deltoids, .traps], [.biceps])),

            // MARK: Legs
            ("Back Squat",                inv([.quads, .glutes], [.hamstrings, .lowerBack, .adductors])),
            ("Front Squat",               inv([.quads], [.glutes, .lowerBack, .abs])),
            ("Pause Squat",               inv([.quads, .glutes], [.hamstrings, .lowerBack])),
            ("Box Squat",                 inv([.glutes, .quads], [.hamstrings, .lowerBack])),
            ("Goblet Squat",              inv([.quads], [.glutes, .adductors])),
            ("Bulgarian Split Squat",     inv([.quads, .glutes], [.hamstrings, .adductors])),
            ("Walking Lunge",             inv([.quads, .glutes], [.hamstrings, .adductors])),
            ("Reverse Lunge",             inv([.glutes, .quads], [.hamstrings])),
            ("Step-Up",                   inv([.quads, .glutes], [.hamstrings])),
            ("Leg Press",                 inv([.quads, .glutes], [.hamstrings, .adductors])),
            ("Hack Squat",                inv([.quads], [.glutes])),
            ("Romanian Deadlift",         inv([.hamstrings, .glutes], [.lowerBack])),
            ("Stiff-Leg Deadlift",        inv([.hamstrings, .glutes], [.lowerBack])),
            ("Good Morning",              inv([.hamstrings, .lowerBack], [.glutes])),
            ("Hip Thrust",                inv([.glutes], [.hamstrings])),
            ("Glute Bridge",              inv([.glutes], [.hamstrings])),
            ("Leg Curl",                  inv([.hamstrings])),
            ("Leg Extension",             inv([.quads])),
            ("Standing Calf Raise",       inv([.calves])),
            ("Seated Calf Raise",         inv([.calves])),
            ("Wall Sit",                  inv([.quads], [.glutes])),
            ("Hip Adduction",             inv([.adductors])),
            ("Hip Abduction",             inv([.glutes])),

            // MARK: Arms
            ("Barbell Curl",              inv([.biceps], [.forearms])),
            ("EZ-Bar Curl",               inv([.biceps], [.forearms])),
            ("Dumbbell Curl",             inv([.biceps], [.forearms])),
            ("Hammer Curl",               inv([.forearms, .biceps])),
            ("Incline Dumbbell Curl",     inv([.biceps], [.forearms])),
            ("Preacher Curl",             inv([.biceps], [.forearms])),
            ("Cable Curl",                inv([.biceps], [.forearms])),
            ("Concentration Curl",        inv([.biceps])),
            ("Tricep Pushdown",           inv([.triceps])),
            ("Rope Pushdown",             inv([.triceps])),
            ("Skullcrusher",              inv([.triceps])),
            ("Overhead Tricep Extension", inv([.triceps])),
            ("Dumbbell Tricep Kickback",  inv([.triceps])),
            ("Close-Grip Push-Up",        inv([.triceps, .pectorals], [.deltoids])),
            ("Wrist Curl",                inv([.forearms])),
            ("Reverse Wrist Curl",        inv([.forearms])),

            // MARK: Core
            ("Plank",                     inv([.abs], [.obliques, .lowerBack])),
            ("Side Plank",                inv([.obliques], [.abs])),
            ("Hollow Hold",               inv([.abs], [.hipFlexors])),
            ("L-Sit",                     inv([.abs], [.hipFlexors, .triceps])),
            ("Hanging Leg Raise",         inv([.abs], [.hipFlexors, .obliques])),
            ("Hanging Knee Raise",        inv([.abs], [.hipFlexors])),
            ("Cable Crunch",              inv([.abs], [.obliques])),
            ("Ab Wheel Rollout",          inv([.abs], [.lowerBack, .lats])),
            ("Russian Twist",             inv([.obliques], [.abs])),
            ("Pallof Press",              inv([.obliques], [.abs])),
            ("Dead Bug",                  inv([.abs], [.hipFlexors])),
            ("Bird Dog",                  inv([.lowerBack, .glutes], [.abs])),
            ("Farmer's Carry",            inv([.traps, .forearms], [.abs, .obliques, .quads])),
        ]
        return Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
    }()
}
