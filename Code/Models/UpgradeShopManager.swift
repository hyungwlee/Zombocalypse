//
//  UpgradeShopManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import Foundation

class UpgradeShopManager {
    var XPCount: Int = 0
    var XPToNextLevel: Int = 1
    var nextShopXPThreshold: Int = 1
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

        let choices = skillManager.getRandomRegularChoices()
        
        // MARK: Uncomment this when scene is implemented
        scene.showUpgradeShopOverlay(with: choices)
    }
    
    func playerDidSelectSkill(_ skill: RegularSkill) {
        skillManager.acquireOrUpgradeRegularSkill(skill)
        XPToNextLevel += 1
        nextShopXPThreshold = XPCount + XPToNextLevel
    }
}
