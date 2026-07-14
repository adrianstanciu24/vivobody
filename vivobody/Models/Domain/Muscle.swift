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
    nonisolated private var nodeBaseNames: [String] {
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
    nonisolated var nodeNames: [String] {
        nodeBaseNames.flatMap { ["\($0)_L", "\($0)_R"] }
    }
}

// MARK: - Default exercise → muscle map

nonisolated extension Muscle {
    /// Per-muscle contribution for one exercise: an ordered list of
    /// (muscle, weight) pairs, where weight ∈ 0...1 is the fraction of
    /// the exercise's effort credited to that muscle. Prime movers sit
    /// at/above `primeThreshold`; lighter synergists grade down. The
    /// `primary`/`secondary` accessors project this back onto the old
    /// two-tier view for callers that still want it.
    nonisolated struct Involvement {
        /// Standard contribution levels used to author the catalog.
        static let prime = 1.0   // the target muscle
        static let major = 0.7   // heavily-loaded synergist
        static let minor = 0.4   // clear assistor
        static let trace = 0.2   // light stabiliser
        /// At/above this a contribution reads as a prime mover.
        static let primeThreshold = 0.85

        /// The bounded vocabulary used when authoring involvement.
        /// Catalog analytics keep storing Doubles, while the editor
        /// avoids implying precision the underlying data does not have.
        nonisolated enum Level: Double, CaseIterable {
            case prime = 1.0
            case major = 0.7
            case minor = 0.4
            case trace = 0.2
            case none = 0

            var displayName: String {
                switch self {
                case .prime: return "Prime"
                case .major: return "Major"
                case .minor: return "Minor"
                case .trace: return "Trace"
                case .none:  return "None"
                }
            }

            init(weight: Double) {
                guard weight > 0 else {
                    self = .none
                    return
                }
                self = Self.allCases.min {
                    Swift.abs($0.rawValue - weight) < Swift.abs($1.rawValue - weight)
                } ?? .none
            }
        }

        let contributions: [(muscle: Muscle, weight: Double)]

        static let empty = Involvement(contributions: [])

        init(contributions: [(muscle: Muscle, weight: Double)]) {
            self.contributions = contributions
        }

        init(snapshot: [String: Double]) {
            let weightsByMuscle = Dictionary(
                snapshot.compactMap { raw, weight -> (Muscle, Double)? in
                    guard let muscle = Muscle(rawValue: raw), weight > 0 else { return nil }
                    return (muscle, weight)
                },
                uniquingKeysWith: max
            )
            self.contributions = Muscle.allCases.compactMap { muscle in
                guard let weight = weightsByMuscle[muscle] else { return nil }
                return (muscle: muscle, weight: weight)
            }
        }

        var snapshot: [String: Double] {
            Dictionary(contributions.map { ($0.muscle.rawValue, $0.weight) }, uniquingKeysWith: max)
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
        var hasPrime: Bool {
            contributions.contains { $0.weight >= Self.primeThreshold }
        }
        var isEmpty: Bool { contributions.isEmpty }
    }

    /// Coarse fallback for custom or renamed exercises that have no
    /// curated catalog entry. This keeps user-created work visible in
    /// muscle analytics instead of disappearing entirely.
    static func defaultInvolvement(for group: MuscleGroup) -> Involvement {
        switch group {
        case .chest:
            return Involvement(contributions: [(.pectorals, Involvement.prime)])
        case .back:
            return Involvement(contributions: [(.lats, Involvement.prime), (.traps, Involvement.major), (.rhomboids, Involvement.major)])
        case .shoulders:
            return Involvement(contributions: [(.deltoids, Involvement.prime)])
        case .legs:
            return Involvement(contributions: [(.quads, Involvement.prime), (.hamstrings, Involvement.major), (.glutes, Involvement.major)])
        case .arms:
            return Involvement(contributions: [(.biceps, Involvement.prime), (.triceps, Involvement.prime), (.forearms, Involvement.minor)])
        case .core:
            return Involvement(contributions: [(.abs, Involvement.prime), (.obliques, Involvement.major)])
        }
    }

    /// Graded muscle involvement for an exercise, resolved by name
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// Unknown names fall back to a coarse group map when provided so
    /// custom exercises still contribute to analytics.
    static func involvement(forExerciseNamed name: String) -> Involvement {
        CatalogData.record(forExerciseNamed: name)?.muscleInvolvement ?? .empty
    }

    static func involvement(forExerciseNamed name: String, fallbackGroup group: MuscleGroup) -> Involvement {
        let curated = involvement(forExerciseNamed: name)
        return curated.isEmpty ? defaultInvolvement(for: group) : curated
    }
}
