import SwiftData
import SwiftUI

struct TemplateExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [TemplateExerciseItem]
    @Query(sort: \Exercise.name) private var catalogExercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedFilter = "ALL"
    @State private var selectedExercise: Exercise?
    @State private var filters: [ExerciseCatalogFilter] = []
    @State private var sections: [ExerciseCatalogSection] = []
    @State private var recentExercises: [Exercise] = []

    private var availableExercises: [Exercise] {
        catalogExercises.filter { exercise in
            !exercises.contains(where: { $0.catalogID == exercise.catalogID })
        }
    }

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                pickerHeader
                ScrollView {
                    VStack(spacing: 0) {
                        CatalogSearchBar(totalCount: availableExercises.count)
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
            TemplateExerciseConfigView(exercise: exercise) { item in
                exercises.append(item)
                dismiss()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: catalogExercises) { _, _ in refreshCatalogState() }
        .onChange(of: exercises) { _, _ in refreshCatalogState() }
        .onChange(of: selectedFilter) { _, _ in refreshCatalogState() }
        .onChange(of: workouts) { _, _ in refreshCatalogState() }
        .onAppear { refreshCatalogState() }
    }

    private func refreshCatalogState() {
        let available = availableExercises
        filters = ExerciseCatalogPresenter.filters(from: available)
        sections = ExerciseCatalogPresenter.sections(from: available, selectedFilter: selectedFilter)
        recentExercises = ExerciseCatalogPresenter.recentExercises(from: workouts)
            .filter { exercise in
                !exercises.contains(where: { $0.catalogID == exercise.catalogID })
            }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

private extension TemplateExercisePickerView {
    var pickerHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }
            Spacer()
            Text("ADD EXERCISE")
                .font(.vivoMono(VivoFont.monoCaption))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("\u{2190} BACK")
                .font(.vivoMono(VivoFont.monoSM))
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
    TemplateExercisePickerView(
        exercises: .constant([])
    )
    .modelContainer(
        for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self],
        inMemory: true
    )
}
