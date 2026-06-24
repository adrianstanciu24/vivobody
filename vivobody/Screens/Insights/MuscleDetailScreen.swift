//
//  MuscleDetailScreen.swift
//  vivobody
//
//  The full per-muscle breakdown, pushed from the "Train next"
//  section's "Show all muscles." It's the reference view the triage
//  list summarises: the complete Muscle Balance roster, the Momentum
//  buckets, and the detraining Forecast — the three original
//  instruments, kept intact but moved off the main Insights scroll so
//  the tab leads with the verdict instead of the raw data.
//
//  It takes the already-computed value-type boards rather than
//  re-deriving them, so the numbers here always match the list that
//  led the user in.
//

import SwiftUI

struct MuscleDetailScreen: View {
    let stats: [MuscleVolumeStat]
    let momentum: MuscleMomentumBoard
    let forecast: MuscleForecastBoard

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                MuscleBalanceSection(stats: stats)
                groupSeparator
                MomentumSection(board: momentum)
                groupSeparator
                ForecastSection(board: forecast)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("All muscles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupSeparator: some View {
        SectionDivider()
            .padding(.vertical, Space.xl)
    }
}
