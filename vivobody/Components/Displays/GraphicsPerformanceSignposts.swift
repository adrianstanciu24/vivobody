//
//  GraphicsPerformanceSignposts.swift
//  vivobody
//
//  Points-of-Interest intervals for profiling the app's continuously
//  rendered graphics and SceneKit setup in Instruments. The fast path is
//  dormant unless a signpost collector is active, so Release/Profile builds
//  exercise the same rendering code without unconditional logging work.
//

import os

nonisolated enum GraphicsPerformanceSignposts {
    private static let signposter = OSSignposter(
        subsystem: "astanciu.vivobody.app",
        category: .pointsOfInterest
    )

    static func begin(_ name: StaticString) -> OSSignpostIntervalState? {
        guard signposter.isEnabled else { return nil }
        return signposter.beginInterval(name, id: signposter.makeSignpostID())
    }

    static func end(
        _ name: StaticString,
        _ state: OSSignpostIntervalState?
    ) {
        guard let state else { return }
        signposter.endInterval(name, state)
    }
}
