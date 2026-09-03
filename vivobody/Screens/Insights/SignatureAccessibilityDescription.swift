//
//  SignatureAccessibilityDescription.swift
//  vivobody
//
//  Adapts a Training Signature into the exact spoken equivalent of the
//  Canvas instrument. A pure input keeps empty, populated, and defensive
//  no-volume wording deterministic without coupling semantics to drawing.
//

import VivoKit

nonisolated struct SignatureAccessibilityInput: Equatable {
    let hasSignature: Bool
    let hasVolume: Bool
    let volumeSplit: String
    let balancePercent: Int
    let trainedGroupCount: Int
    let identityLine: String
}

enum SignatureAccessibilityDescription {
    static func input(for signature: TrainingSignature) -> SignatureAccessibilityInput {
        SignatureAccessibilityInput(
            hasSignature: signature.hasSignature,
            hasVolume: signature.hasVolume,
            volumeSplit: signature.petals
                .filter { $0.volumeShare > 0 }
                .map {
                    "\($0.group.displayName) \(signatureShareSpokenLabel($0.volumeShare))"
                }
                .joined(separator: ", "),
            balancePercent: Int((signature.balance * 100).rounded()),
            trainedGroupCount: signature.trainedGroupCount,
            identityLine: signature.identityLine
        )
    }

    static func text(for signature: TrainingSignature) -> String {
        text(for: input(for: signature))
    }

    static func text(for input: SignatureAccessibilityInput) -> String {
        let volume = if !input.hasSignature {
            "No signature data yet. Complete a strength set on an exercise with muscle targets to begin."
        } else if input.hasVolume {
            "All-time volume split: \(input.volumeSplit). Balance \(input.balancePercent) percent, with \(input.trainedGroupCount) of 6 regions represented."
        } else {
            "No completed muscle-targeted strength work yet."
        }
        return "Training signature. \(volume) \(input.identityLine). Dashed outlines show an even six-way split."
    }
}
