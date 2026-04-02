import SwiftData
import SwiftUI

struct ExerciseLibraryView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var searchText = ""
    @State private var selectedFilter = ExerciseCatalogPresenter.allFilter
    @State private var filters: [ExerciseCatalogFilter] = []
    @State private var sections: [ExerciseCatalogSection] = []
    @State private var flatList: [Exercise] = []
    @State private var stats = ExerciseLibraryStats()

    private var isSpecialFilter: Bool {
        [ExerciseCatalogPresenter.recentFilter,
         ExerciseCatalogPresenter.favoritesFilter].contains(selectedFilter)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vivoBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        statsRow
                        vivoDivider
                        searchBar
                        CatalogFilterBar(filters: filters, selectedFilter: $selectedFilter)

                        if isSpecialFilter {
                            specialFilterContent
                        } else if sections.isEmpty {
                            emptySection
                        } else {
                            ForEach(sections.enumerated(), id: \.element.id) { index, section in
                                muscleGroupSection(section, sectionIndex: index)
                            }
                        }

                        footerSection
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Exercises")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: exercises) { _, _ in rebuildAll() }
        .onChange(of: workouts) { _, _ in rebuildAll() }
        .onChange(of: searchText) { _, _ in rebuildContent() }
        .onChange(of: selectedFilter) { _, _ in rebuildContent() }
        .onAppear { rebuildAll() }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func searchFilter(_ exercise: Exercise) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return exercise.name.localizedCaseInsensitiveContains(query)
            || exercise.primaryTag.localizedCaseInsensitiveContains(query)
            || exercise.secondaryTags.localizedCaseInsensitiveContains(query)
            || exercise.muscleGroup.displayName.localizedCaseInsensitiveContains(query)
            || exercise.category.displayName.localizedCaseInsensitiveContains(query)
            || exercise.motionFamily.replacing("_", with: " ")
            .localizedCaseInsensitiveContains(query)
    }

    private func rebuildAll() {
        stats = ExerciseLibraryStats(exercises: exercises)
        filters = ExerciseCatalogPresenter.filters(from: exercises)
        rebuildContent()
    }

    private func rebuildContent() {
        if selectedFilter == ExerciseCatalogPresenter.recentFilter {
            flatList = ExerciseCatalogPresenter.recentExercises(from: workouts, limit: 20)
                .filter(searchFilter)
            sections = []
        } else if selectedFilter == ExerciseCatalogPresenter.favoritesFilter {
            flatList = exercises.filter(\.isFavorite).filter(searchFilter)
            sections = []
        } else {
            let base = exercises.filter(searchFilter)
            sections = ExerciseCatalogPresenter.sections(from: base, selectedFilter: selectedFilter)
            flatList = []
        }
    }

    private var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Subviews

private extension ExerciseLibraryView {
    var statsRow: some View {
        HStack(spacing: 10) {
            VivoStatColumn(
                value: "\(stats.total)", label: "CATALOG",
                valueColor: .vivoAccent
            )
            statDivider
            VivoStatColumn(value: "\(stats.muscleGroups)", label: "GROUPS")
            statDivider
            VivoStatColumn(value: "\(stats.performed)", label: "PERFORMED")
            statDivider
            VivoStatColumn(value: stats.topGroup, label: "TOP GROUP")
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    var statDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(width: 1, height: 28)
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.vivoMuted)
                .accessibilityHidden(true)

            TextField("", text: $searchText, prompt: Text("Search exercises...")
                .font(.vivoMono(VivoFont.monoDefault))
                .foregroundStyle(Color.vivoMuted))
                .font(.vivoMono(VivoFont.monoDefault))
                .foregroundStyle(Color.vivoPrimary)
                .submitLabel(.done)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 10)
    }

    // MARK: Special Filter (RECENT / FAVORITES)

    @ViewBuilder
    var specialFilterContent: some View {
        if flatList.isEmpty {
            specialFilterEmptyState
        } else {
            VStack(spacing: 0) {
                ForEach(flatList.enumerated(), id: \.element.persistentModelID) { index, exercise in
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

    var specialFilterEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedFilter == ExerciseCatalogPresenter.recentFilter {
                if isSearching {
                    Text("NO RESULTS")
                        .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                        .tracking(VivoTracking.wide)
                        .foregroundStyle(Color.vivoMuted)
                    Text(
                        "No recent exercises matched \"\(searchText.trimmingCharacters(in: .whitespaces))\"."
                    )
                    .font(.vivoMono(VivoFont.monoCaption))
                    .foregroundStyle(Color.vivoSecondary)
                } else {
                    Text("NO RECENT EXERCISES")
                        .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                        .tracking(VivoTracking.wide)
                        .foregroundStyle(Color.vivoMuted)
                    Text("Exercises from your workouts will appear here.")
                        .font(.vivoMono(VivoFont.monoCaption))
                        .foregroundStyle(Color.vivoSecondary)
                }
            } else {
                if isSearching {
                    Text("NO RESULTS")
                        .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                        .tracking(VivoTracking.wide)
                        .foregroundStyle(Color.vivoMuted)
                    Text(
                        "No favorites matched \"\(searchText.trimmingCharacters(in: .whitespaces))\"."
                    )
                    .font(.vivoMono(VivoFont.monoCaption))
                    .foregroundStyle(Color.vivoSecondary)
                } else {
                    Text("NO FAVORITES YET")
                        .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                        .tracking(VivoTracking.wide)
                        .foregroundStyle(Color.vivoMuted)
                    Text("Tap the heart on any exercise to save it here.")
                        .font(.vivoMono(VivoFont.monoCaption))
                        .foregroundStyle(Color.vivoSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }

    // MARK: Muscle Group Sections (ALL + specific groups)

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
                            number: String(format: "%02d", index + 1),
                            showPrimaryTag: false
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
            if isSearching {
                Text("NO RESULTS")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.wide)
                    .foregroundStyle(Color.vivoMuted)
                Text(
                    "Nothing matched \"\(searchText.trimmingCharacters(in: .whitespaces))\". Try a different name, muscle group, or equipment type."
                )
                .font(.vivoMono(VivoFont.monoCaption))
                .foregroundStyle(Color.vivoSecondary)
            } else {
                Text("NO CATALOG EXERCISES")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.wide)
                    .foregroundStyle(Color.vivoMuted)
                Text("The bundled exercise catalog is empty.")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .foregroundStyle(Color.vivoSecondary)
            }
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
