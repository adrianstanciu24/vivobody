#if DEBUG
//
    //  BrowserColumnsGallery.swift
    //  vivobody
//
    //  A small browser built on BrowserColumns with string rows, a default
    //  selection that never pushes, a drill-out inside the detail stack, and
    //  a removal that falls back to the next row. Preview it in compact and
    //  regular width to feel both column behaviors.
//

    import SwiftUI
    import VivoKit

    struct BrowserColumnsGallery: View {
        @State private var rows = ["Bench Press", "Back Squat", "Deadlift", "Pull-Up"]
        @State private var selection: String?

        var body: some View {
            BrowserColumns(selection: $selection) { navigation in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.self) { row in
                            Button { navigation.open(row) } label: {
                                Text(row)
                                    .font(Typography.headline)
                                    .foregroundStyle(Ink.primary)
                                    .frame(maxWidth: .infinity, minHeight: Space.rowMin, alignment: .leading)
                                    .padding(.horizontal, Space.lg)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .browserRowSelection(navigation.isHighlighted(row))
                        }
                    }
                    .contentCard()
                }
                .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
                .screenBackground()
                .navigationTitle("Browser")
            } detail: { id, navigation in
                if let id {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text(id)
                            .font(Typography.display)
                            .foregroundStyle(Ink.primary)
                        NavigationLink("Instructions") {
                            Text("Instructions for \(id)")
                                .screenBackground()
                        }
                        Button("Remove", role: .destructive) {
                            rows.removeAll { $0 == id }
                            navigation.showList()
                        }
                    }
                    .padding(Space.gutter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .screenBackground()
                    .navigationTitle(id)
                } else {
                    Color.clear.screenBackground()
                }
            }
            .onChange(of: rows, initial: true) { _, rows in
                selection = BrowserSelection.retainOrFirst(
                    selection,
                    isValid: rows.contains,
                    first: rows.first
                )
            }
        }
    }

    #Preview("Browser columns, compact") {
        BrowserColumnsGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Browser columns, regular") {
        BrowserColumnsGallery()
            .environment(\.appDisplayLayout, .regularWide)
            .environment(\.horizontalSizeClass, .regular)
            .preferredColorScheme(.dark)
    }

#endif
