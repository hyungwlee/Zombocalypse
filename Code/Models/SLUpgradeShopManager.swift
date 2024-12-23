//
//  SLUpgradeShopManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import Foundation

class SLUpgradeShopManager {
    var XPCount: Int = 0
    var XPToNextLevel: Int = 1
    var nextShopXPThreshold: Int = 1
    private weak var scene: SLGameScene?
    private var skillManager: SLSkillManager
    
    init(scene: SLGameScene, skillManager: SLSkillManager) {
        self.scene = scene
        self.skillManager = skillManager
        resetXP()
    }
    
    func resetXP() {
        XPCount = 0
        XPToNextLevel = 1
        nextShopXPThreshold = 1
    }
    
    func incrementXPCount() {
        XPCount += 1
//        checkForShop()
    }
    
    func checkForShop() {
        guard XPCount >= nextShopXPThreshold, let scene = scene else { return }

        XPToNextLevel += 3
        nextShopXPThreshold = XPCount + XPToNextLevel
        
        let choices = skillManager.getRandomRegularChoices()
        scene.showUpgradeShopOverlay(with: choices)
    }
    
    func playerDidSelectSkill(_ skill: SLRegularSkill) {
        skillManager.acquireOrUpgradeRegularSkill(skill)
        if skill.definition.type == .healthUpgrade || skill.definition.type == .bonusHealth {
            scene?.restoreHealth(1.0)
        }

    }
}
