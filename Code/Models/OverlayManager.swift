//
//  OverlayManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//

import SpriteKit

// MARK: The purpose of this file is to make sure the special and regular skill overlays work in harmony
class OverlayManager {
    private weak var scene: ZPGameScene?
    private var overlayQueue: [SKNode] = []
    private var isShowingOverlay: Bool = false
    
    init(scene: ZPGameScene) {
        self.scene = scene
    }
    
    func enqueueOverlay(_ overlay: SKNode) {
        overlayQueue.append(overlay)
        showNextOverlayIfPossible()
    }
    
    func showNextOverlayIfPossible() {
        guard !isShowingOverlay, !overlayQueue.isEmpty, let scene = scene, let cameraNode = scene.camera else { return }
        isShowingOverlay = true
        let nextOverlay = overlayQueue.removeFirst()
        cameraNode.addChild(nextOverlay)
        scene.pauseGame()
//        scene.isPaused = true
//        scene.stopXPSpawnTimer()
    }
    
    func closeCurrentOverlay(_ overlay: SKNode) {
        overlay.removeFromParent()
        isShowingOverlay = false
        scene?.unpauseGame()
        //scene?.isPaused = false
        showNextOverlayIfPossible()
        scene?.updateXPBar()
        scene?.updateUpgradeStatsLabel()
        scene?.startXPSpawnTimer()
    }
}
