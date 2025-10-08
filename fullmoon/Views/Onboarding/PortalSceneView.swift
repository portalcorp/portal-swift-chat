//
//  PortalSceneView.swift
//  fullmoon
//
//  Created by Xavier on 17/12/2024.
//

import ModelIO
import SceneKit
import SceneKit.ModelIO
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class PortalSceneController: ObservableObject {
    let scene: SCNScene
    let cameraNode: SCNNode

    private let modelNode: SCNNode
    @Published private(set) var isReady = false

    private var isUserInteracting = false
    private var spinDuration: TimeInterval = 8
    private var spinDirection: CGFloat = 1

    init() {
        scene = SCNScene()
        modelNode = SCNNode()
        scene.rootNode.addChildNode(modelNode)

        scene.background.contents = PlatformColor.clear

        cameraNode = PortalSceneController.makeCameraNode()
        scene.rootNode.addChildNode(cameraNode)

        addLighting()
        loadPortal()
    }

    func startAnimation(reset: Bool = false) {
        guard !isUserInteracting else { return }
        if !reset, modelNode.action(forKey: "spin") != nil { return }
        modelNode.removeAction(forKey: "spin")
        let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2 * spinDirection, z: 0, duration: spinDuration)
        modelNode.runAction(.repeatForever(rotation), forKey: "spin")
    }

    func stopAnimation() {
        modelNode.removeAction(forKey: "spin")
    }

    func beginUserInteraction() {
        guard isReady, !isUserInteracting else { return }
        isUserInteracting = true
        modelNode.removeAction(forKey: "spin")
    }

    func applyUserRotation(delta: CGSize) {
        guard isReady else { return }
        let sensitivity: Float = 0.008
        modelNode.eulerAngles.y += Float(delta.width) * sensitivity
        var newPitch = modelNode.eulerAngles.x + Float(delta.height) * sensitivity
        let maxPitch = Float.pi / 4
        newPitch = max(-maxPitch, min(maxPitch, newPitch))
        modelNode.eulerAngles.x = newPitch
    }

    func endUserInteraction(predictedVelocity: CGSize) {
        guard isReady else { return }
        let velocity = predictedVelocity.width
        let baseDuration: TimeInterval = 8
        let speedAdjustment = Double(max(-0.6, min(0.6, velocity / 2000)))
        spinDuration = max(3, min(12, baseDuration - (speedAdjustment * baseDuration)))
        spinDirection = velocity < 0 ? -1 : 1
        isUserInteracting = false
        startAnimation(reset: true)
    }

    private func loadPortal() {
        guard let url = Bundle.main.url(forResource: "portal-logo", withExtension: "stl") else {
            #if DEBUG
            print("portal-logo.stl not found in bundle.")
            #endif
            return
        }

        let asset = MDLAsset(url: url)
        let portalScene = SCNScene(mdlAsset: asset)

        for child in portalScene.rootNode.childNodes {
            modelNode.addChildNode(child)
        }

        guard !modelNode.childNodes.isEmpty else { return }

        normalizeModel()
        applyDefaultMaterial(to: modelNode)
        modelNode.eulerAngles = SCNVector3Zero
        isReady = true
    }

    private func normalizeModel() {
        let (minVec, maxVec) = modelNode.boundingBox

        let extent = SCNVector3(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )

        let largestDimension = max(extent.x, max(extent.y, extent.z))

        if largestDimension > 0 {
            let targetSize: Float = 2.0
            let scale = targetSize / largestDimension
            modelNode.scale = SCNVector3(x: scale, y: scale, z: scale)
        }

        let center = SCNVector3(
            (minVec.x + maxVec.x) / 2,
            (minVec.y + maxVec.y) / 2,
            (minVec.z + maxVec.z) / 2
        )

        modelNode.position = SCNVector3(-center.x, -center.y, -center.z)
        modelNode.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)
    }

    private func addLighting() {
        let keyLight = SCNNode()
        let keyLightSource = SCNLight()
        keyLightSource.type = .omni
        keyLightSource.intensity = 1200
        keyLightSource.color = PlatformColor.white
        keyLight.light = keyLightSource
        keyLight.position = SCNVector3(2, 1.5, 3)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        let fillLightSource = SCNLight()
        fillLightSource.type = .omni
        fillLightSource.intensity = 600
        fillLightSource.color = PlatformColor.white
        fillLight.light = fillLightSource
        fillLight.position = SCNVector3(-2, -1.5, 2)
        scene.rootNode.addChildNode(fillLight)

        let ambientNode = SCNNode()
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 200
        ambientLight.color = PlatformColor.white
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }

    private static func makeCameraNode() -> SCNNode {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 6)
        return cameraNode
    }

    private func applyDefaultMaterial(to node: SCNNode) {
        if let geometry = node.geometry {
            var materials = geometry.materials
            if materials.isEmpty {
                materials = [SCNMaterial()]
            }

            for material in materials {
                material.diffuse.contents = primaryPortalColor
                material.emission.contents = secondaryPortalColor.withAlphaComponent(0.15)
                material.specular.contents = PlatformColor.white
                material.lightingModel = .physicallyBased
                material.metalness.contents = 0.25
                material.roughness.contents = 0.35
            }

            geometry.materials = materials
        }

        for child in node.childNodes {
            applyDefaultMaterial(to: child)
        }
    }

    private var primaryPortalColor: PlatformColor {
        #if os(macOS)
        return PlatformColor.systemPurple
        #else
        return PlatformColor.systemPurple
        #endif
    }

    private var secondaryPortalColor: PlatformColor {
        #if os(macOS)
        return PlatformColor.systemBlue
        #else
        return PlatformColor.systemBlue
        #endif
    }
}

struct PortalSceneView: View {
    @StateObject private var controller = PortalSceneController()
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        PortalSceneContainer(controller: controller)
            .opacity(controller.isReady ? 1 : 0)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onAppear { controller.startAnimation() }
            .onDisappear { controller.stopAnimation() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if lastDragTranslation == .zero {
                    controller.beginUserInteraction()
                }
                let delta = CGSize(
                    width: value.translation.width - lastDragTranslation.width,
                    height: value.translation.height - lastDragTranslation.height
                )
                controller.applyUserRotation(delta: delta)
                lastDragTranslation = value.translation
            }
            .onEnded { value in
                controller.endUserInteraction(predictedVelocity: value.predictedEndTranslation)
                lastDragTranslation = .zero
            }
    }
}

#if os(macOS)
private struct PortalSceneContainer: NSViewRepresentable {
    @ObservedObject var controller: PortalSceneController

    func makeNSView(context _: Context) -> SCNView {
        configure(SCNView())
    }

    func updateNSView(_ nsView: SCNView, context _: Context) {
        configure(nsView)
    }

    private func configure(_ view: SCNView) -> SCNView {
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.showsStatistics = false
        view.isPlaying = true
        view.rendersContinuously = true
        return view
    }
}
#else
private struct PortalSceneContainer: UIViewRepresentable {
    @ObservedObject var controller: PortalSceneController

    func makeUIView(context _: Context) -> SCNView {
        configure(SCNView())
    }

    func updateUIView(_ uiView: SCNView, context _: Context) {
        configure(uiView)
    }

    private func configure(_ view: SCNView) -> SCNView {
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.allowsCameraControl = false
        view.showsStatistics = false
        view.isPlaying = true
        view.rendersContinuously = true
        return view
    }
}
#endif

#if os(macOS)
private typealias PlatformColor = NSColor
#else
private typealias PlatformColor = UIColor
#endif
