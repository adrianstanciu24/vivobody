import SwiftUI

struct HistoryActivityGrid: View {
    private let columns = 12
    private let rows = 7

    private let activityData: [[Int]] = [
        [2, 3, 1, 0, 2, 3, 1, 2, 3, 2, 1, 3],
        [1, 0, 2, 3, 1, 0, 2, 1, 2, 3, 2, 1],
        [3, 2, 0, 1, 2, 1, 3, 0, 1, 2, 3, 2],
        [0, 1, 2, 3, 0, 2, 1, 3, 2, 0, 1, 2],
        [2, 3, 1, 2, 3, 1, 0, 2, 3, 1, 2, 0],
        [1, 0, 3, 1, 2, 0, 2, 1, 0, 3, 2, 1],
        [3, 2, 1, 0, 1, 3, 2, 3, 1, 2, 0, 4]
    ]

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            gridView
            legendRow
        }
    }

    private var sectionHeader: some View {
        Text("ACTIVITY · LAST 12 WEEKS")
            .font(.vivoMono(12))
            .tracking(2)
            .foregroundStyle(Color.vivoMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 10)
    }

    private var gridView: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< columns, id: \.self) { col in
                VStack(spacing: 2) {
                    ForEach(0 ..< rows, id: \.self) { row in
                        Circle()
                            .fill(cellColor(activityData[row][col]))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func cellColor(_ level: Int) -> Color {
        switch level {
        case 0: Color.vivoSurface
        case 1: Color.vivoAccent.opacity(0.3)
        case 2: Color.vivoAccent.opacity(0.6)
        case 3: Color.vivoAccent
        case 4: Color.vivoGreen
        default: Color.vivoSurface
        }
    }

    private var legendRow: some View {
        HStack(spacing: 6) {
            Text("LESS")
                .font(.vivoMono(7))
                .tracking(1)
                .foregroundStyle(Color.vivoMuted)

            HStack(spacing: 2) {
                ForEach(0 ..< 5, id: \.self) { level in
                    Circle()
                        .fill(cellColor(level))
                        .frame(width: 8, height: 8)
                }
            }

            Text("MORE")
                .font(.vivoMono(7))
                .tracking(1)
                .foregroundStyle(Color.vivoMuted)

            Circle()
                .fill(Color.vivoGreen)
                .frame(width: 8, height: 8)
                .padding(.leading, 6)

            Text("PR DAY")
                .font(.vivoMono(7))
                .tracking(1)
                .foregroundStyle(Color.vivoMuted)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

#Preview {
    HistoryActivityGrid()
        .background(Color.vivoBackground)
}
