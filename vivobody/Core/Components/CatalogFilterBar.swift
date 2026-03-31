import SwiftUI

struct CatalogFilterBar: View {
    let filters: [ExerciseCatalogFilter]
    @Binding var selectedFilter: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(filters) { filter in
                    CatalogFilterPill(
                        filter: filter,
                        isSelected: filter.name == selectedFilter
                    ) {
                        selectedFilter = filter.name
                    }
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 12)
    }
}

struct CatalogFilterPill: View {
    let filter: ExerciseCatalogFilter
    let isSelected: Bool
    let action: () -> Void

    private var label: String {
        if let count = filter.count {
            "\(filter.name)\(count)"
        } else {
            filter.name
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.vivoMono(VivoFont.monoCaption, weight: isSelected ? .bold : .regular))
                .tracking(VivoTracking.tight)
                .foregroundStyle(isSelected ? Color.vivoBackground : Color.vivoSecondary)
                .padding(.horizontal, VivoSpacing.cardPadding)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(isSelected ? Color.vivoPrimary : .clear)
                )
                .overlay(
                    isSelected ? nil :
                        RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .stroke(Color.vivoSurface, lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    VStack {
        CatalogFilterBar(
            filters: [
                ExerciseCatalogFilter(name: "ALL", count: nil),
                ExerciseCatalogFilter(name: "QUADS", count: 3),
                ExerciseCatalogFilter(name: "GLUTES", count: 2)
            ],
            selectedFilter: .constant("ALL")
        )
    }
    .background(Color.vivoBackground)
}
