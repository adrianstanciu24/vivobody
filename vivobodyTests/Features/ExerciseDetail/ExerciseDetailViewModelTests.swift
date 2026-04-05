import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseDetailViewModelTests {
    @Test func loadProfileSucceedsForKnownCatalogID() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        #expect(vm.profile != nil)
        #expect(vm.hasProfile)
        #expect(vm.profile?.exercise.id == "front_squat")
    }

    @Test func loadProfileReturnsNilForUnknownCatalogID() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "nonexistent_exercise",
            name: "Unknown",
            muscleGroup: .other
        )
        vm.loadProfile(for: exercise)

        #expect(vm.profile == nil)
        #expect(!vm.hasProfile)
    }

    @Test func loadProfileReturnsNilForEmptyCatalogID() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "",
            name: "Empty ID",
            muscleGroup: .other
        )
        vm.loadProfile(for: exercise)

        #expect(vm.profile == nil)
    }

    @Test func profileContainsExpectedTargets() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "low_bar_back_squat",
            name: "Low-Bar Back Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        let targets = vm.profile?.targets
        #expect(targets != nil)
        #expect((targets?.primary.count ?? 0) > 0)
        #expect((targets?.secondary.count ?? 0) > 0)
        #expect((targets?.all.count ?? 0) > 0)

        let firstPrimary = targets?.primary.first
        #expect(firstPrimary?.id == "quads")
        #expect(firstPrimary?.role == "primary")
        #expect(firstPrimary?.share ?? 0 > 0)
    }

    @Test func profileContainsExpectedDemands() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "low_bar_back_squat",
            name: "Low-Bar Back Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        let demands = vm.profile?.demands
        #expect(demands != nil)
        #expect((demands?.jointActions.count ?? 0) > 0)
        #expect((demands?.jointStress.count ?? 0) > 0)
        #expect((demands?.phaseBreakdown.count ?? 0) > 0)
        #expect(demands?.stability.score ?? 0 > 0)
        #expect(demands?.tempoSensitivity.score ?? 0 > 0)
    }

    @Test func profileContainsTopMuscles() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "front_squat",
            name: "Front Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        let muscles = vm.profile?.topMuscles ?? []
        #expect(!muscles.isEmpty)
        #expect(muscles.first?.estimatedRelativeLoad ?? 0 > 0)
    }

    @Test func profileContainsKinematics() {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "low_bar_back_squat",
            name: "Low-Bar Back Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        let rom = vm.profile?.kinematics.rangeOfMotion ?? []
        #expect(!rom.isEmpty)
        #expect(rom.first?.rangeDeg ?? 0 > 0)

        let windows = vm.profile?.kinematics.phaseWindows ?? []
        #expect(!windows.isEmpty)
    }

    @Test func profileContainsBiases() throws {
        let vm = ExerciseDetailViewModel()
        let exercise = Exercise(
            catalogID: "low_bar_back_squat",
            name: "Low-Bar Back Squat",
            muscleGroup: .legs,
            category: .barbell
        )
        vm.loadProfile(for: exercise)

        let biases = vm.profile?.biases
        #expect(biases != nil)
        #expect(try !(#require(biases?.kneeVsHip.bias.isEmpty)))
        #expect(try #require(biases?.kneeVsHip.kneeShare) > 0)
        #expect(try !(#require(biases?.stretch.level.isEmpty)))
        #expect(try !(#require(biases?.stretch.topGroups.isEmpty)))
    }
}
