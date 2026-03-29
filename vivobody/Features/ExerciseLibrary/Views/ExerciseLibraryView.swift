import SwiftUI

struct ExerciseLibraryView: View {
    @State private var selectedFilter = "ALL"

    var body: some View {
        ZStack {
            Color.vivoBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    searchBar
                    filterPills
                    vivoDivider
                    recentSection
                    vivoDivider
                        .padding(.top, 10)
                    muscleGroupSection(
                        title: "Chest",
                        count: 32,
                        exercises: Self.chestExercises
                    )
                    vivoDivider
                    muscleGroupSection(
                        title: "Back",
                        count: 41,
                        exercises: Self.backExercises
                    )
                    vivoDivider
                    createCustomButton
                    footerSection
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var vivoDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
            .padding(.horizontal, VivoSpacing.screenH)
    }
}

// MARK: - Search Bar

private extension ExerciseLibraryView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Text("⚲")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)

            Text("Search exercises...")
                .font(.vivoMono(VivoFont.monoCaption))
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
        .padding(.top, 8)
    }
}

// MARK: - Filter Pills

private extension ExerciseLibraryView {
    static let filters: [(name: String, count: Int?)] = [
        ("ALL", nil),
        ("CHEST", 32),
        ("BACK", 41),
        ("LEGS", 48),
        ("SHOULDERS", 28),
        ("ARMS", 36),
        ("CORE", 22)
    ]

    var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.filters, id: \.name) { filter in
                    filterPill(filter.name, count: filter.count)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
        .padding(.vertical, 12)
    }

    func filterPill(_ name: String, count: Int?) -> some View {
        let isSelected = name == selectedFilter
        let label: String = if let count { "\(name)\(count)" } else { name }

        return Button { selectedFilter = name } label: {
            Text(label)
                .font(.vivoMono(VivoFont.monoXS, weight: isSelected ? .bold : .regular))
                .tracking(VivoTracking.tight)
                .foregroundStyle(isSelected ? Color.vivoBackground : Color.vivoSecondary)
                .padding(.horizontal, VivoSpacing.cardPadding)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(isSelected ? Color.vivoPrimary : Color.clear)
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

private extension ExerciseLibraryView {
    struct RecentExercise: Identifiable {
        let id: String
        let name: String
        let muscleGroup: String
        let category: String
        let lastWeight: String
    }

    static let recentExercises: [RecentExercise] = [
        RecentExercise(
            id: "r1",
            name: "Barbell Bench Press",
            muscleGroup: "CHEST",
            category: "COMPOUND",
            lastWeight: "LAST: 185 LB × 08"
        ),
        RecentExercise(
            id: "r2",
            name: "Barbell Squat",
            muscleGroup: "LEGS",
            category: "COMPOUND",
            lastWeight: "LAST: 275 LB × 05"
        ),
        RecentExercise(
            id: "r3",
            name: "Pull-Up",
            muscleGroup: "BACK",
            category: "COMPOUND",
            lastWeight: "LAST: BW+25 × 08"
        ),
        RecentExercise(
            id: "r4",
            name: "OHP",
            muscleGroup: "SHOULDERS",
            category: "COMPOUND",
            lastWeight: "LAST: 135 LB × 06"
        )
    ]

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT · LAST 7 DAYS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.recentExercises) { exercise in
                        recentCard(exercise)
                    }
                }
                .padding(.horizontal, VivoSpacing.screenH)
            }
            .padding(.bottom, 10)
        }
    }

    func recentCard(_ exercise: RecentExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.vivoDisplay(VivoFont.body))
                .foregroundStyle(Color.vivoPrimary)
                .lineLimit(2)

            Text(
                "\(Text(exercise.muscleGroup).foregroundStyle(Color.vivoAccent))\(Text(" · \(exercise.category)").foregroundStyle(Color.vivoSecondary))"
            )
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.tight)

            Spacer()

            Text(exercise.lastWeight)
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
}

// MARK: - Muscle Group Section

private extension ExerciseLibraryView {
    func muscleGroupSection(
        title: String,
        count: Int,
        exercises: [LibraryExercise]
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.vivoDisplay(VivoFont.sectionTitle))
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                Text("\(count) EXERCISES")
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    ExerciseLibraryRow(exercise: exercise)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
    }
}

// MARK: - Create Custom Button

private extension ExerciseLibraryView {
    var createCustomButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoAccent)
                Text("CREATE CUSTOM EXERCISE")
                    .font(.vivoMono(VivoFont.monoCaption))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.card)
                    .stroke(Color.vivoSurface, lineWidth: 1.5)
            )
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }
}

// MARK: - Footer

private extension ExerciseLibraryView {
    var footerSection: some View {
        VivoFooter()
    }
}

// MARK: - Preview

#Preview {
    ExerciseLibraryView()
}
