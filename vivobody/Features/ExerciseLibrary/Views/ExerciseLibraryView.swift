import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var selectedFilter = "ALL"
    @State private var filters: [ExerciseCatalogFilter] = []
    @State private var sections: [ExerciseCatalogSection] = []
    @State private var recentExercises: [Exercise] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vivoBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        searchBar
                        CatalogFilterBar(filters: filters, selectedFilter: $selectedFilter)
                        vivoDivider

                        if !recentExercises.isEmpty {
                            recentSection
                            vivoDivider
                                .padding(.top, 10)
                        }

                        if sections.isEmpty {
                            emptySection
                        } else {
                            ForEach(sections.enumerated(), id: \.element.id) { index, section in
                                muscleGroupSection(section, sectionIndex: index)
                                if index < sections.count - 1 {
                                    vivoDivider
                                }
                            }
                        }

                        footerSection
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
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

    private var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

private extension ExerciseLibraryView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Text("⚲")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)

            Text("Bundled exercise catalog")
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoMuted)

            Spacer()

            Text("\(exercises.count) TOTAL")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoSurface, lineWidth: 1)
                )
        }
        .padding(.horizontal, VivoSpacing.cardPadding)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
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
                        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
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

    func muscleGroupSection(
        _ section: ExerciseCatalogSection,
        sectionIndex: Int
    ) -> some View {
        VStack(spacing: 0) {
            CatalogSectionHeader(title: section.title, exerciseCount: section.exercises.count)

            VStack(spacing: 0) {
                ForEach(section.exercises.enumerated(), id: \.element.persistentModelID) { index, exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        ExerciseLibraryRow(
                            exercise: exercise,
                            number: String(format: "%02d", index + 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }

    var emptySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NO CATALOG EXERCISES")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Text("The bundled JSON catalog did not load any exercises for this filter.")
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }

    var footerSection: some View {
        VivoFooter()
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(
            for: [
                Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
                WorkoutTemplate.self, TemplateExercise.self
            ],
            inMemory: true
        )
}
