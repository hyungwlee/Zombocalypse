//
//  XPBarNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/9/24.
//


import SpriteKit

class XPBarNode: SKNode {
    private let barWidth: CGFloat
    private let barHeight: CGFloat
    private let backgroundNode: SKSpriteNode
    private let fillNode: SKShapeNode
    private let cropNode: SKCropNode
    private let xpBarTexture: SKTexture
    
    private let thresholdLabel: SKLabelNode
    private let xpLabel: SKLabelNode
    private let levelLabel: SKLabelNode
    
    private var currentXP: Int = 0
    private var xpToNextLevel: Int = 1
    private var xpThreshold: Int = 1
    private var currentLevel: Int = 0
    
    private var previousFraction: CGFloat = 0.0
    private let animationDuration: TimeInterval = 0.3
    
    // Initialize the bar with a given width and height
    init(width: CGFloat) {
        self.xpBarTexture = SKTexture(imageNamed: "sk_xp_bar")
        backgroundNode = SKSpriteNode(texture: xpBarTexture)

        let scale = width / backgroundNode.size.width
        backgroundNode.setScale(scale)
        self.barWidth = backgroundNode.size.width
        self.barHeight = backgroundNode.size.height
        print(barWidth, barHeight)
        backgroundNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        print(backgroundNode.size)
        //Initialize the fill node with green color
        fillNode = SKShapeNode(rectOf: CGSize(width: 0, height: barHeight), cornerRadius: barHeight / 2)
        fillNode.fillColor = .green
        fillNode.strokeColor = .clear
        //fillNode.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillNode.position = CGPoint(x: -barWidth / 2, y: -barHeight / 2)
        
        //Initialize the crop node with a solid mask
        cropNode = SKCropNode()
        let maskShape = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: barHeight / 2)
        maskShape.fillColor = .white
        maskShape.strokeColor = .clear
        cropNode.maskNode = maskShape
        cropNode.position = CGPoint(x: 0, y: 0)
        
        //Add fillNode to cropNode
        cropNode.addChild(fillNode)
        
        xpLabel = SKLabelNode(fontNamed: "Arial")
        let xpLabelFontSize = barWidth * 0.04545454545
        xpLabel.fontSize = xpLabelFontSize
        xpLabel.fontColor = .white
        xpLabel.verticalAlignmentMode = .center
        xpLabel.horizontalAlignmentMode = .left
        // Position the XP label to the left of the bar
        xpLabel.position = CGPoint(x: -barWidth / 2 - 10, y: 0)
        
        // Create labels
        thresholdLabel = SKLabelNode(fontNamed: "Arial")
        
        let thresholdLabelFontSize = barWidth * 14 / 100
        thresholdLabel.fontSize = thresholdLabelFontSize
        thresholdLabel.fontColor = .white
        thresholdLabel.verticalAlignmentMode = .center
        thresholdLabel.horizontalAlignmentMode = .right
        // Position the threshold label to the right of the bar
        thresholdLabel.position = CGPoint(x: barWidth/2 + 10, y: 0)
        
//        levelLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
//        levelLabel.fontSize = 28
//        levelLabel.fontColor = .systemGreen
//        levelLabel.verticalAlignmentMode = .center
//        levelLabel.horizontalAlignmentMode = .center
//        // Position the level label above the middle of the bar
//        levelLabel.position = CGPoint(x: 0, y: barHeight / 2 + 15)
        levelLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
        let levelLabelFontSize = barWidth * 0.090909090909
        levelLabel.fontSize = levelLabelFontSize
        levelLabel.horizontalAlignmentMode = .center
        levelLabel.verticalAlignmentMode = .center
        
        let strokeColor = UIColor.black
        let strokeWidth: Int = -Int(barWidth * 0.0194805195)
        let textColor = UIColor(hex: "#21EF16") ?? .systemGreen
        
        let attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: strokeColor,
            .foregroundColor: textColor,
            .strokeWidth: strokeWidth,
            .font: UIFont(name: "InknutAntiqua-ExtraBold", size: levelLabelFontSize) ?? UIFont.systemFont(ofSize: levelLabelFontSize)
        ]
        
        let attributedText = NSAttributedString(string: "0", attributes: attributes)
        levelLabel.attributedText = attributedText
        levelLabel.position = CGPoint(x: 0, y: barHeight / 2 + 15)
        
        
        super.init()
        
        addChild(cropNode)
        addChild(backgroundNode)
        //addChild(fillNode) //Already being added to cropNode
        //addChild(thresholdLabel)
        //addChild(xpLabel)
        addChild(levelLabel)
        
        // Start at 0% progress
        updateBar(animated: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func checkLevelUp() {
        if currentXP >= xpThreshold {
            currentLevel += 1
        }
    }
    
    /// Update current XP and threshold, then redraw the bar and update labels
    func setXP(currentXP: Int, xpToNextLevel: Int, xpThreshold: Int) {
        self.currentXP = currentXP
        self.xpToNextLevel = xpToNextLevel
        self.xpThreshold = max(xpThreshold, 1) // Avoid division by zero
        checkLevelUp()
        updateBar(animated: true)
    }
    
    private func updateBar(animated: Bool) {
//        let fraction = CGFloat(currentXP) / CGFloat(xpThreshold)
        let fraction = CGFloat(currentXP - (xpThreshold - xpToNextLevel)) / CGFloat(xpToNextLevel)
        let clampedFraction = min(max(fraction, 0), 1.0)

        if animated {
            let duration = animationDuration
            let startFraction = previousFraction // Start from the current progress
            previousFraction = clampedFraction  // Update the stored progress fraction

            let animation = SKAction.customAction(withDuration: duration) { [weak self] node, elapsedTime in
                guard let self = self else { return }
                let progress = elapsedTime / CGFloat(duration)
                let currentFraction = startFraction + (clampedFraction - startFraction) * progress
                let currentWidth = self.barWidth * currentFraction
                let currentPath = CGPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: currentWidth, height: self.barHeight)), cornerWidth: self.barHeight / 2, cornerHeight: self.barHeight / 2, transform: nil)
                self.fillNode.path = currentPath
            }
            fillNode.run(animation)
        } else {
            previousFraction = clampedFraction
            let newWidth = barWidth * clampedFraction
            let newPath = CGPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: newWidth, height: barHeight)), cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil)
            fillNode.path = newPath
        }

        let levelLabelFontSize = barWidth * 0.090909090909
        let strokeColor = UIColor.black
        let strokeWidth: Int = -Int(barWidth * 0.0194805195)
        let textColor = UIColor(hex: "#21EF16") ?? .systemGreen
        
        let attributes: [NSAttributedString.Key: Any] = [
            .strokeColor: strokeColor,
            .foregroundColor: textColor,
            .strokeWidth: strokeWidth,
            .font: UIFont(name: "InknutAntiqua-ExtraBold", size: levelLabelFontSize) ?? UIFont.systemFont(ofSize: levelLabelFontSize)
        ]
        levelLabel.attributedText = NSAttributedString(string: "\(currentLevel)", attributes: attributes)
    }
}
