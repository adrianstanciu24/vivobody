//
//  replace-body-model-regions.swift
//  vivobody asset tooling
//
//  Replaces a bilateral aggregate geometry pair in BodyModel.scn with
//  independently exported anatomical regions. The rest of the SceneKit
//  graph is preserved, and the written archive is reloaded before success
//  is reported so missing nodes or materially changed bounds fail fast.
//
//  Example:
//    xcrun swift Scripts/replace-body-model-regions.swift \
//      BodyModel.scn obj-directory BodyModel.updated.scn \
//      Trapezius Upper,Middle,Lower
//

import Foundation
import SceneKit

private enum ReplacementError: Error, CustomStringConvertible {
    case usage
    case invalidRegions
    case missingNode(String)
    case missingGeometry(URL)
    case missingParent(String)
    case unexpectedParent(node: String, parent: String?)
    case boundsChanged(side: String, old: SCNBoundingVolume, new: SCNBoundingVolume)
    case writeFailed(URL)
    case validationFailed(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: xcrun swift Scripts/replace-body-model-regions.swift <source.scn> <obj-directory> <output.scn> <base-name> <comma-separated-regions>"
        case .invalidRegions:
            return "Provide at least two non-empty region names."
        case let .missingNode(name):
            return "Scene is missing required node '\(name)'."
        case let .missingGeometry(url):
            return "OBJ contains no geometry: \(url.path)"
        case let .missingParent(name):
            return "Node '\(name)' has no parent."
        case let .unexpectedParent(node, parent):
            return "Node '\(node)' must be directly under bodyPivot; found \(parent ?? "no parent")."
        case let .boundsChanged(side, old, new):
            return "Replacement changed \(side) bounds too much. Old: \(old), new: \(new)."
        case let .writeFailed(url):
            return "SceneKit could not write \(url.path)."
        case let .validationFailed(message):
            return "Written archive validation failed: \(message)"
        }
    }
}

private struct SCNBoundingVolume: CustomStringConvertible {
    var min: SCNVector3
    var max: SCNVector3

    var description: String {
        "min=(\(min.x), \(min.y), \(min.z)) max=(\(max.x), \(max.y), \(max.z))"
    }

    func includes(_ other: SCNBoundingVolume) -> SCNBoundingVolume {
        SCNBoundingVolume(
            min: SCNVector3(
                Swift.min(min.x, other.min.x),
                Swift.min(min.y, other.min.y),
                Swift.min(min.z, other.min.z)
            ),
            max: SCNVector3(
                Swift.max(max.x, other.max.x),
                Swift.max(max.y, other.max.y),
                Swift.max(max.z, other.max.z)
            )
        )
    }

    func approximatelyEquals(_ other: SCNBoundingVolume, tolerance: CGFloat) -> Bool {
        let minXMatches = Swift.abs(min.x - other.min.x) <= tolerance
        let minYMatches = Swift.abs(min.y - other.min.y) <= tolerance
        let minZMatches = Swift.abs(min.z - other.min.z) <= tolerance
        let maxXMatches = Swift.abs(max.x - other.max.x) <= tolerance
        let maxYMatches = Swift.abs(max.y - other.max.y) <= tolerance
        let maxZMatches = Swift.abs(max.z - other.max.z) <= tolerance
        return minXMatches && minYMatches && minZMatches
            && maxXMatches && maxYMatches && maxZMatches
    }
}

private let sides = ["L", "R"]
private let boundsTolerance: CGFloat = 0.001

private func geometryNode(in scene: SCNScene) -> SCNNode? {
    var result: SCNNode?
    scene.rootNode.enumerateChildNodes { node, stop in
        guard node.geometry != nil else { return }
        result = node
        stop.pointee = true
    }
    return result
}

private func geometryNodeCount(in scene: SCNScene) -> Int {
    var count = 0
    scene.rootNode.enumerateChildNodes { node, _ in
        if node.geometry != nil { count += 1 }
    }
    return count
}

private func bounds(of node: SCNNode) -> SCNBoundingVolume {
    let box = node.boundingBox
    return SCNBoundingVolume(min: box.min, max: box.max)
}

private func copiedMaterials(from node: SCNNode) -> [SCNMaterial] {
    node.geometry?.materials.map { material in
        (material.copy() as? SCNMaterial) ?? material
    } ?? []
}

private func run() throws {
    guard CommandLine.arguments.count == 6 else { throw ReplacementError.usage }

    let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let objectDirectoryURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
    let baseName = CommandLine.arguments[4]
    let regions = CommandLine.arguments[5]
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard regions.count >= 2 else { throw ReplacementError.invalidRegions }

    let scene = try SCNScene(url: sourceURL)
    let originalGeometryCount = geometryNodeCount(in: scene)

    for side in sides {
        let oldName = "\(baseName)_\(side)"
        guard let oldNode = scene.rootNode.childNode(withName: oldName, recursively: true) else {
            throw ReplacementError.missingNode(oldName)
        }
        guard let parent = oldNode.parent else {
            throw ReplacementError.missingParent(oldName)
        }
        guard parent.name == "bodyPivot" else {
            throw ReplacementError.unexpectedParent(node: oldName, parent: parent.name)
        }

        let originalBounds = bounds(of: oldNode)
        let insertionIndex = parent.childNodes.firstIndex(of: oldNode) ?? parent.childNodes.count
        let materials = copiedMaterials(from: oldNode)
        var replacements: [SCNNode] = []
        var replacementBounds: SCNBoundingVolume?

        for region in regions {
            let name = "\(baseName)_\(region)_\(side)"
            let objectURL = objectDirectoryURL.appendingPathComponent("\(name).obj")
            let objectScene = try SCNScene(url: objectURL)
            guard let exportedNode = geometryNode(in: objectScene),
                  let geometry = exportedNode.geometry else {
                throw ReplacementError.missingGeometry(objectURL)
            }

            let node = oldNode.clone()
            node.childNodes.forEach { $0.removeFromParentNode() }
            node.name = name
            node.geometry = geometry
            node.geometry?.name = "\(name)_Geometry"
            node.geometry?.materials = materials.map { material in
                (material.copy() as? SCNMaterial) ?? material
            }
            replacements.append(node)

            let nodeBounds = bounds(of: node)
            replacementBounds = replacementBounds?.includes(nodeBounds) ?? nodeBounds
        }

        guard let replacementBounds,
              originalBounds.approximatelyEquals(replacementBounds, tolerance: boundsTolerance) else {
            throw ReplacementError.boundsChanged(
                side: side,
                old: originalBounds,
                new: replacementBounds ?? originalBounds
            )
        }

        oldNode.removeFromParentNode()
        for (offset, node) in replacements.enumerated() {
            parent.insertChildNode(node, at: insertionIndex + offset)
        }
    }

    let expectedGeometryCount = originalGeometryCount + sides.count * (regions.count - 1)
    guard geometryNodeCount(in: scene) == expectedGeometryCount else {
        throw ReplacementError.validationFailed("unexpected in-memory geometry-node count")
    }

    let wrote = scene.write(
        to: outputURL,
        options: nil,
        delegate: nil,
        progressHandler: nil
    )
    guard wrote else { throw ReplacementError.writeFailed(outputURL) }

    let writtenScene = try SCNScene(url: outputURL)
    guard geometryNodeCount(in: writtenScene) == expectedGeometryCount else {
        throw ReplacementError.validationFailed("unexpected reloaded geometry-node count")
    }
    for side in sides {
        guard writtenScene.rootNode.childNode(
            withName: "\(baseName)_\(side)",
            recursively: true
        ) == nil else {
            throw ReplacementError.validationFailed("legacy \(baseName)_\(side) node remains")
        }
        for region in regions {
            let name = "\(baseName)_\(region)_\(side)"
            guard writtenScene.rootNode.childNode(withName: name, recursively: true)?.geometry != nil else {
                throw ReplacementError.validationFailed("missing replacement node \(name)")
            }
        }
    }

    print("Wrote \(outputURL.path)")
    print("Replaced \(baseName) with regions: \(regions.joined(separator: ", "))")
    print("Geometry nodes: \(originalGeometryCount) -> \(expectedGeometryCount)")
}

do {
    try run()
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
