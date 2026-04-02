import SwiftUI

struct CatalogFilterBar: View {
    let filters: [ExerciseCatalogFilter]
    @Binding var selectedFilter: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(filters.enumerated(), id: \.element.id) { index, filter in
                    if index > 0, !filter.isSpecial, filters[index - 1].isSpecial {
                        Rectangle()
                            .fill(Color.vivoSurface)
                            .frame(width: 1, height: 20)
                            .padding(.horizontal, 4)
                    }
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
        .padding(.vertical, 16)
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

    private var fillColor: Color {
        guard isSelected else { return .clear }
        return filter.isSpecial ? Color.vivoAccent : Color.vivoPrimary
    }

    private var textColor: Color {
        guard isSelected else { return Color.vivoSecondary }
        return filter.isSpecial ? .white : Color.vivoBackground
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.vivoMono(VivoFont.monoCaption, weight: isSelected ? .bold : .regular))
                .tracking(VivoTracking.tight)
                .foregroundStyle(textColor)
                .padding(.horizontal, VivoSpacing.cardPadding)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.pill)
                        .fill(fillColor)
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
                ExerciseCatalogFilter(name: "RECENT", count: nil, isSpecial: true),
                ExerciseCatalogFilter(name: "ALL", count: nil, isSpecial: true),
                ExerciseCatalogFilter(name: "FAVORITES", count: nil, isSpecial: true),
                ExerciseCatalogFilter(name: "QUADS", count: 3),
                ExerciseCatalogFilter(name: "GLUTES", count: 2)
            ],
            selectedFilter: .constant("ALL")
        )
    }
    .background(Color.vivoBackground)
}
