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
    
    // Initialize the bar with a given width and height
    init(width: CGFloat = 100, height: CGFloat = 20) {
        self.xpBarTexture = SKTexture(imageNamed: "sk_xp_bar")
        self.barWidth = xpBarTexture.size().width
        self.barHeight = xpBarTexture.size().height
        
        // Create the background of the XP bar
        backgroundNode = SKSpriteNode(texture: xpBarTexture)
        backgroundNode.size = CGSize(width: barWidth, height: barHeight)
        backgroundNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
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
        xpLabel.fontSize = 14
        xpLabel.fontColor = .white
        xpLabel.verticalAlignmentMode = .center
        xpLabel.horizontalAlignmentMode = .left
        // Position the XP label to the left of the bar
        xpLabel.position = CGPoint(x: -barWidth/2 - 10, y: 0)
        
        // Create labels
        thresholdLabel = SKLabelNode(fontNamed: "Arial")
        thresholdLabel.fontSize = 14
        thresholdLabel.fontColor = .white
        thresholdLabel.verticalAlignmentMode = .center
        thresholdLabel.horizontalAlignmentMode = .right
        // Position the threshold label to the right of the bar
        thresholdLabel.position = CGPoint(x: barWidth/2 + 10, y: 0)
        
        levelLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
        levelLabel.fontSize = 28
        levelLabel.fontColor = .systemGreen
        levelLabel.verticalAlignmentMode = .center
        levelLabel.horizontalAlignmentMode = .center
        // Position the level label above the middle of the bar
        levelLabel.position = CGPoint(x: 0, y: barHeight / 2 + 15)
        
        super.init()
        
        addChild(cropNode)
        addChild(backgroundNode)
        //addChild(fillNode) //Already being added to cropNode
        //addChild(thresholdLabel)
        //addChild(xpLabel)
        addChild(levelLabel)
        
        // Start at 0% progress
        updateBar()
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
        updateBar()
    }
    
    private func updateBar() {
//        let fraction = CGFloat(currentXP) / CGFloat(xpThreshold)
        let fraction = CGFloat(currentXP - (xpThreshold - xpToNextLevel)) / CGFloat(xpToNextLevel)
        let clampedFraction = min(max(fraction, 0), 1.0)
        
        let newWidth = barWidth * clampedFraction
          
        //Update the fill node path
        let newSize = CGSize(width: newWidth, height: barHeight)
        let newPath = CGPath(roundedRect: CGRect(origin: .zero, size: newSize), cornerWidth: barHeight / 4, cornerHeight: barHeight / 4, transform: nil)
        fillNode.path = newPath
        
        
        // Update labels
        //thresholdLabel.text = "\(xpThreshold)"
        //xpLabel.text = "\(currentXP)"
        levelLabel.text="\(currentLevel)"
    }
}
