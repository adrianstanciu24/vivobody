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
import UIKit
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

        // ...and the diffuse is the EXPECTED developed orange for this
        // theme, not merely some colour: a wrong material assignment
        // (e.g. from a scene-structure change) would otherwise pass.
        let expected = MuscleColor.rgb(for: .init(adaptation: 0.9), theme: theme)
        let color = try #require(developed.diffuse.contents as? UIColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(Double(r) - expected.red) < 0.02)
        #expect(abs(Double(g) - expected.green) < 0.02)
        #expect(abs(Double(b) - expected.blue) < 0.02)

        // The skeleton renders its fixed anatomical tone, no shader.
        if let bone = material(named: "Skeleton", in: scene) {
            #expect(bone.shaderModifiers?[.surface] == nil)
        }
    }

    /// Every mesh name the taxonomy paints (plus the skeleton) must
    /// exist as a real node in the bundled archive, or that muscle
    /// silently renders untrained. Guards the exact-spelling node names
    /// (e.g. Adductor_Mangus, Biceps_femoris) against a future archive
    /// re-export that "corrects" them — the string-shape check in
    /// MuscleMappingTests can't see the archive.
    @Test func everyMappedNodeExistsInArchive() throws {
        let scene = try #require(BodyModelScene.make(theme: .dark))
        let pivot = try #require(
            scene.rootNode.childNode(withName: "bodyPivot", recursively: true)
        )

        var names = Set<String>()
        pivot.enumerateChildNodes { node, _ in
            if let name = node.name { names.insert(name) }
        }

        for muscle in Muscle.allCases {
            for node in muscle.nodeNames {
                #expect(
                    names.contains(node),
                    "BodyModel.scn missing node '\(node)' for \(muscle)"
                )
            }
        }
        #expect(names.contains("Skeleton"))
    }
}
