import SwiftUI

struct CatalogSectionHeader: View {
    let title: String
    let exerciseCount: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoAccent)
            Spacer()
            Text("\(exerciseCount)")
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
        .background(Color.vivoSurface.opacity(0.3))
    }
}

#Preview {
    VStack(spacing: 0) {
        CatalogSectionHeader(title: "Quads", exerciseCount: 3)
        CatalogSectionHeader(title: "Glutes", exerciseCount: 5)
    }
    .background(Color.vivoBackground)
}
