//
//  BossSpinnerOverlayNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import SpriteKit


// MARK: - String Extension for Multi-Line Support
extension String {
    /// Splits the string into multiple lines based on the specified font and maximum width.
    func splitIntoLines(font: UIFont, maxWidth: CGFloat) -> [String] {
        let words = self.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let size = (testLine as NSString).size(withAttributes: attributes)
            
            if size.width > maxWidth {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = String(word)
                } else {
                    // Word itself is longer than maxWidth, force split
                    lines.append(String(word))
                    currentLine = ""
                }
            } else {
                currentLine = testLine
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
}

// MARK: - BossSpinnerOverlayNode Class
class BossSpinnerOverlayNode: SKNode {
    private weak var overlayManager: OverlayManager?
    private var skillManager: SkillManager
    private var specialSkills: [SkillType] = []
    
    private var background: SKSpriteNode!
    private var skillNodes: [SKSpriteNode] = []
    private var skillIcons: [SKSpriteNode] = []
    private var ownedSkillBoxes: [SKSpriteNode] = []
    private var ownedSkillIcons: [SKSpriteNode] = []
    private var currentHighlightedIndex = 0
    private var chosenSkill: SkillType?
    
    private var bgWidth: CGFloat = 0
    private var bgHeight: CGFloat = 0
    
    private var state: State = .idle
    
    enum State {
        case idle
        case spinning
        case result
    }
    
    // Reference to the shine node for spinning animation
    private var shineNode: SKSpriteNode?
    
    init(skillManager: SkillManager, overlayManager: OverlayManager, overlaySize: CGSize) {
        self.skillManager = skillManager
        self.overlayManager = overlayManager
        self.bgWidth = overlaySize.width
        self.bgHeight = overlaySize.height
        super.init()
        
        specialSkills = skillManager.getAvailableSpecialSkills()
        
        setupOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    private func setupOverlay() {
        // Add a full-screen semi-transparent black background to darken the scene
        let screenSize = CGSize(width: bgWidth, height: bgHeight) // Adjust to match your scene's size
        background = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: screenSize)
        background.zPosition = 100
        background.position = CGPoint.zero
        background.alpha = 0 // Initial state for fade-in
        addChild(background)
        
        // Use sk_lucky_draw sprite as title
        let titleNode = SKSpriteNode(imageNamed: "sk_lucky_draw")
        titleNode.zPosition = 101
        titleNode.position = CGPoint(x: 0, y: bgHeight * 0.35 - titleNode.size.height / 2)
        titleNode.alpha = 0 // Initial state for fade-in
        titleNode.name = "sk_lucky_draw" // Assign a unique name for access
        addChild(titleNode)
        
        // Display owned skills
        displayOwnedSkills(in: screenSize)
        
        // Add spinner background
        let spinnerBg = SKSpriteNode(imageNamed: "sk_boss_spinner")
        spinnerBg.zPosition = 101
        spinnerBg.position = CGPoint(x: 0, y: bgHeight * -0.05)
        spinnerBg.alpha = 0 // Initial state for fade-in
        spinnerBg.name = "spinnerBg" // Assign a unique name for access
        addChild(spinnerBg)
        
        // Arrange skills in a circle on spinnerBg
        arrangeSkillsInCircle(on: spinnerBg)
        
        // Add spin button initially
        let spinButton = SKSpriteNode(imageNamed: "sk_spin_button")
        spinButton.zPosition = 101
        spinButton.position = CGPoint(x: 0, y: spinnerBg.position.y - (spinnerBg.size.height / 2) - 100)
        spinButton.name = "spinButton"
        spinButton.alpha = 0 // Initial state for fade-in
        addChild(spinButton)
        
        // Animate overlay and nodes appearing
        animateOverlayShowing()
    }
    
    private func displayOwnedSkills(in screenSize: CGSize) {
        let ownedSkills = skillManager.ownedSpecialSkills
        let totalSpecialSkills = skillManager.getAvailableSpecialSkills().count
        
        // Change title to "OWNED:"
        let ownedTitle = SKLabelNode(text: "OWNED:")
        ownedTitle.fontName = "InknutAntiqua-ExtraBold"
        ownedTitle.fontSize = 12
        ownedTitle.fontColor = .white
        ownedTitle.position = CGPoint(x: 0, y: screenSize.height * 0.22)
        ownedTitle.zPosition = 101
        ownedTitle.alpha = 0 // Initial state for fade-in
        ownedTitle.name = "ownedTitle" // Assign a unique name for access
        addChild(ownedTitle)
        
        // Calculate spacing based on total special skills
        let boxWidth: CGFloat = 40
        let spacing: CGFloat = 10
        let totalWidth = CGFloat(totalSpecialSkills) * boxWidth + CGFloat(totalSpecialSkills - 1) * spacing
        let startX = -totalWidth / 2 + boxWidth / 2
        
        for i in 0..<totalSpecialSkills {
            let box = SKSpriteNode(imageNamed: "sk_selected_box")
            box.size = CGSize(width: boxWidth, height: boxWidth)
            box.zPosition = 101
            box.position = CGPoint(x: startX + CGFloat(i) * (boxWidth + spacing), y: ownedTitle.position.y - 30)
            box.alpha = 0 // Initial state for fade-in
            box.name = "ownedSkillBox_\(i)" // Optional: Assign unique names
            addChild(box)
            ownedSkillBoxes.append(box)
            
            // If the player owns this skill, add the icon
            if i < ownedSkills.count {
                let ownedSkill = ownedSkills[i]
                let icon = SKSpriteNode(imageNamed: ownedSkill.type.iconName)
                icon.size = CGSize(width: boxWidth * 0.8, height: boxWidth * 0.8)
                icon.zPosition = 102
                icon.position = CGPoint.zero
                icon.alpha = 0 // Initial state for fade-in
                box.addChild(icon)
                ownedSkillIcons.append(icon)
            }
        }
    }
    
    private func arrangeSkillsInCircle(on spinnerBg: SKSpriteNode) {
        guard specialSkills.count > 0 else { return }
        
        let radius: CGFloat = spinnerBg.size.width * 0.25
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(specialSkills.count)
        
        for (index, skillType) in specialSkills.enumerated() {
            let angle = angleIncrement * CGFloat(index) + CGFloat.pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            
            let skillBox = SKSpriteNode(imageNamed: "sk_unselected_box")
            skillBox.zPosition = 102
            skillBox.position = CGPoint(x: x, y: y)
            skillBox.alpha = 0 // Initial state for fade-in
            spinnerBg.addChild(skillBox)
            skillNodes.append(skillBox)
            
            // Skill Icon
            let icon = SKSpriteNode(imageNamed: skillType.iconName)
            icon.setScale(0.65)
            icon.position = CGPoint.zero
            icon.zPosition = 103
            icon.alpha = 0 // Initial state for fade-in
            skillBox.addChild(icon)
            skillIcons.append(icon)
        }
        
        highlightSkill(at: 0)  // Start highlighting the first skill
    }
    
    private func highlightSkill(at index: Int) {
        for (i, node) in skillNodes.enumerated() {
            if let sprite = node as? SKSpriteNode {
                sprite.texture = SKTexture(imageNamed: (i == index) ? "sk_selected_box" : "sk_unselected_box")
            }
        }
        currentHighlightedIndex = index
    }
    
    // MARK: - Overlay Appearance Animation
    private func animateOverlayShowing() {
        // Create fade-in actions
        let fadeInAction = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        
        // Sequence of actions for owned skills
        let ownedSkillsFadeIn = SKAction.run {
            for box in self.ownedSkillBoxes {
                box.run(fadeInAction)
            }
            for icon in self.ownedSkillIcons {
                icon.run(fadeInAction)
            }
            self.childNode(withName: "ownedTitle")?.run(fadeInAction)
        }
        
        // Fade in all main elements
        let mainFadeIn = SKAction.group([
            SKAction.run { self.background.run(fadeInAction) },
            SKAction.run { self.childNode(withName: "sk_lucky_draw")?.run(fadeInAction) },
            SKAction.run { self.childNode(withName: "spinnerBg")?.run(fadeInAction) },
            SKAction.run { self.childNode(withName: "spinButton")?.run(fadeInAction) },
            ownedSkillsFadeIn,
        ])
        
        let skillsFadeIn = SKAction.run {
            for (index, skillBox) in self.skillNodes.enumerated() {
                let delay = SKAction.wait(forDuration: 0.05 * Double(index))
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                skillBox.run(SKAction.sequence([delay, fadeIn]))
                
                let skillIcon = self.skillIcons[index]
                skillIcon.run(SKAction.sequence([delay, fadeIn]))
            }
        }
        
        run(SKAction.sequence([SKAction.wait(forDuration: 0.1), mainFadeIn])) {
            self.run(skillsFadeIn)
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchBegan(at: point)
    }
    
    func touchBegan(at point: CGPoint) {
        let nodesAtPoint = nodes(at: point)
        
        switch state {
        case .idle:
            // If we're idle, check if we tapped the spin button
            for node in nodesAtPoint {
                if node.name == "spinButton" {
                    handleButtonPress()
                    return
                }
            }
        case .result:
            // After showing chosen skill, tapping anywhere will close
            applyChosenSkillAndClose()
        default:
            break
        }
    }
    
    private func handleButtonPress() {
        switch state {
        case .idle:
            // Start spinning
            state = .spinning
            // Remove the spin button since we only tap once
            if let spinButton = childNode(withName: "spinButton") {
                spinButton.removeFromParent()
            }
            runSpinAnimation()
        default:
            break
        }
    }
    
    private func runSpinAnimation() {
        let finalIndex = Int.random(in: 0..<specialSkills.count)
        let totalCycles = specialSkills.count * 5 + finalIndex // 5 full rotations + final landing
        
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
            self.state = .result
            self.showChosenSkillPopup()
        }
        
        run(SKAction.sequence([spinAction, completion]))
    }
    
    // MARK: - Popup Display and Animation
    private func showChosenSkillPopup() {
        guard let chosenSkill = chosenSkill else { return }
        
        // Add an additional opaque black background to further darken the UI
        let popupOpaqueBackground = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.6), size: CGSize(width: bgWidth, height: bgHeight))
        popupOpaqueBackground.zPosition = 200 // Above main background
        popupOpaqueBackground.position = CGPoint.zero
        popupOpaqueBackground.alpha = 0 // Initial state for fade-in
        popupOpaqueBackground.name = "popupOpaqueBackground" // Assign a unique name
        addChild(popupOpaqueBackground)
        
        // Animate the opaque background fade-in
        let fadeInOpaque = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        popupOpaqueBackground.run(fadeInOpaque)
        
        // Popup container to hold all popup elements
        let popupContainer = SKSpriteNode(imageNamed: "sk_spinner_select_scroll")
        popupContainer.zPosition = 500 // Above the opaque background and all other nodes
        popupContainer.position = CGPoint.zero
        popupContainer.setScale(0.5) // Initial scale for animation
        popupContainer.alpha = 0 // Initial state for fade-in
        popupContainer.name = "popupContainer" // Assign a unique name
        addChild(popupContainer)
        
        // Animate the popup container scaling and fading in
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        let fadeInPopup = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let popupGroup = SKAction.group([scaleUp, fadeInPopup])
        popupContainer.run(popupGroup)
        
        // Skill Icon below the name
        let icon = SKSpriteNode(imageNamed: chosenSkill.iconName)
        icon.zPosition = 502 // Above popupContainer and skillNameLabel
        icon.position = CGPoint(x: 0, y: popupContainer.size.height * 0.1)
        icon.setScale(1.2)
        icon.alpha = 0 // Initial state for fade-in
        popupContainer.addChild(icon)
        
        // Animate the skill icon fade-in
        let fadeInIcon = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        icon.run(SKAction.sequence([SKAction.wait(forDuration: 0.2), fadeInIcon]))
        
        // Define maximum width for the skill name label
        let maxSkillNameWidth: CGFloat = popupContainer.size.width * 0.8
        
        // Skill Name Label with Multi-Line Support
        let skillNameFont = UIFont(name: "InknutAntiqua-ExtraBold", size: 25.6) ?? UIFont.systemFont(ofSize: 25.6)
        let skillNameLines = chosenSkill.displayName.splitIntoLines(font: skillNameFont, maxWidth: maxSkillNameWidth)
        
        let lineHeight: CGFloat = 24 // Adjust based on font size and desired spacing
        let totalSkillNameHeight = CGFloat(skillNameLines.count) * lineHeight
        let startY = icon.position.y + icon.size.height / 2 + popupContainer.size.height * 0.2 + totalSkillNameHeight / 2
        
        for (index, line) in skillNameLines.enumerated() {
            let skillNameLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
            skillNameLabel.fontSize = 25.6
            skillNameLabel.zPosition = 501 // Above popupContainer
            skillNameLabel.horizontalAlignmentMode = .center
            skillNameLabel.verticalAlignmentMode = .center
            skillNameLabel.alpha = 0 // Initial state for fade-in
            
            // Create an attributed string with stroke
            let strokeColor = UIColor.black
            let strokeWidth: CGFloat = -4.0
            let textColor = UIColor(hex: "#614519") ?? .brown
            
            let attributes: [NSAttributedString.Key: Any] = [
                .strokeColor: strokeColor,
                .foregroundColor: textColor,
                .strokeWidth: strokeWidth,
                .font: skillNameFont
            ]
            
            let attributedText = NSAttributedString(string: line, attributes: attributes)
            skillNameLabel.attributedText = attributedText
            
            // Position each line
            skillNameLabel.position = CGPoint(x: 0, y: startY - CGFloat(index) * lineHeight)
            popupContainer.addChild(skillNameLabel)
            
            // Animate each line's fade-in with slight delays
            let fadeInLine = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            let delay = SKAction.wait(forDuration: 0.05 * Double(index))
            skillNameLabel.run(SKAction.sequence([delay, fadeInLine]))
        }
        
        // Shine Node - Adjusted zPosition and parent
        let shine = SKSpriteNode(imageNamed: "sk_shine")
        shine.zPosition = 499 // Below popupContainer's children
        shine.position = icon.position
        shine.alpha = 0 // Initial state for fade-in
        popupContainer.addChild(shine)
        
        // Animate the shine node fade-in
        let fadeInShine = SKAction.fadeAlpha(to: 0.6, duration: 0.3)
        shine.run(SKAction.sequence([SKAction.wait(forDuration: 0.3), fadeInShine]))
        
        // Start spinning the shine after it fades in
        shine.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 4.0)))
        shineNode = shine // Keep a reference to stop the spin later if needed
        
        // Skill Description below the icon
        let descriptionLabel = SKLabelNode(fontNamed: "InknutAntiqua-Regular")
        descriptionLabel.text = chosenSkill.skillDescription
        descriptionLabel.fontSize = 14
        descriptionLabel.fontColor = UIColor(hex: "#614519")
        descriptionLabel.position = CGPoint(x: 0, y: icon.position.y - icon.size.height / 2 - 50)
        descriptionLabel.horizontalAlignmentMode = .center
        descriptionLabel.verticalAlignmentMode = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.preferredMaxLayoutWidth = icon.size.width * 2.0
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.alpha = 0 // Initial state for fade-in
        popupContainer.addChild(descriptionLabel)
        
        // Animate the description label fade-in
        let fadeInDescription = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let delayDescription = SKAction.wait(forDuration: 0.4)
        descriptionLabel.run(SKAction.sequence([delayDescription, fadeInDescription]))
        
        // Smaller, flashing "Tap to continue" at the bottom
        let continueLabel = SKLabelNode(fontNamed: "InknutAntiqua-Regular")
        continueLabel.text = "TAP TO CONTINUE"
        continueLabel.fontSize = 8
        continueLabel.fontColor = .yellow
        continueLabel.position = CGPoint(x: 0, y: descriptionLabel.position.y - descriptionLabel.frame.height / 2 - 30)
        continueLabel.horizontalAlignmentMode = .center
        continueLabel.verticalAlignmentMode = .center
        continueLabel.alpha = 0 // Initial state for fade-in
        popupContainer.addChild(continueLabel)
        
        // Animate the "Tap to continue" label fade-in
        let fadeInContinue = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let delayContinue = SKAction.wait(forDuration: 0.5)
        continueLabel.run(SKAction.sequence([delayContinue, fadeInContinue]))
        
        // Flashing animation for "Tap to continue"
        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.5)
        let fadeInBack = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let blinkSequence = SKAction.sequence([fadeOut, fadeInBack])
        let blinkForever = SKAction.repeatForever(blinkSequence)
        continueLabel.run(blinkForever)
    }
    
    // MARK: - Overlay Closing Animation
    private func applyChosenSkillAndClose() {
        if let chosenSkill = chosenSkill {
            skillManager.acquireSpecialSkill(chosenSkill)
        }
        
        // Animate overlay closing
        animateOverlayClosing()
    }
    
    private func animateOverlayClosing() {
        // Access the popupContainer and popupOpaqueBackground by name
        guard let popupContainer = childNode(withName: "popupContainer") as? SKSpriteNode,
              let popupOpaqueBackground = childNode(withName: "popupOpaqueBackground") else {
            // If not found, simply remove the overlay
            let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
            let remove = SKAction.removeFromParent()
            run(SKAction.sequence([fadeOut, remove]))
            return
        }
        
        // Create fade-out actions
        let fadeOutPopup = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
        let scaleDownPopup = SKAction.scale(to: 0.5, duration: 0.3)
        let popupGroup = SKAction.group([fadeOutPopup, scaleDownPopup])
        
        // Fade out the popupContainer
        popupContainer.run(popupGroup)
        
        // Fade out the opaque background
        let fadeOutOpaque = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
        popupOpaqueBackground.run(fadeOutOpaque)
        
        // Stop the shine spinning
        shineNode?.removeAllActions()
        
        // Remove nodes after fade-out
        let removeNodes = SKAction.group([
            SKAction.removeFromParent(),
            SKAction.run {
                self.shineNode = nil // Clean up the reference
            }
        ])
        
        // Sequence to fade out and then remove
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            removeNodes
        ])
        
        run(sequence)
    }
}
