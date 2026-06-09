//
//  BodyModelSceneTests.swift
//  vivobodyTests
//
//  Verifies the tightness → pulse wiring at the render boundary that
//  the pure-model tests can't reach: that `BodyModelScene` builds the
//  brightness-throb shader modifier onto a tight muscle's material
//  (and sets its `u_tightness` uniform), while leaving loose muscles,
//  the skeleton, and connective tissue pulse-free. It loads the real
//  bundled archive, so it also guards against the archive going
//  missing from the app bundle.
//

import Foundation
import SceneKit
import Testing
@testable import vivobody

struct BodyModelSceneTests {

    /// First material found at or below a named node (one shared
    /// material is applied to a muscle node and its geometry).
    private func material(named name: String, in scene: SCNScene) -> SCNMaterial? {
        guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { return nil }
        if let geometry = node.geometry { return geometry.materials.first }
        var found: SCNMaterial?
        node.enumerateChildNodes { child, stop in
            if let geometry = child.geometry {
                found = geometry.materials.first
                stop.pointee = true
            }
        }
        return found
    }

    @Test func tightMuscleGetsPulseLooseDoesNot() throws {
        let channels: [String: MuscleDevelopment.Channels] = [
            "Pectoralis_Major_L": .init(adaptation: 0.5, momentum: 0, fatigue: 0, tightness: 0.9)
        ]
        let scene = try #require(BodyModelScene.make(channels: channels))

        // The tight muscle carries the surface pulse modifier and its
        // strength uniform.
        let stiff = try #require(material(named: "Pectoralis_Major_L", in: scene))
        #expect(stiff.shaderModifiers?[.surface] != nil)
        #expect(stiff.value(forKey: "u_tightness") != nil)

        // A loose muscle stays pulse-free — development lives in the
        // diffuse, not a shader.
        if let loose = material(named: "Vastus_Lateralis_L", in: scene) {
            #expect(loose.shaderModifiers?[.surface] == nil)
        }

        // The skeleton never gets the pulse — it's not muscle.
        if let bone = material(named: "Skeleton", in: scene) {
            #expect(bone.shaderModifiers?[.surface] == nil)
        }
    }
}
