//
//  BreathingTimerGallery.swift
//  vivobody
//
//  Interactive preview for BreathingTimer.
//  Starts at 30s so you can feel the warning + finish quickly.
//  Pull down to skip, pull up to add 30s, tap reset to start over.
//

import SwiftUI

struct BreathingTimerGallery: View {
    @State private var resetCount: Int = 0
    @State private var duration: TimeInterval = 30

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BreathingTimer(
                duration: duration,
                nextSetLabel: "Set 2 of 5  ·  8 × 145 lb",
                onComplete: { print("complete") },
                onSkip: { print("skip") },
                onExtend: { sec in print("extend +\(Int(sec))s") }
            )
            .id(resetCount)

            VStack(alignment: .trailing, spacing: 8) {
                resetButton
                durationPicker
            }
            .padding(.top, 60)
            .padding(.trailing, 18)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var resetButton: some View {
        Button {
            Haptics.rigid()
            resetCount &+= 1
        } label: {
            Text("Restart")
                .font(Typography.metricUnit)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassPill()
        }
        .buttonStyle(.plain)
    }

    private var durationPicker: some View {
        HStack(spacing: 4) {
            ForEach([15, 30, 60, 90], id: \.self) { secs in
                Button {
                    if duration != TimeInterval(secs) {
                        Haptics.selection()
                        duration = TimeInterval(secs)
                        resetCount &+= 1
                    }
                } label: {
                    Text("\(secs)s")
                        .font(Typography.metricMicro)
                        .foregroundStyle(duration == TimeInterval(secs) ? .black : .white.opacity(0.65))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background {
                            if duration == TimeInterval(secs) {
                                Capsule().fill(Tint.primary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassPill()
    }
}

#Preview("Breathing Timer") {
    BreathingTimerGallery()
}
