import SwiftUI

// MARK: - PR Badge

struct PRBadge: View {
    let count: Int

    var body: some View {
        Text(count == 1 ? "1 PR" : "\(count) PRs")
            .font(.vivoMono(VivoFont.monoXS))
            .tracking(VivoTracking.normal)
            .foregroundStyle(Color.vivoAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

// MARK: - Barcode Decoration

struct BarcodeDecor: View {
    static let defaultHeights: [CGFloat] = [
        20, 14, 20, 8, 18, 20, 6, 16, 20, 10,
        20, 14, 4, 20, 12, 20, 8, 18, 20, 6
    ]

    let heights: [CGFloat]

    init(heights: [CGFloat] = BarcodeDecor.defaultHeights) {
        self.heights = heights
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, barHeight in
                Rectangle()
                    .fill(Color.vivoMuted)
                    .frame(width: 1, height: barHeight)
            }
        }
    }
}

// MARK: - Vivo Footer

struct VivoFooter: View {
    var line1 = "VIVOBODY WORKOUT SYS"
    var line2 = "ATHLETE: AS \u{00B7} #0042"
    var line3 = "127 SESSIONS \u{00B7} SINCE AUG 2024"

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                footerLine(line1)
                footerLine(line2)
                footerLine(line3)
            }
            Spacer()
            BarcodeDecor()
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 12)
    }

    private func footerLine(_ text: String) -> some View {
        Text(text)
            .font(.vivoMono(VivoFont.monoMin))
            .tracking(VivoTracking.medium)
            .foregroundStyle(Color.vivoMuted)
    }
}

// MARK: - Stepper Button

struct VivoStepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.vivoMono(VivoFont.monoXL))
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.stepper)
                        .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.stepper)
                        .stroke(Color.vivoSurface, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Segment Picker

struct VivoSegmentPicker: View {
    let options: [String]
    @Binding var selection: String
    var accentSelected = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button { selection = option } label: {
                    Text(option)
                        .font(.vivoMono(VivoFont.monoSM, weight: isSelected ? .bold : .regular))
                        .tracking(VivoTracking.tight)
                        .foregroundStyle(foreground(isSelected))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(background(isSelected))
                        .clipShape(RoundedRectangle(cornerRadius: VivoRadius.pill))
                        .overlay(
                            isSelected ? nil :
                                RoundedRectangle(cornerRadius: VivoRadius.pill)
                                .stroke(Color.vivoSurface, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    private func foreground(_ selected: Bool) -> Color {
        if !selected { return Color.vivoMuted }
        return accentSelected ? .white : Color.vivoBackground
    }

    private func background(_ selected: Bool) -> Color {
        if !selected { return .clear }
        return accentSelected ? Color.vivoAccent : Color.vivoPrimary
    }
}

// MARK: - Stat Column

struct VivoStatColumn: View {
    let value: String
    let label: String
    var valueColor: Color = .vivoPrimary
    var valueFont: CGFloat = VivoFont.headlineMD

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.vivoDisplay(valueFont, weight: .bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("PR Badge") {
    HStack {
        PRBadge(count: 1)
        PRBadge(count: 3)
    }
    .padding()
    .background(Color.vivoBackground)
}

#Preview("Footer") {
    VivoFooter()
        .background(Color.vivoBackground)
}
