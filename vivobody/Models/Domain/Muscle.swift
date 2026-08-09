//
//  Muscle.swift
//  vivobody
//
//  The trainable-muscle taxonomy bridging exercise programming,
//  muscle-volume analytics, and the individually named anatomical
//  meshes in BodyModel.scn. It also defines categorical exercise roles
//  so snapshot encoding, anatomy emphasis, and hard-set credit remain
//  separate concepts.
//
//    1. `Muscle.nodeNames` — which model meshes each region paints.
//    2. `MuscleRole` / `Muscle.Involvement` — primary, secondary, and
//       stabilizer roles, with separate snapshot, anatomy, and volume
//       projections.
//    3. `Muscle.involvement(forExerciseNamed:)` — a bundled-catalog
//       lookup used when constructing a snapshot directly by canonical
//       name. Catalog picks persist the authored roles; custom exercises
//       must author their own rather than inheriting a browse-group guess.
//
//  Persisted snapshots decode directly via `Involvement(snapshot:)`.
//  Snapshots from older taxonomies are rewritten once at launch by
//  `InvolvementSnapshotRepair` (App/), not recovered on every access.
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
nonisolated enum Muscle: String, Codable, Hashable, CaseIterable, Sendable {
    // Chest
    case pectorals
    case serratus
    // Back
    case lats
    case traps
    case rhomboids
    case externalRotators
    case teresMajor
    case subscapularis
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
    case gluteMax
    case gluteMed
    case tensorFasciaeLatae
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
        case .externalRotators: return "External Rotators"
        case .teresMajor: return "Teres Major"
        case .subscapularis: return "Subscapularis"
        case .lowerBack:  return "Lower Back"
        case .deltoids:   return "Shoulders"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .abs:        return "Abs"
        case .obliques:   return "Obliques"
        case .quads:      return "Quads"
        case .hamstrings: return "Hamstrings"
        case .gluteMax:   return "Glute Max"
        case .gluteMed:   return "Glute Med"
        case .tensorFasciaeLatae: return "TFL"
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
        case .lats, .traps, .rhomboids, .teresMajor,
             .lowerBack:                                  return .back
        case .deltoids, .externalRotators, .subscapularis: return .shoulders
        case .biceps, .triceps, .forearms:                return .arms
        case .abs, .obliques:                             return .core
        case .quads, .hamstrings, .gluteMax, .gluteMed,
             .tensorFasciaeLatae, .calves,
             .adductors, .hipFlexors, .shins:             return .legs
        }
    }

    /// Mesh base-names (without the `_L`/`_R` suffix) this region
    /// covers in BodyModel.scn. Exact archive spelling — see file
    /// header.
    nonisolated private var nodeBaseNames: [String] {
        switch self {
        case .pectorals:
            return [
                "Pectoralis_Major_Clavicular", "Pectoralis_Major_Sternocostal",
                "Pectoralis_Minor",
            ]
        case .serratus:
            return ["Serratus_Anterior"]
        case .lats:
            return ["Latissimus_Dorsi"]
        case .traps:
            return [
                "Trapezius_Upper", "Trapezius_Middle", "Trapezius_Lower",
                "Levator_Scapulaes",
            ]
        case .rhomboids:
            return ["Rhomboideus_Major", "Rhomboideus_Minor"]
        case .externalRotators:
            return ["Teres_Minor", "Infraspinatus"]
        case .teresMajor:
            return ["Teres_Major"]
        case .subscapularis:
            // BodyModel.scn has no subscapularis mesh. The region is
            // still modeled for exercise analytics, but deliberately
            // contributes no visual nodes.
            return []
        case .lowerBack:
            return ["Quadratus_Lumborum", "Serratus_Posterior_Inferior", "Serratus_Posterior_Superior"]
        case .deltoids:
            return ["Deltoid_Anterior", "Deltoid_Lateral", "Deltoid_Posterior"]
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
        case .gluteMax:
            return ["Gluteus_Maximus"]
        case .gluteMed:
            return ["Gluteus_Medius"]
        case .tensorFasciaeLatae:
            return ["Tensor_Fascia_Latae"]
        case .calves:
            return ["Gastrocnemius", "Soleus", "Flexor_Hallucis_Longus"]
        case .adductors:
            return ["Adductor_Brevis", "Adductor_Longus", "Adductor_Mangus", "Gracilis", "Pectineus"]
        case .hipFlexors:
            return ["Psoas_Major", "Iliacus", "Sartorius"]
        case .shins:
            return [
                "Tibialis_Anterior",
                "Peroneus_Longus", "Peroneus_Brevis", "Peroneus_Tertius",
                "Extensor_Digitorum_Longus", "Extensor_Hallucis_Longus"
            ]
        }
    }

    /// Full mesh node names this region paints — every base name
    /// expanded to its `_L` and `_R` halves. These match
    /// `SCNNode.name` values in BodyModel.scn.
    nonisolated var nodeNames: [String] {
        nodeBaseNames.flatMap { ["\($0)_L", "\($0)_R"] }
    }

    /// Whether BodyModel.scn can paint this region. Subscapularis is
    /// anatomically modeled but has no corresponding surface mesh.
    nonisolated var isVisualized: Bool { !nodeBaseNames.isEmpty }
}

// MARK: - Muscle role

/// A muscle's categorical contribution to an exercise. Role is the
/// authored fact; its anatomy emphasis and hard-set volume credit are
/// deliberately independent projections.
nonisolated enum MuscleRole: String, Codable, Hashable, CaseIterable, Sendable {
    case primary
    case secondary
    case stabilizer

    nonisolated var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        case .stabilizer: return "Stabilizer"
        }
    }

    /// Compact value persisted in SwiftData snapshots. It identifies
    /// the role inside the existing `[String: Double]` schema; it must
    /// not be consumed as development credit.
    nonisolated var snapshotValue: Double {
        switch self {
        case .primary: return 1
        case .secondary: return 0.5
        case .stabilizer: return 0.2
        }
    }

    /// Temporary emphasis on the Exercise Anatomy model. This shows
    /// that a stabilizer participates without claiming hard-set volume.
    nonisolated var anatomyIntensity: Double {
        switch self {
        case .primary: return 1
        case .secondary: return 0.5
        case .stabilizer: return 0.2
        }
    }

    /// Fractional hard-set credit used by muscle-volume analytics.
    /// Stabilization alone stays listed but earns no hypertrophy volume.
    nonisolated var volumeCredit: Double {
        switch self {
        case .primary: return 1
        case .secondary: return 0.5
        case .stabilizer: return 0
        }
    }

    /// Exercise-detail body-map channels. This anatomy-only projection
    /// is intentionally independent from `volumeCredit`.
    nonisolated var anatomyMapChannels: MuscleMapChannels {
        MuscleMapChannels(intensity: anatomyIntensity)
    }

    /// Decodes the compact SwiftData representation. Only the three
    /// canonical values are valid here; persisted legacy snapshots are
    /// rewritten once at launch by `InvolvementSnapshotRepair`.
    nonisolated init?(snapshotValue: Double) {
        guard let role = Self.allCases.first(where: {
            abs($0.snapshotValue - snapshotValue) < 0.000_001
        }) else {
            return nil
        }
        self = role
    }
}

// MARK: - Exercise involvement

nonisolated extension Muscle {
    /// Ordered categorical muscle roles for one exercise.
    nonisolated struct Involvement {
        nonisolated struct Contribution: Hashable, Sendable {
            let muscle: Muscle
            let role: MuscleRole

            nonisolated init(muscle: Muscle, role: MuscleRole) {
                self.muscle = muscle
                self.role = role
            }

            nonisolated var snapshotValue: Double { role.snapshotValue }
            nonisolated var anatomyIntensity: Double { role.anatomyIntensity }
            nonisolated var volumeCredit: Double { role.volumeCredit }
        }

        let contributions: [Contribution]

        static let empty = Involvement(contributions: [])

        init(contributions: [Contribution]) {
            var strongestRoleByMuscle: [Muscle: MuscleRole] = [:]
            var authoredOrder: [Muscle] = []

            for contribution in contributions {
                if strongestRoleByMuscle[contribution.muscle] == nil {
                    authoredOrder.append(contribution.muscle)
                }
                let existing = strongestRoleByMuscle[contribution.muscle]
                if existing.map({ contribution.role.snapshotValue > $0.snapshotValue }) ?? true {
                    strongestRoleByMuscle[contribution.muscle] = contribution.role
                }
            }

            self.contributions = authoredOrder.compactMap { muscle in
                strongestRoleByMuscle[muscle].map { Contribution(muscle: muscle, role: $0) }
            }
        }

        init(snapshot: [String: Double]) {
            self.contributions = Muscle.allCases.compactMap { muscle in
                guard
                    let value = snapshot[muscle.rawValue],
                    let role = MuscleRole(snapshotValue: value)
                else {
                    return nil
                }
                return Contribution(muscle: muscle, role: role)
            }
        }

        /// Whether every persisted entry belongs to the current muscle
        /// taxonomy and encodes one of the three canonical roles. Older
        /// stores can contain removed keys such as `glutes` / `teres` or
        /// pre-role graded weights such as 0.4 / 0.7.
        static func isCanonicalSnapshot(_ snapshot: [String: Double]) -> Bool {
            !snapshot.isEmpty && snapshot.allSatisfy { rawMuscle, value in
                Muscle(rawValue: rawMuscle) != nil
                    && MuscleRole(snapshotValue: value) != nil
            }
        }

        var snapshot: [String: Double] {
            Dictionary(
                contributions.map { ($0.muscle.rawValue, $0.snapshotValue) },
                uniquingKeysWith: max
            )
        }

        var roles: [Muscle: MuscleRole] {
            Dictionary(uniqueKeysWithValues: contributions.map { ($0.muscle, $0.role) })
        }

        /// Temporary Exercise Anatomy colours keyed by exact SceneKit
        /// mesh name. Stabilizers remain faintly visible here while
        /// retaining zero hard-set credit in volume analytics.
        var anatomyNodeChannels: [String: MuscleMapChannels] {
            var result: [String: MuscleMapChannels] = [:]
            for contribution in contributions {
                let channels = contribution.role.anatomyMapChannels
                for node in contribution.muscle.nodeNames {
                    result[node] = channels
                }
            }
            return result
        }

        /// Fractional hard-set credits consumed by volume analytics.
        var volumeCredits: [Muscle: Double] {
            Dictionary(uniqueKeysWithValues: contributions.map { ($0.muscle, $0.volumeCredit) })
        }

        func role(for muscle: Muscle) -> MuscleRole? { roles[muscle] }
        func volumeCredit(for muscle: Muscle) -> Double { volumeCredits[muscle] ?? 0 }

        var primary: [Muscle] {
            contributions.filter { $0.role == .primary }.map(\.muscle)
        }
        var secondary: [Muscle] {
            contributions.filter { $0.role == .secondary }.map(\.muscle)
        }
        var stabilizers: [Muscle] {
            contributions.filter { $0.role == .stabilizer }.map(\.muscle)
        }
        var hasPrimary: Bool { contributions.contains { $0.role == .primary } }
        var isEmpty: Bool { contributions.isEmpty }
    }

    /// Categorical muscle involvement for an exercise, resolved by name
    /// (case-insensitive) from the bundled catalog (`CatalogData`).
    /// Unknown names stay empty. Inventing roles from a browse group is
    /// biomechanically unsafe (for example, “legs” cannot tell gluteus
    /// maximus from gluteus medius), so custom exercises must author
    /// their roles explicitly in the editor.
    static func involvement(forExerciseNamed name: String) -> Involvement {
        CatalogData.record(forExerciseNamed: name)?.muscleInvolvement ?? .empty
    }
}
