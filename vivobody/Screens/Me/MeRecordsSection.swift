//
//  MeRecordsSection.swift
//  vivobody
//
//  Standing-record preview rows for Me. The shell supplies the navigable
//  header while this section renders only immutable record presentation.
//

import SwiftUI
import VivoKit

struct MeRecordsSection<Header: View>: View {
    let presentation: MePresentation.Records
    @ViewBuilder let header: () -> Header

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header()

            VStack(spacing: Space.sm) {
                ForEach(presentation.preview) { record in
                    MeRecordRow(presentation: record)
                }
            }
        }
    }
}

private struct MeRecordRow: View {
    let presentation: MePresentation.Record

    var body: some View {
        KitRow(
            title: presentation.name,
            subtitle: presentation.subtitle
        ) {
            HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                if presentation.isRecent {
                    Image(systemName: "sparkles")
                        .font(Typography.caption)
                        .foregroundStyle(Tint.primary)
                }
                Text(presentation.headlineValue)
                    .font(Typography.statValue)
                    .foregroundStyle(
                        presentation.isRecent ? Tint.primary : Ink.primary
                    )
                    .monospacedDigit()
                if let qualifier = presentation.qualifierValue {
                    Text(qualifier)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.tertiary)
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.valueAccessibilityLabel)
        }
    }
}
