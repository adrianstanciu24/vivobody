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
//  Muscles are coloured by training via a 2-channel + bloom encoding
//  (see `MuscleColor`): development sets lightness, growth momentum
//  sets saturation, and acute fatigue adds a transient emissive glow.
//  The input is a `channels` map keyed by node name (see
//  `MuscleDevelopment`). The skeleton and connective tissue keep their
//  fixed anatomical tones; an empty channels map renders every muscle
//  at the untrained base.
//

import SceneKit
import UIKit

enum BodyModelScene {
    /// Loads the baked geometry, applies materials, and adds the
    /// camera + lights. `channels` maps a mesh's node name to its
    /// development / momentum / fatigue triple; absent nodes render
    /// untrained. Returns nil only if the bundled archive is missing
    /// (a build-packaging error, not a runtime condition).
    static func make(
        channels: [String: MuscleDevelopment.Channels] = [:],
        breathing: Bool = true
    ) -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "BodyModel", withExtension: "scn"),
              let scene = try? SCNScene(url: url) else { return nil }

        if let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) {
            applyMaterials(pivot: pivot, channels: channels)
            if breathing { addBreathing(to: pivot) }
        }
        configureCamera(scene: scene)
        configureLighting(scene: scene)
        return scene
    }

    /// Re-tint an already-built scene's muscles for new training data,
    /// without reloading the 26 MB archive. Used by the SwiftUI
    /// wrapper when the development map changes (e.g. a workout was
    /// just archived).
    static func applyChannels(_ channels: [String: MuscleDevelopment.Channels], to scene: SCNScene) {
        guard let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) else { return }
        applyMaterials(pivot: pivot, channels: channels)
    }

    // MARK: - Idle breathing

    /// A slow, shallow scale pulse on the whole figure so it reads as
    /// alive at rest rather than a frozen mannequin. Uses `scale(by:)`
    /// (multiplicative) so it respects whatever scale the baked archive
    /// already applies to the pivot, and the inhale/exhale are exact
    /// inverses so it never drifts. Independent of the pan gesture,
    /// which only touches the pivot's Y rotation.
    private static func addBreathing(to node: SCNNode) {
        let amount: CGFloat = 1.014
        let inhale = SCNAction.scale(by: amount, duration: 2.0)
        inhale.timingMode = .easeInEaseOut
        let exhale = SCNAction.scale(by: 1.0 / amount, duration: 2.7)
        exhale.timingMode = .easeInEaseOut
        let cycle = SCNAction.sequence([inhale, exhale])
        node.runAction(.repeatForever(cycle), forKey: "breathing")
    }

    // MARK: - Camera

    private static func configureCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 36
        camera.zNear = 0.01
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.9, 3.05)
        cameraNode.look(at: SCNVector3(0, 0.9, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Lighting

    private static func configureLighting(scene: SCNScene) {
        // The rig is deliberately warm. A neutral white key over the
        // gray base meshes read clinical — an anatomy plate, not a
        // living body. A warm key + warm ambient pulls the whole
        // figure toward the app's molten/forge temperature so it feels
        // lit from the same fire as the screen behind it; a faintly
        // cool fill is kept only to preserve cross-form modelling.
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1000
        keyLight.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        keyLight.eulerAngles = SCNVector3(-0.5, 0.5, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 460
        fillLight.light?.color = UIColor(red: 0.86, green: 0.89, blue: 0.96, alpha: 1)
        fillLight.eulerAngles = SCNVector3(-0.2, -0.8, 0)
        scene.rootNode.addChildNode(fillLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        ambient.light?.color = UIColor(red: 0.62, green: 0.56, blue: 0.48, alpha: 1)
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

    /// Peak emission applied at full fatigue. Kept modest so the
    /// "just trained" bloom reads as a warm glow, not a light bulb.
    private static let maxEmission: CGFloat = 0.55

    /// Channels for a muscle that has never been trained — the dark,
    /// desaturated base every untargeted mesh renders at.
    private static let untrainedChannels = MuscleDevelopment.Channels(
        adaptation: 0, momentum: 0, fatigue: 0
    )

    /// Builds a muscle's material from its channels via the perceptual
    /// `MuscleColor` map: development → lightness, momentum → chroma,
    /// fatigue → an emissive bloom. Developed muscle reads a touch
    /// glossier. A fresh material per mesh (≈240) is cheap to rebuild
    /// on each re-tint.
    private static func muscleMaterial(for channels: MuscleDevelopment.Channels) -> SCNMaterial {
        let c = MuscleColor.rgb(for: channels)
        let color = UIColor(red: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue), alpha: 1)

        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = CGFloat(c.emissive) * maxEmission
        mat.roughness.contents = 0.70 - 0.25 * CGFloat(max(0, min(1, channels.adaptation)))
        mat.metalness.contents = 0.12
        mat.lightingModel = .physicallyBased
        return mat
    }

    private static let tissueMaterial = makeTierMaterial(red: 0.70, green: 0.70, blue: 0.70, rough: 0.6)
    private static let boneMaterial = makeTierMaterial(red: 0.85, green: 0.82, blue: 0.75, rough: 0.8)

    private static let connectiveTissue: Set<String> = [
        "Iliotibial_Tract_L", "Iliotibial_Tract_R"
    ]

    private static func applyMaterials(pivot: SCNNode, channels: [String: MuscleDevelopment.Channels]) {
        for child in pivot.childNodes {
            guard let name = child.name else { continue }
            child.opacity = 1
            setMaterial(materialFor(name: name, channels: channels), on: child)
        }
    }

    private static func materialFor(name: String, channels: [String: MuscleDevelopment.Channels]) -> SCNMaterial {
        if name == "Skeleton" { return boneMaterial }
        if connectiveTissue.contains(name) { return tissueMaterial }
        // Every muscle — including untrained ones and the display-only
        // face/hand meshes that no exercise targets — rides the same
        // map, so the body reads uniformly until training data lights
        // specific muscles up.
        return muscleMaterial(for: channels[name] ?? untrainedChannels)
    }

    private static func setMaterial(_ mat: SCNMaterial, on node: SCNNode) {
        if node.geometry != nil { node.geometry?.materials = [mat] }
        node.enumerateChildNodes { child, _ in
            guard child.geometry != nil else { return }
            child.geometry?.materials = [mat]
        }
    }
}
