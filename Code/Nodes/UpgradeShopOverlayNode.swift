//
//  UpgradeShopOverlayNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import SpriteKit

class UpgradeShopOverlayNode: SKNode {
    weak var manager: UpgradeShopManager?
    var choices: [RegularSkill] = []
    
    private let background = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "Arial")
    private var skillButtons: [SKLabelNode] = []
    
    init(choices: [RegularSkill], manager: UpgradeShopManager) {
        self.manager = manager
        self.choices = choices
        super.init()
        setupOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupOverlay() {
        // Dim background
        let bgRect = CGRect(x: -200, y: -150, width: 400, height: 300)
        background.path = CGPath(rect: bgRect, transform: nil)
        background.fillColor = .black.withAlphaComponent(0.7)
        background.zPosition = 100
        addChild(background)
        
        // Title
        titleLabel.text = "Choose an Upgrade"
        titleLabel.fontSize = 30
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 100)
        titleLabel.zPosition = 101
        addChild(titleLabel)
        
        // Regular Skill Options
        let startY: CGFloat = 40
        let gapY: CGFloat = -50
        for (index, skill) in choices.enumerated() {
            let skillLabel = SKLabelNode(fontNamed: "Arial")
            skillLabel.text = "\(skill.definition.type)" /// will need to hard code some better looking names for each type
            skillLabel.fontSize = 20
            skillLabel.fontColor = .yellow
            skillLabel.position = CGPoint(x: 0, y: startY + (gapY * CGFloat(index)))
            skillLabel.name = "skillButton_\(index)"
            skillLabel.zPosition = 101
            addChild(skillLabel)
            skillButtons.append(skillLabel)
        }
    }
    
    func touchBegan(at point: CGPoint) {
        let nodesAtPoint = nodes(at: point)
        for node in nodesAtPoint {
            if let nodeName = node.name, nodeName.starts(with: "skillButton_") {
                let indexString = nodeName.replacingOccurrences(of: "skillButton_", with: "")
                if let index = Int(indexString), index < choices.count {
                    let chosenSkill = choices[index]
                    manager?.playerDidSelectSkill(chosenSkill)
                    removeFromParent()
                    return
                }
            }
        }
    }
}
