import SwiftUI

struct TemplateExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [TemplateExerciseItem]
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
                        divider
                        muscleGroupSection(
                            title: "Shoulders",
                            exercises: Self.shoulderExercises
                        )
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            TemplateExerciseConfigView(
                exerciseName: exercise.name,
                exerciseTags: exercise.tags
            ) { item in
                exercises.append(item)
                dismiss()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Header

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
}

// MARK: - Search Bar

private extension TemplateExercisePickerView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Text("\u{26B2}")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)

            Text("Search exercises...")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Spacer()

            Text("248 TOTAL")
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
        .padding(.top, 4)
    }
}

// MARK: - Filter Pills

private extension TemplateExercisePickerView {
    static let filters = [
        "ALL", "CHEST", "BACK", "LEGS", "SHOULDERS", "ARMS"
    ]

    var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.filters, id: \.self) { name in
                    filterPill(name)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
        .padding(.vertical, 12)
    }

    func filterPill(_ name: String) -> some View {
        let isSelected = name == selectedFilter
        return Button { selectedFilter = name } label: {
            Text(name)
                .font(.vivoMono(
                    VivoFont.monoCaption,
                    weight: isSelected ? .bold : .regular
                ))
                .tracking(VivoTracking.tight)
                .foregroundStyle(
                    isSelected ? Color.vivoBackground : Color.vivoSecondary
                )
                .padding(.horizontal, VivoSpacing.cardPadding)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(isSelected ? Color.vivoPrimary : .clear)
                )
                .overlay(
                    isSelected ? nil :
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .stroke(Color.vivoSurface, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Recent Section

private extension TemplateExercisePickerView {
    var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT \u{00B7} LAST 7 DAYS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.recentPicks) { pick in
                        recentCard(pick)
                    }
                }
                .padding(.horizontal, VivoSpacing.screenH)
            }
            .padding(.bottom, 10)
        }
    }

    func recentCard(_ pick: PickerExercise) -> some View {
        Button { selectExercise(pick) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(pick.name)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(pick.tags)
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
                Spacer()
                Text(pick.detail)
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }
            .padding(14)
            .frame(width: 180, height: 130, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoSurface, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectExercise(_ exercise: PickerExercise) {
        selectedExercise = exercise
    }
}

// MARK: - Muscle Group Section

private extension TemplateExercisePickerView {
    func muscleGroupSection(
        title: String,
        exercises: [PickerExercise]
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.vivoDisplay(VivoFont.sectionTitle))
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                Text("\(exercises.count) EXERCISES")
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    Button { selectExercise(exercise) } label: {
                        pickerRow(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }

    func pickerRow(_ exercise: PickerExercise) -> some View {
        HStack(spacing: 12) {
            Text(exercise.number)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(exercise.tags)
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.tight)
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

#Preview {
    TemplateExercisePickerView(
        exercises: .constant([])
    )
}
