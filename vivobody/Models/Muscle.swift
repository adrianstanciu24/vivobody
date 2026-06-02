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
//    2. `Muscle.Involvement` — graded per-muscle contribution for an
//       exercise: an ordered list of (muscle, weight) pairs, where
//       weight ∈ 0...1 is the fraction of effort each muscle receives.
//    3. `Muscle.involvement(forExerciseNamed:)` — the curated, graded
//       per-exercise muscle map for the seeded catalog. The single
//       source of truth that every `muscleInvolvement` resolver reads
//       from, keyed purely by exercise name.
//
//  The model node names are exact strings baked into BodyModel.scn,
//  including its spelling quirks (`Adductor_Mangus`, `Biceps_femoris`).
//  Don't "correct" them here — they must match the archive.
//

import Foundation

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
    /// existing `MuscleGroup` vocabulary. `nonisolated` so the pure
    /// value-type stat models can roll muscles up off the main actor.
    nonisolated var group: MuscleGroup {
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
    /// Per-muscle contribution for one exercise: an ordered list of
    /// (muscle, weight) pairs, where weight ∈ 0...1 is the fraction of
    /// the exercise's effort credited to that muscle. Prime movers sit
    /// at/above `primeThreshold`; lighter synergists grade down. The
    /// `primary`/`secondary` accessors project this back onto the old
    /// two-tier view for callers that still want it.
    struct Involvement {
        /// Standard contribution levels used to author the catalog.
        static let prime = 1.0   // the target muscle
        static let major = 0.7   // heavily-loaded synergist
        static let minor = 0.4   // clear assistor
        static let trace = 0.2   // light stabiliser
        /// At/above this a contribution reads as a prime mover.
        static let primeThreshold = 0.85

        let contributions: [(muscle: Muscle, weight: Double)]

        static let empty = Involvement(contributions: [])

        init(contributions: [(muscle: Muscle, weight: Double)]) {
            self.contributions = contributions
        }

        /// Effort multiplier per muscle, deduplicated by max.
        var weights: [Muscle: Double] {
            Dictionary(contributions.map { ($0.muscle, $0.weight) }, uniquingKeysWith: max)
        }
        /// Prime movers (weight ≥ `primeThreshold`), in author order.
        var primary: [Muscle] {
            contributions.filter { $0.weight >= Self.primeThreshold }.map(\.muscle)
        }
        /// Everything below prime but still involved.
        var secondary: [Muscle] {
            contributions.filter { $0.weight > 0 && $0.weight < Self.primeThreshold }.map(\.muscle)
        }
        var isEmpty: Bool { contributions.isEmpty }
    }

    /// Graded muscle involvement for an exercise, resolved by name
    /// (case-insensitive). Covers every entry in the seeded catalog
    /// and returns `.empty` for unknown names. The single source of
    /// truth every `muscleInvolvement` resolver reads from.
    static func involvement(forExerciseNamed name: String) -> Involvement {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return defaultMap[key] ?? .empty
    }

    /// Keyed by lowercased exercise name. Mirrors the seed catalog in
    /// `ExerciseCatalogItem.seedItems`.
    private static let defaultMap: [String: Involvement] = {
        // Graded contribution: prime movers at full weight, then
        // `major` / `minor` / `trace` synergists stepping down. The
        // weight is the fraction of an exercise's effort each muscle
        // receives (see `MuscleDevelopment.sessionStimulus`).
        func inv(
            _ prime: [Muscle],
            major: [Muscle] = [],
            minor: [Muscle] = [],
            trace: [Muscle] = []
        ) -> Involvement {
            Involvement(contributions:
                prime.map { ($0, Involvement.prime) } +
                major.map { ($0, Involvement.major) } +
                minor.map { ($0, Involvement.minor) } +
                trace.map { ($0, Involvement.trace) }
            )
        }
        let pairs: [(String, Involvement)] = [
            // MARK: Chest
            ("Bench Press",               inv([.pectorals], major: [.triceps], minor: [.deltoids])),
            ("Incline Bench Press",       inv([.pectorals], major: [.deltoids], minor: [.triceps])),
            ("Decline Bench Press",       inv([.pectorals], major: [.triceps])),
            ("Close-Grip Bench Press",    inv([.triceps, .pectorals], minor: [.deltoids])),
            ("Paused Bench Press",        inv([.pectorals], major: [.triceps], minor: [.deltoids])),
            ("Dumbbell Bench Press",      inv([.pectorals], major: [.triceps], minor: [.deltoids])),
            ("Incline Dumbbell Press",    inv([.pectorals], major: [.deltoids], minor: [.triceps])),
            ("Dumbbell Fly",              inv([.pectorals], trace: [.deltoids])),
            ("Cable Fly",                 inv([.pectorals], trace: [.deltoids])),
            ("Pec Deck",                  inv([.pectorals])),
            ("Push-Up",                   inv([.pectorals], major: [.triceps], minor: [.deltoids], trace: [.abs])),
            ("Dip",                       inv([.pectorals, .triceps], minor: [.deltoids])),

            // MARK: Back
            ("Deadlift",                  inv([.glutes, .hamstrings, .lowerBack], major: [.traps, .forearms], minor: [.lats, .quads])),
            ("Sumo Deadlift",             inv([.glutes, .adductors, .quads], major: [.lowerBack], minor: [.hamstrings, .traps])),
            ("Trap Bar Deadlift",         inv([.quads, .glutes, .hamstrings], major: [.traps, .forearms], minor: [.lowerBack])),
            ("Block Pull",                inv([.glutes, .hamstrings, .lowerBack], major: [.traps, .forearms], minor: [.lats])),
            ("Rack Pull",                 inv([.traps, .lowerBack, .glutes], major: [.forearms], minor: [.lats, .hamstrings])),
            ("Barbell Row",               inv([.lats, .rhomboids], major: [.traps, .biceps], minor: [.teres, .lowerBack])),
            ("Pendlay Row",               inv([.lats, .rhomboids], major: [.traps, .biceps], minor: [.teres])),
            ("T-Bar Row",                 inv([.lats, .rhomboids], major: [.biceps], minor: [.traps, .teres])),
            ("Chest-Supported Row",       inv([.lats, .rhomboids], major: [.biceps], minor: [.traps, .teres])),
            ("Pull-Up",                   inv([.lats], major: [.biceps], minor: [.teres, .rhomboids, .forearms])),
            ("Chin-Up",                   inv([.lats, .biceps], minor: [.teres, .rhomboids, .forearms])),
            ("Neutral-Grip Pull-Up",      inv([.lats], major: [.biceps], minor: [.teres, .forearms])),
            ("Weighted Pull-Up",          inv([.lats], major: [.biceps], minor: [.teres, .rhomboids, .forearms])),
            ("Lat Pulldown",              inv([.lats], major: [.biceps], minor: [.teres, .rhomboids])),
            ("Wide-Grip Lat Pulldown",    inv([.lats], minor: [.teres, .biceps, .rhomboids])),
            ("Seated Cable Row",          inv([.lats, .rhomboids], major: [.biceps], minor: [.traps, .teres])),
            ("Single-Arm Dumbbell Row",   inv([.lats, .rhomboids], major: [.biceps], minor: [.traps, .teres])),
            ("Straight-Arm Pulldown",     inv([.lats], minor: [.teres])),
            ("Shrug",                     inv([.traps], minor: [.forearms])),
            ("Dead Hang",                 inv([.forearms], minor: [.lats, .traps])),

            // MARK: Shoulders
            ("Overhead Press",            inv([.deltoids], major: [.triceps], minor: [.traps])),
            ("Seated Barbell Press",      inv([.deltoids], major: [.triceps], minor: [.traps])),
            ("Push Press",                inv([.deltoids], major: [.triceps], minor: [.traps, .quads])),
            ("Dumbbell Shoulder Press",   inv([.deltoids], major: [.triceps], minor: [.traps])),
            ("Arnold Press",              inv([.deltoids], major: [.triceps], minor: [.traps])),
            ("Landmine Press",            inv([.deltoids], major: [.triceps], minor: [.pectorals])),
            ("Lateral Raise",             inv([.deltoids])),
            ("Cable Lateral Raise",       inv([.deltoids])),
            ("Front Raise",               inv([.deltoids])),
            ("Rear Delt Fly",             inv([.deltoids], minor: [.rhomboids, .teres])),
            ("Face Pull",                 inv([.deltoids], major: [.rhomboids], minor: [.traps, .teres])),
            ("Upright Row",               inv([.deltoids, .traps], minor: [.biceps])),

            // MARK: Legs
            ("Back Squat",                inv([.quads, .glutes], major: [.hamstrings], minor: [.lowerBack, .adductors])),
            ("Front Squat",               inv([.quads], major: [.glutes], minor: [.lowerBack, .abs])),
            ("Pause Squat",               inv([.quads, .glutes], major: [.hamstrings], minor: [.lowerBack])),
            ("Box Squat",                 inv([.glutes, .quads], major: [.hamstrings], minor: [.lowerBack])),
            ("Goblet Squat",              inv([.quads], major: [.glutes], minor: [.adductors])),
            ("Bulgarian Split Squat",     inv([.quads, .glutes], major: [.hamstrings], minor: [.adductors])),
            ("Walking Lunge",             inv([.quads, .glutes], major: [.hamstrings], minor: [.adductors])),
            ("Reverse Lunge",             inv([.glutes, .quads], minor: [.hamstrings])),
            ("Step-Up",                   inv([.quads, .glutes], minor: [.hamstrings])),
            ("Leg Press",                 inv([.quads, .glutes], major: [.hamstrings], minor: [.adductors])),
            ("Hack Squat",                inv([.quads], minor: [.glutes])),
            ("Romanian Deadlift",         inv([.hamstrings, .glutes], major: [.lowerBack])),
            ("Stiff-Leg Deadlift",        inv([.hamstrings, .glutes], major: [.lowerBack])),
            ("Good Morning",              inv([.hamstrings, .lowerBack], major: [.glutes])),
            ("Hip Thrust",                inv([.glutes], major: [.hamstrings])),
            ("Glute Bridge",              inv([.glutes], minor: [.hamstrings])),
            ("Leg Curl",                  inv([.hamstrings])),
            ("Leg Extension",             inv([.quads])),
            ("Standing Calf Raise",       inv([.calves])),
            ("Seated Calf Raise",         inv([.calves])),
            ("Wall Sit",                  inv([.quads], minor: [.glutes])),
            ("Hip Adduction",             inv([.adductors])),
            ("Hip Abduction",             inv([.glutes])),

            // MARK: Arms
            ("Barbell Curl",              inv([.biceps], minor: [.forearms])),
            ("EZ-Bar Curl",               inv([.biceps], minor: [.forearms])),
            ("Dumbbell Curl",             inv([.biceps], minor: [.forearms])),
            ("Hammer Curl",               inv([.forearms, .biceps])),
            ("Incline Dumbbell Curl",     inv([.biceps], minor: [.forearms])),
            ("Preacher Curl",             inv([.biceps], minor: [.forearms])),
            ("Cable Curl",                inv([.biceps], minor: [.forearms])),
            ("Concentration Curl",        inv([.biceps])),
            ("Tricep Pushdown",           inv([.triceps])),
            ("Rope Pushdown",             inv([.triceps])),
            ("Skullcrusher",              inv([.triceps])),
            ("Overhead Tricep Extension", inv([.triceps])),
            ("Dumbbell Tricep Kickback",  inv([.triceps])),
            ("Close-Grip Push-Up",        inv([.triceps, .pectorals], minor: [.deltoids])),
            ("Wrist Curl",                inv([.forearms])),
            ("Reverse Wrist Curl",        inv([.forearms])),

            // MARK: Core
            ("Plank",                     inv([.abs], major: [.obliques], minor: [.lowerBack])),
            ("Side Plank",                inv([.obliques], major: [.abs])),
            ("Hollow Hold",               inv([.abs], minor: [.hipFlexors])),
            ("L-Sit",                     inv([.abs], minor: [.hipFlexors, .triceps])),
            ("Hanging Leg Raise",         inv([.abs], major: [.hipFlexors], minor: [.obliques])),
            ("Hanging Knee Raise",        inv([.abs], major: [.hipFlexors])),
            ("Cable Crunch",              inv([.abs], minor: [.obliques])),
            ("Ab Wheel Rollout",          inv([.abs], minor: [.lowerBack, .lats])),
            ("Russian Twist",             inv([.obliques], major: [.abs])),
            ("Pallof Press",              inv([.obliques], minor: [.abs])),
            ("Dead Bug",                  inv([.abs], minor: [.hipFlexors])),
            ("Bird Dog",                  inv([.lowerBack, .glutes], minor: [.abs])),
            ("Farmer's Carry",            inv([.traps, .forearms], minor: [.abs, .obliques, .quads])),
        ]
        return Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
    }()
}
