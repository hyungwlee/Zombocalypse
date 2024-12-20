//
//  UpgradeShopOverlayNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import SpriteKit

class UpgradeShopOverlayNode: SKNode {
    weak var manager: UpgradeShopManager?
    weak var overlayManager: OverlayManager?
    weak var skillManager: SkillManager?
    var choices: [RegularSkill] = []
    
    private let darkOverlay = SKSpriteNode()
    private var skillStatusNodes: [SKNode] = []
    private var choiceNodes: [SKNode] = []
    
    // Layout constants
    private var bgWidth: CGFloat = 0
    private var bgHeight: CGFloat = 0
    private var listStartY: CGFloat = 0
    private let rowSpacing: CGFloat   // Vertical distance between rows of statuses
    private let iconXOffset: CGFloat // Icon offset inside status node
    private let starScale: CGFloat
    private let scaleFactor: CGFloat
    
    // After statuses, we place the skill_bg for choices
    private let skillBgPaddingTop: CGFloat = 0   // Vertical gap between last status row and skill_bg
    
    // Maximum width for description labels
    
    // Reference to skillBg for animations
    private var skillBg: SKSpriteNode!
    
    
    init(choices: [RegularSkill], manager: UpgradeShopManager, overlayManager: OverlayManager, skillManager: SkillManager, overlaySize: CGSize,
    scaleFactor: CGFloat) {
        self.manager = manager
        self.choices = choices
        self.overlayManager = overlayManager
        self.skillManager = skillManager
        self.bgWidth = overlaySize.width
        self.bgHeight = overlaySize.height
        
        self.rowSpacing = 30 * scaleFactor
        self.iconXOffset = -50 * scaleFactor
        self.starScale = scaleFactor
        self.scaleFactor = scaleFactor
        
        super.init()
        
        SLSoundManager.shared.playSoundEffect(.openShop)

        setupOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupOverlay() {
        // Create a full-screen dark overlay using hex color
        darkOverlay.color = UIColor(hex: "#000000") ?? .black  // Black color with hex
        darkOverlay.alpha = 0.0  // Start invisible
        darkOverlay.size = CGSize(width: bgWidth, height: bgHeight)
        darkOverlay.position = CGPoint.zero
        darkOverlay.zPosition = 100
        addChild(darkOverlay)
        
        // Animate dark overlay fading in
        let fadeIn = SKAction.fadeAlpha(to: 0.7, duration: 0.3)
        darkOverlay.run(fadeIn)
        
        // "sk_level_up" title at the top
        let titleNode = SKSpriteNode(imageNamed: "sk_level_up")
        titleNode.zPosition = 101
        titleNode.position = CGPoint(x: 0, y: bgHeight * 0.35 - titleNode.size.height / 2)
        titleNode.alpha = 0.0  // Start invisible
        titleNode.setScale(0.5 * scaleFactor) // Start scaled down
        addChild(titleNode)
        
        // Animate title scaling up and fading in
        let scaleUp = SKAction.scale(to: scaleFactor, duration: 0.5)
        let fadeInTitle = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let group = SKAction.group([scaleUp, fadeInTitle])
        titleNode.run(group) {
            let pulseIn = SKAction.scale(to: self.scaleFactor * 1.05, duration: 2.0)
            let pulseOut = SKAction.scale(to: self.scaleFactor, duration: 2.0)
            let pulseSequence = SKAction.sequence([pulseOut, pulseIn])
            let pulseForever = SKAction.repeatForever(pulseSequence)
            titleNode.run(pulseForever)
        }
        
        // Display statuses in three columns
        let finalStatusY = displayAllSkills()
        
        // Now place the skill_bg under the statuses
        displaySkillChoicesContainer(startY: finalStatusY - skillBgPaddingTop)
        
        // Animate skill choices popping up
        let skillChoices = skillBg.children.filter { $0.name?.starts(with: "skillButton_") ?? false }
        for (index, choice) in skillChoices.enumerated() {
            choice.alpha = 0.0
            choice.setScale(0.5)
            let delay = SKAction.wait(forDuration: 0.1 * Double(index))
            let scaleUpChoice = SKAction.scale(to: 1.0, duration: 0.3)
            let fadeInChoice = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            let groupChoice = SKAction.group([scaleUpChoice, fadeInChoice])
            let sequence = SKAction.sequence([delay, groupChoice])
            choice.run(sequence) {
                let pulseIn = SKAction.scale(to: 1.03, duration: 1.0)
                let pulseOut = SKAction.scale(to: 1.0, duration: 1.0)
                let pulseSequence = SKAction.sequence([pulseIn, pulseOut])
                let pulseForever = SKAction.repeatForever(pulseSequence)
                choice.run(pulseForever)
            }
        }
    }
    
    private func displayAllSkills() -> CGFloat {
        guard let skillManager = skillManager else { return listStartY }
        let allDefs = skillManager.allRegularDefinitions
        
        let columnXOffsets = [bgWidth * -0.25, 0, bgWidth * 0.25]
        
        // Arrange skills in rows of three columns
        listStartY = bgHeight * 0.225
        var yPos = listStartY
        let maxStars = 4
        var index = 0
        
        while index < allDefs.count {
            // Get up to three skills for the current row
            let rowDefs = Array(allDefs[index..<min(index+3, allDefs.count)])
            
            for (col, def) in rowDefs.enumerated() {
                let currentLevel = skillManager.ownedRegularSkills.first(where: { $0.definition.type == def.type })?.currentLevel ?? 0
                
                let skillStatusBg = SKSpriteNode(imageNamed: "sk_skill_status")
                skillStatusBg.setScale(scaleFactor)
                skillStatusBg.zPosition = 101
                skillStatusBg.position = CGPoint(x: columnXOffsets[col], y: yPos)
                addChild(skillStatusBg)
                skillStatusNodes.append(skillStatusBg)
                
                // Skill Icon
                let iconName = def.type.iconName
                let skillIcon: SKSpriteNode
                if !iconName.isEmpty {
                    skillIcon = SKSpriteNode(imageNamed: iconName)
                    skillIcon.setScale(scaleFactor * 0.38)
                } else {
                    skillIcon = SKSpriteNode(color: UIColor(hex: "#0000FF") ?? .blue, size: CGSize(width: 20, height: 20)) // Blue color with hex
                }
                skillIcon.zPosition = 102
                // Position icon relative to the skillStatusBg
                skillIcon.position = CGPoint(x: (-skillStatusBg.size.width * 0.295) /*+ (skillIcon.size.width / 2)*/, y: 0)
                skillStatusBg.addChild(skillIcon)
                
                // Add the stars to represent current level
                let starSpacing: CGFloat = 14 * scaleFactor
                let startX: CGFloat = -skillStatusBg.size.width * 0.05
                for i in 0..<maxStars {
                    let starImageName = (i < currentLevel) ? "sk_status_star_full" : "sk_status_star_empty"
                    let starNode = SKSpriteNode(imageNamed: starImageName)
                    starNode.setScale(starScale)
                    starNode.zPosition = 102
                    let starX = startX + CGFloat(i) * starSpacing
                    starNode.position = CGPoint(x: starX, y: 0)
                    skillStatusBg.addChild(starNode)
                }
            }
            
            // Move down for the next row of statuses
            yPos -= rowSpacing
            index += 3
        }
        
        // Return the last used Y position
        return yPos
    }
    
    private func displaySkillChoicesContainer(startY: CGFloat) {
        // sk_shop_bg that houses the three choices
        skillBg = SKSpriteNode(imageNamed: "sk_shop_bg")
        skillBg.setScale(scaleFactor)
        skillBg.zPosition = 101
        skillBg.position = CGPoint(x: 0, y: startY - skillBg.size.height / 2)
        addChild(skillBg)
        
        // Now place the three choices (sk_skill_option) inside skillBg
        let choiceStartY = skillBg.size.height * 0.4
        var yPos = choiceStartY
        for (index, skill) in choices.enumerated() {
            let choiceBg = SKSpriteNode(imageNamed: "sk_skill_option")
            choiceBg.setScale(scaleFactor)
            choiceBg.zPosition = 102
            choiceBg.position = CGPoint(x: 0, y: yPos - choiceBg.size.height / 2)
            choiceBg.name = "skillButton_\(index)"
            skillBg.addChild(choiceBg)
            choiceNodes.append(choiceBg)
            
            // Skill Icon
            let iconSize: CGFloat = 40 * scaleFactor
            let icon: SKSpriteNode
            if !skill.definition.type.iconName.isEmpty {
                icon = SKSpriteNode(imageNamed: skill.definition.type.iconName)
            } else {
                icon = SKSpriteNode(color: UIColor(hex: "#0000FF") ?? .blue, size: CGSize(width: iconSize, height: iconSize)) // Blue color with hex
            }
            icon.setScale(scaleFactor)
            icon.zPosition = 103
            icon.position = CGPoint(x: -choiceBg.size.width * 0.2 /*+ (icon.size.width / 2)*/, y: -choiceBg.size.height * 0.16)
            choiceBg.addChild(icon)
            
            // Skill Name Label with Block Stroke
            let skillNameLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
            let skillFontSize = 13.4 * scaleFactor
            skillNameLabel.fontSize = skillFontSize
            skillNameLabel.zPosition = 103
            skillNameLabel.horizontalAlignmentMode = .center
            skillNameLabel.verticalAlignmentMode = .center
            
            // Create an attributed string with stroke
            let strokeColor = UIColor.black
            let strokeWidth: CGFloat = CGFloat(Int(-4.0 * scaleFactor))  // Negative for both fill and stroke
            let textColor = UIColor(hex: "#614519") ?? .brown  // SaddleBrown color
            
            let attributes: [NSAttributedString.Key: Any] = [
                .strokeColor: strokeColor,
                .foregroundColor: textColor,
                .strokeWidth: strokeWidth,
                .font: UIFont(name: "InknutAntiqua-ExtraBold", size: skillFontSize) ?? UIFont.systemFont(ofSize: skillFontSize)
            ]
            
            let attributedText = NSAttributedString(string: skill.displayName, attributes: attributes)
            skillNameLabel.attributedText = attributedText
            skillNameLabel.position = CGPoint(x: 0, y: choiceBg.size.height * 0.33)
            choiceBg.addChild(skillNameLabel)
            
            // Description Labels with Text Wrapping
            let descriptionFontSize = 12 * scaleFactor
            let descriptionFont = UIFont(name: "InknutAntiqua-Regular", size: descriptionFontSize) ?? UIFont.systemFont(ofSize: descriptionFontSize)
            let descriptionColor = UIColor(hex: "#D3D3D3") ?? .lightGray  // LightGray color
            let descriptionText = skill.definition.type.skillDescription
            
            let descriptionMaxWidth = choiceBg.size.width * 0.6
            let descriptionLines = splitText(descriptionText, maxWidth: descriptionMaxWidth, font: descriptionFont)
            for (lineIndex, line) in descriptionLines.enumerated() {
                let descriptionLabel = SKLabelNode(fontNamed: "InknutAntiqua-Regular")
                descriptionLabel.fontSize = 8 * scaleFactor
                descriptionLabel.fontColor = descriptionColor
                descriptionLabel.zPosition = 103
                descriptionLabel.horizontalAlignmentMode = .left
                descriptionLabel.verticalAlignmentMode = .center
                descriptionLabel.position = CGPoint(x: 0, y:  (choiceBg.size.height * 0.05) - CGFloat(lineIndex) * 16 * scaleFactor) // Adjust vertical spacing as needed
                descriptionLabel.text = line
                choiceBg.addChild(descriptionLabel)
            }
            
            // Replace Next Level Label with Star System
            let currentLevel = skill.currentLevel
            let maxLevel = skill.definition.maxLevel
            let starSpacing: CGFloat = 22 * scaleFactor
            let startX: CGFloat = choiceBg.size.width * 0.05
            let maxStars = 4 // Assuming maxLevel is 4
            
            for i in 0..<maxStars {
                let starImageName = (i < currentLevel) ? "sk_select_star_full" : "sk_select_star_empty"
                let starNode = SKSpriteNode(imageNamed: starImageName)
                starNode.setScale(starScale)
                starNode.zPosition = 103
                let starX = startX + CGFloat(i) * starSpacing
                starNode.position = CGPoint(x: starX, y: -choiceBg.size.height * 0.35) // Position stars near the description
                choiceBg.addChild(starNode)
            }
            
            // Calculate the gap for the next choice
            let choiceGapY = choiceBg.size.height * -1.2
            yPos += choiceGapY
        }
    }
}
    
    // MARK: - Helper Methods
    
extension UpgradeShopOverlayNode {
    
    /// Splits the input text into multiple lines based on the maximum width and font.
    ///
    /// - Parameters:
    ///   - text: The input text to be split.
    ///   - maxWidth: The maximum width for each line.
    ///   - font: The font used for calculating the text size.
    /// - Returns: An array of strings, each representing a line of text.
    func splitText(_ text: String, maxWidth: CGFloat, font: UIFont) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        
        let words = text.split(separator: " ").map { String($0) }
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let testSize = (testLine as NSString).size(withAttributes: [.font: font])
            
            if testSize.width > maxWidth {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = word
                } else {
                    // Word itself is longer than maxWidth, force split
                    lines.append(word)
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
    
    // Override the touch handling to ensure it captures touches correctly
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchBegan(at: point)
    }
    
    func touchBegan(at point: CGPoint) {
        let nodesAtPoint = nodes(at: point)
        for node in nodesAtPoint {
            if let nodeName = node.name, nodeName.starts(with: "skillButton_") {
                let indexString = nodeName.replacingOccurrences(of: "skillButton_", with: "")
                if let index = Int(indexString), index < choices.count {
                    let chosenSkill = choices[index]
                    
                    // Animate the pressed choice
                    if let choiceNode = node as? SKSpriteNode {
                        let scaleDown = SKAction.scale(to: 0.9 * scaleFactor, duration: 0.1)
                        let scaleUp = SKAction.scale(to: 1.0 * scaleFactor, duration: 0.1)
                        let sequence = SKAction.sequence([scaleDown, scaleUp])
                        
                        choiceNode.run(sequence) { [weak self] in
                            // After animation completes, perform selection
                            SLHapticManager.shared.triggerImpact(style: .medium)
                            SLSoundManager.shared.playSoundEffect(.buttonPress)
                            self?.manager?.playerDidSelectSkill(chosenSkill)
                            self?.overlayManager?.closeCurrentOverlay(self!)
                            self?.removeFromParent()
                        }
                        
                        return
                    }
                }
            }
        }
    }
}

    
import UIKit

extension UIColor {
    
    /// Initializes a UIColor object using a hexadecimal string.
    ///
    /// - Parameter hex: The hexadecimal string representing the color. It can optionally start with a `#`.
    ///               It must be a 6-character string (RRGGBB).
    convenience init?(hex: String) {
        // Trim whitespace and uppercase the string
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Remove the '#' prefix if present
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        // The hex string must be exactly 6 characters
        guard hexSanitized.count == 6 else {
            print("Invalid hex string length. It should be 6 characters.")
            return nil
        }
        
        // Scan the hex value
        var rgbValue: UInt64 = 0
        let scanner = Scanner(string: hexSanitized)
        
        guard scanner.scanHexInt64(&rgbValue) else {
            print("Unable to scan hex value.")
            return nil
        }
        
        // Extract RGB components
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        // Initialize UIColor
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
