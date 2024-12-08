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
