//
//  OneRepMaxEditorSheet.swift
//  vivobody
//
//  Small sheet for entering a measured one-rep max. Opens seeded on
//  the current value (measured / estimated / heaviest set), scrubs in
//  the user's unit via `WeightScrubber`, and saves a canonical-lb
//  value. The secondary action clears the measured max (passing nil)
//  — it only appears when one is set, and reads "Use estimate
//  instead" when there's an estimate to fall back to, otherwise
//  "Remove measured max" (which returns the row to empty).
//

import VivoKit
import SwiftUI

struct OneRepMaxEditorSheet: View {
    let initialValue: Double
    let hasMeasured: Bool
    let hasEstimate: Bool
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Double

    init(
        initialValue: Double,
        hasMeasured: Bool,
        hasEstimate: Bool,
        onSave: @escaping (Double?) -> Void
    ) {
        self.initialValue = initialValue
        self.hasMeasured = hasMeasured
        self.hasEstimate = hasEstimate
        self.onSave = onSave
        _draft = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.lg) {
                Text("Enter your tested one-rep max. A measured max is more accurate than the estimate from your logged sets.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.lg)

                WeightScrubber(canonicalWeight: $draft, purpose: .strength, label: "One-rep max")

                if hasMeasured {
                    Button {
                        Haptics.soft()
                        onSave(nil)
                        dismiss()
                    } label: {
                        Text(hasEstimate ? "Use estimate instead" : "Remove measured max")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.secondary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Surface.background.ignoresSafeArea())
            .navigationTitle("One-Rep Max")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.soft()
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .presentationDetents([.medium])
        }
    }
}
