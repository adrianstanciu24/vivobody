import SwiftUI

struct ExerciseDetailPRTimeline: View {
    private static let prEntries: [PREntry] = [
        PREntry(weight: "225 LB", reps: "× 01", rir: "RIR 0", jump: "+10 LB", date: "MAR 15, 2025"),
        PREntry(weight: "215 LB", reps: "× 02", rir: "RIR 1", jump: "+5 LB", date: "FEB 28, 2025"),
        PREntry(weight: "210 LB", reps: "× 01", rir: "RIR 0", jump: "+5 LB", date: "FEB 10, 2025"),
        PREntry(weight: "205 LB", reps: "× 03", rir: "RIR 1", jump: "+10 LB", date: "JAN 22, 2025"),
        PREntry(weight: "195 LB", reps: "× 05", rir: "RIR 2", jump: "+5 LB", date: "JAN 05, 2025"),
        PREntry(weight: "190 LB", reps: "× 01", rir: "RIR 0", jump: "+15 LB", date: "DEC 18, 2024"),
        PREntry(weight: "175 LB", reps: "× 01", rir: "RIR 0", jump: "FIRST", date: "AUG 12, 2024")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            ForEach(Array(Self.prEntries.enumerated()), id: \.offset) { _, entry in
                PRTimelineRow(entry: entry)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("PR TIMELINE")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("07 PRs")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoAccent)
        }
        .padding(.bottom, VivoSpacing.itemGap)
    }
}

// MARK: - Data

struct PREntry {
    let weight: String
    let reps: String
    let rir: String
    let jump: String
    let date: String
}

// MARK: - Row

struct PRTimelineRow: View {
    let entry: PREntry

    var body: some View {
        HStack(spacing: 0) {
            timelineIndicator
                .frame(width: 20)

            Text(entry.weight)
                .font(.vivoMono(VivoFont.monoMD, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
                .frame(width: 72, alignment: .leading)

            Text(entry.reps)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 36, alignment: .leading)

            Text(entry.rir)
                .font(.vivoMono(VivoFont.monoXS))
                .foregroundStyle(Color.vivoSecondary)
                .frame(width: 42, alignment: .leading)

            Spacer()

            Text(entry.jump)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoGreen)
                .frame(width: 56, alignment: .trailing)

            Text(entry.date)
                .font(.vivoMono(VivoFont.monoMicro))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 92, alignment: .trailing)
        }
        .frame(height: 36)
    }

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1)
            Circle()
                .fill(Color.vivoAccent)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.vivoSurface)
                .frame(width: 1)
        }
    }
}

#Preview {
    ExerciseDetailPRTimeline()
        .background(Color.vivoBackground)
}
