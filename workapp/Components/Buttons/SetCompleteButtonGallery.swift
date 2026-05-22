//
//  SetCompleteButtonGallery.swift
//  workapp
//
//  Interactive preview for SetCompleteButton.
//  Five stacked sets — tap each to feel the crescendo + ripple.
//  Haptics fire on device only.
//

import SwiftUI

struct SetCompleteButtonGallery: View {
    @State private var completed: [Bool] = Array(repeating: false, count: 5)

    private let sets: [(reps: Int, weight: Double)] = [
        (8, 135),
        (8, 155),
        (6, 175),
        (5, 185),
        (3, 205),
    ]

    private var doneCount: Int { completed.filter { $0 }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(spacing: 12) {
                    ForEach(0..<sets.count, id: \.self) { i in
                        SetCompleteButton(
                            reps: sets[i].reps,
                            weight: sets[i].weight,
                            isComplete: completed[i],
                            intensity: i == sets.count - 1 ? .peak : .standard,
                            onToggle: { completed[i].toggle() }
                        )
                    }
                }

                resetRow

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SET COMPLETE BUTTON")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Bench press")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    DigitTicker(
                        value: Double(doneCount),
                        font: .system(size: 22, weight: .semibold, design: .rounded),
                        color: .white.opacity(doneCount == sets.count ? 1 : 0.5)
                    )
                    Text("/ \(sets.count)")
                }
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(doneCount == sets.count ? 1 : 0.5))
            }
            Text("Tap a set to complete it. Tap again to undo.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resetRow: some View {
        HStack {
            Spacer()
            Button {
                Haptics.rigid()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    completed = Array(repeating: false, count: sets.count)
                }
            } label: {
                Text("RESET")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 12)
    }
}

#Preview("Set Complete Button") {
    SetCompleteButtonGallery()
        .preferredColorScheme(.dark)
}
