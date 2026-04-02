import SwiftUI

struct WorkoutsTabToggleBar: View {
    @Binding var selectedTab: WorkoutTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WorkoutTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button { selectedTab = tab } label: {
                    Text(tab.label)
                        .font(.vivoMono(
                            VivoFont.monoSM,
                            weight: isSelected ? .bold : .regular
                        ))
                        .tracking(VivoTracking.tight)
                        .foregroundStyle(
                            isSelected ? Color.vivoBackground : Color.vivoSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: VivoRadius.card)
                                .fill(isSelected ? Color.vivoPrimary : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: VivoRadius.card)
                                .stroke(Color.vivoSurface, lineWidth: 1.5)
                                .opacity(isSelected ? 0 : 1)
                        )
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

#Preview {
    WorkoutsTabToggleBar(selectedTab: .constant(.history))
        .background(Color.vivoBackground)
}
