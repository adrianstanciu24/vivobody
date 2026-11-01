//
//  LibraryTemplatesEmptyDetail.swift
//  vivobody
//
//  The detail column of an empty Templates segment on a wide window. With no
//  template to select, it shows the shape of two template cards as a redacted
//  outline, so the column says what a template holds without inventing a
//  plan, and puts the create action beneath it.
//

import SwiftUI
import VivoKit

struct LibraryTemplatesEmptyDetail: View {
    let onCreate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                intro
                sampleTemplates
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            createBar
        }
        .screenBackground()
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Your first template")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Text("Save a workout you repeat, with its exercises and sets. Pin it to weekdays and Today shows it, ready to start.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The strings and counts only size the placeholder; none of them is shown.
    /// Grayscale keeps the schedule dots from reading as today's orange.
    private var sampleTemplates: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sampleCard(
                name: "Upper A",
                exercises: "Bench Press · Barbell Row · Overhead Press  +2",
                setGroups: [3, 3, 3, 2, 2],
                weekdays: [2, 5]
            )
            sampleCard(
                name: "Lower A",
                exercises: "Back Squat · Romanian Deadlift · Leg Press",
                setGroups: [4, 3, 3],
                weekdays: [3, 6]
            )
        }
        .foregroundStyle(Ink.primary)
        .redacted(reason: .placeholder)
        .grayscale(1)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample templates")
        .accessibilityIdentifier("librarySampleTemplates")
    }

    private func sampleCard(
        name: String,
        exercises: String,
        setGroups: [Int],
        weekdays: Set<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(Typography.sectionHeading)
            Text(exercises)
                .font(Typography.caption)
                .lineLimit(1)
            HStack(alignment: .center, spacing: Space.sm + 2) {
                SetPipStrip(groups: setGroups, tint: Ink.tertiary)
                Text("\(setGroups.reduce(0, +)) sets")
                    .font(Typography.metricInline)
            }
            .padding(.top, Space.sm)
            ScheduleStrip(scheduled: weekdays, today: 0)
                .padding(.top, Space.xs + 2)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var createBar: some View {
        PrimaryActionButton(
            title: "Create Template",
            icon: "plus",
            inputLabels: ["Create Template", "New Template", "Create"],
            sound: .click
        ) {
            onCreate()
        }
        .accessibilityHint("Opens the template builder")
        .accessibilityIdentifier("libraryEmptyCreateTemplateButton")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
    }
}

#Preview {
    LibraryTemplatesEmptyDetail {}
        .preferredColorScheme(.dark)
}
