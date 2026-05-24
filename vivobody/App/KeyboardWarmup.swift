//
//  KeyboardWarmup.swift
//  vivobody
//
//  Workaround for a known iOS bug (first reported 2012, still
//  present in iOS 17/18/26 in 2025): the very first time any
//  UITextField in a process becomes first responder, iOS lazily
//  initializes the entire virtual-keyboard subsystem — text-input
//  services, language model, autocorrect, predictive text, dark-
//  mode keyboard assets. In Release builds this takes ~200ms and is
//  mostly imperceptible. In Debug builds attached to the LLDB
//  debugger it takes 3-5 seconds and freezes the responder chain,
//  surfacing as "Result accumulator timeout" + "Gesture: System
//  gesture gate timed out" in the console while the UI appears
//  hung.
//
//  Workaround: at app launch, briefly bring a throwaway UITextField
//  to first responder and immediately resign + remove it. This
//  forces iOS to wake the keyboard subsystem during launch (where a
//  small invisible cost is fine) instead of during the user's first
//  real interaction with a sheet (where it feels like a bug).
//
//  Reference: https://stackoverflow.com/q/9357026 — top SwiftUI-era
//  answer from 2025 confirms the trick still works on current iOS.
//

import SwiftUI
import UIKit

/// Tracks whether the warmup already ran for this process. Static
/// so it survives view rebuilds without re-running the trick.
private var didWarmUpKeyboard: Bool = false

extension View {
    /// Attach to the app's root view. On first appearance, runs a
    /// one-time keyboard preload. No-op on subsequent appearances
    /// and on every later view in the same process.
    func warmUpKeyboardOnce() -> some View {
        onAppear {
            guard !didWarmUpKeyboard else { return }
            didWarmUpKeyboard = true
            preloadKeyboard()
        }
    }
}

private func preloadKeyboard() {
    guard
        let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first
    else { return }

    let probe = UITextField(frame: .zero)
    probe.isHidden = true
    window.addSubview(probe)
    probe.becomeFirstResponder()
    probe.resignFirstResponder()
    probe.removeFromSuperview()
}
