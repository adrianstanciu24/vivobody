import SwiftUI

extension EmptyWorkoutView {
    private var quickPicks: [Exercise] {
        let recentExercises = ExerciseCatalogPresenter.recentExercises(from: workouts, limit: 3)
        return recentExercises.isEmpty
            ? ExerciseCatalogPresenter.quickPicks(from: catalogExercises, limit: 3)
            : recentExercises
    }

    var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK PICKS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 20)

            ForEach(quickPicks.enumerated(), id: \.element.persistentModelID) { index, pick in
                Button {
                    selectedQuickPick = pick
                } label: {
                    quickPickRow(pick, number: String(format: "%02d", index + 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }

    func quickPickRow(_ pick: Exercise, number: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(pick.name)
                    .font(.vivoDisplay(VivoFont.body, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(pick.tags)
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
            }

            Spacer()

            Text("CATALOG")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoAccent, lineWidth: 1)
                )
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

// MARK: - Active Content

extension EmptyWorkoutView {
    var activeContent: some View {
        VStack(spacing: 14) {
            ForEach((session?.exercises ?? []).enumerated(), id: \.element.id) { index, exercise in
                ActiveExerciseCard(
                    exercise: exercise,
                    number: index + 1,
                    onLogSet: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            session?.logSet(exerciseID: exercise.id)
                        }
                    },
                    onEditSet: {
                        editingExerciseID = exercise.id
                        showEditSet = true
                    }
                )
            }

            if let exercise = session?.exercises.last {
                RestTimerCard(
                    currentSet: exercise.currentSetNumber,
                    totalSets: exercise.totalSets
                )
            }

            addAnotherSection
        }
        .padding(.top, 14)
    }

    var addAnotherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD ANOTHER")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)

            ForEach(suggestions.enumerated(), id: \.element.persistentModelID) { index, suggestion in
                Button {
                    selectedQuickPick = suggestion
                } label: {
                    suggestionRow(suggestion, number: String(format: "%02d", index + 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }

    private var suggestions: [Exercise] {
        let excludedCatalogIDs = Set(session?.exercises.map(\.catalogID) ?? [])
        return ExerciseCatalogPresenter.suggestions(
            from: catalogExercises,
            excluding: excludedCatalogIDs,
            limit: 3
        )
    }

    func suggestionRow(_ item: Exercise, number: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Text(item.name)
                .font(.vivoDisplay(VivoFont.body, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text("CATALOG")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoAccent, lineWidth: 1)
                )
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

// MARK: - Active Bottom Bar

extension EmptyWorkoutView {
    var activeBottomBar: some View {
        Button { showExercisePicker = true } label: {
            Text("+ ADD EXERCISE")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.normal)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
        .background(
            Color.vivoBackground
                .overlay(
                    Rectangle()
                        .fill(Color.vivoSurface)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}

// MARK: - Edit Set Sheet

extension EmptyWorkoutView {
    private var editingSessionExercise: SessionExercise? {
        guard let exerciseID = editingExerciseID else { return nil }
        return session?.exercises.first(where: { $0.id == exerciseID })
    }

    @ViewBuilder
    var editSetSheet: some View {
        if let sessionExercise = editingSessionExercise {
            EditSetView(exercise: sessionExercise) { reps, weight, rir in
                if let exerciseID = editingExerciseID {
                    session?.updateCurrentSet(
                        exerciseID: exerciseID,
                        reps: reps,
                        weight: weight,
                        rir: rir
                    )
                    session?.logSet(exerciseID: exerciseID)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Footer

extension EmptyWorkoutView {
    var footerLabel: some View {
        Text("SESSION #129 · CUSTOM · AUTO-SAVED 09:41")
            .font(.vivoMono(VivoFont.monoXS))
            .tracking(VivoTracking.medium)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 20)
    }
}
