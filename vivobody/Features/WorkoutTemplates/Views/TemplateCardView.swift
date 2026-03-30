import SwiftData
import SwiftUI

struct TemplateCardView: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                musclePills
                statsRow
                scheduleRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\u{203A}")
                .font(.vivoDisplay(VivoFont.headlineSM))
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(VivoSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .fill(Color.vivoAccent)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 6)
    }

    private var cardHeader: some View {
        Text(template.name.uppercased())
            .font(.vivoDisplay(VivoFont.sectionTitle, weight: .bold))
            .foregroundStyle(Color.vivoPrimary)
    }

    @ViewBuilder
    private var musclePills: some View {
        if !template.muscleGroups.isEmpty {
            HStack(spacing: 6) {
                ForEach(template.muscleGroups, id: \.self) { muscle in
                    musclePill(muscle.displayName.uppercased())
                }
            }
            .padding(.top, 8)
        }
    }

    private func musclePill(_ label: String) -> some View {
        Text(label)
            .font(.vivoMono(VivoFont.monoTiny, weight: .bold))
            .tracking(VivoTracking.tight)
            .foregroundStyle(Color.vivoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .fill(Color.vivoAccent.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .stroke(Color.vivoAccent.opacity(0.3), lineWidth: 1)
            )
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(
                value: String(format: "%02d", template.exercises.count),
                label: " exercises"
            )
            dot
            stat(
                value: "\(template.exercises.reduce(0) { $0 + $1.targetSets })",
                label: " sets"
            )
            dot
            stat(value: "~\(estimatedMinutes)m", label: "")
        }
        .padding(.top, 10)
    }

    private var scheduleRow: some View {
        HStack(spacing: 0) {
            if !template.scheduleDays.isEmpty {
                Text(dayLabels)
                    .font(.vivoMono(VivoFont.monoSM))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoSecondary)
                dot
            }
            Text("USED \(template.timesUsed)\u{00D7}")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func stat(value: String, label: String) -> some View {
        HStack(spacing: 0) {
            Text(value)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(label)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoSecondary)
        }
    }

    private var dot: some View {
        Text("  \u{00B7}  ")
            .font(.vivoMono(VivoFont.monoSM))
            .foregroundStyle(Color.vivoMuted)
    }

    private var estimatedMinutes: Int {
        let setTime = 45
        var totalRest = 0
        var totalSets = 0
        for exercise in template.exercises {
            totalSets += exercise.targetSets
            totalRest += exercise.targetSets * exercise.restSeconds
        }
        return max(1, (totalSets * setTime + totalRest) / 60)
    }

    private var dayLabels: String {
        let labels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        return template.scheduleDays.sorted()
            .compactMap { $0 < labels.count ? labels[$0] : nil }
            .joined(separator: " \u{00B7} ")
    }
}

#Preview {
    TemplateCardView(template: WorkoutTemplate(name: "Push Day", muscleGroups: [.chest, .shoulders]))
        .background(Color.vivoBackground)
        .modelContainer(
            for: [WorkoutTemplate.self, TemplateExercise.self],
            inMemory: true
        )
}
