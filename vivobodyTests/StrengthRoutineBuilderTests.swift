//
//  StrengthRoutineBuilderTests.swift
//  vivobodyTests
//
//  Guards deterministic strength-routine generation, hard constraints,
//  stable locks and replacements, shortage reporting, and plan coverage.
//

import Foundation
import Testing
@testable import vivobody

struct StrengthRoutineBuilderTests {
    private var allCandidates: [StrengthRoutineCandidate] {
        CatalogData.records.map { StrengthRoutineCandidate(record: $0) }
    }

    private func input(
        dayCount: Int = 2,
        duration: StrengthRoutineSessionDuration = .minutes45,
        goal: StrengthRoutineGoal = .balanced,
        equipment: Set<Equipment> = Set(Equipment.allCases),
        emphasis: MuscleGroup? = nil,
        included: Set<String> = [],
        excluded: Set<String> = [],
        preferFamiliar: Bool = true,
        locks: [StrengthRoutineSlotID: String] = [:]
    ) -> StrengthRoutineBuilderInput {
        let weekdays = Array([
            StrengthRoutineWeekday.monday,
            .wednesday,
            .friday,
            .saturday,
        ].prefix(dayCount))
        return StrengthRoutineBuilderInput(
            weekdays: weekdays,
            sessionDuration: duration,
            goal: goal,
            availableEquipment: equipment,
            emphasis: emphasis,
            includedCatalogIDs: included,
            excludedCatalogIDs: excluded,
            preferFamiliar: preferFamiliar,
            lockedSelections: locks
        )
    }

    private func candidate(
        _ catalogID: String,
        familiarity: StrengthRoutineFamiliarity = .none
    ) throws -> StrengthRoutineCandidate {
        let record = try #require(CatalogData.record(forCatalogID: catalogID))
        return StrengthRoutineCandidate(record: record, familiarity: familiarity)
    }

    private func selectedID(
        slotID: StrengthRoutineSlotID,
        plan: StrengthRoutinePlan
    ) -> String? {
        plan.days
            .flatMap(\.slots)
            .first(where: { $0.id == slotID })?
            .exercise?
            .catalogID
    }

    @Test func inputOrderCannotChangeThePlan() {
        let constraints = input(dayCount: 4, duration: .minutes60)

        let forward = StrengthRoutineBuilder.build(
            input: constraints,
            candidates: allCandidates
        )
        let reverse = StrengthRoutineBuilder.build(
            input: constraints,
            candidates: Array(allCandidates.reversed())
        )

        #expect(forward == reverse)
    }

    @Test func equipmentIsAHardFilter() {
        let available: Set<Equipment> = [.dumbbell]
        let plan = StrengthRoutineBuilder.build(
            input: input(equipment: available),
            candidates: allCandidates
        )

        #expect(!plan.exercises.isEmpty)
        #expect(plan.exercises.allSatisfy {
            available.contains($0.candidate.equipment)
                || $0.candidate.equipment == .bodyweight
        })
        #expect(plan.exercises.contains { $0.candidate.equipment == .bodyweight })
    }

    @Test func bodyweightRemainsEligibleWithoutEquipmentSelection() {
        let plan = StrengthRoutineBuilder.build(
            input: input(equipment: []),
            candidates: allCandidates
        )

        #expect(!plan.exercises.isEmpty)
        #expect(plan.exercises.allSatisfy { $0.candidate.equipment == .bodyweight })
        #expect(plan.days.flatMap(\.slots).contains {
            $0.kind == .core && $0.exercise?.candidate.equipment == .bodyweight
        })
    }

    @MainActor
    @Test func routinePickersTreatBodyweightAsImplicitEquipment() {
        let purposes: [ExercisePickerPurpose] = [
            .routineInclude(excludedIDs: [], equipment: []),
            .routineAvoid(excludedIDs: [], equipment: []),
            .routineSwap(
                excludedIDs: [],
                equipment: [],
                compatibleCatalogIDs: ["plank"]
            ),
        ]

        for purpose in purposes {
            #expect(purpose.allowsRoutineEquipment(.bodyweight))
            #expect(!purpose.allowsRoutineEquipment(.barbell))
        }
    }

    @Test func includesAndExclusionsAreHonored() {
        let includedID = "barbell-bench-press"
        let excludedID = "pull-up"
        let plan = StrengthRoutineBuilder.build(
            input: input(
                included: [includedID],
                excluded: [excludedID]
            ),
            candidates: allCandidates
        )
        let selectedIDs = Set(plan.exercises.map(\.catalogID))

        #expect(selectedIDs.contains(includedID))
        #expect(!selectedIDs.contains(excludedID))
        #expect(plan.exercises.first(where: { $0.catalogID == includedID })?
            .selectionReasons.contains(.includedByUser) == true)
    }

    @Test func compatibleLockIsPreservedAndExplained() {
        let slotID = StrengthRoutineSlotID(weekday: .monday, kind: .horizontalPush)
        let lockedID = "standing-cable-chest-press"
        let plan = StrengthRoutineBuilder.build(
            input: input(locks: [slotID: lockedID]),
            candidates: allCandidates
        )
        let slot = plan.days.flatMap(\.slots).first { $0.id == slotID }

        #expect(slot?.exercise?.catalogID == lockedID)
        #expect(slot?.exercise?.selectionReasons.contains(.lockedByUser) == true)
    }

    @Test func incompatibleLockProducesBlockingGap() {
        let slotID = StrengthRoutineSlotID(weekday: .monday, kind: .hinge)
        let curlID = "supinated-straight-bar-cable-curl"
        let plan = StrengthRoutineBuilder.build(
            input: input(locks: [slotID: curlID]),
            candidates: allCandidates
        )

        #expect(selectedID(slotID: slotID, plan: plan) == nil)
        #expect(plan.gaps.contains {
            $0.severity == .blocking
                && $0.kind == .incompatibleLockedExercise(slotID, curlID)
        })
    }

    @Test func familiarityBreaksAnOtherwiseStructuralTie() throws {
        let familiarID = "dumbbell-bench-press"
        let editorialID = "barbell-bench-press"
        let familiar = try candidate(
            familiarID,
            familiarity: .init(
                sessionCount: 12,
                lastPerformedAt: Date(timeIntervalSince1970: 2000)
            )
        )
        let editorial = try candidate(editorialID)
        let candidates = [editorial, familiar]
        let slotID = StrengthRoutineSlotID(weekday: .monday, kind: .horizontalPush)

        let personalized = StrengthRoutineBuilder.build(
            input: input(equipment: [.barbell, .dumbbell], preferFamiliar: true),
            candidates: candidates
        )
        let unpersonalized = StrengthRoutineBuilder.build(
            input: input(equipment: [.barbell, .dumbbell], preferFamiliar: false),
            candidates: candidates
        )

        #expect(selectedID(slotID: slotID, plan: personalized) == familiarID)
        #expect(selectedID(slotID: slotID, plan: unpersonalized) == editorialID)
    }

    @Test func shortagesAreBlockingAndLeaveHonestEmptySlots() throws {
        let benchOnly = try [candidate("barbell-bench-press")]
        let plan = StrengthRoutineBuilder.build(
            input: input(equipment: [.barbell]),
            candidates: benchOnly
        )

        #expect(plan.hasBlockingGaps)
        #expect(plan.days.flatMap(\.slots).contains { $0.exercise == nil })
        #expect(plan.gaps.contains {
            if case .noEligibleExercise = $0.kind { true } else { false }
        })
    }

    @Test(arguments: [2, 3, 4])
    func dayStructuresCoverTheCoreMovementPatterns(dayCount: Int) {
        let plan = StrengthRoutineBuilder.build(
            input: input(dayCount: dayCount, duration: .minutes60),
            candidates: allCandidates
        )
        let selected = plan.exercises.map(\.candidate)

        #expect(plan.days.count == dayCount)
        #expect(selected.contains { $0.pattern == .push && $0.direction == .horizontal })
        #expect(selected.contains { $0.pattern == .pull && $0.direction == .horizontal })
        #expect(selected.contains { $0.pattern == .push && $0.direction == .vertical })
        #expect(selected.contains { $0.pattern == .pull && $0.direction == .vertical })
        #expect(selected.contains { $0.pattern == .squat })
        #expect(selected.contains { $0.pattern == .hinge })
    }

    @Test func activeHangDoesNotSatisfyVerticalPullCoverage() throws {
        let activeHang = try candidate("active-dead-hang")
        let plan = StrengthRoutineBuilder.build(
            input: input(equipment: []),
            candidates: [activeHang]
        )

        #expect(plan.gaps.contains {
            $0.kind == .missingMovement(.pull, .vertical)
        })
        #expect(!plan.days.flatMap(\.slots).contains {
            $0.kind == .verticalPull
                && $0.exercise?.catalogID == "active-dead-hang"
        })
    }

    @Test func fourDayEmphasisOnlyAppearsOnItsTrainingRegion() {
        for duration in StrengthRoutineSessionDuration.allCases {
            for emphasis in MuscleGroup.allCases {
                let plan = StrengthRoutineBuilder.build(
                    input: input(
                        dayCount: 4,
                        duration: duration,
                        emphasis: emphasis
                    ),
                    candidates: allCandidates
                )
                let upperSlots = plan.days
                    .filter { $0.title.hasPrefix("Upper") }
                    .flatMap(\.slots)
                let lowerSlots = plan.days
                    .filter { $0.title.hasPrefix("Lower") }
                    .flatMap(\.slots)
                let expectedKind = StrengthRoutineSlotKind.emphasis(emphasis)

                if emphasis.strengthRoutineRegion == .upper {
                    #expect(upperSlots.contains { $0.kind == expectedKind })
                    #expect(!lowerSlots.contains { $0.kind == expectedKind })
                } else {
                    #expect(lowerSlots.contains { $0.kind == expectedKind })
                    #expect(!upperSlots.contains { $0.kind == expectedKind })
                }
                #expect(plan.exercises.contains { $0.candidate.group == emphasis })
                #expect(!plan.gaps.contains { $0.kind == .missingEmphasis(emphasis) })
            }
        }
    }

    @Test func everyDurationAppliesFullBodyEmphasisWithoutDroppingCoverage() {
        for dayCount in [2, 3] {
            for duration in StrengthRoutineSessionDuration.allCases {
                for emphasis in MuscleGroup.allCases {
                    let plan = StrengthRoutineBuilder.build(
                        input: input(
                            dayCount: dayCount,
                            duration: duration,
                            emphasis: emphasis
                        ),
                        candidates: allCandidates
                    )
                    let emphasisKind = StrengthRoutineSlotKind.emphasis(emphasis)

                    #expect(plan.days.flatMap(\.slots).contains { $0.kind == emphasisKind })
                    #expect(plan.exercises.contains { $0.candidate.group == emphasis })
                    #expect(!plan.gaps.contains { $0.kind == .missingEmphasis(emphasis) })
                    #expect(!plan.gaps.contains {
                        if case .missingMovement = $0.kind { true } else { false }
                    })
                    #expect(!plan.gaps.contains {
                        if case .missingBodyRegion = $0.kind { true } else { false }
                    })
                }
            }
        }
    }

    @Test func twoDayThirtyMinutePlanIncludesEveryMajorBodyRegion() {
        let plan = StrengthRoutineBuilder.build(
            input: input(dayCount: 2, duration: .minutes30),
            candidates: allCandidates
        )

        for region in StrengthRoutineBodyRegion.allCases {
            #expect(plan.exercises.contains { region.contains($0.candidate.group) })
            #expect(!plan.gaps.contains { $0.kind == .missingBodyRegion(region) })
        }
        #expect(plan.gaps.isEmpty)
    }

    @Test func missingTrunkProducesTypedBodyRegionGap() {
        let plan = StrengthRoutineBuilder.build(
            input: input(dayCount: 2, duration: .minutes30),
            candidates: allCandidates.filter { $0.group != .core }
        )

        #expect(plan.gaps.contains {
            $0.severity == .advisory && $0.kind == .missingBodyRegion(.trunk)
        })
    }

    @Test func unavailableOptionalEmphasisFallsBackWithoutBlockingSave() throws {
        let constraints = input(
            dayCount: 2,
            duration: .minutes30,
            emphasis: .arms
        )
        let plan = StrengthRoutineBuilder.build(
            input: constraints,
            candidates: allCandidates.filter { $0.group != .arms }
        )
        let emphasisSlot = try #require(plan.days.flatMap(\.slots).first {
            $0.kind == .emphasis(.arms)
        })

        #expect(emphasisSlot.exercise != nil)
        #expect(!plan.hasBlockingGaps)
        #expect(plan.gaps.contains {
            $0.severity == .advisory && $0.kind == .missingEmphasis(.arms)
        })
        #expect(emphasisSlot.exercise?.selectionReasons.contains(.emphasis(.arms)) == false)
    }

    @Test func sparseCatalogNeverRepeatsAnExerciseWithinOneDay() throws {
        let diagonalPress = try candidate("incline-barbell-bench-press")
        let plan = StrengthRoutineBuilder.build(
            input: input(
                dayCount: 4,
                duration: .minutes30,
                equipment: [.barbell]
            ),
            candidates: [diagonalPress]
        )
        let upperA = try #require(plan.days.first { $0.title == "Upper A" })
        let selectedIDs = upperA.slots.compactMap { $0.exercise?.catalogID }
        let verticalPushID = StrengthRoutineSlotID(
            weekday: upperA.weekday,
            kind: .verticalPush
        )

        #expect(selectedIDs == [diagonalPress.catalogID])
        #expect(Set(selectedIDs).count == selectedIDs.count)
        #expect(selectedID(slotID: verticalPushID, plan: plan) == nil)
        #expect(plan.hasBlockingGaps)
        #expect(plan.gaps.contains {
            $0.severity == .blocking && $0.kind == .noEligibleExercise(verticalPushID)
        })
    }

    @Test func sessionBucketsHaveStableSlotCounts() {
        let expectations: [(StrengthRoutineSessionDuration, Int)] = [
            (.minutes30, 4),
            (.minutes45, 5),
            (.minutes60, 6),
        ]
        for (duration, expectedCount) in expectations {
            let plan = StrengthRoutineBuilder.build(
                input: input(duration: duration),
                candidates: allCandidates
            )
            #expect(plan.days.allSatisfy { $0.slots.count == expectedCount })
        }
    }

    @Test func fullCatalogAvoidsDuplicateExerciseIDs() {
        let plan = StrengthRoutineBuilder.build(
            input: input(dayCount: 4, duration: .minutes60),
            candidates: allCandidates
        )
        let ids = plan.exercises.map(\.catalogID)

        #expect(Set(ids).count == ids.count)
    }

    @Test func replacementChangesOneSlotWithoutInventingLocks() {
        let constraints = input(dayCount: 2)
        let original = StrengthRoutineBuilder.build(
            input: constraints,
            candidates: allCandidates
        )
        let slotID = StrengthRoutineSlotID(weekday: .monday, kind: .horizontalPush)
        let originalID = selectedID(slotID: slotID, plan: original)
        let replacement = StrengthRoutineBuilder.replacing(
            slotID: slotID,
            in: original,
            input: constraints,
            candidates: allCandidates
        )

        #expect(selectedID(slotID: slotID, plan: replacement) != originalID)
        #expect(replacement.exercises.allSatisfy {
            !$0.selectionReasons.contains(.lockedByUser)
        })
    }

    @Test func prescriptionsAreExactConservativeProductPolicy() throws {
        let compound = try candidate("barbell-bench-press")
        let isolation = try candidate("supinated-straight-bar-cable-curl")

        #expect(StrengthRoutinePolicy.prescription(for: compound, goal: .strength)
            == StrengthRoutinePrescription(sets: 3, targetReps: 5))
        #expect(StrengthRoutinePolicy.prescription(for: isolation, goal: .strength)
            == StrengthRoutinePrescription(sets: 2, targetReps: 10))
        #expect(StrengthRoutinePolicy.prescription(for: compound, goal: .muscle)
            == StrengthRoutinePrescription(sets: 3, targetReps: 8))
        #expect(StrengthRoutinePolicy.prescription(for: isolation, goal: .muscle)
            == StrengthRoutinePrescription(sets: 3, targetReps: 12))
    }
}
