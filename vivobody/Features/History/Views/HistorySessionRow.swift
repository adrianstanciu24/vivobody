import SwiftUI

struct HistorySessionRow: View {
    let day: String
    let month: String
    let name: String
    let detail: String
    let volume: String
    let prText: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(day)
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoPrimary)
                Text(month)
                    .font(.vivoMono(8))
                    .tracking(1)
                    .foregroundStyle(Color.vivoMuted)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.vivoDisplay(16))
                    .foregroundStyle(Color.vivoPrimary)
                Text(detail)
                    .font(.vivoMono(12))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(volume)
                    .font(.vivoMono(11))
                    .foregroundStyle(Color.vivoPrimary)
                Text("VOLUME")
                    .font(.vivoMono(7))
                    .tracking(1)
                    .foregroundStyle(Color.vivoSecondary)
                if let prText {
                    Text(prText)
                        .font(.vivoMono(8))
                        .foregroundStyle(Color.vivoGreen)
                }
            }

            Text("›")
                .font(.vivoDisplay(14))
                .foregroundStyle(Color.vivoMuted)
        }
        .frame(minHeight: 65)
    }
}

#Preview {
    VStack {
        HistorySessionRow(
            day: "17", month: "MAR",
            name: "Lower Body A",
            detail: "58 min · 24 sets · 5 exercises",
            volume: "18,240", prText: "1 PR"
        )
        HistorySessionRow(
            day: "16", month: "MAR",
            name: "Upper Pull B",
            detail: "49 min · 20 sets · 5 exercises",
            volume: "12,650", prText: nil
        )
    }
    .padding(.horizontal, 24)
    .background(Color.vivoBackground)
}
