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
    
    func playerDidSelectSkill(_ skill: SLRegularSkill) {
        skillManager.acquireOrUpgradeRegularSkill(skill)
        if skill.definition.type == .healthUpgrade || skill.definition.type == .bonusHealth {
            scene?.restoreHealth(1.0)
        }
        XPToNextLevel += 1
        nextShopXPThreshold = XPCount + XPToNextLevel
    }
}
