import SwiftUI

// MARK: - Logged Set Model

struct LoggedSet: Identifiable {
    let id = UUID()
    let reps: Int
    let load: Int
    let rir: Int
    let rom: String
    let tempo: String
}

// MARK: - Set Configuration

extension AddExerciseView {
    var setConfiguration: some View {
        HStack(spacing: 0) {
            stepperColumn(value: String(format: "%02d", reps), label: "REPS") {
                reps = max(1, reps - 1)
            } onPlus: {
                reps += 1
            }

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1, height: 158)

            stepperColumn(
                value: "\(load)",
                label: "LOAD",
                suffix: "lb",
                hint: "HOLD TO ACCELERATE"
            ) {
                load = max(0, load - 5)
            } onPlus: {
                load += 5
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
    }

    func stepperColumn(
        value: String,
        label: String,
        suffix: String? = nil,
        hint: String? = nil,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.vivoDisplay(VivoFont.heroXL, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                if let suffix {
                    Text(suffix)
                        .font(.vivoMono(VivoFont.monoDefault))
                        .foregroundStyle(Color.vivoMuted)
                        .offset(y: 12)
                }
            }

            Text(label)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)

            HStack(spacing: 12) {
                VivoStepperButton(symbol: "\u{2212}", action: onMinus)
                VivoStepperButton(symbol: "+", action: onPlus)
            }

            if let hint {
                Text(hint)
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent Loads

extension AddExerciseView {
    static let recentLoads = [135, 185, 205, 225, 275]

    var recentLoads: some View {
        HStack(spacing: 10) {
            Text("RECENT")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)

            HStack(spacing: 6) {
                ForEach(Self.recentLoads, id: \.self) { weight in
                    Button { load = weight } label: {
                        Text("\(weight)")
                            .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                            .tracking(VivoTracking.tight)
                            .foregroundStyle(
                                load == weight ? Color.vivoAccent : Color.vivoMuted
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: VivoRadius.pill)
                                    .stroke(
                                        load == weight ? Color.vivoAccent : Color.vivoSurface,
                                        lineWidth: 1.5
                                    )
                            )
                    }
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
    }
}

// MARK: - RIR Control

extension AddExerciseView {
    var rirControl: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                VivoStepperButton(symbol: "\u{2212}") { rir = max(0, rir - 1) }

                HStack(spacing: 8) {
                    Text(String(format: "%02d", rir))
                        .font(.vivoDisplay(VivoFont.heroLG, weight: .bold))
                        .foregroundStyle(rirColor)

                    Text("REPS LEFT IN TANK")
                        .font(.vivoMono(VivoFont.monoSM))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                }

                Spacer()

                VivoStepperButton(symbol: "+") { rir = min(9, rir + 1) }
            }

            HStack(spacing: 4) {
                ForEach(0 ..< 10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: VivoRadius.bar)
                        .fill(index <= rir ? rirBarColor(index) : Color.vivoSurface)
                        .frame(height: 6)
                }
            }

            HStack {
                Text("FAILURE")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
                Spacer()
                Text("EASY")
                    .font(.vivoMono(VivoFont.monoMicro))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.bottom, 10)
    }

    var rirColor: Color {
        if rir <= 1 { return Color.vivoAccent }
        if rir <= 3 { return Color.vivoYellow }
        return Color.vivoGreen
    }

    func rirBarColor(_ index: Int) -> Color {
        if index <= 1 { return Color.vivoAccent }
        if index <= 3 { return Color.vivoYellow }
        return Color.vivoGreen
    }
}

// MARK: - Log Set Button

extension AddExerciseView {
    var logSetButton: some View {
        Button { logCurrentSet() } label: {
            Text("LOG SET \(String(format: "%02d", loggedSets.count + 1)) \u{2193}")
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .tracking(VivoTracking.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.vivoAccent)
                .clipShape(RoundedRectangle(cornerRadius: VivoRadius.card))
                .shadow(color: Color.vivoAccentShadow, radius: 0, x: 0, y: 2)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 16)
    }

    func logCurrentSet() {
        let logged = LoggedSet(
            reps: reps,
            load: load,
            rir: rir,
            rom: rom,
            tempo: tempo
        )
        withAnimation(.easeOut(duration: 0.25)) {
            loggedSets.append(logged)
        }
    }
}

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
