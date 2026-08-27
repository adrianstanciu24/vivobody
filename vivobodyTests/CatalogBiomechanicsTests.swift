//
//  CatalogBiomechanicsTests.swift
//  vivobodyTests
//
//  Guards the family-first runtime projection as one canonical data
//  product: 71 reviewed families compile to 166 exercises with stable
//  identities, multi-plane classification, exact muscle regions, and
//  coherent modality/load semantics.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct CatalogBiomechanicsTests {
    @Test func canonicalFamilyAndExerciseCountsArePinned() {
        #expect(CatalogData.records.count == 166)
        #expect(Set(CatalogData.records.map(\.familyID)).count == 71)
        #expect(CatalogData.record(forCatalogID: "barbell-bench-press")?.familyID == "horizontal-press")
        #expect(CatalogData.record(forCatalogID: "pull-up")?.familyID == "vertical-pull")
        #expect(CatalogData.record(forCatalogID: "seated-45-degree-cable-pulldown")?.familyID == "diagonal-pull")
        #expect(CatalogData.record(forCatalogID: "repetitive-grip-trainer-close")?.familyID == "finger-flexion-grip")
        #expect(CatalogData.record(forCatalogID: "conventional-barbell-deadlift")?.familyID == "conventional-deadlift")
        #expect(CatalogData.record(forCatalogID: "barbell-romanian-deadlift")?.familyID == "romanian-deadlift")
        #expect(CatalogData.record(forCatalogID: "barbell-power-clean")?.modality == .power)
        #expect(CatalogData.record(forCatalogID: "wall-sit")?.trackingMode == .duration)
    }

    @Test func stableIDsNamesAndAliasesAreGloballyUnique() {
        var catalogIDs: Set<String> = []
        var vocabularyOwners: [String: String] = [:]

        for record in CatalogData.records {
            #expect(Self.isStableID(record.familyID))
            #expect(Self.isStableID(record.catalogID))
            #expect(catalogIDs.insert(record.catalogID).inserted)
            #expect((0 ... 100).contains(record.searchPriorityValue))

            for term in [record.name] + record.aliases {
                let normalizedTerm = Self.normalized(term)
                #expect(!normalizedTerm.isEmpty)
                if let owner = vocabularyOwners[normalizedTerm] {
                    Issue.record("Vocabulary term '\(term)' belongs to both '\(owner)' and '\(record.name)'")
                } else {
                    vocabularyOwners[normalizedTerm] = record.name
                }
            }
        }
    }

    @Test func executionInstructionsAreAuthoredAndComplete() {
        for record in CatalogData.records {
            let execution = record.execution
            let texts = [
                execution.startingPosition,
                execution.movement,
                execution.endpoint,
                execution.controlledJoints,
                execution.supportAndPosture,
            ] + execution.disqualifyingCompensations
                + [execution.returnPhase, execution.sideOrDirection].compactMap { $0 }

            for text in texts {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let words = trimmed
                    .split(whereSeparator: \.isWhitespace)
                    .map {
                        String($0)
                            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                            .lowercased()
                    }
                    .filter { !$0.isEmpty }

                #expect(trimmed == text)
                #expect(trimmed.count >= 12, "'\(record.name)' has an underspecified instruction")
                #expect(trimmed.first?.isUppercase == true)
                #expect(trimmed.last == "." || trimmed.last == "!" || trimmed.last == "?")
                #expect(!zip(words, words.dropFirst()).contains { left, right in left == right })
            }

            #expect(!execution.disqualifyingCompensations.isEmpty)
            #expect(
                Set(execution.disqualifyingCompensations).count
                    == execution.disqualifyingCompensations.count
            )
            #expect((execution.returnPhase != nil) == (record.trackingMode == .reps))
            #expect(
                (execution.sideOrDirection != nil)
                    == (record.laterality == .unilateral || record.pattern == .carry)
            )
        }
    }

    @Test func modalityLoadAndClassificationInvariantsHoldAcrossBundle() {
        for record in CatalogData.records {
            switch record.modality {
            case .dynamicStrength, .power:
                #expect(record.trackingMode == .reps)
            case .isometricStrength:
                #expect(record.trackingMode == .duration)
                #expect((record.defaultDuration ?? 0) > 0)
            }

            #expect(record.involvement.contains { $0.role == .primary })
            #expect(record.involvement.contains {
                $0.role == .primary && $0.muscle.group == record.group
            })

            switch record.loadMode {
            case .external, .nonComparable:
                #expect(record.bodyweightFraction == 0)
            case .bodyweightAdded, .assistanceSubtracted:
                #expect(record.bodyweightFraction > 0 && record.bodyweightFraction <= 1)
            }

            if record.equipment == .band {
                #expect(record.loadMode == .nonComparable)
            }

            switch record.mechanic {
            case .compound:
                #expect(record.pattern != nil)
            case .isolation:
                #expect(record.pattern == nil)
            }

            if record.pattern == .push || record.pattern == .pull {
                #expect(record.trainingRole.rawValue == record.pattern?.rawValue)
            }

            let isPushPull = record.pattern == .push || record.pattern == .pull
            #expect((record.direction != nil) == isPushPull)
            #expect(!record.planes.isEmpty)
            #expect(Set(record.planes).count == record.planes.count)

            if record.defaultWeight > 0 {
                let kilograms = record.defaultWeightKg
                #expect(kilograms != nil)
                if let kilograms {
                    #expect(abs((kilograms / 2.5).rounded() - kilograms / 2.5) < 0.000_001)
                }
            }
        }

        #expect(CatalogData.records.contains { $0.equipment == .band })
    }

    @Test func directionsAndPlaneComponentsPreserveReviewedFamilyContracts() throws {
        let flat = try #require(CatalogData.record(forExerciseNamed: "Barbell Bench Press"))
        #expect(flat.familyID == "horizontal-press")
        #expect(flat.direction == .horizontal)
        #expect(flat.planes == [.transverse])

        let incline = try #require(CatalogData.record(forExerciseNamed: "Incline Barbell Bench Press"))
        #expect(incline.familyID == "incline-press")
        #expect(incline.direction == .diagonal)
        #expect(incline.planes == [.sagittal, .transverse])

        let decline = try #require(CatalogData.record(forExerciseNamed: "Decline Barbell Bench Press"))
        #expect(decline.familyID == "decline-press")
        #expect(decline.direction == .diagonal)
        #expect(decline.planes == [.transverse])

        let pullUp = try #require(CatalogData.record(forExerciseNamed: "Pull-Up"))
        #expect(pullUp.direction == .vertical)
        #expect(pullUp.planes == [.sagittal, .frontal])

        let pushPress = try #require(CatalogData.record(forExerciseNamed: "Barbell Push Press"))
        #expect(pushPress.direction == .vertical)
        #expect(pushPress.planes == [.sagittal, .frontal])
    }

    @Test func trapBarEquipmentAndHandleFixturesAreFirstClass() throws {
        #expect(Equipment.trapBar.rawValue == "trapBar")
        #expect(Equipment.trapBar.displayName == "Trap Bar")

        let lowHandle = try #require(
            CatalogData.record(forCatalogID: "low-handle-trap-bar-deadlift")
        )
        let highHandle = try #require(
            CatalogData.record(forCatalogID: "high-handle-trap-bar-deadlift")
        )

        #expect(lowHandle.name == "Low-Handle Trap-Bar Deadlift")
        #expect(highHandle.name == "High-Handle Trap-Bar Deadlift")
        #expect(
            Set(
                CatalogData.records
                    .filter { $0.familyID == "trap-bar-deadlift" }
                    .map(\.catalogID)
            ) == [
                "low-handle-trap-bar-deadlift",
                "high-handle-trap-bar-deadlift",
            ]
        )

        for record in [lowHandle, highHandle] {
            #expect(record.familyID == "trap-bar-deadlift")
            #expect(record.equipment == .trapBar)
            #expect(record.laterality == .bilateral)
            #expect(record.mechanic == .compound)
            #expect(record.pattern == .hinge)
            #expect(record.planes == [.sagittal])
            #expect(record.modality == .dynamicStrength)
            #expect(record.trackingMode == .reps)
            #expect(record.loadMode == .external)
            #expect(record.bodyweightFraction == 0)
            #expect(record.reps == 1)
            #expect(record.defaultWeight == 45)
            #expect(record.defaultWeightKg == 20)
            #expect(record.muscleInvolvement.role(for: .gluteMax) == .primary)
            #expect(record.muscleInvolvement.role(for: .vasti) == .primary)
            #expect(record.muscleInvolvement.role(for: .rectusFemoris) == .secondary)
            #expect(record.muscleInvolvement.role(for: .gastrocnemius) == .secondary)
            #expect(record.muscleInvolvement.role(for: .soleus) == .secondary)
            #expect(record.muscleInvolvement.role(for: .medialHamstrings) == .stabilizer)
            #expect(record.muscleInvolvement.role(for: .bicepsFemoris) == .stabilizer)
            #expect(record.muscleInvolvement.role(for: .fingerFlexors) == .stabilizer)
            #expect(record.muscleInvolvement.role(for: .lumbarExtensors) == .stabilizer)
        }
    }

    @Test func sumoDeadliftKeepsThreeJointCompoundRuntimeSignature() throws {
        let sumo = try #require(
            CatalogData.record(forCatalogID: "barefoot-dead-stop-sumo-barbell-deadlift")
        )

        #expect(sumo.familyID == "sumo-deadlift")
        #expect(sumo.name == "Barefoot Dead-Stop Sumo Barbell Deadlift")
        #expect(sumo.aliases == [
            "Sumo Barbell Deadlift",
            "Sumo Deadlift",
            "Double-Overhand Dead-Stop Sumo Deadlift",
        ])
        #expect(sumo.equipment == .barbell)
        #expect(sumo.laterality == .bilateral)
        #expect(sumo.mechanic == .compound)
        #expect(sumo.trainingRole == .legs)
        #expect(sumo.pattern == .hinge)
        #expect(sumo.planes == [.sagittal])
        #expect(sumo.modality == .dynamicStrength)
        #expect(sumo.trackingMode == .reps)
        #expect(sumo.loadMode == .external)
        #expect(sumo.bodyweightFraction == 0)
        #expect(sumo.reps == 3)
        #expect(sumo.defaultWeight == 45)
        #expect(sumo.defaultWeightKg == 20)

        #expect(sumo.muscleInvolvement.role(for: .gluteMax) == .primary)
        #expect(sumo.muscleInvolvement.role(for: .vasti) == .primary)
        #expect(sumo.muscleInvolvement.role(for: .rectusFemoris) == .secondary)
        #expect(sumo.muscleInvolvement.role(for: .gastrocnemius) == .secondary)
        #expect(sumo.muscleInvolvement.role(for: .soleus) == .secondary)
        #expect(sumo.muscleInvolvement.role(for: .medialHamstrings) == .stabilizer)
        #expect(sumo.muscleInvolvement.role(for: .adductorMagnus) == .stabilizer)

        let item = ExerciseCatalogItem(record: sumo, createdAt: Date(timeIntervalSince1970: 0))
        let aliasMatch = ExerciseSearch.rank(items: [item], query: "Sumo Deadlift")
        #expect(aliasMatch.first?.catalogID == sumo.catalogID)
    }

    @Test func singleLegDeadliftsKeepHipOnlyProjectionAndLoadSideAliases() throws {
        let barbell = try #require(
            CatalogData.record(forCatalogID: "barbell-single-leg-deadlift")
        )
        let sameSide = try #require(
            CatalogData.record(
                forCatalogID: "dumbbell-single-leg-romanian-deadlift-ipsilateral-load"
            )
        )
        let oppositeSide = try #require(
            CatalogData.record(
                forCatalogID: "dumbbell-single-leg-romanian-deadlift-contralateral-load"
            )
        )

        #expect(
            Set(
                CatalogData.records
                    .filter { $0.familyID == "single-leg-deadlift" }
                    .map(\.catalogID)
            ) == [
                "barbell-single-leg-deadlift",
                "dumbbell-single-leg-romanian-deadlift-ipsilateral-load",
                "dumbbell-single-leg-romanian-deadlift-contralateral-load",
            ]
        )

        for record in [barbell, sameSide, oppositeSide] {
            #expect(record.familyID == "single-leg-deadlift")
            #expect(record.laterality == .unilateral)
            #expect(record.mechanic == .compound)
            #expect(record.trainingRole == .legs)
            #expect(record.pattern == .hinge)
            #expect(record.planes == [.sagittal])
            #expect(record.modality == .dynamicStrength)
            #expect(record.trackingMode == .reps)
            #expect(record.loadMode == .external)
            #expect(record.bodyweightFraction == 0)
            #expect(record.muscleInvolvement.role(for: .medialHamstrings) == .primary)
            #expect(record.muscleInvolvement.role(for: .gluteMax) == .primary)
            #expect(record.muscleInvolvement.role(for: .lumbarExtensors) == .secondary)
            #expect(record.muscleInvolvement.role(for: .vasti) == nil)
            #expect(record.muscleInvolvement.role(for: .rectusFemoris) == nil)
            #expect(record.muscleInvolvement.role(for: .gastrocnemius) == .stabilizer)
            #expect(record.muscleInvolvement.role(for: .soleus) == .stabilizer)
            #expect(record.muscleInvolvement.role(for: .gluteMed) == .stabilizer)
        }

        #expect(barbell.name == "Barbell Single-Leg Deadlift")
        #expect(barbell.equipment == .barbell)
        #expect(barbell.reps == 5)
        #expect(barbell.defaultWeight == 45)
        #expect(barbell.defaultWeightKg == 20)

        #expect(sameSide.name == "Ipsilateral-Load Dumbbell Single-Leg Romanian Deadlift")
        #expect(sameSide.equipment == .dumbbell)
        #expect(sameSide.reps == 6)
        #expect(sameSide.defaultWeight == 25)
        #expect(sameSide.defaultWeightKg == 12.5)
        #expect(sameSide.aliases.contains("Same-Side-Load Dumbbell Single-Leg Romanian Deadlift"))

        #expect(oppositeSide.name == "Contralateral-Load Dumbbell Single-Leg Romanian Deadlift")
        #expect(oppositeSide.equipment == .dumbbell)
        #expect(oppositeSide.reps == 6)
        #expect(oppositeSide.defaultWeight == 25)
        #expect(oppositeSide.defaultWeightKg == 12.5)
        #expect(oppositeSide.aliases.contains(
            "Opposite-Side-Load Dumbbell Single-Leg Romanian Deadlift"
        ))

        let createdAt = Date(timeIntervalSince1970: 0)
        let items = [barbell, sameSide, oppositeSide].map {
            ExerciseCatalogItem(record: $0, createdAt: createdAt)
        }
        let sameSideMatch = ExerciseSearch.rank(
            items: items,
            query: "Same-Side-Load Dumbbell Single-Leg Romanian Deadlift"
        )
        let oppositeSideMatch = ExerciseSearch.rank(
            items: items,
            query: "Opposite-Side-Load Dumbbell Single-Leg Romanian Deadlift"
        )
        #expect(sameSideMatch.first?.catalogID == sameSide.catalogID)
        #expect(oppositeSideMatch.first?.catalogID == oppositeSide.catalogID)
    }

    @Test func trainingRolesCoverCompoundAndIsolationProgrammingPlacement() throws {
        let bench = try #require(CatalogData.record(forExerciseNamed: "Barbell Bench Press"))
        let fly = try #require(CatalogData.record(forExerciseNamed: "Flat Dumbbell Fly"))
        let curl = try #require(CatalogData.record(forExerciseNamed: "Supinated Straight-Bar Cable Curl"))
        let reverseFly = try #require(CatalogData.record(forExerciseNamed: "Prone Dumbbell Reverse Fly"))
        let legExtension = try #require(CatalogData.record(forExerciseNamed: "Upright Unilateral Machine Leg Extension"))

        #expect(bench.trainingRole == .push)
        #expect(fly.mechanic == .isolation && fly.trainingRole == .push)
        #expect(curl.mechanic == .isolation && curl.trainingRole == .pull)
        #expect(reverseFly.mechanic == .isolation && reverseFly.trainingRole == .pull)
        #expect(legExtension.trainingRole == .legs)
    }

    @Test func highRiskAnatomyFixturesKeepExactRegions() throws {
        let bench = try #require(CatalogData.record(forExerciseNamed: "Barbell Bench Press"))
        #expect(bench.muscleInvolvement.role(for: .pectoralisMajorSternocostal) == .primary)
        #expect(bench.muscleInvolvement.role(for: .pectoralisMajorClavicular) == .secondary)
        #expect(bench.muscleInvolvement.role(for: .deltoidAnterior) == .secondary)
        #expect(bench.muscleInvolvement.role(for: .triceps) == .secondary)

        for name in ["Bar Dip", "Ring Dip"] {
            let dip = try #require(CatalogData.record(forExerciseNamed: name))
            #expect(dip.muscleInvolvement.role(for: .pectoralisMajorClavicular) == .primary)
            #expect(dip.muscleInvolvement.role(for: .pectoralisMajorSternocostal) == .primary)
            #expect(dip.muscleInvolvement.anatomyNodeChannels[
                "Pectoralis_Major_Sternocostal_L"
            ]?.intensity == 1)
            #expect(dip.muscleInvolvement.anatomyNodeChannels[
                "Pectoralis_Major_Sternocostal_R"
            ]?.intensity == 1)
        }

        for name in ["Single-Arm Dumbbell Front Raise", "Seated Dumbbell Overhead Press"] {
            let neutralStartFlexion = try #require(
                CatalogData.record(forExerciseNamed: name)
            )
            #expect(
                neutralStartFlexion.muscleInvolvement.role(
                    for: .pectoralisMajorSternocostal
                ) == nil
            )
        }

        let hipThrust = try #require(CatalogData.record(forExerciseNamed: "Barbell Hip Thrust"))
        #expect(hipThrust.muscleInvolvement.role(for: .gluteMax) == .primary)
        #expect(hipThrust.muscleInvolvement.role(for: .gluteMed) == .stabilizer)
        #expect(hipThrust.muscleInvolvement.role(for: .vasti) == .secondary)

        let hipAbduction = try #require(
            CatalogData.record(forExerciseNamed: "Pressure-Biofeedback Side-Lying Hip Abduction")
        )
        #expect(hipAbduction.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(hipAbduction.muscleInvolvement.role(for: .tensorFasciaeLatae) == .secondary)
        #expect(hipAbduction.muscleInvolvement.role(for: .gluteMax) == nil)

        let internalRotation = try #require(
            CatalogData.record(forExerciseNamed: "Seated Flywheel Hip Internal Rotation")
        )
        #expect(internalRotation.muscleInvolvement.role(for: .gluteMed) == .primary)
        #expect(internalRotation.muscleInvolvement.role(for: .tensorFasciaeLatae) == .primary)
        #expect(internalRotation.muscleInvolvement.role(for: .gluteMin) == .secondary)
        #expect(internalRotation.muscleInvolvement.role(for: .gluteMax) == nil)

        let externalRotation = try #require(
            CatalogData.record(forExerciseNamed: "Therapist-Held Supine Band Hip External Rotation")
        )
        #expect(externalRotation.muscleInvolvement.role(for: .obturatorInternusGemelli) == .primary)
        #expect(externalRotation.muscleInvolvement.role(for: .obturatorExternus) == .secondary)
        #expect(externalRotation.muscleInvolvement.role(for: .piriformis) == .secondary)
        #expect(externalRotation.muscleInvolvement.role(for: .quadratusFemoris) == .secondary)
        #expect(externalRotation.muscleInvolvement.role(for: .gluteMax) == nil)
        #expect(externalRotation.muscleInvolvement.role(for: .gluteMed) == nil)
        #expect(externalRotation.muscleInvolvement.role(for: .sartorius) == nil)

        let pallof = try #require(
            CatalogData.record(forExerciseNamed: "Feet-Together Band Pallof Hold")
        )
        #expect(pallof.muscleInvolvement.role(for: .fingerFlexors) == .stabilizer)
        #expect(pallof.muscleInvolvement.role(for: .extensorCarpiRadialis) == .stabilizer)

        let retraction = try #require(
            CatalogData.record(forExerciseNamed: "Standing Band Scapular Retraction")
        )
        #expect(retraction.familyID == "scapular-retraction")
        #expect(retraction.planes == [.transverse])
        #expect(retraction.muscleInvolvement.role(for: .trapeziusMiddle) == .primary)
        #expect(retraction.muscleInvolvement.role(for: .trapeziusLower) == .secondary)
        #expect(retraction.muscleInvolvement.role(for: .rhomboids) == nil)

        let depression = try #require(
            CatalogData.record(forExerciseNamed: "Standing Band Scapular Depression")
        )
        #expect(depression.familyID == "scapular-depression")
        #expect(depression.planes == [.frontal])
        #expect(depression.muscleInvolvement.role(for: .trapeziusLower) == .primary)
        #expect(depression.muscleInvolvement.role(for: .serratus) == .stabilizer)
        #expect(depression.muscleInvolvement.role(for: .pectoralisMinor) == nil)

        let stabilizationShrug = try #require(
            CatalogData.record(forExerciseNamed: "Bilateral 30-Degree Stabilization Shrug")
        )
        #expect(stabilizationShrug.familyID == "scapular-elevation")
        #expect(stabilizationShrug.muscleInvolvement.role(for: .trapeziusUpper) == .primary)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .levatorScapulae) == .primary)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .serratus) == .secondary)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .trapeziusLower) == .secondary)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .deltoidLateral) == .stabilizer)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .supraspinatus) == .stabilizer)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .fingerFlexors) == nil)
        #expect(stabilizationShrug.muscleInvolvement.role(for: .extensorCarpiRadialis) == nil)

        let uprightRow = try #require(
            CatalogData.record(forExerciseNamed: "Standing Low-Cable Upright Row")
        )
        #expect(uprightRow.familyID == "upright-row")
        #expect(uprightRow.mechanic == .compound)
        #expect(uprightRow.pattern == .pull)
        #expect(uprightRow.direction == .vertical)
        #expect(uprightRow.planes == [.sagittal, .frontal])
        #expect(uprightRow.muscleInvolvement.role(for: .deltoidLateral) == .primary)
        #expect(uprightRow.muscleInvolvement.role(for: .deltoidAnterior) == .secondary)
        #expect(uprightRow.muscleInvolvement.role(for: .supraspinatus) == .secondary)
        #expect(uprightRow.muscleInvolvement.role(for: .bicepsBrachii) == .secondary)
        #expect(uprightRow.muscleInvolvement.role(for: .trapeziusMiddle) == .stabilizer)

        let diagonalPull = try #require(
            CatalogData.record(forExerciseNamed: "Seated 45-Degree Cable Pulldown")
        )
        #expect(diagonalPull.familyID == "diagonal-pull")
        #expect(diagonalPull.mechanic == .compound)
        #expect(diagonalPull.pattern == .pull)
        #expect(diagonalPull.direction == .diagonal)
        #expect(diagonalPull.planes == [.sagittal])
        #expect(diagonalPull.loadMode == .external)
        #expect(diagonalPull.defaultWeight == 35)
        #expect(diagonalPull.defaultWeightKg == 15)
        #expect(diagonalPull.muscleInvolvement.role(for: .lats) == .primary)
        #expect(diagonalPull.muscleInvolvement.role(for: .teresMajor) == .secondary)
        #expect(diagonalPull.muscleInvolvement.role(for: .deltoidPosterior) == .secondary)
        #expect(diagonalPull.muscleInvolvement.role(for: .bicepsBrachii) == .secondary)
        #expect(diagonalPull.muscleInvolvement.role(for: .trapeziusMiddle) == .stabilizer)
        #expect(diagonalPull.muscleInvolvement.role(for: .rhomboids) == .stabilizer)
        #expect(diagonalPull.muscleInvolvement.role(for: .fingerFlexors) == .stabilizer)
        #expect(diagonalPull.muscleInvolvement.role(for: .extensorCarpiRadialis) == .stabilizer)

        let gripTrainer = try #require(
            CatalogData.record(forExerciseNamed: "Repetitive Grip-Trainer Close")
        )
        #expect(gripTrainer.familyID == "finger-flexion-grip")
        #expect(gripTrainer.mechanic == .isolation)
        #expect(gripTrainer.pattern == nil)
        #expect(gripTrainer.direction == nil)
        #expect(gripTrainer.planes == [.sagittal])
        #expect(gripTrainer.equipment == .gripTrainer)
        #expect(gripTrainer.equipment.displayName == "Grip Trainer")
        #expect(gripTrainer.laterality == .unilateral)
        #expect(gripTrainer.modality == .dynamicStrength)
        #expect(gripTrainer.trackingMode == .reps)
        #expect(gripTrainer.loadMode == .nonComparable)
        #expect(gripTrainer.defaultWeight == 0)
        #expect(gripTrainer.reps == 30)
        #expect(gripTrainer.muscleInvolvement.role(for: .fingerFlexors) == .primary)
        #expect(gripTrainer.muscleInvolvement.role(for: .extensorCarpiRadialis) == .stabilizer)
        #expect(gripTrainer.muscleInvolvement.contributions.count == 2)

        let landmine = try #require(
            CatalogData.record(forExerciseNamed: "Standing Single-Arm Landmine Press Power Test")
        )
        #expect(landmine.familyID == "landmine-press")
        #expect(landmine.mechanic == .compound)
        #expect(landmine.pattern == .push)
        #expect(landmine.direction == .diagonal)
        #expect(landmine.planes == [.sagittal])
        #expect(landmine.modality == .power)
        #expect(landmine.loadMode == .external)
        #expect(landmine.defaultWeight == 45)
        #expect(landmine.defaultWeightKg == 20)
        #expect(landmine.muscleInvolvement.role(for: .deltoidAnterior) == .primary)
        #expect(landmine.muscleInvolvement.role(for: .triceps) == .secondary)
        #expect(landmine.muscleInvolvement.role(for: .serratus) == .stabilizer)

        let handstand = try #require(
            CatalogData.record(forExerciseNamed: "Wall-Supported Strict Handstand Push-Up")
        )
        #expect(handstand.familyID == "vertical-press")
        #expect(handstand.mechanic == .compound)
        #expect(handstand.pattern == .push)
        #expect(handstand.direction == .vertical)
        #expect(handstand.planes == [.sagittal, .frontal])
        #expect(handstand.equipment == .bodyweight)
        #expect(handstand.loadMode == .nonComparable)
        #expect(handstand.defaultWeight == 0)
        #expect(handstand.muscleInvolvement.role(for: .deltoidAnterior) == .primary)
        #expect(handstand.muscleInvolvement.role(for: .triceps) == .secondary)
        #expect(handstand.muscleInvolvement.role(for: .fingerFlexors) == .stabilizer)
        #expect(handstand.muscleInvolvement.role(for: .gluteMax) == .stabilizer)

        let hipFlexion = try #require(
            CatalogData.record(forExerciseNamed: "Bodyweight Active Straight-Leg Raise")
        )
        #expect(hipFlexion.familyID == "hip-flexion")
        #expect(hipFlexion.mechanic == .isolation)
        #expect(hipFlexion.pattern == nil)
        #expect(hipFlexion.planes == [.sagittal])
        #expect(hipFlexion.loadMode == .nonComparable)
        #expect(hipFlexion.muscleInvolvement.role(for: .iliopsoas) == .primary)
        #expect(hipFlexion.muscleInvolvement.role(for: .rectusFemoris) == .secondary)
        #expect(hipFlexion.muscleInvolvement.role(for: .tensorFasciaeLatae) == nil)
        #expect(hipFlexion.muscleInvolvement.role(for: .sartorius) == nil)

        let goodMorning = try #require(
            CatalogData.record(forExerciseNamed: "25% Body-Mass Barbell Good Morning")
        )
        #expect(goodMorning.familyID == "hip-hinge")
        #expect(goodMorning.mechanic == .compound)
        #expect(goodMorning.pattern == .hinge)
        #expect(goodMorning.planes == [.sagittal])
        #expect(goodMorning.loadMode == .external)
        #expect(goodMorning.defaultWeight == 45)
        #expect(goodMorning.defaultWeightKg == 20)
        #expect(goodMorning.muscleInvolvement.role(for: .medialHamstrings) == .primary)
        #expect(goodMorning.muscleInvolvement.role(for: .gluteMax) == .primary)
        #expect(goodMorning.muscleInvolvement.role(for: .lumbarExtensors) == .primary)
        #expect(goodMorning.muscleInvolvement.role(for: .bicepsFemoris) == .stabilizer)

        for name in ["Bodyweight Forward Lunge", "Bodyweight Reverse Lunge"] {
            let lunge = try #require(CatalogData.record(forExerciseNamed: name))
            #expect(lunge.familyID == "dynamic-lunge")
            #expect(lunge.mechanic == .compound)
            #expect(lunge.pattern == .lunge)
            #expect(lunge.planes == [.sagittal])
            #expect(lunge.loadMode == .nonComparable)
            #expect(lunge.laterality == .unilateral)
            #expect(lunge.muscleInvolvement.role(for: .vasti) == .primary)
            #expect(lunge.muscleInvolvement.role(for: .gluteMax) == .primary)
            #expect(lunge.muscleInvolvement.role(for: .rectusFemoris) == .secondary)
            #expect(lunge.muscleInvolvement.role(for: .gastrocnemius) == .secondary)
            #expect(lunge.muscleInvolvement.role(for: .soleus) == .secondary)
            #expect(lunge.muscleInvolvement.role(for: .medialHamstrings) == .stabilizer)
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func isStableID(_ value: String) -> Bool {
        guard
            !value.isEmpty,
            value.first != "-",
            value.last != "-",
            !value.contains("--")
        else { return false }

        return value.unicodeScalars.allSatisfy { scalar in
            (97 ... 122).contains(scalar.value)
                || (48 ... 57).contains(scalar.value)
                || scalar.value == 45
        }
    }
}
