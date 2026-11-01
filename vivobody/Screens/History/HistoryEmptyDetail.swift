//
//  HistoryEmptyDetail.swift
//  vivobody
//
//  The detail column of an empty History on a wide window. With no workout
//  to select, it shows the shape of a receipt as a redacted outline, so the
//  column says what History will hold without inventing numbers, and puts
//  the start action beneath it. HistoryContent presents the start flow, so
//  the start stays on History.
//

import SwiftUI
import VivoKit

struct HistoryEmptyDetail: View {
    var appState: AppState
    /// True while no saved template turns the start into a choice.
    let startsFreshDirectly: Bool
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                intro
                sampleReceipt
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            startBar
        }
        .screenBackground()
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Your first receipt")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Text("Each finished workout keeps its volume, time, sets, and every exercise here.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The hero card and two exercise cards of a session receipt, redacted.
    /// The strings only size the placeholder bars; none of them is shown.
    private var sampleReceipt: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Monday · Nov 2 · 18:30")
                        .panelLegendType()
                    Text("Full body")
                        .font(Typography.title)
                }
                Text("12,450 lb")
                    .font(Typography.metricLg)
                StatStrip(
                    stats: [
                        Stat(value: "54", unit: "min", label: "Duration"),
                        Stat(value: "18", label: "Sets"),
                        Stat(value: "142", label: "Reps"),
                    ],
                    edgeAligned: true
                )
            }
            .padding(Space.lg)
            .contentCard()

            ForEach(["Barbell Back Squat", "Bench Press"], id: \.self) { name in
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("Legs · 4,200 lb")
                        .font(Typography.caption)
                    Text(name)
                        .font(Typography.headline)
                    Text("135 lb × 8")
                        .font(Typography.metricInline)
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentCard()
            }
        }
        .foregroundStyle(Ink.primary)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample workout receipt")
        .accessibilityIdentifier("historySampleReceipt")
    }

    /// A draft waiting for the workout to dismiss is already gone, as on
    /// Today's start bar.
    private var activeSession: WorkoutSession? {
        appState.workout.isDiscardPending ? nil : appState.workout.activeSession
    }

    private var startBar: some View {
        Group {
            if activeSession != nil {
                PrimaryActionButton(
                    title: "Resume Workout",
                    icon: "chevron.up",
                    inputLabels: ["Resume Workout", "Resume", "Workout"]
                ) {
                    appState.workout.expandWorkout()
                }
                .accessibilityHint("Opens the workout you have in progress")
            } else {
                PrimaryActionButton(
                    title: startsFreshDirectly ? "Start Fresh Workout" : "Start Workout",
                    icon: startsFreshDirectly ? "plus" : "chevron.up",
                    inputLabels: startsFreshDirectly
                        ? ["Start Fresh Workout", "Start Fresh", "New Workout"]
                        : ["Start Workout", "Start", "Begin"],
                    sound: .commit
                ) {
                    onStart()
                }
                .accessibilityHint(
                    startsFreshDirectly
                        ? "Opens the exercise picker for a fresh workout"
                        : "Opens workout options"
                )
            }
        }
        .accessibilityIdentifier("historyEmptyStartButton")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
    }
}
