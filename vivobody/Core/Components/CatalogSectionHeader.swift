import SwiftUI

struct CatalogSectionHeader: View {
    let title: String
    let exerciseCount: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.vivoDisplay(VivoFont.sectionTitle))
                .foregroundStyle(Color.vivoPrimary)
            Spacer()
            Text("\(exerciseCount) EXERCISES")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

#Preview {
    CatalogSectionHeader(title: "Quads", exerciseCount: 3)
        .background(Color.vivoBackground)
}
