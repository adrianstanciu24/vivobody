import SwiftUI

struct CatalogSearchBar: View {
    let totalCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\u{26B2}")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoMuted)

            Text("Bundled exercise catalog")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Spacer()

            Text("\(totalCount) TOTAL")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .stroke(Color.vivoSurface, lineWidth: 1)
                )
        }
        .padding(.horizontal, VivoSpacing.cardPadding)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 4)
    }
}

#Preview {
    CatalogSearchBar(totalCount: 6)
        .background(Color.vivoBackground)
}
