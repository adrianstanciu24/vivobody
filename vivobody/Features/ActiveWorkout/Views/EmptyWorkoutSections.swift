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
                quickPickRow(pick)
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

// MARK: - Bottom Bar

extension EmptyWorkoutView {
    var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Text("DISCARD")
                    .font(.vivoMono(14, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.vivoMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 47)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.vivoSurface, lineWidth: 1.5)
                    )
            }
            .frame(width: 134)

            Button {} label: {
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
        Text("SESSION #129 · EMPTY START · AUTO-SAVED 09:41")
            .font(.vivoMono(10))
            .tracking(1.5)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
    }
}
