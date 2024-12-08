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
        scene.isPaused = true
    }
    
    func closeCurrentOverlay(_ overlay: SKNode) {
        overlay.removeFromParent()
        isShowingOverlay = false
        scene?.isPaused = false
        showNextOverlayIfPossible()
    }
}


// MARK: place with other values at the top of ZPGameScene
// var upgradeShopManager: UpgradeShopManager!
// private var upgradeOverlay: UpgradeShopOverlay?

// MARK: New function for ZPGameScene
//func showUpgradeShopOverlay(with choices: [RegularSkill]) {
//    let upgradeOverlay = UpgradeShopOverlayNode(choices: choices, manager: upgradeShopManager, overlayManager: overlayManager)
//    overlayManager.enqueueOverlay(upgradeOverlay)
//}

// MARK: In ZPGameScene.touchesBegan() ...
// MARK: first move "guard let cameraNode = self.camera else { continue }" ABOVE the "for touch in touches {" line
// MARK: then, place the below code snippet under "guard let cameraNode = self.camera else { continue }"
// MARK: the below code snippet should also be ABOVE "for touch in touches {"
// // If there's currently an overlay shown, we handle touches there
//if let overlay = cameraNode.children.first(where: { $0 is UpgradeShopOverlay || $0 is BossSpinnerOverlay }) {
//    if let spinnerOverlay = overlay as? BossSpinnerOverlay {
//        for touch in touches {
//            let location = touch.location(in: cameraNode)
//            spinnerOverlay.touchBegan(at: location)
//        }
//        return
//    } else if let upgradeOverlay = overlay as? UpgradeShopOverlay {
//        for touch in touches {
//            let location = touch.location(in: cameraNode)
//            upgradeOverlay.touchBegan(at: location)
//        }
//        return
//    }
//}

// MARK: place in ZPGameScene.handleEnemyDefeat()
// MARK: this will launch the shop if it's time
// MARK: be careful with the wave logic, as it will need to pause the game correctly and not mess anything up
// // Right now, this will increment XP each kill, but will be replaced with XP collection
//upgradeShopManager.incrementXPCount()

// MARK: place in ZPGameScene.handleBossDefeat()
// // Create the special skill spinner overlay
//let spinnerOverlay = BossSpinnerOverlay(skillManager: skillManager, overlayManager: overlayManager)
//overlayManager.enqueueOverlay(spinnerOverlay)

// MARK: place in ZPGameScene.didMove() under "SkillManager" line
// upgradeShopManager = UpgradeShopManager(scene: self, skillManager: skillManager)
// overlayManager = OverlayManager(scene: self)

