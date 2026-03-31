import SwiftData
import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedFilter = "ALL"
    @State private var selectedExercise: Exercise?
    @State private var filters: [ExerciseCatalogFilter] = []
    @State private var sections: [ExerciseCatalogSection] = []
    @State private var recentExercises: [Exercise] = []

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                pickerHeader
                ScrollView {
                    VStack(spacing: 0) {
                        CatalogSearchBar(totalCount: exercises.count)
                        CatalogFilterBar(filters: filters, selectedFilter: $selectedFilter)
                        divider

                        if !recentExercises.isEmpty {
                            recentSection
                            divider
                        }

                        ForEach(sections.enumerated(), id: \.element.id) { index, section in
                            muscleGroupSection(section)
                            if index < sections.count - 1 {
                                divider
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            AddExerciseView(exercise: exercise)
                .environment(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .onDisappear {
                    if session?.exercises.last?.catalogID == exercise.catalogID {
                        dismiss()
                    }
                }
        }
        .onChange(of: exercises) { _, newValue in
            filters = ExerciseCatalogPresenter.filters(from: newValue)
            sections = ExerciseCatalogPresenter.sections(from: newValue, selectedFilter: selectedFilter)
        }
        .onChange(of: selectedFilter) { _, newValue in
            sections = ExerciseCatalogPresenter.sections(from: exercises, selectedFilter: newValue)
        }
        .onChange(of: workouts) { _, newValue in
            recentExercises = ExerciseCatalogPresenter.recentExercises(from: newValue)
        }
        .onAppear {
            filters = ExerciseCatalogPresenter.filters(from: exercises)
            sections = ExerciseCatalogPresenter.sections(from: exercises, selectedFilter: selectedFilter)
            recentExercises = ExerciseCatalogPresenter.recentExercises(from: workouts)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

private extension ExercisePickerView {
    var pickerHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(VivoFont.monoMD))
                    .foregroundStyle(Color.vivoPrimary)
            }

            Spacer()

            Text("ADD EXERCISE")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text("\u{2190} BACK")
                .font(.vivoMono(VivoFont.monoMD))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT \u{00B7} CATALOG MATCHES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(recentExercises) { exercise in
                        Button { selectedExercise = exercise } label: {
                            CatalogRecentCard(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, VivoSpacing.screenH)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 10)
        }
    }

    func muscleGroupSection(_ section: ExerciseCatalogSection) -> some View {
        VStack(spacing: 0) {
            CatalogSectionHeader(title: section.title, exerciseCount: section.exercises.count)

            VStack(spacing: 0) {
                ForEach(section.exercises.enumerated(), id: \.element.persistentModelID) { index, exercise in
                    Button { selectedExercise = exercise } label: {
                        CatalogExerciseRow(exercise: exercise, number: String(format: "%02d", index + 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }
}

#Preview {
    ExercisePickerView()
        .environment(WorkoutSession())
        .modelContainer(
            for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
            inMemory: true
        )
}
