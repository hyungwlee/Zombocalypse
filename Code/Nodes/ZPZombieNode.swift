//
//  ZPZombieNode.swift
//  Zombocalypse
//
//
//

import SpriteKit

class ZPZombie: SKSpriteNode {
    var baseColor: SKColor = .red
    
    var movementSpeed: CGFloat = 0.4
    var baseSpeed: CGFloat = 0.4
    var isSlowedByBarrier = false
    
    var isAttacking: Bool = false
    var hitPlayerCooldown: TimeInterval = 1.0
    var lastHitPlayerTime: TimeInterval = 0
    var lastSpinningBladeDamageTime: TimeInterval = 0
    var lastBarrierDamageTime: TimeInterval = 0
    var lastShieldHitTime: TimeInterval = 0.0
    
    var isZombiePaused: Bool = false
    var isFrozen: Bool = false
    var freezeEndTime: TimeInterval = 0
    private let healthBar: HealthBarNode
    private var iceNode: SKSpriteNode?
    
    private var isFlashing: Bool = false
    private var deathFrames: [SKTexture] = []
    
    var health: Double {
        didSet{
            healthBar.setHealth(health)
            //Commenting this out deals with zombies not decrementing count in pendingEnemies when caught in explosion
            //Leaving here for now just in case this breaks something later down the line
//            if isDead {
//                removeFromParent()
//            }
        }
    }
    var isDead: Bool {
        return health <= 0
    }
    
    //private let healthLabel: SKLabelNode
    
    
    init(health: Double, textureName: String) {

        //self.healthLabel = SKLabelNode(text: "Enemy | HP: \(health)")
        let skeletonTexture = SKTexture(imageNamed: textureName)
        
        self.health = health
        let barSize = CGSize(width: skeletonTexture.size().width * 0.9, height: 10)
        self.healthBar = HealthBarNode(size: barSize, maxHealth: health, foregroundColor: .red, backgroundColor: .darkGray)
        super.init(texture: skeletonTexture, color: .red, size: skeletonTexture.size())
        setScale(0.35)
        
        healthBar.position = CGPoint(x: 0, y: skeletonTexture.size().height * 0.6)
//        healthLabel.fontSize = 20
//        healthLabel.fontColor = .black
//        healthLabel.position = CGPoint(x: 0, y: size.height / 2 + 10)
        addChild(healthBar)
        
        loadDeathAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
        
    }
    
    private func loadDeathAnimation() {
        let frameCount = 14
        deathFrames = (1...frameCount).map { frameNumber in
            SKTexture(imageNamed: "sk_skeleton_death_\(frameNumber)")
        }
    }
    
    func die() {
        // Disable physics to prevent further interactions
        self.physicsBody?.categoryBitMask = PhysicsCategory.none
        self.physicsBody?.contactTestBitMask = PhysicsCategory.none
        self.physicsBody?.collisionBitMask = PhysicsCategory.none
        
        // Optionally, disable any movement or actions
        self.removeAllActions()
        
        // Create a sequence of actions to update texture and size
        var actions: [SKAction] = []
        
        for texture in deathFrames {
            // Create an action to set the texture and adjust size
            let setTexture = SKAction.setTexture(texture)
            
            // Calculate the new size based on the texture
            let newSize = texture.size()
            let resize = SKAction.resize(toWidth: newSize.width, height: newSize.height, duration: 0.05)
//            let resize = SKAction.resize(toWidth: newSize.width * 0.35, height: newSize.height * 0.35, duration: 0.05)
            
            // Optionally, you can animate the size change smoothly
            let group = SKAction.group([setTexture, resize])
            
            actions.append(group)
        }
        
        // Add an action to remove the node after the animation
        let removeAction = SKAction.removeFromParent()
        actions.append(removeAction)
        
        // Run the sequence of actions
        let sequence = SKAction.sequence(actions)
        
        self.run(sequence) { [weak self] in
            guard let self = self else { return }
            if let gameScene = self.scene as? ZPGameScene {
                // Remove the zombie from the enemy manager
                gameScene.enemyManager.removeEnemy(self)
            }
        }
    }
    
    func moveTowards(playerPosition: CGPoint, speed: CGFloat? = nil) {
        guard !isAttacking else { return }
        if isFrozen || isZombiePaused {
            return
        }
        let updatedSpeed = speed ?? movementSpeed

        let direction = CGVector(dx: playerPosition.x - self.position.x, dy: playerPosition.y - self.position.y)
        let length = hypot(direction.dx, direction.dy)
        
        if length > 0 { // Check if the enemy is not at the player's position
            let normalizedDirection = CGVector(dx: direction.dx / length, dy: direction.dy / length)
            self.position = CGPoint(x: self.position.x + normalizedDirection.dx * updatedSpeed,
                                    y: self.position.y + normalizedDirection.dy * updatedSpeed)
        }
    }
    
    func takeDamage(amount: Double) {
        health -= amount
        flashRed() // Trigger the flash effect when taking damage
        if isDead {
            if let gameScene = self.scene as? ZPGameScene {
                gameScene.handleEnemyDefeat(at: self.position)
                gameScene.enemyManager.removeEnemy(self)
//                self.die()
            }
//            removeFromParent()
        }
    }
    
    func freeze(currentTime: TimeInterval, duration: TimeInterval) {
        isFrozen = true
        freezeEndTime = currentTime + duration
        addIceNode()
    }
    
    func updateFreezeState(currentTime: TimeInterval) {
        if isFrozen && currentTime >= freezeEndTime {
            unfreeze()
        }
    }
    
    func unfreeze() {
        isFrozen = false
        removeIceNode()
    }
    
    func pause() {
        isZombiePaused = true
    }
    
    func resume() {
        isZombiePaused = false
    }
    
    private func addIceNode() {
        if iceNode != nil { return }
        
        let ice = SKSpriteNode(imageNamed: "sk_ice")
        ice.name = "iceNode"
        ice.setScale(0.0)
        ice.zPosition = self.zPosition + 1
        ice.position = CGPoint.zero
        
        addChild(ice)
        self.iceNode = ice
        
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let spawnGroup = SKAction.group([scaleUp, fadeIn])
        ice.run(spawnGroup)
    }
    
    private func removeIceNode() {
        guard let ice = iceNode else { return }
        
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.1)
        let scaleDown = SKAction.scale(to: 0.0, duration: 0.1)
        let remove = SKAction.removeFromParent()
        let group = SKAction.group([fadeOut, scaleDown])
        let sequence = SKAction.sequence([group, remove])
        ice.run(sequence)
        
        iceNode = nil
    }
    
    private func flashRed() {
        guard !isFlashing else { return }
        isFlashing = true
        
        let flashDuration: TimeInterval = 0.2
        let originalColor = self.color
        let flashColor = SKColor.white
        
        let colorizeToFlash = SKAction.colorize(with: flashColor, colorBlendFactor: 1.0, duration: 0.05)
        let colorizeBack = SKAction.colorize(with: originalColor, colorBlendFactor: 1.0, duration: 0.05)
        
        let flashSequence = SKAction.sequence([colorizeToFlash, colorizeBack])
        
        let repeatFlash = SKAction.repeat(flashSequence, count: 1)
        
        let completion = SKAction.run { [weak self] in
            self?.isFlashing = false
            self?.colorBlendFactor = 0.0
        }
        
        self.run(SKAction.sequence([repeatFlash, completion]))
    }
}
