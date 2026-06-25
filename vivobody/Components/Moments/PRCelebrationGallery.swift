//
//  PRCelebrationGallery.swift
//  vivobody
//
//  A faux "workout complete" surface lives behind the celebration so
//  you can see how the overlay reads against real context. Three
//  trigger buttons cover the common PR shapes: weight, reps, volume.
//

import SwiftUI

struct PRCelebrationGallery: View {
    @State private var showWeightPR: Bool = false
    @State private var showRepsPR: Bool = false
    @State private var showVolumePR: Bool = false

    var body: some View {
        ZStack {
            // Background — looks like a post-workout summary screen
            // so the celebration has something to overlay.
            backdrop

            // Triggers
            VStack(spacing: 14) {
                Spacer()
                triggerButton(label: "Weight PR · 225 lb") {
                    showWeightPR = true
                }
                triggerButton(label: "Rep PR · 12 @ 185 lb") {
                    showRepsPR = true
                }
                triggerButton(label: "Volume PR · 14,250 lb") {
                    showVolumePR = true
                }
                Spacer().frame(height: 36)
            }
            .padding(.horizontal, 22)

            // The celebrations — three instances, only one fires at a time.
            PRCelebration(
                isPresented: $showWeightPR,
                title: "Personal record",
                value: "225",
                unit: "lb",
                detail: "Bench press · 1RM"
            )

            PRCelebration(
                isPresented: $showRepsPR,
                title: "Rep record",
                value: "12",
                unit: "reps",
                detail: "Back squat · 185 lb"
            )

            PRCelebration(
                isPresented: $showVolumePR,
                title: "Volume record",
                value: "14,250",
                unit: "lb",
                detail: "Total · Tuesday session"
            )
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var backdrop: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Header strip
            VStack(alignment: .leading, spacing: 8) {
                Text("PR celebration")
                    .sectionLabelStyle(0.55)
                Text("Earn it, then taste it.")
                    .font(Typography.display)
                    .foregroundStyle(.white)
                Text("Tap a button to fire the moment. Tap anywhere on the celebration to dismiss.")
                    .font(Typography.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)

            // Faux summary stats
            VStack(alignment: .leading, spacing: 14) {
                Text("Tuesday · 47 min · 8 sets")
                    .sectionLabelStyle(0.55)

                HStack(spacing: 18) {
                    statBlock(value: "14,250", unit: "lb", label: "Volume")
                    statBlock(value: "47", unit: "min", label: "Duration")
                    statBlock(value: "3", unit: nil, label: "Exercises")
                }
            }
            .padding(.horizontal, 22)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func statBlock(value: String, unit: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(.white.opacity(0.92))
                if let unit {
                    Text(unit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
            Text(label)
                .sectionLabelStyle(0.55)
        }
    }

    private func triggerButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(.white.opacity(0.90))
                Spacer()
                Image(systemName: "play.fill")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .glassChip(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview("PR Celebration") {
    PRCelebrationGallery()
        .preferredColorScheme(.dark)
}

#Preview("Celebration — solo") {
    @Previewable @State var show = true
    return ZStack {
        Color.black.ignoresSafeArea()
        PRCelebration(
            isPresented: $show,
            title: "Personal record",
            value: "315",
            unit: "lb",
            detail: "Deadlift · 1RM"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Celebration — frozen") {
    ZStack {
        Color.black.ignoresSafeArea()
        PRCelebrationFrozen(
            title: "Personal record",
            value: "225",
            unit: "lb",
            detail: "Bench press · 1RM"
        )
    }
    .preferredColorScheme(.dark)
}
