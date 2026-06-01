//
//  BodyModelScene.swift
//  vivobody
//
//  Builds the SceneKit scene for the anatomical body model shown as
//  the hero on the Today screen. The geometry ships as a single baked
//  archive — `BodyModel.scn` — assembled from ~240 per-muscle meshes
//  under a node named "bodyPivot" (the rotation anchor). This type
//  loads that archive, then layers on the things that are cheap to
//  keep in code rather than bake into the file: a camera, a 3-light
//  rig, and per-part PBR materials.
//
//  Muscles are coloured by training: each mesh is tinted along a
//  ramp from a dark untrained base to Volt (the app's single accent),
//  driven by an `activations` map keyed by node name (see
//  `MuscleHeatmap`). The skeleton and connective tissue keep their
//  fixed anatomical tones; an empty activations map renders every
//  muscle at the untrained base.
//

import SceneKit
import UIKit

enum BodyModelScene {
    /// Loads the baked geometry, applies materials, and adds the
    /// camera + lights. `activations` maps a mesh's node name to its
    /// training intensity in `0...1`; absent nodes render untrained.
    /// Returns nil only if the bundled archive is missing (a build-
    /// packaging error, not a runtime condition).
    static func make(activations: [String: CGFloat] = [:]) -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "BodyModel", withExtension: "scn"),
              let scene = try? SCNScene(url: url) else { return nil }

        if let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) {
            applyMaterials(pivot: pivot, activations: activations)
        }
        configureCamera(scene: scene)
        configureLighting(scene: scene)
        return scene
    }

    /// Re-tint an already-built scene's muscles for new training data,
    /// without reloading the 26 MB archive. Used by the SwiftUI
    /// wrapper when the all-time heatmap changes (e.g. a workout was
    /// just archived).
    static func applyActivations(_ activations: [String: CGFloat], to scene: SCNScene) {
        guard let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) else { return }
        applyMaterials(pivot: pivot, activations: activations)
    }

    // MARK: - Camera

    private static func configureCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 36
        camera.zNear = 0.01
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.9, 3.35)
        cameraNode.look(at: SCNVector3(0, 0.9, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Lighting

    private static func configureLighting(scene: SCNScene) {
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1000
        keyLight.light?.color = UIColor.white
        keyLight.eulerAngles = SCNVector3(-0.5, 0.5, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 500
        fillLight.light?.color = UIColor(white: 0.9, alpha: 1)
        fillLight.eulerAngles = SCNVector3(-0.2, -0.8, 0)
        scene.rootNode.addChildNode(fillLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        ambient.light?.color = UIColor(white: 0.6, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Materials

    private static func makeTierMaterial(red: CGFloat, green: CGFloat, blue: CGFloat, rough: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        mat.roughness.contents = rough
        mat.metalness.contents = 0.12
        mat.lightingModel = .physicallyBased
        return mat
    }

    /// Endpoints of the muscle ramp. Untrained muscles sit at a dark,
    /// desaturated base so trained ones read as glowing; the hot end
    /// is electric orange — the app's single accent (`Tint.primary`,
    /// RGB 1.0 / 0.45 / 0.0).
    private static let untrainedColor = (r: 0.26, g: 0.245, b: 0.275)
    private static let accentColor    = (r: 1.0, g: 0.45, b: 0.0)

    /// Four discrete training tiers — untrained → light → solid →
    /// hard. The eye can't resolve a fine gradient across separate
    /// muscles on a figure this size; four clear steps read as
    /// categories you can actually compare at a glance. Each tier is
    /// the untrained→accent ramp sampled at a fixed point, with a
    /// touch more gloss as it climbs.
    private static let tierMaterials: [SCNMaterial] = {
        let fractions: [CGFloat] = [0.0, 0.5, 0.78, 1.0]
        return fractions.map { f in
            func lerp(_ a: Double, _ b: Double) -> CGFloat { CGFloat(a + (b - a) * Double(f)) }
            return makeTierMaterial(
                red: lerp(untrainedColor.r, accentColor.r),
                green: lerp(untrainedColor.g, accentColor.g),
                blue: lerp(untrainedColor.b, accentColor.b),
                rough: 0.70 - 0.25 * f
            )
        }
    }()

    /// Maps a `0...1` intensity to one of the four tiers. No logged
    /// work stays at the untrained base; any training lifts a muscle
    /// to at least "light", then bands evenly into "solid" and "hard".
    private static func muscleMaterial(intensity: CGFloat) -> SCNMaterial {
        let t = max(0, min(1, intensity))
        let tier: Int
        switch t {
        case ...0:          tier = 0   // untrained
        case ..<(1.0/3.0):  tier = 1   // light
        case ..<(2.0/3.0):  tier = 2   // solid
        default:            tier = 3   // hard
        }
        return tierMaterials[tier]
    }

    private static let tissueMaterial = makeTierMaterial(red: 0.70, green: 0.70, blue: 0.70, rough: 0.6)
    private static let boneMaterial = makeTierMaterial(red: 0.85, green: 0.82, blue: 0.75, rough: 0.8)

    private static let connectiveTissue: Set<String> = [
        "Iliotibial_Tract_L", "Iliotibial_Tract_R"
    ]

    private static func applyMaterials(pivot: SCNNode, activations: [String: CGFloat]) {
        for child in pivot.childNodes {
            guard let name = child.name else { continue }
            child.opacity = 1
            setMaterial(materialFor(name: name, activations: activations), on: child)
        }
    }

    private static func materialFor(name: String, activations: [String: CGFloat]) -> SCNMaterial {
        if name == "Skeleton" { return boneMaterial }
        if connectiveTissue.contains(name) { return tissueMaterial }
        // Every muscle — including untrained ones and the display-only
        // face/hand meshes that no exercise targets (intensity 0) —
        // rides the same ramp, so the body reads uniformly until
        // training data lights specific muscles up.
        return muscleMaterial(intensity: activations[name] ?? 0)
    }

    private static func setMaterial(_ mat: SCNMaterial, on node: SCNNode) {
        if node.geometry != nil { node.geometry?.materials = [mat] }
        node.enumerateChildNodes { child, _ in
            guard child.geometry != nil else { return }
            child.geometry?.materials = [mat]
        }
    }
}
