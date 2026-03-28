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
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(month)
                    .font(.vivoMono(VivoFont.monoTiny))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoMuted)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.vivoDisplay(VivoFont.body))
                    .foregroundStyle(Color.vivoPrimary)
                Text(detail)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(volume)
                    .font(.vivoMono(VivoFont.monoCaption))
                    .foregroundStyle(Color.vivoPrimary)
                Text("VOLUME")
                    .font(.vivoMono(VivoFont.monoMin))
                    .tracking(VivoTracking.normal)
                    .foregroundStyle(Color.vivoSecondary)
                if let prText {
                    Text(prText)
                        .font(.vivoMono(VivoFont.monoTiny))
                        .foregroundStyle(Color.vivoGreen)
                }
            }

            Text("›")
                .font(.vivoDisplay(VivoFont.bodySmall))
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
    .padding(.horizontal, VivoSpacing.screenH)
    .background(Color.vivoBackground)
}
