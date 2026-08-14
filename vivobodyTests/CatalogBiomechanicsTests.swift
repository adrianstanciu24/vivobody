//
//  CatalogBiomechanicsTests.swift
//  vivobodyTests
//
//  Guards the family-first runtime projection as one canonical data
//  product: 54 reviewed families compile to 132 exercises with stable
//  identities, multi-plane classification, exact muscle regions, and
//  coherent modality/load semantics.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct CatalogBiomechanicsTests {

    @Test func canonicalFamilyAndExerciseCountsArePinned() {
        #expect(CatalogData.records.count == 132)
        #expect(Set(CatalogData.records.map(\.familyID)).count == 54)
        #expect(CatalogData.record(forCatalogID: "barbell-bench-press")?.familyID == "horizontal-press")
        #expect(CatalogData.record(forCatalogID: "pull-up")?.familyID == "vertical-pull")
    }

    @Test func stableIDsNamesAndAliasesAreGloballyUnique() {
        var catalogIDs: Set<String> = []
        var vocabularyOwners: [String: String] = [:]

        for record in CatalogData.records {
            #expect(Self.isStableID(record.familyID))
            #expect(Self.isStableID(record.catalogID))
            #expect(catalogIDs.insert(record.catalogID).inserted)
            #expect((0...100).contains(record.searchPriorityValue))

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

    @Test func movementDefinitionsAreAuthoredAndComplete() {
        for record in CatalogData.records {
            let definition = record.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = definition
                .split(whereSeparator: \.isWhitespace)
                .map {
                    String($0)
                        .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        .lowercased()
                }
                .filter { !$0.isEmpty }

            #expect(definition.count >= 24, "'\(record.name)' has an underspecified definition")
            #expect(definition.first?.isUppercase == true)
            #expect(definition.last == "." || definition.last == "!" || definition.last == "?")
            #expect(!zip(words, words.dropFirst()).contains { left, right in left == right })
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
            case .conditioning, .mobility:
                break
            }

            if record.modality.requiresPrimaryMuscle {
                #expect(record.involvement.contains { $0.role == .primary })
                #expect(record.involvement.contains {
                    $0.role == .primary && $0.muscle.group == record.group
                })
            }

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
            (97...122).contains(scalar.value)
                || (48...57).contains(scalar.value)
                || scalar.value == 45
        }
    }
}
