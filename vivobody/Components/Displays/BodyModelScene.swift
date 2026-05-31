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
//  Materials are intentionally data-agnostic for now (every muscle
//  renders at the same base tier). The muscle-name sets and tiered
//  material ramp below are the seam for a future pass that colours
//  muscles by how much they've been trained.
//

import SceneKit
import UIKit

enum BodyModelScene {
    /// Loads the baked geometry, applies materials, and adds the
    /// camera + lights. Returns nil only if the bundled archive is
    /// missing (a build-packaging error, not a runtime condition).
    static func make() -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "BodyModel", withExtension: "scn"),
              let scene = try? SCNScene(url: url) else { return nil }

        if let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) {
            applyMaterials(pivot: pivot)
        }
        configureCamera(scene: scene)
        configureLighting(scene: scene)
        return scene
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

    /// 5-step activation ramp (untrained → high). Unused tiers are
    /// kept so a later data-driven pass can index into them directly.
    private static let tierMaterials: [SCNMaterial] = [
        makeTierMaterial(red: 0.30, green: 0.18, blue: 0.12, rough: 0.70),
        makeTierMaterial(red: 0.50, green: 0.22, blue: 0.08, rough: 0.65),
        makeTierMaterial(red: 0.70, green: 0.26, blue: 0.04, rough: 0.58),
        makeTierMaterial(red: 0.85, green: 0.30, blue: 0.02, rough: 0.52),
        makeTierMaterial(red: 1.00, green: 0.33, blue: 0.00, rough: 0.45)
    ]

    private static let tissueMaterial = makeTierMaterial(red: 0.70, green: 0.70, blue: 0.70, rough: 0.6)
    private static let boneMaterial = makeTierMaterial(red: 0.85, green: 0.82, blue: 0.75, rough: 0.8)
    private static let muscleBaseMaterial = tierMaterials[0]

    private static let connectiveTissue: Set<String> = [
        "Iliotibial_Tract_L", "Iliotibial_Tract_R"
    ]

    /// Facial / display-only muscles that have no training meaning;
    /// rendered at the brightest tier so the head reads as detailed.
    private static let displayOnlyMuscles: Set<String> = {
        let bases = [
            "Frontalis", "Temporalis", "Masseter", "Buccinator", "Procerus", "Orbicularis_Oculi",
            "Nasalis", "Zygomaticus_Major", "Zygomaticus_Minor", "Levator_Labii_Superioris",
            "Levator_Labii_Superioris_Alaeque_Nasi", "Levator_Anguli_Oris", "Depressor_Anguli_Oris",
            "Depressor_Labii_Inferioris", "Depressor_Supercilii", "Corrugator_Supercilii",
            "Mentalis", "Risorius", "Auricularis_Anterior", "Auricularis_Posterior",
            "Auricularis_Superior", "Auricular_Cartilage", "Lower_Lateral_Cartilage",
            "Upper_Lateral_Cartilage", "Occipitalis", "Eye"
        ]
        return Set(bases.flatMap { ["\($0)_L", "\($0)_R"] } + ["Epicranial_Aponeurosis", "Orbicularis_Oris", "Lips"])
    }()

    private static func applyMaterials(pivot: SCNNode) {
        for child in pivot.childNodes {
            guard let name = child.name else { continue }
            child.opacity = 1
            setMaterial(materialFor(name: name), on: child)
        }
    }

    private static func materialFor(name: String) -> SCNMaterial {
        if name == "Skeleton" { return boneMaterial }
        if connectiveTissue.contains(name) { return tissueMaterial }
        // displayOnlyMuscles (face/ears) render at the base tier too,
        // for a uniform "plain" body until coloring is data-driven.
        return muscleBaseMaterial
    }

    private static func setMaterial(_ mat: SCNMaterial, on node: SCNNode) {
        if node.geometry != nil { node.geometry?.materials = [mat] }
        node.enumerateChildNodes { child, _ in
            guard child.geometry != nil else { return }
            child.geometry?.materials = [mat]
        }
    }
}
