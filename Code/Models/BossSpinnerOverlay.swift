//
//  BossSpinnerOverlay.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//

import SpriteKit

class BossSpinnerOverlay: SKNode {
    private weak var overlayManager: OverlayManager?
    private var skillManager: SkillManager
    private var specialSkills: [SkillType] = []
    
    private let background = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "Arial")
    private let buttonLabel = SKLabelNode(fontNamed: "Arial")
    private var skillNodes: [SKShapeNode] = []
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
        let bgRect = CGRect(x: -250, y: -200, width: 500, height: 400)
        background.path = CGPath(rect: bgRect, transform: nil)
        background.fillColor = .black.withAlphaComponent(0.7)
        background.zPosition = 100
        addChild(background)
        
        titleLabel.text = "Boss Defeated! Get a Special Skill!"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 150)
        titleLabel.zPosition = 101
        addChild(titleLabel)
        
        buttonLabel.text = "Spin"
        buttonLabel.fontSize = 20
        buttonLabel.fontColor = .cyan
        buttonLabel.name = "spinButton"
        buttonLabel.position = CGPoint(x: 0, y: -150)
        buttonLabel.zPosition = 101
        addChild(buttonLabel)
        
        arrangeSkillsInCircle()
    }
    
    private func arrangeSkillsInCircle() {
        let radius: CGFloat = 100
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(specialSkills.count)
        
        for (index, skill) in specialSkills.enumerated() {
            let angle = angleIncrement * CGFloat(index)
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            
            let skillNode = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 5)
            skillNode.fillColor = .gray
            skillNode.strokeColor = .white
            skillNode.position = CGPoint(x: x, y: y)
            skillNode.zPosition = 101
            addChild(skillNode)
            skillNodes.append(skillNode)
        }
        
        highlightSkill(at: 0)  // start highlighting the first skill
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
            // Continue / close the overlay
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
        }
        
        run(SKAction.sequence([spinAction, completion]))
    }
}
