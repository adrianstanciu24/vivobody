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
nonisolated enum Muscle: String, Codable, Hashable, CaseIterable {
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
    case quadratusLumborum
    case lumbarExtensors

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
    case gluteMin
    case tensorFasciaeLatae
    case piriformis
    case obturatorInternusGemelli
    case obturatorExternus
    case quadratusFemoris
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
        case .pectoralisMajorClavicular: "Upper Chest"
        case .pectoralisMajorSternocostal: "Mid / Lower Chest"
        case .pectoralisMinor: "Pectoralis Minor"
        case .serratus: "Serratus"
        case .lats: "Lats"
        case .trapeziusUpper: "Upper Traps"
        case .trapeziusMiddle: "Middle Traps"
        case .trapeziusLower: "Lower Traps"
        case .levatorScapulae: "Levator Scapulae"
        case .rhomboids: "Rhomboids"
        case .teresMajor: "Teres Major"
        case .quadratusLumborum: "Quadratus Lumborum"
        case .lumbarExtensors: "Lumbar Extensors"
        case .deltoidAnterior: "Front Delts"
        case .deltoidLateral: "Side Delts"
        case .deltoidPosterior: "Rear Delts"
        case .externalRotators: "External Rotators"
        case .subscapularis: "Subscapularis"
        case .supraspinatus: "Supraspinatus"
        case .bicepsBrachii: "Biceps"
        case .brachialis: "Brachialis"
        case .brachioradialis: "Brachioradialis"
        case .forearmPronators: "Forearm Pronators"
        case .supinator: "Supinator"
        case .flexorCarpiRadialis: "Flexor Carpi Radialis"
        case .flexorCarpiUlnaris: "Flexor Carpi Ulnaris"
        case .extensorCarpiRadialis: "Radial Wrist Extensors"
        case .extensorCarpiUlnaris: "Extensor Carpi Ulnaris"
        case .fingerFlexors: "Finger Flexors"
        case .fingerExtensors: "Finger Extensors"
        case .triceps: "Triceps"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .rectusFemoris: "Rectus Femoris"
        case .vasti: "Vasti"
        case .bicepsFemoris: "Biceps Femoris"
        case .medialHamstrings: "Medial Hamstrings"
        case .gluteMax: "Glute Max"
        case .gluteMed: "Glute Med"
        case .gluteMin: "Glute Min"
        case .tensorFasciaeLatae: "TFL"
        case .piriformis: "Piriformis"
        case .obturatorInternusGemelli: "Obturator Internus + Gemelli"
        case .obturatorExternus: "Obturator Externus"
        case .quadratusFemoris: "Quadratus Femoris"
        case .gastrocnemius: "Gastrocnemius"
        case .soleus: "Soleus"
        case .flexorHallucisLongus: "Big-Toe Flexor"
        case .adductorMagnus: "Adductor Magnus"
        case .adductorLongusBrevis: "Adductor Longus / Brevis"
        case .gracilis: "Gracilis"
        case .pectineus: "Pectineus"
        case .iliopsoas: "Iliopsoas"
        case .sartorius: "Sartorius"
        case .tibialisAnterior: "Tibialis Anterior"
        case .fibularisLongusBrevis: "Fibularis Longus / Brevis"
        case .fibularisTertius: "Fibularis Tertius"
        case .toeExtensors: "Toe Extensors"
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
            .chest
        case .lats, .trapeziusUpper, .trapeziusMiddle, .trapeziusLower,
             .levatorScapulae, .rhomboids, .teresMajor, .quadratusLumborum,
             .lumbarExtensors:
            .back
        case .deltoidAnterior, .deltoidLateral, .deltoidPosterior,
             .externalRotators, .subscapularis, .supraspinatus:
            .shoulders
        case .bicepsBrachii, .brachialis, .brachioradialis,
             .forearmPronators, .supinator, .flexorCarpiRadialis,
             .flexorCarpiUlnaris, .extensorCarpiRadialis,
             .extensorCarpiUlnaris, .fingerFlexors, .fingerExtensors,
             .triceps:
            .arms
        case .abs, .obliques:
            .core
        case .rectusFemoris, .vasti, .bicepsFemoris, .medialHamstrings,
             .gluteMax, .gluteMed, .gluteMin, .tensorFasciaeLatae,
             .piriformis, .obturatorInternusGemelli, .obturatorExternus,
             .quadratusFemoris, .gastrocnemius,
             .soleus, .flexorHallucisLongus, .adductorMagnus,
             .adductorLongusBrevis, .gracilis, .pectineus, .iliopsoas,
             .sartorius, .tibialisAnterior, .fibularisLongusBrevis,
             .fibularisTertius, .toeExtensors:
            .legs
        }
    }

    /// Mesh base-names (without the `_L`/`_R` suffix) this region
    /// covers in BodyModel.scn. Exact archive spelling — see file
    /// header.
    private nonisolated var nodeBaseNames: [String] {
        switch self {
        case .pectoralisMajorClavicular:
            ["Pectoralis_Major_Clavicular"]
        case .pectoralisMajorSternocostal:
            ["Pectoralis_Major_Sternocostal"]
        case .pectoralisMinor:
            ["Pectoralis_Minor"]
        case .serratus:
            ["Serratus_Anterior"]
        case .lats:
            ["Latissimus_Dorsi"]
        case .trapeziusUpper:
            ["Trapezius_Upper"]
        case .trapeziusMiddle:
            ["Trapezius_Middle"]
        case .trapeziusLower:
            ["Trapezius_Lower"]
        case .levatorScapulae:
            ["Levator_Scapulaes"]
        case .rhomboids:
            ["Rhomboideus_Major", "Rhomboideus_Minor"]
        case .teresMajor:
            ["Teres_Major"]
        case .quadratusLumborum:
            ["Quadratus_Lumborum"]
        case .lumbarExtensors:
            []
        case .deltoidAnterior:
            ["Deltoid_Anterior"]
        case .deltoidLateral:
            ["Deltoid_Lateral"]
        case .deltoidPosterior:
            ["Deltoid_Posterior"]
        case .externalRotators:
            ["Teres_Minor", "Infraspinatus"]
        case .subscapularis, .supraspinatus:
            []
        case .bicepsBrachii:
            ["Biceps"]
        case .brachialis:
            ["Brachialis"]
        case .brachioradialis:
            ["Brachioradialis"]
        case .forearmPronators, .supinator:
            []
        case .flexorCarpiRadialis:
            ["Flexor_Carpi_Radialis"]
        case .flexorCarpiUlnaris:
            ["Flexor_Carpi_Ulnaris"]
        case .extensorCarpiRadialis:
            [
                "Extensor_Carpi_Radialis_Longus",
                "Extensor_Carpi_Radialis_Brevis",
            ]
        case .extensorCarpiUlnaris:
            ["Extensor_Carpi_Ulnaris"]
        case .fingerFlexors:
            [
                "Flexor_Digitorum_Superficialis",
                "Flexor_Digitorum_Profundus",
            ]
        case .fingerExtensors:
            ["Extensor_Digitorum_Communis"]
        case .triceps:
            ["Triceps"]
        case .abs:
            ["Rectus_Abdomini"]
        case .obliques:
            ["External_Oblique", "Internal_Oblique"]
        case .rectusFemoris:
            ["Rectus_Femoris"]
        case .vasti:
            ["Vastus_Lateralis", "Vastus_Medialis", "Vastus_Intermedius"]
        case .bicepsFemoris:
            ["Biceps_femoris"]
        case .medialHamstrings:
            ["Semitendinosus", "Semimembranosus"]
        case .gluteMax:
            ["Gluteus_Maximus"]
        case .gluteMed:
            ["Gluteus_Medius"]
        case .gluteMin, .piriformis, .obturatorInternusGemelli,
             .obturatorExternus, .quadratusFemoris:
            []
        case .tensorFasciaeLatae:
            ["Tensor_Fascia_Latae"]
        case .gastrocnemius:
            ["Gastrocnemius"]
        case .soleus:
            ["Soleus"]
        case .flexorHallucisLongus:
            ["Flexor_Hallucis_Longus"]
        case .adductorMagnus:
            ["Adductor_Mangus"]
        case .adductorLongusBrevis:
            ["Adductor_Longus", "Adductor_Brevis"]
        case .gracilis:
            ["Gracilis"]
        case .pectineus:
            ["Pectineus"]
        case .iliopsoas:
            ["Psoas_Major", "Iliacus"]
        case .sartorius:
            ["Sartorius"]
        case .tibialisAnterior:
            ["Tibialis_Anterior"]
        case .fibularisLongusBrevis:
            ["Peroneus_Longus", "Peroneus_Brevis"]
        case .fibularisTertius:
            ["Peroneus_Tertius"]
        case .toeExtensors:
            ["Extensor_Digitorum_Longus", "Extensor_Hallucis_Longus"]
        }
    }

    /// Full mesh node names this region paints — every base name
    /// expanded to its `_L` and `_R` halves. These match
    /// `SCNNode.name` values in BodyModel.scn.
    nonisolated var nodeNames: [String] {
        nodeBaseNames.flatMap { ["\($0)_L", "\($0)_R"] }
    }

    /// Whether BodyModel.scn can paint this region. Ten modeled
    /// regions have no corresponding surface mesh.
    nonisolated var isVisualized: Bool {
        !nodeBaseNames.isEmpty
    }
}

// MARK: - Muscle role

/// A muscle's categorical contribution to an exercise. Role is the
/// authored fact; its anatomy emphasis and hard-set volume credit are
/// deliberately independent projections.
nonisolated enum MuscleRole: String, Codable, Hashable, CaseIterable {
    case primary
    case secondary
    case stabilizer

    nonisolated var displayName: String {
        switch self {
        case .primary: "Primary"
        case .secondary: "Secondary"
        case .stabilizer: "Stabilizer"
        }
    }

    /// Compact value persisted in SwiftData snapshots. It identifies
    /// the role inside the existing `[String: Double]` schema; it must
    /// not be consumed as development credit.
    nonisolated var snapshotValue: Double {
        switch self {
        case .primary: 1
        case .secondary: 0.5
        case .stabilizer: 0.2
        }
    }

    /// Temporary emphasis on the Exercise Anatomy model. This shows
    /// that a stabilizer participates without claiming hard-set volume.
    nonisolated var anatomyIntensity: Double {
        switch self {
        case .primary: 1
        case .secondary: 0.5
        case .stabilizer: 0.2
        }
    }

    /// Fractional hard-set credit used by muscle-volume analytics.
    /// Stabilization alone stays listed but earns no hypertrophy volume.
    nonisolated var volumeCredit: Double {
        switch self {
        case .primary: 1
        case .secondary: 0.5
        case .stabilizer: 0
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
        nonisolated struct Contribution: Hashable {
            let muscle: Muscle
            let role: MuscleRole

            nonisolated init(muscle: Muscle, role: MuscleRole) {
                self.muscle = muscle
                self.role = role
            }

            nonisolated var snapshotValue: Double {
                role.snapshotValue
            }

            nonisolated var anatomyIntensity: Double {
                role.anatomyIntensity
            }

            nonisolated var volumeCredit: Double {
                role.volumeCredit
            }
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

        func role(for muscle: Muscle) -> MuscleRole? {
            roles[muscle]
        }

        func volumeCredit(for muscle: Muscle) -> Double {
            volumeCredits[muscle] ?? 0
        }

        var primary: [Muscle] {
            contributions.filter { $0.role == .primary }.map(\.muscle)
        }

        var secondary: [Muscle] {
            contributions.filter { $0.role == .secondary }.map(\.muscle)
        }

        var stabilizers: [Muscle] {
            contributions.filter { $0.role == .stabilizer }.map(\.muscle)
        }

        var hasPrimary: Bool {
            contributions.contains { $0.role == .primary }
        }

        var isEmpty: Bool {
            contributions.isEmpty
        }
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
