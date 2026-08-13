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
    case pectoralisMajorClavicular
    case pectoralisMajorSternocostal
    case pectoralisMinor
    case serratus

    // Back
    case lats
    case trapeziusUpper
    case trapeziusMiddle
    case trapeziusLower
    case levatorScapulae
    case rhomboids
    case teresMajor
    case lowerBack

    // Shoulders
    case deltoidAnterior
    case deltoidLateral
    case deltoidPosterior
    case externalRotators
    case subscapularis
    case supraspinatus

    // Arms
    case bicepsBrachii
    case brachialis
    case brachioradialis
    case forearmPronators
    case supinator
    case flexorCarpiRadialis
    case flexorCarpiUlnaris
    case extensorCarpiRadialis
    case extensorCarpiUlnaris
    case fingerFlexors
    case fingerExtensors
    case triceps

    // Core
    case abs
    case obliques

    // Legs
    case rectusFemoris
    case vasti
    case bicepsFemoris
    case medialHamstrings
    case gluteMax
    case gluteMed
    case tensorFasciaeLatae
    case gastrocnemius
    case soleus
    case flexorHallucisLongus
    case adductorMagnus
    case adductorLongusBrevis
    case gracilis
    case pectineus
    case iliopsoas
    case sartorius
    case tibialisAnterior
    case fibularisLongusBrevis
    case fibularisTertius
    case toeExtensors

    var displayName: String {
        switch self {
        case .pectoralisMajorClavicular: return "Upper Chest"
        case .pectoralisMajorSternocostal: return "Mid / Lower Chest"
        case .pectoralisMinor: return "Pectoralis Minor"
        case .serratus: return "Serratus"
        case .lats: return "Lats"
        case .trapeziusUpper: return "Upper Traps"
        case .trapeziusMiddle: return "Middle Traps"
        case .trapeziusLower: return "Lower Traps"
        case .levatorScapulae: return "Levator Scapulae"
        case .rhomboids: return "Rhomboids"
        case .teresMajor: return "Teres Major"
        case .lowerBack: return "Lower Back"
        case .deltoidAnterior: return "Front Delts"
        case .deltoidLateral: return "Side Delts"
        case .deltoidPosterior: return "Rear Delts"
        case .externalRotators: return "External Rotators"
        case .subscapularis: return "Subscapularis"
        case .supraspinatus: return "Supraspinatus"
        case .bicepsBrachii: return "Biceps"
        case .brachialis: return "Brachialis"
        case .brachioradialis: return "Brachioradialis"
        case .forearmPronators: return "Forearm Pronators"
        case .supinator: return "Supinator"
        case .flexorCarpiRadialis: return "Flexor Carpi Radialis"
        case .flexorCarpiUlnaris: return "Flexor Carpi Ulnaris"
        case .extensorCarpiRadialis: return "Radial Wrist Extensors"
        case .extensorCarpiUlnaris: return "Extensor Carpi Ulnaris"
        case .fingerFlexors: return "Finger Flexors"
        case .fingerExtensors: return "Finger Extensors"
        case .triceps: return "Triceps"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .rectusFemoris: return "Rectus Femoris"
        case .vasti: return "Vasti"
        case .bicepsFemoris: return "Biceps Femoris"
        case .medialHamstrings: return "Medial Hamstrings"
        case .gluteMax: return "Glute Max"
        case .gluteMed: return "Glute Med"
        case .tensorFasciaeLatae: return "TFL"
        case .gastrocnemius: return "Gastrocnemius"
        case .soleus: return "Soleus"
        case .flexorHallucisLongus: return "Big-Toe Flexor"
        case .adductorMagnus: return "Adductor Magnus"
        case .adductorLongusBrevis: return "Adductor Longus / Brevis"
        case .gracilis: return "Gracilis"
        case .pectineus: return "Pectineus"
        case .iliopsoas: return "Iliopsoas"
        case .sartorius: return "Sartorius"
        case .tibialisAnterior: return "Tibialis Anterior"
        case .fibularisLongusBrevis: return "Fibularis Longus / Brevis"
        case .fibularisTertius: return "Fibularis Tertius"
        case .toeExtensors: return "Toe Extensors"
        }
    }

    /// The coarse group this region rolls up into. Lets a future
    /// surface (e.g. group-level coverage) bridge back to the
    /// existing `MuscleGroup` vocabulary. `nonisolated` so the pure
    /// value-type stat models can roll muscles up off the main actor.
    nonisolated var group: MuscleGroup {
        switch self {
        case .pectoralisMajorClavicular, .pectoralisMajorSternocostal,
             .pectoralisMinor, .serratus:
            return .chest
        case .lats, .trapeziusUpper, .trapeziusMiddle, .trapeziusLower,
             .levatorScapulae, .rhomboids, .teresMajor, .lowerBack:
            return .back
        case .deltoidAnterior, .deltoidLateral, .deltoidPosterior,
             .externalRotators, .subscapularis, .supraspinatus:
            return .shoulders
        case .bicepsBrachii, .brachialis, .brachioradialis,
             .forearmPronators, .supinator, .flexorCarpiRadialis,
             .flexorCarpiUlnaris, .extensorCarpiRadialis,
             .extensorCarpiUlnaris, .fingerFlexors, .fingerExtensors,
             .triceps:
            return .arms
        case .abs, .obliques:
            return .core
        case .rectusFemoris, .vasti, .bicepsFemoris, .medialHamstrings,
             .gluteMax, .gluteMed, .tensorFasciaeLatae, .gastrocnemius,
             .soleus, .flexorHallucisLongus, .adductorMagnus,
             .adductorLongusBrevis, .gracilis, .pectineus, .iliopsoas,
             .sartorius, .tibialisAnterior, .fibularisLongusBrevis,
             .fibularisTertius, .toeExtensors:
            return .legs
        }
    }

    /// Mesh base-names (without the `_L`/`_R` suffix) this region
    /// covers in BodyModel.scn. Exact archive spelling — see file
    /// header.
    nonisolated private var nodeBaseNames: [String] {
        switch self {
        case .pectoralisMajorClavicular:
            return ["Pectoralis_Major_Clavicular"]
        case .pectoralisMajorSternocostal:
            return ["Pectoralis_Major_Sternocostal"]
        case .pectoralisMinor:
            return ["Pectoralis_Minor"]
        case .serratus:
            return ["Serratus_Anterior"]
        case .lats:
            return ["Latissimus_Dorsi"]
        case .trapeziusUpper:
            return ["Trapezius_Upper"]
        case .trapeziusMiddle:
            return ["Trapezius_Middle"]
        case .trapeziusLower:
            return ["Trapezius_Lower"]
        case .levatorScapulae:
            return ["Levator_Scapulaes"]
        case .rhomboids:
            return ["Rhomboideus_Major", "Rhomboideus_Minor"]
        case .teresMajor:
            return ["Teres_Major"]
        case .lowerBack:
            return [
                "Quadratus_Lumborum",
                "Serratus_Posterior_Inferior",
                "Serratus_Posterior_Superior",
            ]
        case .deltoidAnterior:
            return ["Deltoid_Anterior"]
        case .deltoidLateral:
            return ["Deltoid_Lateral"]
        case .deltoidPosterior:
            return ["Deltoid_Posterior"]
        case .externalRotators:
            return ["Teres_Minor", "Infraspinatus"]
        case .subscapularis, .supraspinatus:
            return []
        case .bicepsBrachii:
            return ["Biceps"]
        case .brachialis:
            return ["Brachialis"]
        case .brachioradialis:
            return ["Brachioradialis"]
        case .forearmPronators, .supinator:
            return []
        case .flexorCarpiRadialis:
            return ["Flexor_Carpi_Radialis"]
        case .flexorCarpiUlnaris:
            return ["Flexor_Carpi_Ulnaris"]
        case .extensorCarpiRadialis:
            return [
                "Extensor_Carpi_Radialis_Longus",
                "Extensor_Carpi_Radialis_Brevis",
            ]
        case .extensorCarpiUlnaris:
            return ["Extensor_Carpi_Ulnaris"]
        case .fingerFlexors:
            return [
                "Flexor_Digitorum_Superficialis",
                "Flexor_Digitorum_Profundus",
            ]
        case .fingerExtensors:
            return ["Extensor_Digitorum_Communis"]
        case .triceps:
            return ["Triceps"]
        case .abs:
            return ["Rectus_Abdomini"]
        case .obliques:
            return ["External_Oblique", "Internal_Oblique"]
        case .rectusFemoris:
            return ["Rectus_Femoris"]
        case .vasti:
            return ["Vastus_Lateralis", "Vastus_Medialis", "Vastus_Intermedius"]
        case .bicepsFemoris:
            return ["Biceps_femoris"]
        case .medialHamstrings:
            return ["Semitendinosus", "Semimembranosus"]
        case .gluteMax:
            return ["Gluteus_Maximus"]
        case .gluteMed:
            return ["Gluteus_Medius"]
        case .tensorFasciaeLatae:
            return ["Tensor_Fascia_Latae"]
        case .gastrocnemius:
            return ["Gastrocnemius"]
        case .soleus:
            return ["Soleus"]
        case .flexorHallucisLongus:
            return ["Flexor_Hallucis_Longus"]
        case .adductorMagnus:
            return ["Adductor_Mangus"]
        case .adductorLongusBrevis:
            return ["Adductor_Longus", "Adductor_Brevis"]
        case .gracilis:
            return ["Gracilis"]
        case .pectineus:
            return ["Pectineus"]
        case .iliopsoas:
            return ["Psoas_Major", "Iliacus"]
        case .sartorius:
            return ["Sartorius"]
        case .tibialisAnterior:
            return ["Tibialis_Anterior"]
        case .fibularisLongusBrevis:
            return ["Peroneus_Longus", "Peroneus_Brevis"]
        case .fibularisTertius:
            return ["Peroneus_Tertius"]
        case .toeExtensors:
            return ["Extensor_Digitorum_Longus", "Extensor_Hallucis_Longus"]
        }
    }

    /// Full mesh node names this region paints — every base name
    /// expanded to its `_L` and `_R` halves. These match
    /// `SCNNode.name` values in BodyModel.scn.
    nonisolated var nodeNames: [String] {
        nodeBaseNames.flatMap { ["\($0)_L", "\($0)_R"] }
    }

    /// Whether BodyModel.scn can paint this region. Four modeled
    /// regions have no corresponding surface mesh.
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

    /// Decodes the compact snapshot representation. Only the three
    /// canonical role values are valid.
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
