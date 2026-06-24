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
//  Muscles are coloured by training (see `MuscleColor`): development
//  sets the diffuse — a tint ramp from the theme's untrained base to
//  a vivid, saturated orange. The input is a `channels` map keyed by
//  node name (see `MuscleDevelopment`). The skeleton and connective
//  tissue keep fixed anatomical tones per theme; an empty channels map
//  renders every muscle at the untrained base.
//
//  Everything is themed (see `BodyModelTheme`): on the dark stage the
//  figure separates by being LIGHTER than black — bright rim lights
//  carving the silhouette, a flush that glows hotter. On the light
//  page it separates by being DARKER than the page — deeper tones,
//  rims dialled way down (bright edges would erase the silhouette
//  into the page), and a flush that deepens to a burnt ember.
//

import SceneKit
import UIKit

enum BodyModelScene {
    /// Loads the baked geometry, applies themed materials + lights,
    /// and adds the camera. `channels` maps a mesh's node name to its
    /// development channels; absent nodes render untrained. Returns nil
    /// only if the bundled archive is missing
    /// (a build-packaging error, not a runtime condition).
    static func make(
        channels: [String: MuscleDevelopment.Channels] = [:],
        theme: BodyModelTheme
    ) -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "BodyModel", withExtension: "scn"),
              let scene = try? SCNScene(url: url) else { return nil }

        apply(channels: channels, theme: theme, to: scene)
        configureCamera(scene: scene)
        return scene
    }

    /// Re-tint an already-built scene's muscles + light rig for new
    /// training data or a colour-scheme flip, without reloading the
    /// 26 MB archive. Used by the SwiftUI wrapper when the development
    /// map or the resolved appearance changes.
    static func apply(
        channels: [String: MuscleDevelopment.Channels],
        theme: BodyModelTheme,
        to scene: SCNScene
    ) {
        if let pivot = scene.rootNode.childNode(withName: "bodyPivot", recursively: true) {
            applyMaterials(pivot: pivot, channels: channels, theme: theme)
        }
        configureLighting(scene: scene, theme: theme)
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

    /// The whole rig lives under one named container so a theme flip
    /// can swap it atomically.
    private static let lightRigName = "lightRig"

    private static func configureLighting(scene: SCNScene, theme: BodyModelTheme) {
        scene.rootNode.childNode(withName: lightRigName, recursively: false)?
            .removeFromParentNode()

        let rig = SCNNode()
        rig.name = lightRigName

        // The rig is deliberately warm. A neutral white key over the
        // gray base meshes read clinical — an anatomy plate, not a
        // living body. A warm key + warm ambient pulls the whole
        // figure toward the app's molten/forge temperature so it feels
        // lit from the same fire as the screen behind it; a faintly
        // cool fill is kept only to preserve cross-form modelling.
        //
        // Per theme: the dark stage runs the key warmer and the rims
        // hot, carving the silhouette out of black. The light page
        // cools the key a touch (the forge wash already heats the
        // scene), neutralises the ambient so shadows read gray-warm
        // rather than muddy, and drops the rims to a whisper — bright
        // edges separate a figure from black but erase it into a
        // near-white page; there, separation comes from the figure
        // being darker than the page.
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = theme == .dark ? 1000 : 900
        keyLight.light?.color = theme == .dark
            ? UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
            : UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1)
        keyLight.eulerAngles = SCNVector3(-0.5, 0.5, 0)
        rig.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = theme == .dark ? 460 : 420
        fillLight.light?.color = theme == .dark
            ? UIColor(red: 0.86, green: 0.89, blue: 0.96, alpha: 1)
            : UIColor(red: 0.88, green: 0.90, blue: 0.95, alpha: 1)
        fillLight.eulerAngles = SCNVector3(-0.2, -0.8, 0)
        rig.addChildNode(fillLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = theme == .dark ? 300 : 340
        ambient.light?.color = theme == .dark
            ? UIColor(red: 0.62, green: 0.56, blue: 0.48, alpha: 1)
            : UIColor(red: 0.62, green: 0.59, blue: 0.55, alpha: 1)
        rig.addChildNode(ambient)

        // Grazing rim lights placed behind the figure. One cool, one
        // warm for depth. Strong on the dark stage (they carve the
        // silhouette); faint on the light page (they'd erase it).
        let rimIntensity: CGFloat = theme == .dark ? 1800 : 650

        let leftRim = SCNNode()
        leftRim.light = SCNLight()
        leftRim.light?.type = .directional
        leftRim.light?.intensity = rimIntensity
        leftRim.light?.color = UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1)
        leftRim.eulerAngles = SCNVector3(-0.2, -2.6, 0)
        rig.addChildNode(leftRim)

        let rightRim = SCNNode()
        rightRim.light = SCNLight()
        rightRim.light?.type = .directional
        rightRim.light?.intensity = rimIntensity
        rightRim.light?.color = UIColor(red: 1.0, green: 0.92, blue: 0.85, alpha: 1)
        rightRim.eulerAngles = SCNVector3(-0.2, 2.6, 0)
        rig.addChildNode(rightRim)

        scene.rootNode.addChildNode(rig)
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

    /// Channels for a muscle that has never been trained — the dark,
    /// desaturated base every untargeted mesh renders at.
    private static let untrainedChannels = MuscleDevelopment.Channels(adaptation: 0)

    /// Builds a muscle's material from its channels via the
    /// `MuscleColor` map: development sets the diffuse (untrained
    /// base → vivid orange on the theme's ramp). Developed muscle reads
    /// a touch glossier. A fresh material per mesh (≈240) is cheap to
    /// rebuild on each re-tint.
    private static func muscleMaterial(
        for channels: MuscleDevelopment.Channels,
        theme: BodyModelTheme
    ) -> SCNMaterial {
        let c = MuscleColor.rgb(for: channels, theme: theme)
        let color = UIColor(red: CGFloat(c.red), green: CGFloat(c.green), blue: CGFloat(c.blue), alpha: 1)

        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.roughness.contents = 0.70 - 0.25 * CGFloat(max(0, min(1, channels.adaptation)))
        mat.metalness.contents = 0.12
        mat.lightingModel = .physicallyBased
        return mat
    }

    /// Fixed anatomical tones, one step darker on the light page so
    /// bone and tendon stay below the page's luminance — at the dark
    /// values' brightness they'd vanish into near-white.
    private static func tissueMaterial(for theme: BodyModelTheme) -> SCNMaterial {
        theme == .dark
            ? makeTierMaterial(red: 0.70, green: 0.70, blue: 0.70, rough: 0.6)
            : makeTierMaterial(red: 0.56, green: 0.56, blue: 0.56, rough: 0.6)
    }

    private static func boneMaterial(for theme: BodyModelTheme) -> SCNMaterial {
        theme == .dark
            ? makeTierMaterial(red: 0.85, green: 0.82, blue: 0.75, rough: 0.8)
            : makeTierMaterial(red: 0.72, green: 0.68, blue: 0.61, rough: 0.8)
    }

    private static let connectiveTissue: Set<String> = [
        "Iliotibial_Tract_L", "Iliotibial_Tract_R"
    ]

    private static func applyMaterials(
        pivot: SCNNode,
        channels: [String: MuscleDevelopment.Channels],
        theme: BodyModelTheme
    ) {
        let bone = boneMaterial(for: theme)
        let tissue = tissueMaterial(for: theme)
        for child in pivot.childNodes {
            guard let name = child.name else { continue }
            child.opacity = 1
            setMaterial(
                materialFor(
                    name: name, channels: channels, theme: theme,
                    bone: bone, tissue: tissue
                ),
                on: child
            )
        }
    }

    private static func materialFor(
        name: String,
        channels: [String: MuscleDevelopment.Channels],
        theme: BodyModelTheme,
        bone: SCNMaterial,
        tissue: SCNMaterial
    ) -> SCNMaterial {
        if name == "Skeleton" { return bone }
        if connectiveTissue.contains(name) { return tissue }
        // Every muscle — including untrained ones and the display-only
        // face/hand meshes that no exercise targets — rides the same
        // map, so the body reads uniformly until training data lights
        // specific muscles up.
        return muscleMaterial(
            for: channels[name] ?? untrainedChannels,
            theme: theme
        )
    }

    private static func setMaterial(_ mat: SCNMaterial, on node: SCNNode) {
        if node.geometry != nil { node.geometry?.materials = [mat] }
        node.enumerateChildNodes { child, _ in
            guard child.geometry != nil else { return }
            child.geometry?.materials = [mat]
        }
    }
}
