//
//  UpgradeShopManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import Foundation

class UpgradeShopManager {
    private var XPCount: Int = 0
    private var nextShopXPThreshold: Int = 5
    private weak var scene: ZPGameScene?
    private var skillManager: SkillManager
    
    init(scene: ZPGameScene, skillManager: SkillManager) {
        self.scene = scene
        self.skillManager = skillManager
    }
    
    func incrementXPCount() {
        XPCount += 1
        checkForShop()
    }
    
    private func checkForShop() {
        guard XPCount >= nextShopXPThreshold, let scene = scene else { return }
        
        // this is the swift native way to pause node actions, I don't think it'll be enough, we will
        // probably need a custom pause method to handle everything getting paused
        scene.isPaused = true

        let choices = skillManager.getRandomRegularChoices()
        
        // MARK: Uncomment this when scene is implemented
//        scene.showUpgradeShopOverlay(with: choices)
    }
    
    func playerDidSelectSkill(_ skill: RegularSkill) {
        skillManager.acquireOrUpgradeRegularSkill(skill)
        
        // Again, we will probably need to hard code a pause/resume to handle everything
        scene?.isPaused = false
        
        nextShopXPThreshold += 1
    }
}



// MARK: place with other values at the top of ZPGameScene
// var upgradeShopManager: UpgradeShopManager!
// private var upgradeOverlay: UpgradeShopOverlay?


// MARK: New function for ZPGameScene
//func showUpgradeShopOverlay(with choices: [RegularSkill]) {
//    guard let cameraNode = self.camera else { return }
//    let overlay = UpgradeShopOverlay(choices: choices, manager: upgradeShopManager)
//    overlay.zPosition = 100
//    cameraNode.addChild(overlay)
//    upgradeOverlay = overlay
//}

// MARK: In ZPGameScene.touchesBegan() ...
// MARK: first move "guard let cameraNode = self.camera else { continue }" ABOVE the "for touch in touches {" line
// MARK: then, place the below code snippet under "guard let cameraNode = self.camera else { continue }"
// MARK: the below code snippet should also be ABOVE "for touch in touches {"
// // If overlay is present, let it handle touch
//if let overlay = upgradeOverlay {
//    for touch in touches {
//        let location = touch.location(in: cameraNode)
//        overlay.touchBegan(at: location)
//    }
//    return
//}


// MARK: place in ZPGameScene.handleEnemyDefeat()
// MARK: this will launch the shop if it's time
// MARK: be careful with the wave logic, as it will need to pause the game correctly and not mess anything up
// // Right now, this will increment XP each kill, but will be replaced with XP collection
//upgradeShopManager.incrementXPCount()


// MARK: place in ZPGameScene.didMove() under "SkillManager" line
//upgradeShopManager = UpgradeShopManager(scene: self, skillManager: skillManager)

