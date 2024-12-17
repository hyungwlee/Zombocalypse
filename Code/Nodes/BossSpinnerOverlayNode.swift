//
//  BossSpinnerOverlayNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//

import SpriteKit

class BossSpinnerOverlayNode: SKNode {
    private weak var overlayManager: OverlayManager?
    private var skillManager: SkillManager
    private var specialSkills: [SkillType] = []
    
    private let background = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "Arial")
    private let buttonLabel = SKLabelNode(fontNamed: "Arial")
    private var skillNodes: [SKShapeNode] = []
    private var skillLabels: [SKLabelNode] = []
    private var skillIcons: [SKSpriteNode] = []
    private var currentHighlightedIndex = 0
    private var chosenSkill: SkillType?
    
    private var state: State = .idle
    
    enum State {
        case idle  // before spinning
        case spinning
        case result  // after result shown
    }
    
    init(skillManager: SkillManager, overlayManager: OverlayManager) {
        self.skillManager = skillManager
        self.overlayManager = overlayManager
        super.init()
        
        specialSkills = skillManager.getAvailableSpecialSkills()
        
        setupOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupOverlay() {
        // Dim background
        let bgRect = CGRect(x: -250, y: -300, width: 500, height: 700)
        background.path = CGPath(rect: bgRect, transform: nil)
        background.fillColor = .black.withAlphaComponent(0.7)
        background.zPosition = 100
        addChild(background)
        
        // Title
        titleLabel.text = "Boss Defeated! Get a Special Skill!"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 350)
        titleLabel.zPosition = 101
        addChild(titleLabel)
        
        // Spin Button
        buttonLabel.text = "Spin"
        buttonLabel.fontSize = 20
        buttonLabel.fontColor = .cyan
        buttonLabel.name = "spinButton"
        buttonLabel.position = CGPoint(x: 0, y: -270)
        buttonLabel.zPosition = 101
        addChild(buttonLabel)
        
        displayActiveSkills()
        
        arrangeSkillsInCircle()
    }
    
    private func displayActiveSkills() {
        let activeSkills = skillManager.ownedSpecialSkills
        guard activeSkills.count > 0 else { return }
        
        // Create a label to indicate active skills
        let activeSkillsTitle = SKLabelNode(text: "Active Skills:")
        activeSkillsTitle.fontName = "Arial"
        activeSkillsTitle.fontSize = 18
        activeSkillsTitle.fontColor = .white
        activeSkillsTitle.position = CGPoint(x: 0, y: 310)
        activeSkillsTitle.zPosition = 101
        addChild(activeSkillsTitle)
        
        // Display active skills below the title
        let spacing: CGFloat = -25
        for (index, skill) in activeSkills.enumerated() {
            let skillInfo = SKLabelNode(text: skill.type.displayName)
            skillInfo.fontName = "Arial"
            skillInfo.fontSize = 16
            skillInfo.fontColor = .green
            skillInfo.position = CGPoint(x: 0, y: 290 + spacing * CGFloat(index))
            skillInfo.zPosition = 101
            addChild(skillInfo)
            
            // Optionally, add icons next to active skill names
            let icon = SKSpriteNode(imageNamed: skill.type.iconName)
            icon.size = CGSize(width: 20, height: 20)
            icon.position = CGPoint(x: -60, y: 290 + spacing * CGFloat(index))
            icon.zPosition = 101
            addChild(icon)
        }
    }
    
    private func arrangeSkillsInCircle() {
        guard specialSkills.count > 0 else { return }
        
        let radius: CGFloat = 100
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(specialSkills.count)
        
        for (index, skillType) in specialSkills.enumerated() {
            let angle = angleIncrement * CGFloat(index) - CGFloat.pi / 2 // Start from top
            let x = radius * cos(angle)
            let y = radius * sin(angle) - 80
            
            // Skill Box
            let skillBox = SKShapeNode(rectOf: CGSize(width: 120, height: 120), cornerRadius: 10)
            skillBox.fillColor = .gray
            skillBox.strokeColor = .white
            skillBox.position = CGPoint(x: x, y: y)
            skillBox.zPosition = 101
            skillBox.name = "skillBox_\(index)"
            addChild(skillBox)
            skillNodes.append(skillBox)
            
            // Skill Icon
            let icon = SKSpriteNode(imageNamed: skillType.iconName) // Ensure each SkillType has an `iconName` property
            //icon.size = CGSize(width: 40, height: 40)
            icon.position = CGPoint.zero
            icon.zPosition = 102
            skillBox.addChild(icon)
            skillIcons.append(icon)
            
            // Skill Label
            let skillLabel = SKLabelNode(fontNamed: "Arial")
            skillLabel.text = skillType.displayName
            skillLabel.fontSize = 14
            skillLabel.fontColor = .white
            skillLabel.position = CGPoint(x: 0, y: -40) // Below the icon
            skillLabel.zPosition = 102
            skillBox.addChild(skillLabel)
            skillLabels.append(skillLabel)
        }
        
        highlightSkill(at: 0)  // Start highlighting the first skill
    }
    
    private func highlightSkill(at index: Int) {
        for (i, node) in skillNodes.enumerated() {
            node.fillColor = (i == index) ? .yellow : .gray
        }
        currentHighlightedIndex = index
    }
    
    func touchBegan(at point: CGPoint) {
        let nodesAtPoint = nodes(at: point)
        for node in nodesAtPoint {
            if node.name == "spinButton" {
                handleButtonPress()
            }
        }
    }
    
    private func handleButtonPress() {
        switch state {
        case .idle:
            // Start spinning
            state = .spinning
            buttonLabel.text = "Spinning..."
            runSpinAnimation()
        case .result:
            // Apply the chosen skill and close the overlay
            if let chosenSkill = chosenSkill {
                skillManager.acquireSpecialSkill(chosenSkill)
            }
            overlayManager?.closeCurrentOverlay(self)
        default:
            break
        }
    }
    
    private func runSpinAnimation() {
        // Simulate spinning: highlight skills in sequence, then slow down and land on a random skill.
        // We'll pick a random final index
        let finalIndex = Int.random(in: 0..<specialSkills.count)
        let totalCycles = specialSkills.count * 3 + finalIndex // 3 full rotations + final landing
        
        var currentStep = 0
        let spinAction = SKAction.repeat(SKAction.sequence([
            SKAction.run {
                let nextIndex = (self.currentHighlightedIndex + 1) % self.specialSkills.count
                self.highlightSkill(at: nextIndex)
                currentStep += 1
            },
            SKAction.wait(forDuration: 0.1)
        ]), count: totalCycles)
        
        let completion = SKAction.run {
            self.chosenSkill = self.specialSkills[self.currentHighlightedIndex]
            self.buttonLabel.text = "Continue"
            self.state = .result
            self.showChosenSkill()
        }
        
        run(SKAction.sequence([spinAction, completion]))
    }
    
    private func showChosenSkill() {
        guard let chosenSkill = chosenSkill else { return }
        
        // Display the chosen skill's name and icon prominently
        let chosenSkillBackground = SKShapeNode(rectOf: CGSize(width: 200, height: 100), cornerRadius: 10)
        chosenSkillBackground.fillColor = .darkGray
        chosenSkillBackground.strokeColor = .white
        chosenSkillBackground.position = CGPoint(x: 0, y: 150)
        chosenSkillBackground.zPosition = 103
        addChild(chosenSkillBackground)
        
        // Skill Icon
        let icon = SKSpriteNode(imageNamed: chosenSkill.iconName) // Ensure each SkillType has an `iconName` property
        icon.size = CGSize(width: 50, height: 50)
        icon.position = CGPoint(x: -60, y: 0)
        icon.zPosition = 104
        chosenSkillBackground.addChild(icon)
        
        // Skill Name Label
        let skillLabel = SKLabelNode(fontNamed: "Arial")
        skillLabel.text = chosenSkill.displayName
        skillLabel.fontSize = 20
        skillLabel.fontColor = .white
        skillLabel.position = CGPoint(x: 60, y: 0)
        skillLabel.zPosition = 104
        chosenSkillBackground.addChild(skillLabel)
    }
}
