//
//  UpgradeShopOverlayNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//

import SpriteKit

// Regular Skills
class UpgradeShopOverlayNode: SKNode {
    weak var manager: UpgradeShopManager?
    weak var overlayManager: OverlayManager?
    weak var skillManager: SkillManager?
    var choices: [RegularSkill] = []
    
    private let background = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "Arial")
    private var skillButtons: [SKShapeNode] = []
    private var skillIcons: [SKSpriteNode] = []
    private var skillDescriptions: [SKLabelNode] = []
    private var skillLevels: [SKLabelNode] = []
    
    // The vertical spacing constants
    private let listStartY: CGFloat = 200
    private let skillListGapY: CGFloat = -20
    private let choicesStartY: CGFloat = -100
    private let choiceGapY: CGFloat = -60
    
    init(choices: [RegularSkill], manager: UpgradeShopManager, overlayManager: OverlayManager, skillManager: SkillManager) {
        self.manager = manager
        self.choices = choices
        self.overlayManager = overlayManager
        self.skillManager = skillManager
        super.init()
        setupOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupOverlay() {
        // Adjusted height to fit all info
        let bgRect = CGRect(x: -200, y: -300, width: 400, height: 600)
        background.path = CGPath(rect: bgRect, transform: nil)
        background.fillColor = .black.withAlphaComponent(0.7)
        background.zPosition = 100
        addChild(background)
        
        // Title
        titleLabel.text = "Choose an Upgrade"
        titleLabel.fontSize = 26
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: bgRect.height/2 - 50) // position title at the top inside the popup
        titleLabel.zPosition = 101
        addChild(titleLabel)
        
        displayAllSkills(in: bgRect)
        displayChoices()
    }
    
    private func displayAllSkills(in bgRect: CGRect) {
        guard let skillManager = skillManager else { return }

        let allDefs = skillManager.allRegularDefinitions

        var yPos = listStartY
        let skillListLabel = SKLabelNode(fontNamed: "Arial")
        skillListLabel.text = "Your Regular Skills:"
        skillListLabel.fontSize = 20
        skillListLabel.fontColor = .white
        skillListLabel.position = CGPoint(x: 0, y: yPos)
        skillListLabel.zPosition = 101
        addChild(skillListLabel)
        
        yPos += skillListGapY

        for def in allDefs {
            let currentLevel = skillManager.ownedRegularSkills.first(where: { $0.definition.type == def.type })?.currentLevel ?? 0
            let maxLevel = def.maxLevel
            let skillLabel = SKLabelNode(fontNamed: "Arial")
            skillLabel.fontSize = 16
            skillLabel.fontColor = .white
            skillLabel.zPosition = 101
            skillLabel.horizontalAlignmentMode = .center
            skillLabel.verticalAlignmentMode = .center
            
            let skillName = def.type.displayName
            skillLabel.text = "\(skillName): Lvl \(currentLevel)/\(maxLevel)"
            skillLabel.position = CGPoint(x: 0, y: yPos)
            addChild(skillLabel)

            yPos += skillListGapY
        }
    }
    
    private func displayChoices() {
        // We'll show them starting from choicesStartY downwards
        var yPos = choicesStartY
        for (index, skill) in choices.enumerated() {
            let iconSize: CGFloat = 30
            let icon: SKSpriteNode
            if !skill.definition.type.iconName.isEmpty {
                icon = SKSpriteNode(imageNamed: skill.definition.type.iconName)
                //icon.size = CGSize(width: iconSize, height: iconSize)
            } else {
                icon = SKSpriteNode(color: .blue, size: CGSize(width: iconSize, height: iconSize))
            }
            icon.position = CGPoint(x: -100, y: yPos)
            icon.zPosition = 101
            addChild(icon)
            skillIcons.append(icon)
            
            let skillNameLabel = SKLabelNode(fontNamed: "Arial")
            skillNameLabel.fontSize = 18
            skillNameLabel.fontColor = .yellow
            skillNameLabel.zPosition = 101
            skillNameLabel.horizontalAlignmentMode = .left
            skillNameLabel.verticalAlignmentMode = .center
            skillNameLabel.position = CGPoint(x: -60, y: yPos + 10)
            skillNameLabel.text = skill.displayName
            addChild(skillNameLabel)
            skillDescriptions.append(skillNameLabel)
            
            let nextLevelLabel = SKLabelNode(fontNamed: "Arial")
            nextLevelLabel.fontSize = 14
            nextLevelLabel.fontColor = .white
            nextLevelLabel.zPosition = 101
            nextLevelLabel.horizontalAlignmentMode = .left
            nextLevelLabel.verticalAlignmentMode = .center
            nextLevelLabel.position = CGPoint(x: -60, y: yPos - 10)
            
            let currentLevel = skill.currentLevel
            let maxLevel = skill.definition.maxLevel
            if currentLevel >= maxLevel {
                nextLevelLabel.text = "Maxed"
            } else {
                nextLevelLabel.text = "Next Level: \(currentLevel + 1)"
            }
            
            addChild(nextLevelLabel)
            skillLevels.append(nextLevelLabel)
            
            // Create a button area (SKShapeNode) covering the icon and text
            let buttonWidth: CGFloat = 300
            let buttonHeight: CGFloat = 50
            let buttonRect = CGRect(x: -buttonWidth/2, y: -buttonHeight/2, width: buttonWidth, height: buttonHeight)
            let button = SKShapeNode(rect: buttonRect, cornerRadius: 8)
            button.fillColor = .clear
            button.strokeColor = .clear
            button.zPosition = 110
            button.position = CGPoint(x: 0, y: yPos) // center at icon level
            button.name = "skillButton_\(index)"
            addChild(button)
            skillButtons.append(button)
            
            yPos += choiceGapY
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
                    
                    overlayManager?.closeCurrentOverlay(self)
                    removeFromParent()
                    return
                }
            }
        }
    }
}
