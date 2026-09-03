//
//  MeMilestonesSection.swift
//  vivobody
//
//  Lifetime milestone rail driven by ordered immutable milestone items.
//

import SwiftUI
import VivoKit

struct MeMilestonesSection: View {
    let presentation: [MePresentation.MilestoneItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Milestones")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.sm) {
                    ForEach(presentation) { item in
                        MilestoneBadge(
                            milestone: item.milestone,
                            featured: item.featured
                        )
                        .powerOn(item.id)
                    }
                }
            }
        }
    }
}
