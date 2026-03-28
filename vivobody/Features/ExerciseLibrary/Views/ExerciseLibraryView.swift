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
            .padding(.horizontal, 24)
    }
}

// MARK: - Search Bar

private extension ExerciseLibraryView {
    var searchBar: some View {
        HStack(spacing: 10) {
            Text("⚲")
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoMuted)

            Text("Search exercises...")
                .font(.vivoMono(11))
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
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 12)
    }

    func filterPill(_ name: String, count: Int?) -> some View {
        let isSelected = name == selectedFilter
        let label: String = if let count { "\(name)\(count)" } else { name }

        return Button { selectedFilter = name } label: {
            Text(label)
                .font(.vivoMono(10, weight: isSelected ? .bold : .regular))
                .tracking(0.5)
                .foregroundStyle(isSelected ? Color.vivoBackground : Color.vivoSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.vivoPrimary : Color.clear)
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
                .font(.vivoMono(12))
                .tracking(2)
                .foregroundStyle(Color.vivoMuted)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.recentExercises) { exercise in
                        recentCard(exercise)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 10)
        }
    }

    func recentCard(_ exercise: RecentExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.vivoDisplay(16))
                .foregroundStyle(Color.vivoPrimary)
                .lineLimit(2)

            (Text(exercise.muscleGroup)
                .foregroundStyle(Color.vivoAccent)
                + Text(" · \(exercise.category)")
                .foregroundStyle(Color.vivoSecondary))
                .font(.vivoMono(12))
                .tracking(0.5)

            Spacer()

            Text(exercise.lastWeight)
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
                    .font(.vivoDisplay(18))
                    .foregroundStyle(Color.vivoPrimary)
                Spacer()
                Text("\(count) EXERCISES")
                    .font(.vivoMono(12))
                    .tracking(1)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    ExerciseLibraryRow(exercise: exercise)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Create Custom Button

private extension ExerciseLibraryView {
    var createCustomButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Text("+")
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoAccent)
                Text("CREATE CUSTOM EXERCISE")
                    .font(.vivoMono(11))
                    .tracking(1)
                    .foregroundStyle(Color.vivoSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.vivoSurface, lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

// MARK: - Footer

private extension ExerciseLibraryView {
    static let barcodeHeights: [CGFloat] = [
        16, 10, 16, 5, 14, 16, 4, 12, 16, 8, 16, 10
    ]

    var footerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("VIVOBODY EXERCISE DB · V5.0")
                    .font(.vivoMono(7))
                    .tracking(1.5)
                    .foregroundStyle(Color.vivoMuted)
                Text("248 EXERCISES · 7 CATEGORIES")
                    .font(.vivoMono(7))
                    .tracking(1.5)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 1) {
                ForEach(
                    Array(Self.barcodeHeights.enumerated()),
                    id: \.offset
                ) { _, height in
                    Rectangle()
                        .fill(Color.vivoMuted)
                        .frame(width: 1, height: height)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    ExerciseLibraryView()
}
