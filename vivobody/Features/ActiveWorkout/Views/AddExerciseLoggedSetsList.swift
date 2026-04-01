import SwiftUI

// MARK: - Logged Sets

extension AddExerciseView {
    var loggedSetsSection: some View {
        Group {
            if !loggedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    loggedSetsHeader
                        .padding(.top, 16)
                        .padding(.bottom, 2)

                    ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, logged in
                        loggedSetCard(index: index + 1, logged: logged)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, VivoSpacing.screenH)
            }
        }
    }

    private var loggedSetsHeader: some View {
        HStack(spacing: 6) {
            Text("LOGGED SETS")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)

            Text("\(loggedSets.count)")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .fill(Color.vivoAccent.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: VivoRadius.badge)
                                .stroke(Color.vivoAccent, lineWidth: 1)
                        )
                )
        }
    }

    func loggedSetCard(index: Int, logged: LoggedSet) -> some View {
        HStack(spacing: 12) {
            loggedSetBadge(index)
            loggedSetDetails(logged)
            Spacer()
            Text("\u{2713}")
                .font(.vivoDisplay(VivoFont.body))
                .foregroundStyle(Color.vivoGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
    }

    private func loggedSetBadge(_ index: Int) -> some View {
        Text(String(format: "%02d", index))
            .font(.vivoMono(VivoFont.monoLG, weight: .bold))
            .foregroundStyle(Color.vivoAccent)
            .frame(width: 36, height: 48)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.pill)
                    .fill(Color.vivoAccent.opacity(0.1))
            )
    }

    private func loggedSetDetails(_ logged: LoggedSet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("\(logged.reps)")
                    .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(" reps  \u{00B7}  ")
                    .font(.vivoMono(VivoFont.monoBody))
                    .foregroundStyle(Color.vivoMuted)
                Text("\(logged.load)")
                    .font(.vivoMono(VivoFont.monoBody, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(" lb")
                    .font(.vivoMono(VivoFont.monoBody))
                    .foregroundStyle(Color.vivoMuted)
            }

            HStack(spacing: 0) {
                Text("RIR \(logged.rir)")
                    .font(.vivoMono(VivoFont.monoSM, weight: .semibold))
                    .foregroundStyle(loggedRirColor(logged.rir))
                Text("  \u{00B7}  \(logged.rom)  \u{00B7}  \(logged.tempo)")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
                    .lineLimit(1)
            }
        }
    }

    private func loggedRirColor(_ rir: Int) -> Color {
        if rir <= 1 { return Color.vivoAccent }
        if rir <= 3 { return Color.vivoYellow }
        return Color.vivoGreen
    }
}

// MARK: - Footer Info

extension AddExerciseView {
    var footerInfo: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(exercise.name.uppercased()) \u{00B7} \(exercise.primaryTag)")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoMuted)
                Text("LAST PR: 225 LB \u{00B7} FEB 28")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 1) {
                let heights = [16, 10, 16, 5, 14, 16, 4, 12, 16, 8, 16, 10]
                ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                    Rectangle()
                        .fill(Color.vivoMuted)
                        .frame(width: 1, height: CGFloat(height))
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }
}
