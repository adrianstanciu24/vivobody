//
//  BodyModelSceneTests.swift
//  vivobodyTests
//
//  Guards the render boundary the pure-model tests can't reach: that
//  `BodyModelScene` loads the real bundled archive and tints muscles
//  through the diffuse alone (no shader modifiers), so the archive
//  going missing from the app bundle is caught here.
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

    @Test(arguments: [BodyModelTheme.dark, .light])
    func developmentLivesInTheDiffuseNotAShader(theme: BodyModelTheme) throws {
        let channels: [String: MuscleDevelopment.Channels] = [
            "Pectoralis_Major_L": .init(adaptation: 0.9),
            "Gastrocnemius_L": .init(adaptation: 0.5)
        ]
        let scene = try #require(BodyModelScene.make(channels: channels, theme: theme))

        // A developed muscle is tinted through its diffuse, with no
        // shader modifier layered on top.
        let developed = try #require(material(named: "Pectoralis_Major_L", in: scene))
        #expect(developed.shaderModifiers?[.surface] == nil)
        #expect(developed.diffuse.contents != nil)

        // The skeleton renders its fixed anatomical tone, no shader.
        if let bone = material(named: "Skeleton", in: scene) {
            #expect(bone.shaderModifiers?[.surface] == nil)
        }
    }
}
