//
//  ExerciseCatalogBrowserGallery.swift
//  vivobody
//
//  DEBUG gallery for the shared catalog filter strip and long-press row menu.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct ExerciseCatalogBrowserGallery: View {
        @State private var filter: ExerciseCatalogFilter = .all

        private let item = ExerciseCatalogItem(
            catalogID: "gallery-bench-press",
            name: "Barbell Bench Press",
            group: .chest,
            defaultWeight: 135,
            equipment: .barbell,
            trainingRole: .push,
            pattern: .push,
            direction: .horizontal
        )

        var body: some View {
            VStack(alignment: .leading, spacing: Space.xl) {
                ExerciseCatalogFilterStrip(
                    options: [.all, .favorites, .trainingRole(.push), .equipment(.barbell)],
                    selection: $filter,
                    accessibilityPrefix: "galleryExerciseFilter",
                    spacing: Space.md,
                    horizontalContentPadding: Space.gutter
                )

                Text("Long-press Barbell Bench Press")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                    .padding(.horizontal, Space.lg)
                    .contentCard()
                    .exerciseCatalogActions(for: item, actions: actions)
            }
            .padding(.vertical, Space.xl)
            .screenBackground()
        }

        private var actions: ExerciseCatalogBrowserActions {
            ExerciseCatalogBrowserActions(
                allowsEditing: true,
                onToggleFavorite: { _ in },
                onEdit: { _ in },
                onDuplicate: { _ in },
                onRequestDelete: { _ in }
            )
        }
    }

    #Preview("Exercise catalog browser") {
        ExerciseCatalogBrowserGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Exercise catalog browser · Light") {
        ExerciseCatalogBrowserGallery()
            .preferredColorScheme(.light)
    }
#endif
