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
            Text("LOG SET \u{2193}")
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
        loggedSets.append(logged)
    }
}

// MARK: - Logged Sets

extension AddExerciseView {
    var loggedSetsSection: some View {
        Group {
            if !loggedSets.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("LOGGED SETS")
                        .font(.vivoMono(VivoFont.monoSM))
                        .tracking(VivoTracking.wide)
                        .foregroundStyle(Color.vivoMuted)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, logged in
                        loggedSetRow(index: index + 1, logged: logged)
                    }
                }
                .padding(.horizontal, VivoSpacing.screenH)
            }
        }
    }

    func loggedSetRow(index: Int, logged: LoggedSet) -> some View {
        HStack {
            Text(String(format: "%02d", index))
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 20, alignment: .leading)

            HStack(spacing: 0) {
                Text("\(logged.reps)")
                    .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(" reps \u{00B7} ")
                    .font(.vivoMono(VivoFont.monoDefault))
                    .foregroundStyle(Color.vivoMuted)
                Text("\(logged.load)")
                    .font(.vivoMono(VivoFont.monoDefault, weight: .bold))
                    .foregroundStyle(Color.vivoPrimary)
                Text(" lb \u{00B7} RIR \(logged.rir) \u{00B7} \(logged.rom) \u{00B7} \(logged.tempo)")
                    .font(.vivoMono(VivoFont.monoDefault))
                    .foregroundStyle(Color.vivoMuted)
                    .lineLimit(1)
            }

            Spacer()

            Text("\u{2713}")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoGreen)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
        }
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
