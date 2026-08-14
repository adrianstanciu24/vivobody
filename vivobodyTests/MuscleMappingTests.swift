//
//  MuscleMappingTests.swift
//  vivobodyTests
//
//  Pins the complete 58-region catalog taxonomy at the runtime
//  boundary: stable IDs, display names, browse groups, exact SceneKit
//  mesh ownership, catalog coverage, and categorical role projections.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MuscleMappingTests {

    private struct TaxonomyEntry {
        let muscle: Muscle
        let displayName: String
        let group: MuscleGroup
        let meshBases: [String]

        var nodeNames: [String] {
            meshBases.flatMap { ["\($0)_L", "\($0)_R"] }
        }
    }

    private static let taxonomy: [TaxonomyEntry] = [
        .init(muscle: .pectoralisMajorClavicular, displayName: "Upper Chest", group: .chest, meshBases: ["Pectoralis_Major_Clavicular"]),
        .init(muscle: .pectoralisMajorSternocostal, displayName: "Mid / Lower Chest", group: .chest, meshBases: ["Pectoralis_Major_Sternocostal"]),
        .init(muscle: .pectoralisMinor, displayName: "Pectoralis Minor", group: .chest, meshBases: ["Pectoralis_Minor"]),
        .init(muscle: .serratus, displayName: "Serratus", group: .chest, meshBases: ["Serratus_Anterior"]),

        .init(muscle: .lats, displayName: "Lats", group: .back, meshBases: ["Latissimus_Dorsi"]),
        .init(muscle: .trapeziusUpper, displayName: "Upper Traps", group: .back, meshBases: ["Trapezius_Upper"]),
        .init(muscle: .trapeziusMiddle, displayName: "Middle Traps", group: .back, meshBases: ["Trapezius_Middle"]),
        .init(muscle: .trapeziusLower, displayName: "Lower Traps", group: .back, meshBases: ["Trapezius_Lower"]),
        .init(muscle: .levatorScapulae, displayName: "Levator Scapulae", group: .back, meshBases: ["Levator_Scapulaes"]),
        .init(muscle: .rhomboids, displayName: "Rhomboids", group: .back, meshBases: ["Rhomboideus_Major", "Rhomboideus_Minor"]),
        .init(muscle: .teresMajor, displayName: "Teres Major", group: .back, meshBases: ["Teres_Major"]),
        .init(muscle: .quadratusLumborum, displayName: "Quadratus Lumborum", group: .back, meshBases: ["Quadratus_Lumborum"]),
        .init(muscle: .lumbarExtensors, displayName: "Lumbar Extensors", group: .back, meshBases: []),

        .init(muscle: .deltoidAnterior, displayName: "Front Delts", group: .shoulders, meshBases: ["Deltoid_Anterior"]),
        .init(muscle: .deltoidLateral, displayName: "Side Delts", group: .shoulders, meshBases: ["Deltoid_Lateral"]),
        .init(muscle: .deltoidPosterior, displayName: "Rear Delts", group: .shoulders, meshBases: ["Deltoid_Posterior"]),
        .init(muscle: .externalRotators, displayName: "External Rotators", group: .shoulders, meshBases: ["Teres_Minor", "Infraspinatus"]),
        .init(muscle: .subscapularis, displayName: "Subscapularis", group: .shoulders, meshBases: []),
        .init(muscle: .supraspinatus, displayName: "Supraspinatus", group: .shoulders, meshBases: []),

        .init(muscle: .bicepsBrachii, displayName: "Biceps", group: .arms, meshBases: ["Biceps"]),
        .init(muscle: .brachialis, displayName: "Brachialis", group: .arms, meshBases: ["Brachialis"]),
        .init(muscle: .brachioradialis, displayName: "Brachioradialis", group: .arms, meshBases: ["Brachioradialis"]),
        .init(muscle: .forearmPronators, displayName: "Forearm Pronators", group: .arms, meshBases: []),
        .init(muscle: .supinator, displayName: "Supinator", group: .arms, meshBases: []),
        .init(muscle: .flexorCarpiRadialis, displayName: "Flexor Carpi Radialis", group: .arms, meshBases: ["Flexor_Carpi_Radialis"]),
        .init(muscle: .flexorCarpiUlnaris, displayName: "Flexor Carpi Ulnaris", group: .arms, meshBases: ["Flexor_Carpi_Ulnaris"]),
        .init(muscle: .extensorCarpiRadialis, displayName: "Radial Wrist Extensors", group: .arms, meshBases: ["Extensor_Carpi_Radialis_Longus", "Extensor_Carpi_Radialis_Brevis"]),
        .init(muscle: .extensorCarpiUlnaris, displayName: "Extensor Carpi Ulnaris", group: .arms, meshBases: ["Extensor_Carpi_Ulnaris"]),
        .init(muscle: .fingerFlexors, displayName: "Finger Flexors", group: .arms, meshBases: ["Flexor_Digitorum_Superficialis", "Flexor_Digitorum_Profundus"]),
        .init(muscle: .fingerExtensors, displayName: "Finger Extensors", group: .arms, meshBases: ["Extensor_Digitorum_Communis"]),
        .init(muscle: .triceps, displayName: "Triceps", group: .arms, meshBases: ["Triceps"]),

        .init(muscle: .abs, displayName: "Abs", group: .core, meshBases: ["Rectus_Abdomini"]),
        .init(muscle: .obliques, displayName: "Obliques", group: .core, meshBases: ["External_Oblique", "Internal_Oblique"]),

        .init(muscle: .rectusFemoris, displayName: "Rectus Femoris", group: .legs, meshBases: ["Rectus_Femoris"]),
        .init(muscle: .vasti, displayName: "Vasti", group: .legs, meshBases: ["Vastus_Lateralis", "Vastus_Medialis", "Vastus_Intermedius"]),
        .init(muscle: .bicepsFemoris, displayName: "Biceps Femoris", group: .legs, meshBases: ["Biceps_femoris"]),
        .init(muscle: .medialHamstrings, displayName: "Medial Hamstrings", group: .legs, meshBases: ["Semitendinosus", "Semimembranosus"]),
        .init(muscle: .gluteMax, displayName: "Glute Max", group: .legs, meshBases: ["Gluteus_Maximus"]),
        .init(muscle: .gluteMed, displayName: "Glute Med", group: .legs, meshBases: ["Gluteus_Medius"]),
        .init(muscle: .gluteMin, displayName: "Glute Min", group: .legs, meshBases: []),
        .init(muscle: .tensorFasciaeLatae, displayName: "TFL", group: .legs, meshBases: ["Tensor_Fascia_Latae"]),
        .init(muscle: .piriformis, displayName: "Piriformis", group: .legs, meshBases: []),
        .init(muscle: .obturatorInternusGemelli, displayName: "Obturator Internus + Gemelli", group: .legs, meshBases: []),
        .init(muscle: .obturatorExternus, displayName: "Obturator Externus", group: .legs, meshBases: []),
        .init(muscle: .quadratusFemoris, displayName: "Quadratus Femoris", group: .legs, meshBases: []),
        .init(muscle: .gastrocnemius, displayName: "Gastrocnemius", group: .legs, meshBases: ["Gastrocnemius"]),
        .init(muscle: .soleus, displayName: "Soleus", group: .legs, meshBases: ["Soleus"]),
        .init(muscle: .flexorHallucisLongus, displayName: "Big-Toe Flexor", group: .legs, meshBases: ["Flexor_Hallucis_Longus"]),
        .init(muscle: .adductorMagnus, displayName: "Adductor Magnus", group: .legs, meshBases: ["Adductor_Mangus"]),
        .init(muscle: .adductorLongusBrevis, displayName: "Adductor Longus / Brevis", group: .legs, meshBases: ["Adductor_Longus", "Adductor_Brevis"]),
        .init(muscle: .gracilis, displayName: "Gracilis", group: .legs, meshBases: ["Gracilis"]),
        .init(muscle: .pectineus, displayName: "Pectineus", group: .legs, meshBases: ["Pectineus"]),
        .init(muscle: .iliopsoas, displayName: "Iliopsoas", group: .legs, meshBases: ["Psoas_Major", "Iliacus"]),
        .init(muscle: .sartorius, displayName: "Sartorius", group: .legs, meshBases: ["Sartorius"]),
        .init(muscle: .tibialisAnterior, displayName: "Tibialis Anterior", group: .legs, meshBases: ["Tibialis_Anterior"]),
        .init(muscle: .fibularisLongusBrevis, displayName: "Fibularis Longus / Brevis", group: .legs, meshBases: ["Peroneus_Longus", "Peroneus_Brevis"]),
        .init(muscle: .fibularisTertius, displayName: "Fibularis Tertius", group: .legs, meshBases: ["Peroneus_Tertius"]),
        .init(muscle: .toeExtensors, displayName: "Toe Extensors", group: .legs, meshBases: ["Extensor_Digitorum_Longus", "Extensor_Hallucis_Longus"]),
    ]

    @Test func runtimeTaxonomyExactlyMatchesTheReviewed58Regions() {
        let expectedIDs: Set<String> = [
            "pectoralisMajorClavicular", "pectoralisMajorSternocostal", "pectoralisMinor",
            "serratus", "lats", "trapeziusUpper", "trapeziusMiddle", "trapeziusLower",
            "levatorScapulae", "rhomboids", "teresMajor", "quadratusLumborum",
            "lumbarExtensors", "deltoidAnterior",
            "deltoidLateral", "deltoidPosterior", "externalRotators", "subscapularis",
            "supraspinatus", "bicepsBrachii", "brachialis", "brachioradialis",
            "forearmPronators", "supinator", "flexorCarpiRadialis", "flexorCarpiUlnaris",
            "extensorCarpiRadialis", "extensorCarpiUlnaris", "fingerFlexors",
            "fingerExtensors", "triceps", "abs", "obliques", "rectusFemoris", "vasti",
            "bicepsFemoris", "medialHamstrings", "gluteMax", "gluteMed", "gluteMin",
            "tensorFasciaeLatae", "piriformis", "obturatorInternusGemelli",
            "obturatorExternus", "quadratusFemoris", "gastrocnemius", "soleus", "flexorHallucisLongus",
            "adductorMagnus", "adductorLongusBrevis", "gracilis", "pectineus", "iliopsoas",
            "sartorius", "tibialisAnterior", "fibularisLongusBrevis", "fibularisTertius",
            "toeExtensors",
        ]

        #expect(Self.taxonomy.count == 58)
        #expect(Set(Muscle.allCases.map(\.rawValue)) == expectedIDs)
        #expect(Set(Self.taxonomy.map(\.muscle)) == Set(Muscle.allCases))

        var ownedNodes: Set<String> = []
        for entry in Self.taxonomy {
            #expect(entry.muscle.displayName == entry.displayName)
            #expect(entry.muscle.group == entry.group)
            #expect(entry.muscle.nodeNames == entry.nodeNames)
            #expect(entry.muscle.isVisualized == !entry.meshBases.isEmpty)

            for node in entry.nodeNames {
                #expect(ownedNodes.insert(node).inserted, "Mesh node '\(node)' has multiple owners")
            }
        }

        #expect(ownedNodes.count == 120)
        #expect(Set(Muscle.allCases.filter { !$0.isVisualized }) == Set([
            .subscapularis, .supraspinatus, .forearmPronators, .supinator,
            .lumbarExtensors, .gluteMin, .piriformis,
            .obturatorInternusGemelli, .obturatorExternus, .quadratusFemoris,
        ]))
    }

    @Test func catalogCoverageLeavesOnlySixExplicitFoundationHolds() {
        let targeted = Set(CatalogData.records.flatMap(\.involvement).map(\.muscle))
        let untargeted = Set(Muscle.allCases).subtracting(targeted)

        #expect(untargeted == Set([
            .adductorMagnus,
            .fibularisLongusBrevis,
            .fibularisTertius,
            .flexorHallucisLongus,
            .pectineus,
            .toeExtensors,
        ]))
    }

    @Test func involvementRolesProjectToSeparateAnatomyAndVolumeValues() {
        for record in CatalogData.records {
            for contribution in record.muscleInvolvement.contributions {
                #expect(contribution.snapshotValue == contribution.role.snapshotValue)
                #expect(contribution.anatomyIntensity == contribution.role.anatomyIntensity)
                #expect(contribution.volumeCredit == contribution.role.volumeCredit)
            }
        }

        #expect(MuscleRole.primary.snapshotValue == 1)
        #expect(MuscleRole.primary.volumeCredit == 1)
        #expect(MuscleRole.secondary.snapshotValue == 0.5)
        #expect(MuscleRole.secondary.volumeCredit == 0.5)
        #expect(MuscleRole.stabilizer.snapshotValue == 0.2)
        #expect(MuscleRole.stabilizer.volumeCredit == 0)
    }

    @Test func canonicalBenchRolesAndAnatomyProjectionStaySeparated() {
        let bench = Muscle.involvement(forExerciseNamed: "barbell bench press")
        #expect(bench.primary == [.pectoralisMajorSternocostal])
        #expect(bench.secondary == [
            .pectoralisMajorClavicular, .deltoidAnterior, .triceps,
        ])
        #expect(bench.stabilizers == [.serratus, .trapeziusMiddle])
        #expect(bench.anatomyNodeChannels["Pectoralis_Major_Sternocostal_L"]?.intensity == 1)
        #expect(bench.anatomyNodeChannels["Pectoralis_Major_Clavicular_L"]?.intensity == 0.5)
        #expect(bench.anatomyNodeChannels["Trapezius_Middle_L"]?.intensity == 0.2)
        #expect(bench.volumeCredit(for: .trapeziusMiddle) == 0)
    }

    @Test func canonicalDipsPaintAndCreditBothPectoralRegions() {
        for name in ["bar dip", "ring dip"] {
            let dip = Muscle.involvement(forExerciseNamed: name)
            #expect(dip.role(for: .pectoralisMajorClavicular) == .primary)
            #expect(dip.role(for: .pectoralisMajorSternocostal) == .primary)
            #expect(
                dip.anatomyNodeChannels[
                    "Pectoralis_Major_Sternocostal_L"
                ]?.intensity == 1
            )
            #expect(
                dip.anatomyNodeChannels[
                    "Pectoralis_Major_Sternocostal_R"
                ]?.intensity == 1
            )
            #expect(dip.volumeCredit(for: .pectoralisMajorSternocostal) == 1)
        }
    }

    @Test func lumbarFamiliesProjectTruthfulVisibleAndUnvisualizedRoles() {
        let lumbarExtension = Muscle.involvement(
            forExerciseNamed: "MedX Isolated Lumbar Extension"
        )
        #expect(lumbarExtension.role(for: .lumbarExtensors) == .primary)
        #expect(lumbarExtension.role(for: .quadratusLumborum) == nil)
        #expect(lumbarExtension.anatomyNodeChannels.isEmpty)
        #expect(lumbarExtension.volumeCredit(for: .lumbarExtensors) == 1)

        let lateral = Muscle.involvement(
            forExerciseNamed: "Fixed-Leg Side-Lying Lateral Trunk Lift"
        )
        #expect(lateral.role(for: .obliques) == .primary)
        #expect(lateral.role(for: .quadratusLumborum) == .secondary)
        #expect(lateral.role(for: .lumbarExtensors) == .stabilizer)
        #expect(lateral.anatomyNodeChannels["Quadratus_Lumborum_L"]?.intensity == 0.5)
        #expect(lateral.anatomyNodeChannels["Quadratus_Lumborum_R"]?.intensity == 0.5)
        #expect(lateral.volumeCredit(for: .quadratusLumborum) == 0.5)
        #expect(lateral.volumeCredit(for: .lumbarExtensors) == 0)
        #expect(Muscle.allCases.flatMap(\.nodeNames).contains("Serratus_Posterior_Inferior_L") == false)
        #expect(Muscle.allCases.flatMap(\.nodeNames).contains("Serratus_Posterior_Superior_L") == false)
    }

    @Test func hipRotationFamiliesRetainExactRolesWithoutProxyPainting() {
        let internalRotation = Muscle.involvement(
            forExerciseNamed: "Seated Flywheel Hip Internal Rotation"
        )
        #expect(internalRotation.role(for: .gluteMed) == .primary)
        #expect(internalRotation.role(for: .tensorFasciaeLatae) == .primary)
        #expect(internalRotation.role(for: .gluteMin) == .secondary)
        #expect(internalRotation.role(for: .obliques) == .stabilizer)
        #expect(internalRotation.volumeCredit(for: .gluteMin) == 0.5)
        #expect(internalRotation.volumeCredit(for: .obliques) == 0)
        #expect(internalRotation.anatomyNodeChannels["Gluteus_Medius_L"]?.intensity == 1)
        #expect(internalRotation.anatomyNodeChannels["Tensor_Fascia_Latae_L"]?.intensity == 1)

        let externalRotation = Muscle.involvement(
            forExerciseNamed: "Therapist-Held Supine Band Hip External Rotation"
        )
        #expect(externalRotation.role(for: .obturatorInternusGemelli) == .primary)
        #expect(externalRotation.role(for: .obturatorExternus) == .secondary)
        #expect(externalRotation.role(for: .piriformis) == .secondary)
        #expect(externalRotation.role(for: .quadratusFemoris) == .secondary)
        #expect(externalRotation.role(for: .obliques) == .stabilizer)
        #expect(externalRotation.role(for: .medialHamstrings) == .stabilizer)
        #expect(externalRotation.volumeCredit(for: .obturatorInternusGemelli) == 1)
        #expect(externalRotation.volumeCredit(for: .obturatorExternus) == 0.5)
        #expect(externalRotation.volumeCredit(for: .obliques) == 0)
        #expect(externalRotation.volumeCredit(for: .medialHamstrings) == 0)
        #expect(externalRotation.anatomyNodeChannels["Obturator_Internus_L"] == nil)
        #expect(externalRotation.anatomyNodeChannels["Piriformis_L"] == nil)
        #expect(externalRotation.anatomyNodeChannels["Semitendinosus_L"]?.intensity == 0.2)
        #expect(externalRotation.anatomyNodeChannels["External_Oblique_L"]?.intensity == 0.2)
    }

    @Test func unknownAndObsoleteSnapshotKeysDoNotInventAnatomy() {
        #expect(Muscle.involvement(forExerciseNamed: "Totally Made Up Lift").isEmpty)
        #expect(Muscle.Involvement(snapshot: [
            "pectorals": 1,
            "quads": 1,
            "glutes": 1,
            "lowerBack": 1,
        ]).isEmpty)
    }

    @Test func canonicalSnapshotsRoundTripCategoricalRoles() {
        let source = Muscle.Involvement(contributions: [
            .init(muscle: .pectoralisMajorSternocostal, role: .primary),
            .init(muscle: .triceps, role: .secondary),
            .init(muscle: .trapeziusMiddle, role: .stabilizer),
        ])
        #expect(Muscle.Involvement(snapshot: source.snapshot).roles == source.roles)
        #expect(Muscle.Involvement(snapshot: ["pectoralisMajorSternocostal": 0.7]).isEmpty)
    }

    @Test func powerKeepsAnatomyButEarnsNoDevelopmentCredit() throws {
        let record = try #require(CatalogData.record(forExerciseNamed: "Barbell Push Press"))
        #expect(!record.muscleInvolvement.anatomyNodeChannels.isEmpty)

        let exercise = Exercise(
            name: record.name,
            group: record.group,
            plannedSets: 3,
            plannedReps: 5,
            plannedWeight: 95,
            muscleInvolvement: record.muscleInvolvement,
            modality: .power
        )
        exercise.sets.forEach { $0.isCompleted = true }
        #expect(SetStimulus.credit(for: exercise).isEmpty)
    }

    @Test func explicitCustomInvolvementOverridesABundledName() {
        let custom = Muscle.Involvement(contributions: [
            .init(muscle: .vasti, role: .primary),
            .init(muscle: .gluteMax, role: .secondary),
            .init(muscle: .gastrocnemius, role: .stabilizer),
        ])
        let item = ExerciseCatalogItem(
            name: "Barbell Bench Press",
            group: .legs,
            defaultWeight: 0,
            muscleInvolvement: custom,
            isUserCreated: true
        )

        #expect(item.muscleInvolvement.roles == custom.roles)
        #expect(item.muscleInvolvement.role(for: .vasti) == .primary)
        #expect(item.muscleInvolvement.role(for: .pectoralisMajorSternocostal) == nil)
    }

    @Test func customDraftRequiresExplicitMuscleRoles() {
        var draft = CatalogDraft.empty
        #expect(draft.muscleInvolvement.isEmpty)
        draft.group = .legs
        #expect(draft.muscleInvolvement.isEmpty)

        draft.muscleInvolvementSnapshot = Muscle.Involvement(contributions: [
            .init(muscle: .gluteMed, role: .primary)
        ]).snapshot
        #expect(draft.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(draft.muscleInvolvement.role(for: .gluteMax) == nil)
    }

    @Test func everyPushPullRecordHasDirectionAndOtherPatternsDoNot() {
        for record in CatalogData.records {
            let isPushPull = record.pattern == .push || record.pattern == .pull
            #expect((record.direction != nil) == isPushPull)
        }
    }

    @Test func catalogItemKeepsDirectionConsistentWithPattern() {
        let item = ExerciseCatalogItem(
            name: "Test Press",
            group: .chest,
            defaultWeight: 0,
            pattern: .push,
            direction: .diagonal
        )
        #expect(item.movementLabel == "Diagonal Push")

        item.pattern = .squat
        #expect(item.direction == nil)
        #expect(item.movementLabel == "Squat")
    }
}
