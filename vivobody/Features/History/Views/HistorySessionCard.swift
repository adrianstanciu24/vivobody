import SwiftUI

struct HistorySessionCard: View {
    private struct ExerciseEntry: Identifiable {
        let id: String
        let name: String
        let detail: String
        let hasPR: Bool
    }

    private let exercises: [ExerciseEntry] = [
        ExerciseEntry(id: "01", name: "Barbell Bench Press", detail: "4s · 205lb", hasPR: true),
        ExerciseEntry(id: "02", name: "Incline DB Press", detail: "3s · 80lb", hasPR: true),
        ExerciseEntry(id: "03", name: "OHP", detail: "3s · 125lb", hasPR: false),
        ExerciseEntry(id: "04", name: "Cable Fly", detail: "4s · 35lb", hasPR: false),
        ExerciseEntry(id: "05", name: "Lateral Raise", detail: "4s · 25lb", hasPR: false),
        ExerciseEntry(id: "06", name: "Tricep Pushdown", detail: "3s · 60lb", hasPR: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            titleRow
            statsRow
            exercisesList
            viewReceiptButton
        }
        .padding(17.5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var headerRow: some View {
        HStack {
            Text("Wednesday, Mar 18")
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoPrimary)
            Spacer()
            Text("#127")
                .font(.vivoMono(12))
                .foregroundStyle(Color.vivoSecondary)
        }
    }

    private var titleRow: some View {
        Text("Upper Body Push A")
            .font(.vivoDisplay(18, weight: .bold))
            .foregroundStyle(Color.vivoPrimary)
            .padding(.top, 10)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            cardStat(value: "52m", label: "DURATION")
            cardStat(value: "14.8k", label: "VOLUME")
            cardStat(value: "22", label: "SETS")
            cardStat(value: "02", label: "PRs")
        }
        .padding(.top, 12)
    }

    private func cardStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(7))
                .tracking(1.5)
                .foregroundStyle(Color.vivoSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var exercisesList: some View {
        VStack(spacing: 0) {
            ForEach(exercises) { exercise in
                HStack(spacing: 8) {
                    Text(exercise.id)
                        .font(.vivoMono(8))
                        .foregroundStyle(Color.vivoMuted)
                        .frame(width: 16, alignment: .leading)

                    Text(exercise.name)
                        .font(.vivoDisplay(11))
                        .foregroundStyle(Color.vivoPrimary)

                    Spacer()

                    Text(exercise.detail)
                        .font(.vivoMono(12))
                        .foregroundStyle(Color.vivoSecondary)

                    if exercise.hasPR {
                        Text("PR")
                            .font(.vivoMono(8))
                            .tracking(0.5)
                            .foregroundStyle(Color.vivoGreen)
                    }
                }
                .frame(height: 26)
            }
        }
        .padding(.top, 16)
    }

    private var viewReceiptButton: some View {
        Button {} label: {
            Text("VIEW FULL RECEIPT →")
                .font(.vivoMono(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.vivoAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 37)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.vivoSurface, lineWidth: 1)
                )
        }
        .padding(.top, 12)
    }
}

#Preview {
    HistorySessionCard()
        .background(Color.vivoBackground)
}
