import SwiftUI

// MARK: - Quick Pick Data

struct QuickPick: Identifiable {
    let id: String
    let number: String
    let name: String
    let tags: String
    let badge: String
    let isRecent: Bool
}

// MARK: - Quick Picks

extension EmptyWorkoutView {
    static let quickPicks: [QuickPick] = [
        QuickPick(
            id: "1", number: "01",
            name: "Barbell Bench Press",
            tags: "CHEST · COMPOUND · BARBELL",
            badge: "RECENT", isRecent: true
        ),
        QuickPick(
            id: "2", number: "02",
            name: "Back Squat",
            tags: "QUADS · COMPOUND · BARBELL",
            badge: "RECENT", isRecent: false
        ),
        QuickPick(
            id: "3", number: "03",
            name: "Pull-Up",
            tags: "BACK · BODYWEIGHT · VERTICAL",
            badge: "FAVORITE", isRecent: false
        )
    ]

    var quickPicksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK PICKS")
                .font(.vivoMono(12))
                .tracking(2)
                .foregroundStyle(Color.vivoMuted)
                .padding(.top, 20)

            ForEach(Self.quickPicks) { pick in
                Button {
                    session?.addExercise(name: pick.name, tags: pick.tags)
                } label: {
                    quickPickRow(pick)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    func quickPickRow(_ pick: QuickPick) -> some View {
        HStack(spacing: 12) {
            Text(pick.number)
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(pick.name)
                    .font(.vivoDisplay(16, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(pick.tags)
                    .font(.vivoMono(12, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
            }

            Spacer()

            Text(pick.badge)
                .font(.vivoMono(10))
                .tracking(1)
                .foregroundStyle(pick.isRecent ? Color.vivoAccent : Color.vivoMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            pick.isRecent ? Color.vivoAccent : Color.vivoSurface,
                            lineWidth: 1
                        )
                )
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

// MARK: - Active Content

extension EmptyWorkoutView {
    var activeContent: some View {
        VStack(spacing: 14) {
            ForEach(session?.exercises ?? []) { exercise in
                ActiveExerciseCard(exercise: exercise)
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
                .font(.vivoMono(12))
                .tracking(2)
                .foregroundStyle(Color.vivoMuted)

            ForEach(Self.suggestions) { suggestion in
                Button {
                    session?.addExercise(name: suggestion.name, tags: suggestion.tags)
                } label: {
                    suggestionRow(suggestion)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    func suggestionRow(_ item: SuggestionItem) -> some View {
        HStack(spacing: 12) {
            Text(item.number)
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoMuted)

            Text(item.name)
                .font(.vivoDisplay(16, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Spacer()

            Text(item.badge)
                .font(.vivoMono(10))
                .tracking(1)
                .foregroundStyle(item.isRecent ? Color.vivoAccent : Color.vivoMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            item.isRecent ? Color.vivoAccent : Color.vivoSurface,
                            lineWidth: 1
                        )
                )
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }
}

// MARK: - Suggestion Data

struct SuggestionItem: Identifiable {
    let id: String
    let number: String
    let name: String
    let tags: String
    let badge: String
    let isRecent: Bool
}

extension EmptyWorkoutView {
    static let suggestions: [SuggestionItem] = [
        SuggestionItem(
            id: "s1", number: "02",
            name: "Incline DB Press",
            tags: "CHEST · COMPOUND · DUMBBELL",
            badge: "RECENT", isRecent: true
        ),
        SuggestionItem(
            id: "s2", number: "03",
            name: "OHP",
            tags: "SHOULDERS · COMPOUND · BARBELL",
            badge: "RECENT", isRecent: false
        ),
        SuggestionItem(
            id: "s3", number: "04",
            name: "Cable Fly",
            tags: "CHEST · ISOLATION · CABLE",
            badge: "FAVORITE", isRecent: false
        )
    ]
}

// MARK: - Active Bottom Bar

extension EmptyWorkoutView {
    var activeBottomBar: some View {
        Button { showExercisePicker = true } label: {
            Text("+ ADD EXERCISE")
                .font(.vivoMono(14, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
        }
        .padding(.horizontal, 24)
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

// MARK: - Footer

extension EmptyWorkoutView {
    var footerLabel: some View {
        Text("SESSION #129 · CUSTOM · AUTO-SAVED 09:41")
            .font(.vivoMono(10))
            .tracking(1.5)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
    }
}
