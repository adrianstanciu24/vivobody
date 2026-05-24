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
                triggerButton(label: "WEIGHT PR  ·  225 lb") {
                    showWeightPR = true
                }
                triggerButton(label: "REP PR  ·  12 @ 185 lb") {
                    showRepsPR = true
                }
                triggerButton(label: "VOLUME PR  ·  14,250 lb") {
                    showVolumePR = true
                }
                Spacer().frame(height: 36)
            }
            .padding(.horizontal, 22)

            // The celebrations — three instances, only one fires at a time.
            PRCelebration(
                isPresented: $showWeightPR,
                title: "PERSONAL RECORD",
                value: "225",
                unit: "lb",
                detail: "BENCH PRESS  ·  1RM"
            )

            PRCelebration(
                isPresented: $showRepsPR,
                title: "REP RECORD",
                value: "12",
                unit: "reps",
                detail: "BACK SQUAT  ·  185 lb"
            )

            PRCelebration(
                isPresented: $showVolumePR,
                title: "VOLUME RECORD",
                value: "14,250",
                unit: "lb",
                detail: "TOTAL · TUESDAY SESSION"
            )
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    private var backdrop: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Header strip
            VStack(alignment: .leading, spacing: 8) {
                Text("PR CELEBRATION")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
                Text("Earn it, then taste it.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("Tap a button to fire the moment. Tap anywhere on the celebration to dismiss.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)

            // Faux summary stats
            VStack(alignment: .leading, spacing: 14) {
                Text("TUESDAY  ·  47 MIN  ·  8 SETS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 18) {
                    statBlock(value: "14,250", unit: "lb", label: "VOLUME")
                    statBlock(value: "47", unit: "min", label: "DURATION")
                    statBlock(value: "3", unit: nil, label: "EXERCISES")
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
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func triggerButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
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
            title: "PERSONAL RECORD",
            value: "315",
            unit: "lb",
            detail: "DEADLIFT  ·  1RM"
        )
    }
    .preferredColorScheme(.dark)
}
