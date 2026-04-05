import SwiftUI

struct ExerciseDetailRangeOfMotionView: View {
    let rangeOfMotion: [ExerciseProfileROM]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            tableHeader
            ForEach(Array(rangeOfMotion.enumerated()), id: \.offset) { _, rom in
                ROMTableRow(rom: rom)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        Text("RANGE OF MOTION")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .padding(.bottom, VivoSpacing.itemGap)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("JOINT")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("MIN")
                .frame(width: 52, alignment: .trailing)
            Text("MAX")
                .frame(width: 52, alignment: .trailing)
            Text("RANGE")
                .frame(width: 56, alignment: .trailing)
        }
        .font(.vivoMono(VivoFont.monoMicro))
        .tracking(VivoTracking.medium)
        .foregroundStyle(Color.vivoSecondary)
        .frame(height: 28)
    }
}

// MARK: - Row

private struct ROMTableRow: View {
    let rom: ExerciseProfileROM

    var body: some View {
        HStack(spacing: 0) {
            Text(rom.label.uppercased())
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(formatDeg(rom.minDeg))
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 52, alignment: .trailing)
            Text(formatDeg(rom.maxDeg))
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 52, alignment: .trailing)
            Text(formatDeg(rom.rangeDeg))
                .foregroundStyle(Color.vivoAccent)
                .frame(width: 56, alignment: .trailing)
        }
        .font(.vivoMono(VivoFont.monoSM))
        .tracking(VivoTracking.tight)
        .frame(height: 32)
    }

    private func formatDeg(_ value: Double) -> String {
        let intValue = Int(value)
        return "\(intValue)\u{00B0}"
    }
}

#Preview {
    ExerciseDetailRangeOfMotionView(rangeOfMotion: [
        ExerciseProfileROM(joint: "hip_flexion", label: "Hip Flexion", minDeg: 8, maxDeg: 82, rangeDeg: 74),
        ExerciseProfileROM(joint: "knee_flexion", label: "Knee Flexion", minDeg: 8, maxDeg: 104, rangeDeg: 96),
        ExerciseProfileROM(
            joint: "ankle_dorsiflexion",
            label: "Ankle Dorsiflexion",
            minDeg: -8,
            maxDeg: 14,
            rangeDeg: 22
        ),
        ExerciseProfileROM(joint: "trunk_flexion", label: "Trunk Flexion", minDeg: 8, maxDeg: 24, rangeDeg: 16)
    ])
    .background(Color.vivoBackground)
}
