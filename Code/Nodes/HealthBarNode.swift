//
//  HealthBarNode.swift
//  Zombocalypse
//
//
//

import SpriteKit

class HealthBarNode: SKNode {
    
    // MARK: - Properties
    
    private let backgroundBar: SKSpriteNode
    private let foregroundBar: SKSpriteNode
    private let size: CGSize
    private let maxHealth: Double
    private var currentHealth: Double
    
    // Optional progress bar for shooting intervals
    private var progressBar: SKSpriteNode?
    private let progressBarHeight: CGFloat = 5
    private let progressBarWidthRatio: CGFloat = 1.0 // 80% of health bar width
    
    // MARK: - Initialization
    
    /**
     Initializes a HealthBar.
     
     - Parameters:
        - size: The size of the health bar.
        - maxHealth: The maximum health value.
        - foregroundColor: The color representing current health.
        - backgroundColor: The color representing lost health.
        - showProgressBar: A Boolean indicating whether to show a progress bar (used for the player).
     */
    init(size: CGSize, maxHealth: Double, foregroundColor: SKColor, backgroundColor: SKColor, showProgressBar: Bool = false, progressColor: SKColor = .blue) {
        self.size = size
        self.maxHealth = maxHealth
        self.currentHealth = maxHealth
        
        // Initialize background bar
        backgroundBar = SKSpriteNode(color: backgroundColor, size: size)
        backgroundBar.anchorPoint = CGPoint(x: 0, y: 0.5) // Left-center
        backgroundBar.position = CGPoint(x: -size.width / 2, y: 0)
        
        // Initialize foreground bar
        foregroundBar = SKSpriteNode(color: foregroundColor, size: size)
        foregroundBar.anchorPoint = CGPoint(x: 0, y: 0.5) // Left-center
        foregroundBar.position = CGPoint(x: -size.width / 2, y: 0)
        
        super.init()
        
        addChild(backgroundBar)
        addChild(foregroundBar)
        
        // If a progress bar is needed (for the player)
        if showProgressBar {
            let progressSize = CGSize(width: size.width * progressBarWidthRatio, height: progressBarHeight)
            progressBar = SKSpriteNode(color: progressColor, size: size)
            progressBar?.anchorPoint = CGPoint(x: 0, y: 0.5)
            progressBar?.position = CGPoint(x: -size.width / 2, y: 0)
            if let progress = progressBar {
                addChild(progress)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Methods
    
    /**
     Updates the health bar based on the current health.
     
     - Parameter health: The new health value.
     */
    func setHealth(_ health: Double) {
        currentHealth = max(0, min(health, maxHealth)) // Clamp the value between 0 and maxHealth
        let healthPercentage = CGFloat(currentHealth / maxHealth)
        foregroundBar.size.width = size.width * healthPercentage
        
        // Optional: Animate the change
        let resizeAction = SKAction.resize(toWidth: size.width * healthPercentage, duration: 0.2)
        foregroundBar.run(resizeAction)
    }
    
    /**
     Updates the progress bar's progress.
     
     - Parameter progress: A value between 0 and 1 representing the progress.
     */
    func setProgress(_ progress: CGFloat) {
        guard let progressBar = progressBar else { return }
        let clampedProgress = max(0, min(progress, 1))
        let progressBackgroundWidth = backgroundBar.size.width * progressBarWidthRatio
        let newWidth = progressBackgroundWidth * clampedProgress
        progressBar.size.width = newWidth
        
        // Optional: Animate the change
        let resizeAction = SKAction.resize(toWidth: newWidth, duration: 0.01)
        progressBar.run(resizeAction)
    }
    
    /**
     Resets the progress bar to full.
     */
    func resetProgress() {
        setProgress(1.0)
    }
    
    /**
     Resets the health bar to full health.
     */
    func resetHealth() {
        setHealth(maxHealth)
    }
}
