//
//  CatalogBiomechanicsTests.swift
//  vivobodyTests
//
//  Guards the bundled exercise catalog as a biomechanics data product:
//  stable global vocabulary, authored movement definitions, modality/load
//  invariants, clean record consolidation, and high-risk anatomy fixtures.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct CatalogBiomechanicsTests {

    @Test func stableIDsNamesAndAliasesAreGloballyUnique() {
        #expect(CatalogData.records.count == 599)
        var catalogIDs: Set<String> = []
        var vocabularyOwners: [String: String] = [:]

        for record in CatalogData.records {
            #expect(
                Self.isStableCatalogID(record.catalogID),
                "'\(record.name)' has an invalid stable ID: '\(record.catalogID)'"
            )
            #expect(
                catalogIDs.insert(record.catalogID).inserted,
                "Duplicate stable catalog ID: '\(record.catalogID)'"
            )

            for term in [record.name] + record.aliases {
                let normalizedTerm = Self.normalized(term)
                #expect(!normalizedTerm.isEmpty, "'\(record.name)' has an empty name or alias")

                if let existingOwner = vocabularyOwners[normalizedTerm] {
                    Issue.record(
                        "Vocabulary term '\(term)' belongs to both '\(existingOwner)' and '\(record.name)'"
                    )
                } else {
                    vocabularyOwners[normalizedTerm] = record.name
                }
            }
        }
    }

    @Test func movementDefinitionsAreAuthoredAndNonGeneric() {
        let generatedPrefixes = ["a bilateral ", "a unilateral "]

        for record in CatalogData.records {
            let definition = record.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedDefinition = definition.lowercased()
            let hasGeneratedPrefix = generatedPrefixes.contains { normalizedDefinition.hasPrefix($0) }

            #expect(!definition.isEmpty, "'\(record.name)' has no movement definition")
            #expect(definition.count >= 24, "'\(record.name)' has an underspecified movement definition")
            #expect(
                definition.last == "." || definition.last == "!" || definition.last == "?",
                "'\(record.name)' has an incomplete movement definition"
            )
            #expect(
                !hasGeneratedPrefix,
                "'\(record.name)' still uses a generated laterality/equipment definition"
            )
            #expect(
                !normalizedDefinition.contains("exercise performed primarily in the"),
                "'\(record.name)' still uses the generic movement-definition template"
            )
        }
    }

    @Test func malformedRecordsAreGoneAndRenamesAreCanonical() {
        let allVocabulary = Set(CatalogData.records.flatMap { record in
            ([record.name] + record.aliases).map(Self.normalized)
        })
        let canonicalNames = Set(CatalogData.records.map { Self.normalized($0.name) })

        let retiredNames = [
            "Neutral-grip pull-ups or TRX rows",
            "Lying Dumbbell Row SS Seated Shrug",
            "Rope Pullover/row",
            "Assisted chin-ups",
            "Assisted Pull-Up",
            "Pull Ups on Machine",
            "Triceps Dips (Assisted)",
            "Lying Rotator Cuff Exercise",
            "Lateral-to-Front Raises",
            "Shoulder Raise Side and Front DB",
            "Bizeps Curls Trifecta",
            "Hyper Y W Combo",
            "YWTs",
            "Reverse Fly Standing",
            "Lunge Matrix",
            "Military Press mit SZ-Bar",
            "Punch Iso Holds",
        ]
        for retiredName in retiredNames {
            #expect(
                !allVocabulary.contains(Self.normalized(retiredName)),
                "Retired movement remains as a record or alias: '\(retiredName)'"
            )
        }

        let obsoleteCanonicalNames = [
            "Trap press",
            "Dynamic Planche",
            "Dynamic side hold",
            "Shoulder Dumbbell Pendular Exercise",
        ]
        for obsoleteName in obsoleteCanonicalNames {
            #expect(
                !canonicalNames.contains(Self.normalized(obsoleteName)),
                "Ambiguous canonical record was not renamed: '\(obsoleteName)'"
            )
        }

        let consolidatedDuplicateCanonicals = [
            "Barbell Clean and press",
            "Hip Thrust",
            "Walking Lunges",
            "Shoulder External Rotation (Cable)",
            "Seated Hip Abduction",
            "Reverse Curl",
            "2 Handed Kettlebell Swing",
            "Calf Raise using Hack Squat Machine",
            "Push-Ups | Incline",
            "Bench Dips On Floor HD",
            "Pec deck rear delt fly",
            "Bench Press Narrow Grip",
            "Cable Front Raise with a small bar",
            "Flat Machine Press",
            "Romanian Deadlift",
            "Incline Bench Press - Dumbbell",
            "Incline Chest Press DB",
            "Shoulder Shrug",
            "Butterfly Narrow Grip",
            "Australian pull-ups",
            "Rowing with TRX band",
            "Lower Back Extensions",
            "Pendular hack",
            "Step-ups",
            "Shoulder External Rotation with Dumbbell",
            "Push-Ups | Decline",
            "Strict Press-Ups",
            "Wide Pull Up",
            "Incline Dumbbell Row",
            "Shrugs, Dumbbells",
            "Front Raises with Plates",
            "Tricep Dumbbell Kickback",
            "Leg Press Toe Press",
            "Alternate back lunges",
            "Bodyweight lunge HD",
            "Unilateral Lunges",
            "Inverted Lat Pull Down",
            "Biceps Close Grip Pull Down",
            "Long-Pulley, Narrow",
            "Rowing seated, narrow grip",
            "One Arm Triceps Extensions on Cable",
            "Tricep Pushdown on Cable",
            "Triceps Extensions on Cable",
            "Lying Triceps Extensions",
            "Quadruped Hip Abduction",
            "Fast Pogos",
            "Single arm row",
            "Push OHP",
            "Lateral Rows on Cable, One Armed",
            "Schoulder Raise (Dumbbell)",
        ]
        for obsoleteName in consolidatedDuplicateCanonicals {
            #expect(
                !canonicalNames.contains(Self.normalized(obsoleteName)),
                "Semantic duplicate remains canonical: '\(obsoleteName)'"
            )
        }

        let replacements: [String: String] = [
            "Supine Serratus Punch": "supine-serratus-punch",
            "Plank In-and-Out Jump": "plank-in-and-out-jump",
            "Kettlebell Suitcase Hold with March": "kettlebell-suitcase-hold-with-march",
            "Codman Pendulum": "codman-pendulum",
            "Clamshell": "clamshell",
            "Side-Plank Clamshell": "side-plank-clamshell",
            "Dumbbell Frog Pump": "dumbbell-frog-pump",
            "Pendlay Row": "pendlay-row",
            "Side-Lying Dumbbell Internal Rotation": "side-lying-dumbbell-internal-rotation",
            "Lying Leg Curl": "lying-leg-curl",
            "Single-Leg Lunge with Kettlebell": "single-leg-lunge-with-kettlebell",
            "Push-Up Wipers": "push-up-wipers",
        ]
        for (name, expectedID) in replacements {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record != nil, "Missing canonical replacement '\(name)'")
            #expect(record?.catalogID == expectedID, "'\(name)' changed stable catalog ID")
        }
    }

    @Test func modalityLoadAndClassificationInvariantsHoldAcrossBundle() {
        for record in CatalogData.records {
            switch record.modality {
            case .dynamicStrength:
                #expect(record.trackingMode == .reps, "'\(record.name)' is dynamic strength but not rep-tracked")
            case .isometricStrength:
                #expect(record.trackingMode == .duration, "'\(record.name)' is isometric but not duration-tracked")
                #expect((record.defaultDuration ?? 0) > 0, "'\(record.name)' has no positive hold duration")
            case .power:
                #expect(record.trackingMode == .reps, "'\(record.name)' is power work but not rep-tracked")
            case .conditioning, .mobility:
                break
            }

            if record.modality.requiresPrimaryMuscle {
                #expect(
                    record.involvement.contains { $0.role == .primary },
                    "Strength/power movement '\(record.name)' has no primary muscle"
                )
                #expect(
                    record.involvement.contains { $0.role == .primary && $0.muscle.group == record.group },
                    "'\(record.name)' has no primary muscle matching its browse group"
                )
            }

            switch record.loadMode {
            case .external, .nonComparable:
                #expect(
                    record.bodyweightFraction == 0,
                    "'\(record.name)' has a bodyweight coefficient for load mode \(record.loadMode.rawValue)"
                )
            case .bodyweightAdded, .assistanceSubtracted:
                #expect(
                    record.bodyweightFraction > 0 && record.bodyweightFraction <= 1,
                    "'\(record.name)' has no valid bodyweight coefficient"
                )
            }

            if record.equipment == .band {
                #expect(
                    record.loadMode == .nonComparable,
                    "Band movement '\(record.name)' cannot claim a comparable load"
                )
            }

            switch record.mechanic {
            case .compound:
                #expect(record.pattern != nil, "Compound movement '\(record.name)' has no pattern")
            case .isolation:
                #expect(record.pattern == nil, "Isolation movement '\(record.name)' has a compound pattern")
            }

            let isPushPull = record.pattern == .push || record.pattern == .pull
            #expect(
                (record.direction != nil) == isPushPull,
                "'\(record.name)' has inconsistent push/pull direction metadata"
            )
        }
    }

    @Test func gluteMaxAndGluteMedStayAnatomicallySeparate() throws {
        let hipThrust = try #require(CatalogData.record(forExerciseNamed: "Barbell Hip Thrust"))
        #expect(hipThrust.muscleInvolvement.role(for: .gluteMax) == .primary)
        #expect(hipThrust.muscleInvolvement.role(for: .gluteMed) == nil)

        let hipAbduction = try #require(CatalogData.record(forExerciseNamed: "Machine Hip Abduction"))
        #expect(hipAbduction.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(hipAbduction.muscleInvolvement.role(for: .gluteMax) == nil)

        let clamshell = try #require(CatalogData.record(forExerciseNamed: "Clamshell"))
        #expect(clamshell.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(clamshell.muscleInvolvement.role(for: .gluteMax) == .secondary)

        let sidePlankClamshell = try #require(CatalogData.record(forExerciseNamed: "Side-Plank Clamshell"))
        #expect(sidePlankClamshell.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(sidePlankClamshell.muscleInvolvement.role(for: .gluteMax) == .secondary)
        #expect(sidePlankClamshell.muscleInvolvement.role(for: .obliques) == .primary)
    }

    @Test func rotatorCuffActionsUseSeparatedRegions() throws {
        let externalRotation = try #require(CatalogData.record(forExerciseNamed: "Cable External Rotation"))
        #expect(externalRotation.muscleInvolvement.role(for: .externalRotators) == .primary)
        #expect(externalRotation.muscleInvolvement.role(for: .subscapularis) == nil)
        #expect(externalRotation.muscleInvolvement.role(for: .teresMajor) == nil)

        let internalRotation = try #require(CatalogData.record(forExerciseNamed: "Shoulder Internal Rotation (Cable)"))
        #expect(internalRotation.muscleInvolvement.role(for: .subscapularis) == .primary)
        #expect(internalRotation.muscleInvolvement.role(for: .teresMajor) == .secondary)
        #expect(internalRotation.muscleInvolvement.role(for: .externalRotators) == nil)

        let verticalPull = try #require(CatalogData.record(forExerciseNamed: "L-Sit Pull-ups"))
        #expect(verticalPull.muscleInvolvement.role(for: .teresMajor) == .secondary)
        #expect(verticalPull.muscleInvolvement.role(for: .subscapularis) == nil)
    }

    @Test func renamedMovementsKeepTheirIntendedSemantics() throws {
        let serratusPunch = try #require(CatalogData.record(forExerciseNamed: "Supine Serratus Punch"))
        #expect(serratusPunch.group == .chest)
        #expect(serratusPunch.mechanic == .isolation)
        #expect(serratusPunch.plane == .transverse)
        #expect(serratusPunch.modality == .dynamicStrength)
        #expect(serratusPunch.loadMode == .external)
        #expect(serratusPunch.muscleInvolvement.role(for: .serratus) == .primary)

        let plankJump = try #require(CatalogData.record(forExerciseNamed: "Plank In-and-Out Jump"))
        #expect(plankJump.group == .core)
        #expect(plankJump.modality == .conditioning)
        #expect(plankJump.loadMode == .nonComparable)
        #expect(plankJump.pattern == .core)

        let suitcaseMarch = try #require(CatalogData.record(forExerciseNamed: "Kettlebell Suitcase Hold with March"))
        #expect(suitcaseMarch.group == .core)
        #expect(suitcaseMarch.modality == .isometricStrength)
        #expect(suitcaseMarch.trackingMode == .duration)
        #expect(suitcaseMarch.loadMode == .external)
        #expect(suitcaseMarch.pattern == .carry)
        #expect(suitcaseMarch.laterality == .unilateral)
        #expect(suitcaseMarch.muscleInvolvement.role(for: .obliques) == .primary)

        let codman = try #require(CatalogData.record(forExerciseNamed: "Codman Pendulum"))
        #expect(codman.modality == .mobility)
        #expect(codman.loadMode == .nonComparable)
        #expect(codman.mechanic == .isolation)
        #expect(
            codman.involvement.allSatisfy { $0.role == .stabilizer },
            "Codman Pendulum should describe passive mobility, not hard-set muscle targets"
        )
    }

    @Test func highRiskMovementCorrectionsRemainCurated() throws {
        let jumpingJacks = try #require(CatalogData.record(forExerciseNamed: "Jumping Jacks"))
        #expect(jumpingJacks.modality == .conditioning)
        #expect(jumpingJacks.trackingMode == .duration)
        #expect(jumpingJacks.pattern == .locomotion)
        #expect(jumpingJacks.plane == .frontal)
        #expect(jumpingJacks.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(jumpingJacks.muscleInvolvement.role(for: .deltoids) == .primary)

        let toePress = try #require(CatalogData.record(forExerciseNamed: "Calf Press Using Leg Press Machine"))
        #expect(toePress.group == .legs)
        #expect(toePress.mechanic == .isolation)
        #expect(toePress.muscleInvolvement.role(for: .calves) == .primary)
        #expect(toePress.muscleInvolvement.role(for: .quads) == .stabilizer)

        let sideSlides = try #require(CatalogData.record(forExerciseNamed: "Side Slides + Squats"))
        #expect(sideSlides.plane == .frontal)
        #expect(sideSlides.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(sideSlides.muscleInvolvement.role(for: .quads) == .primary)

        let reversePlank = try #require(CatalogData.record(forExerciseNamed: "Reverse Plank"))
        #expect(reversePlank.modality == .isometricStrength)
        #expect(reversePlank.trackingMode == .duration)
        #expect(reversePlank.muscleInvolvement.role(for: .gluteMax) == .primary)
        #expect(reversePlank.muscleInvolvement.role(for: .lowerBack) == .primary)

        let sidePlank = try #require(CatalogData.record(forExerciseNamed: "Side Plank"))
        #expect(sidePlank.modality == .isometricStrength)
        #expect(sidePlank.plane == .frontal)
        #expect(sidePlank.laterality == .unilateral)
        #expect(sidePlank.muscleInvolvement.role(for: .obliques) == .primary)
        #expect(sidePlank.muscleInvolvement.role(for: .gluteMed) == .secondary)

        let powerClean = try #require(CatalogData.record(forExerciseNamed: "Power Clean"))
        #expect(powerClean.modality == .power)
        #expect(powerClean.loadMode == .external)

        let squatJump = try #require(CatalogData.record(forExerciseNamed: "Squat Jumps"))
        #expect(squatJump.modality == .power)
        #expect(squatJump.loadMode == .nonComparable)

        let plankJacks = try #require(CatalogData.record(forExerciseNamed: "Plank Jacks"))
        #expect(plankJacks.modality == .conditioning)
        #expect(plankJacks.pattern == .core)
        #expect(plankJacks.plane == .frontal)

        let hamstringKicks = try #require(CatalogData.record(forExerciseNamed: "Hamstring Kicks"))
        #expect(hamstringKicks.modality == .mobility)
        #expect(hamstringKicks.loadMode == .nonComparable)
    }

    @Test func correctedGroupsPlanesAndLateralityRemainExplicit() {
        let groupFixtures: [(String, MuscleGroup)] = [
            ("L-Sit Pull-ups", .back),
            ("Push-up rotations", .chest),
            ("Wall Pushup", .chest),
            ("Chair dips", .arms),
            ("No push-up burpees", .legs),
            ("Sled Push", .legs),
            ("Glute Bridge Single-Arm Press", .chest),
        ]
        for (name, expectedGroup) in groupFixtures {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record != nil, "Missing corrected group fixture '\(name)'")
            #expect(record?.group == expectedGroup, "'\(name)' has the wrong browse group")
        }

        let planeFixtures: [(String, MovementPlane)] = [
            ("Reverse Snow Angel", .frontal),
            ("Prone Scapular Retraction - Arms at Side", .transverse),
            ("Cable External Rotation", .transverse),
            ("Low-Cable Cross-Over - NB", .transverse),
            ("Omni Cable Cross-over", .transverse),
            ("Bus Drivers", .transverse),
        ]
        for (name, expectedPlane) in planeFixtures {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record != nil, "Missing corrected plane fixture '\(name)'")
            #expect(record?.plane == expectedPlane, "'\(name)' has the wrong movement plane")
        }

        let unilateralFixtures = [
            "Alternating High Cable Row",
            "bicycle crunches",
            "Bird Dog",
            "Black Widow Knee Slides",
            "Deadbug",
            "Mountain climbers",
            "Plank Shoulder Taps",
            "TRX Obliques",
            "Cable External Rotation",
        ]
        for name in unilateralFixtures {
            let record = CatalogData.record(forExerciseNamed: name)
            #expect(record != nil, "Missing laterality fixture '\(name)'")
            #expect(record?.laterality == .unilateral, "'\(name)' should be unilateral")
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func isStableCatalogID(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            value.first != "-",
            value.last != "-",
            !value.contains("--")
        else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            (97...122).contains(scalar.value)
                || (48...57).contains(scalar.value)
                || scalar.value == 45
        }
    }
}
