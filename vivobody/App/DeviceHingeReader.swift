//
//  DeviceHingeReader.swift
//  vivobody
//
//  Reports whether the window's hierarchy receives hinge updates, which a
//  foldable iPhone provides in every pose, folded or open. AppRoot uses it
//  to keep one workout presentation through a fold or an unfold, because
//  iOS cannot turn a sheet into a full-window cover while it is on screen.
//

import SwiftUI
import UIKit

extension View {
    /// Writes whether this view's window reports a hinge to `hasHinge`.
    /// Systems before iOS 27.1 never report one.
    func readsDeviceHinge(into hasHinge: Binding<Bool>) -> some View {
        background {
            if #available(iOS 27.1, *) {
                DeviceHingeReader(hasHinge: hasHinge)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
    }
}

@available(iOS 27.1, *)
private struct DeviceHingeReader: UIViewRepresentable {
    @Binding var hasHinge: Bool

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        let hasHinge = $hasHinge
        view.addInteraction(UIHingeInteraction { _, update in
            let reportsHinge = update.hinge != nil
            if hasHinge.wrappedValue != reportsHinge {
                hasHinge.wrappedValue = reportsHinge
            }
        })
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}
}
