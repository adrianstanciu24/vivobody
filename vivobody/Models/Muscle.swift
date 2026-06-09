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

    /// How prone this region is to functional tightness (`0...1`),
    /// driving how much contraction-biased loading tightens it (see
    /// `MuscleDevelopment`). Postural / tonic muscles — hip flexors,
    /// hamstrings, calves, pecs, upper traps, lats, lumbar erectors —
    /// shorten readily under repeated loading and rate high. Phasic
    /// muscles that tend toward inhibition rather than tightness —
    /// glutes, abs, rhomboids — rate near zero. `nonisolated` so the
    /// pure value-type model can read it off the main actor.
    nonisolated var tightnessSusceptibility: Double {
        switch self {
        case .hipFlexors:            return 1.0
        case .hamstrings:            return 0.9
        case .calves:                return 0.9
        case .pectorals:             return 0.85
        case .lowerBack:             return 0.85
        case .traps:                 return 0.8
        case .lats:                  return 0.7
        case .adductors:             return 0.7
        case .quads:                 return 0.55
        case .teres, .forearms:      return 0.5
        case .biceps, .triceps,
             .deltoids, .obliques:   return 0.4
        case .serratus:              return 0.3
        case .abs, .glutes, .shins:  return 0.2
        case .rhomboids:             return 0.15
        }
    }

    /// The opposing muscle whose neglect lets this one shorten into a
    /// postural fault — the classic crossed-syndrome pairs. When the
    /// agonist far out-develops this antagonist, tightening is
    /// amplified (see `MuscleDevelopment`): the only-bench lifter's
    /// chest tightens into rounded shoulders, the sitter's hip flexors
    /// into an anterior pelvic tilt. `nil` for muscles with no clear
    /// posture-driving opposite. `nonisolated` so the pure value-type
    /// model can read it off the main actor.
    nonisolated var tightnessAntagonist: Muscle? {
        switch self {
        case .pectorals:  return .rhomboids   // rounded shoulders
        case .hipFlexors: return .glutes      // anterior pelvic tilt
        case .lowerBack:  return .abs          // lumbar over-extension
        case .calves:     return .shins        // stiff, plantar-locked ankle
        default:          return nil
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
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// Returns `.empty` for unknown names (e.g. user-created lifts the
    /// catalog never shipped). The single source of truth every
    /// `muscleInvolvement` resolver reads from.
    static func involvement(forExerciseNamed name: String) -> Involvement {
        CatalogData.record(forExerciseNamed: name)?.muscleInvolvement ?? .empty
    }
}
