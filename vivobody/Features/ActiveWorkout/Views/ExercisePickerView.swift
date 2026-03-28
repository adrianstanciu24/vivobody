import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutSession.self) private var session: WorkoutSession?
    @State private var selectedFilter = "ALL"
    @State private var selectedExercise: PickerExercise?

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                pickerHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        searchBar
                        filterPills
                        divider
                        recentSection
                        divider
                        muscleGroupSection(
                            title: "Chest",
                            exercises: Self.chestExercises
                        )
                        divider
                        muscleGroupSection(
                            title: "Back",
                            exercises: Self.backExercises
                        )
                        divider
                        muscleGroupSection(
                            title: "Legs",
                            exercises: Self.legExercises
                        )
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            AddExerciseView(
                exerciseName: exercise.name,
                exerciseTags: exercise.tags
            )
            .environment(session)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .onDisappear {
                if session?.exercises.last?.name == exercise.name {
                    dismiss()
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    private func selectExercise(_ name: String, tags: String = "") {
        selectedExercise = PickerExercise(
            id: UUID().uuidString,
            number: "",
            name: name,
            tags: tags,
            detail: ""
        )
    }
}

// MARK: - Header

private extension ExercisePickerView {
    var pickerHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Text("\u{2190} BACK")
                    .font(.vivoMono(14))
                    .foregroundStyle(Color.vivoPrimary)
            }

            Spacer()

            Text("ADD EXERCISE")
                .font(.vivoMono(14, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text("\u{2190} BACK")
                .font(.vivoMono(14))
                .foregroundStyle(.clear)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// MARK: - Search Bar

private extension ExercisePickerView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Text("\u{26B2}")
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoMuted)

            Text("Search exercises...")
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoMuted)

            Spacer()

            Text("248 TOTAL")
                .font(.vivoMono(12))
                .tracking(0.5)
                .foregroundStyle(Color.vivoSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.vivoSurface, lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }
}

// MARK: - Filter Pills

private extension ExercisePickerView {
    static let filters = ["ALL", "CHEST", "BACK", "LEGS", "SHOULDERS", "ARMS"]

    var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.filters, id: \.self) { name in
                    filterPill(name)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 12)
    }

    func filterPill(_ name: String) -> some View {
        let isSelected = name == selectedFilter
        return Button { selectedFilter = name } label: {
            Text(name)
                .font(.vivoMono(11, weight: isSelected ? .bold : .regular))
                .tracking(0.5)
                .foregroundStyle(
                    isSelected ? Color.vivoBackground : Color.vivoSecondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.vivoPrimary : .clear)
                )
                .overlay(
                    isSelected ? nil :
                        RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.vivoSurface, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Recent Section

private extension ExercisePickerView {
    var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT · LAST 7 DAYS")
                .font(.vivoMono(12))
                .tracking(2)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.recentPicks) { pick in
                        recentCard(pick)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 10)
        }
    }

    func recentCard(_ pick: PickerExercise) -> some View {
        Button { selectExercise(pick.name, tags: pick.tags) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(pick.name)
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(pick.tags)
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoMuted)

                Spacer()

                Text(pick.detail)
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoMuted)
            }
            .padding(14)
            .frame(width: 180, height: 130, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.vivoSurface, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Muscle Group Section

private extension ExercisePickerView {
    func muscleGroupSection(
        title: String,
        exercises: [PickerExercise]
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                Text("\(exercises.count) EXERCISES")
                    .font(.vivoMono(12))
                    .tracking(1)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    Button { selectExercise(exercise.name, tags: exercise.tags) } label: {
                        pickerRow(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    func pickerRow(_ exercise: PickerExercise) -> some View {
        HStack(spacing: 12) {
            Text(exercise.number)
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoPrimary)
                Text(exercise.tags)
                    .font(.vivoMono(12))
                    .tracking(0.5)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Image(systemName: "plus.circle")
                .font(.system(size: 20))
                .foregroundStyle(Color.vivoAccent)
        }
        .frame(height: 72)
    }
}

// MARK: - Preview

#Preview {
    ExercisePickerView()
        .environment(WorkoutSession())
}
