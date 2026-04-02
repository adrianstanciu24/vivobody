import SwiftUI

struct WorkoutsHistorySearchBar: View {
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.vivoMuted)
                .accessibilityHidden(true)

            TextField("", text: $searchText, prompt: Text("Search workouts...")
                .font(.vivoMono(VivoFont.monoDefault))
                .foregroundStyle(Color.vivoMuted))
                .font(.vivoMono(VivoFont.monoDefault))
                .foregroundStyle(Color.vivoPrimary)
                .submitLabel(.done)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: VivoRadius.card)
                .fill(Color(red: 0.094, green: 0.094, blue: 0.094))
                .stroke(Color.vivoSurface, lineWidth: 1)
        )
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 10)
    }
}

#Preview {
    WorkoutsHistorySearchBar()
        .background(Color.vivoBackground)
}
