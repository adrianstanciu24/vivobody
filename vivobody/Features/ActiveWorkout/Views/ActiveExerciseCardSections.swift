import SwiftUI

// MARK: - Rest Timer

extension ActiveExerciseCard {
    var inlineRestTimer: some View {
        let minutes = restSecondsRemaining / 60
        let seconds = restSecondsRemaining % 60
        let formatted = String(format: "%d:%02d", minutes, seconds)
        let target = String(
            format: "%d:%02d",
            exercise.targetRestSeconds / 60,
            exercise.targetRestSeconds % 60
        )

        return HStack(spacing: 0) {
            Text(formatted)
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("REST")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoAccent)
                Text("TARGET: \(target)")
                    .font(.vivoMono(VivoFont.monoXS))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Button { onSkipRest?() } label: {
                Text("SKIP")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoAccent)
                    .frame(width: 56, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.badge)
                            .stroke(Color.vivoAccent, lineWidth: 1)
                    )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.badge)
                .fill(Color.vivoAccent.opacity(0.08))
        )
        .padding(.top, 8)
    }
}

// MARK: - Set Text Views

extension ActiveExerciseCard {
    @ViewBuilder
    func setTrailingAction(isCompleted: Bool) -> some View {
        if isCompleted {
            Text("\u{2713}")
                .font(.vivoDisplay(VivoFont.body))
                .foregroundStyle(Color.vivoGreen)
        }
    }

    func completedSetText(_ exerciseSet: SessionSet) -> some View {
        HStack(spacing: 0) {
            Text("\(exerciseSet.reps)")
                .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" reps \u{00B7} ")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
            Text("\(exerciseSet.weight)")
                .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" lb \u{00B7} RIR \(exerciseSet.rir)")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
        }
    }

    func currentSetText(_ exerciseSet: SessionSet) -> some View {
        HStack(spacing: 0) {
            Text("\(exerciseSet.reps)")
                .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" reps \u{00B7} ")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoPrimary)
            Text("\(exerciseSet.weight)")
                .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" lb \u{00B7} RIR \(exerciseSet.rir)")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoPrimary)
        }
        .lineLimit(1)
    }

    func plannedSetText(_ exerciseSet: SessionSet) -> some View {
        HStack(spacing: 0) {
            Text("\(exerciseSet.reps)")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
            Text(" reps \u{00B7} ")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
            Text("\(exerciseSet.weight)")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
            Text(" lb \u{00B7} RIR \(exerciseSet.rir)")
                .font(.vivoMono(VivoFont.monoBody))
                .foregroundStyle(Color.vivoMuted)
        }
    }
}
