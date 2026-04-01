import SwiftUI

// MARK: - RIR Control

extension EditSetView {
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

// MARK: - Advanced Options

extension EditSetView {
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
                advancedSummary
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    var advancedSummary: some View {
        if !showAdvanced {
            Text("\(rom) \u{00B7} \(tempo)")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
                .lineLimit(1)
        }
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
}
