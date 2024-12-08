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

/// the following is for shop and spinner overlays

// MARK: place with other values at the top of ZPGameScene
//var upgradeShopManager: UpgradeShopManager!
//private var upgradeOverlay: UpgradeShopOverlay?

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
//upgradeShopManager = UpgradeShopManager(scene: self, skillManager: skillManager)
//overlayManager = OverlayManager(scene: self)





/// the following is for XP

// MARK: place with other values at the top of *PlayerState* class
//var currentXP: Int = 0
//var xpPickupRadius: CGFloat = 50.0

// MARK: place with other values at the top of ZPGameScene
//var xpNodes: [XPNode] = []

// MARK: new functions in ZPGameScene
//func spawnXPNode(at position: CGPoint) {
//    let xpNode = XPNode(xpAmount: Int.random(in: 3...10))
//    xpNode.position = position
//    addChild(xpNode)
//    xpNodes.append(xpNode)
//}
//
//func spawnRandomXPNode() {
//    // Spawn a node at a random position within the playable area
//    // Adjust the bounds as necessary; here we use the camera or scene size.
//    let randomX = CGFloat.random(in: -size.width/2...size.width/2) + player.position.x
//    let randomY = CGFloat.random(in: -size.height/2...size.height/2) + player.position.y
//    let randomPosition = CGPoint(x: randomX, y: randomY)
//    spawnXPNode(at: randomPosition)
//}
//
//func checkXPCollection() {
//    for (index, xpNode) in xpNodes.enumerated().reversed() {
//        let distance = player.position.distance(to: xpNode.position)
//        if distance < player.xpPickupRadius {
//            // Player picks up this XP
//            playerState.currentXP += xpNode.xpAmount
//            
//            // Optionally add a sound or animation here
//            
//            xpNode.removeFromParent()
//            xpNodes.remove(at: index)
//        }
//    }
//}

// MARK: take these two lines in check...
//zombie.removeFromParent()
//zombies.remove(at: index)
//handleEnemyDefeat()
//MARK: change them to this:
//let lastHitZombiePosition = zombie.position
//zombie.removeFromParent()
//zombies.remove(at: index)
//handleEnemyDefeat(at: lastHitZombiePosition)
// MARK: Change ZPGameScene "handleEnemyDefeat()" to "handleEnemyDefeat(at lastHitZombiePosition: CGPoint)"
// MARK: place in ZPGameScene.handleEnemyDefeat()
//spawnXPNode(at: lastHitZombiePosition)

// MARK: place in ZPGameScene.didMove()
//let spawnXPAction = SKAction.run { [weak self] in
//    self?.spawnRandomXPNode()
//}
//let waitAction = SKAction.wait(forDuration: 10.0)
//let sequence = SKAction.sequence([spawnXPAction, waitAction])
//let repeatAction = SKAction.repeatForever(sequence)
//run(repeatAction, withKey: "spawnXPForever")

// MARK: place in ZPGameScene.update()
//checkXPCollection()

/// I did not connect the XP with the shops yet
/// Right now, the upgrade shop XP is just based on kills
