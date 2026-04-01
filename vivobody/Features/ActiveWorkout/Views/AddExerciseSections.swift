import SwiftUI

// MARK: - Logged Set Model

struct LoggedSet: Identifiable {
    let id = UUID()
    let reps: Int
    let load: Int
    let rir: Int
    let rom: String
    let tempo: String
    let grip: String
    let stance: String
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

    var advancedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showAdvanced.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(showAdvanced ? "\u{2212}" : "+")
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoAccent)
                Text("ADVANCED OPTIONS")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoAccent)
                Spacer()
                if !showAdvanced {
                    Text("\(rom) \u{00B7} \(tempo)")
                        .font(.vivoMono(VivoFont.monoXS))
                        .tracking(VivoTracking.tight)
                        .foregroundStyle(Color.vivoMuted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    var advancedOptions: some View {
        VStack(spacing: 0) {
            sectionLabel("RANGE OF MOTION")
            VivoSegmentPicker(
                options: ["PARTIAL", "FULL", "DEEP"],
                selection: $rom
            )
            .padding(.horizontal, VivoSpacing.screenH)
            sectionLabel("TEMPO")
            VivoSegmentPicker(
                options: ["EXPLOSIVE", "CONTROLLED", "SLOW", "PAUSED"],
                selection: $tempo,
                accentSelected: true
            )
            .padding(.horizontal, VivoSpacing.screenH)
            sectionLabel("GRIP")
            VivoSegmentPicker(
                options: ["WIDE", "NORMAL", "NARROW"],
                selection: $grip
            )
            .padding(.horizontal, VivoSpacing.screenH)
            sectionLabel("STANCE")
            VivoSegmentPicker(
                options: ["WIDE", "NORMAL", "NARROW"],
                selection: $stance
            )
            .padding(.horizontal, VivoSpacing.screenH)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    func logCurrentSet() {
        let logged = LoggedSet(
            reps: reps,
            load: load,
            rir: rir,
            rom: rom,
            tempo: tempo,
            grip: grip,
            stance: stance
        )
        withAnimation(.easeOut(duration: 0.25)) {
            loggedSets.append(logged)
        }
    }
}
