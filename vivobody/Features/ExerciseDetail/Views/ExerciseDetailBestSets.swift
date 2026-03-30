import SwiftUI

struct ExerciseDetailBestSets: View {
    private static let rows: [BestSetRow] = [
        BestSetRow(reps: "01", weight: "225 LB", e1rm: "225", date: "MAR 15"),
        BestSetRow(reps: "02", weight: "215 LB", e1rm: "222", date: "FEB 28"),
        BestSetRow(reps: "03", weight: "205 LB", e1rm: "224", date: "JAN 22"),
        BestSetRow(reps: "05", weight: "195 LB", e1rm: "220", date: "JAN 05"),
        BestSetRow(reps: "08", weight: "185 LB", e1rm: "228", date: "MAR 10"),
        BestSetRow(reps: "10", weight: "175 LB", e1rm: "233", date: "DEC 01"),
        BestSetRow(reps: "12", weight: "165 LB", e1rm: "234", date: "NOV 18")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            tableHeader
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                BestSetTableRow(row: row)
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        Text("BEST SETS BY REP RANGE")
            .font(.vivoMono(VivoFont.monoSM))
            .tracking(VivoTracking.wide)
            .foregroundStyle(Color.vivoMuted)
            .padding(.bottom, VivoSpacing.itemGap)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("REPS")
                .frame(width: 48, alignment: .leading)
            Text("WEIGHT")
                .frame(width: 80, alignment: .leading)
            Text("E1RM")
                .frame(width: 56, alignment: .leading)
            Spacer()
            Text("DATE")
                .frame(width: 64, alignment: .trailing)
        }
        .font(.vivoMono(VivoFont.monoMicro))
        .tracking(VivoTracking.medium)
        .foregroundStyle(Color.vivoSecondary)
        .frame(height: 28)
    }
}

// MARK: - Data

struct BestSetRow {
    let reps: String
    let weight: String
    let e1rm: String
    let date: String
}

// MARK: - Table Row

struct BestSetTableRow: View {
    let row: BestSetRow

    var body: some View {
        HStack(spacing: 0) {
            Text(row.reps)
                .foregroundStyle(Color.vivoAccent)
                .frame(width: 48, alignment: .leading)
            Text(row.weight)
                .foregroundStyle(Color.vivoPrimary)
                .frame(width: 80, alignment: .leading)
            Text(row.e1rm)
                .foregroundStyle(Color.vivoSecondary)
                .frame(width: 56, alignment: .leading)
            Spacer()
            Text(row.date)
                .foregroundStyle(Color.vivoMuted)
                .frame(width: 64, alignment: .trailing)
        }
        .font(.vivoMono(VivoFont.monoSM))
        .tracking(VivoTracking.tight)
        .frame(height: 32)
    }
}

#Preview {
    ExerciseDetailBestSets()
        .background(Color.vivoBackground)
}
