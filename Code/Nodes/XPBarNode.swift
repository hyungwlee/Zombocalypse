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
    private let backgroundNode: SKShapeNode
    private let fillNode: SKShapeNode
    
    private let thresholdLabel: SKLabelNode
    private let xpLabel: SKLabelNode
    
    private var currentXP: Int = 0
    private var xpToNextLevel: Int = 1
    private var xpThreshold: Int = 1
    
    // Initialize the bar with a given width and height
    init(width: CGFloat = 100, height: CGFloat = 20) {
        self.barWidth = width
        self.barHeight = height
        
        // Create the background of the XP bar
        backgroundNode = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height/4)
        backgroundNode.fillColor = .darkGray
        backgroundNode.strokeColor = .clear
        
        // Create the fill portion of the XP bar
        fillNode = SKShapeNode(rectOf: CGSize(width: 0, height: height), cornerRadius: height/4)
        fillNode.fillColor = .green
        fillNode.strokeColor = .clear
        
        xpLabel = SKLabelNode(fontNamed: "Arial")
        xpLabel.fontSize = 14
        xpLabel.fontColor = .white
        xpLabel.verticalAlignmentMode = .center
        xpLabel.horizontalAlignmentMode = .left
        // Position the XP label to the left of the bar
        xpLabel.position = CGPoint(x: -width/2 - 10, y: 0)
        
        // Create labels
        thresholdLabel = SKLabelNode(fontNamed: "Arial")
        thresholdLabel.fontSize = 14
        thresholdLabel.fontColor = .white
        thresholdLabel.verticalAlignmentMode = .center
        thresholdLabel.horizontalAlignmentMode = .right
        // Position the threshold label to the right of the bar
        thresholdLabel.position = CGPoint(x: width/2 + 10, y: 0)
        
        super.init()
        
        addChild(backgroundNode)
        addChild(fillNode)
        addChild(thresholdLabel)
        addChild(xpLabel)
        
        // Start at 0% progress
        updateBar()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Update current XP and threshold, then redraw the bar and update labels
    func setXP(currentXP: Int, xpToNextLevel: Int, xpThreshold: Int) {
        self.currentXP = currentXP
        self.xpToNextLevel = xpToNextLevel
        self.xpThreshold = max(xpThreshold, 1) // Avoid division by zero
        updateBar()
    }
    
    private func updateBar() {
//        let fraction = CGFloat(currentXP) / CGFloat(xpThreshold)
        let fraction = CGFloat(currentXP - (xpThreshold - xpToNextLevel)) / CGFloat(xpToNextLevel)
        let clampedFraction = min(max(fraction, 0), 1.0)
        
        let newWidth = barWidth * clampedFraction
        
        // Update the fill node path with the new width
        let fillRect = CGRect(x: -barWidth/2, y: -barHeight/2, width: newWidth, height: barHeight)
        fillNode.path = CGPath(roundedRect: fillRect, cornerWidth: barHeight/4, cornerHeight: barHeight/4, transform: nil)
        
        // Update labels
        thresholdLabel.text = "\(xpThreshold)"
        xpLabel.text = "\(currentXP)"
    }
}
