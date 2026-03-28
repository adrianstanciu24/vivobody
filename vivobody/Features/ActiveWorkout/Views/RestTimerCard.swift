import SwiftUI

struct RestTimerCard: View {
    let currentSet: Int
    let totalSets: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("1:42")
                .font(.vivoDisplay(VivoFont.titleSM, weight: .bold))
                .foregroundStyle(Color.vivoAccent)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("REST TIMER")
                    .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                    .tracking(VivoTracking.medium)
                    .foregroundStyle(Color.vivoAccent)
                Text("TARGET: 2:00 · SET \(String(format: "%02d", currentSet)) NEXT")
                    .font(.vivoMono(VivoFont.monoXS))
                    .tracking(VivoTracking.tight)
                    .foregroundStyle(Color.vivoMuted)
            }

            Spacer()

            Button {} label: {
                Text("\u{203A}\u{203A}")
                    .font(.vivoMono(VivoFont.monoLG))
                    .foregroundStyle(Color.vivoAccent)
                    .frame(width: 56, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: VivoRadius.card)
                            .stroke(Color.vivoAccent, lineWidth: 1.5)
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoAccent, lineWidth: 1.5)
        )
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
        )
        .padding(.horizontal, VivoSpacing.screenH)
    }
}

#Preview {
    RestTimerCard(currentSet: 3, totalSets: 4)
        .background(Color.vivoBackground)
}
