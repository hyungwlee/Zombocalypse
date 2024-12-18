//
//  ZPExploderZombieNode.swift
//  Zombocalypse
//
//
//

import SpriteKit
import CoreGraphics

class ZPExploderZombieNode: ZPZombie {
    private var isPreparingToExplode = false
    private var explosionPreparationTime: TimeInterval = 2.0 // 2 seconds to charge before exploding
    private var lastExplosionAttemptTime: TimeInterval = 0
    private var explosionRange: CGFloat = 100.0 // Radius for area-of-effect damage
    private var explosionCooldown: TimeInterval = 1.0 // 1-second cooldown after exploding
    private var blastIndicator: SKShapeNode?
    
    // Initialize with movement speed, pass health to the superclass
    init(health: Double, textureName: String, movementSpeed exploderMovementSpeed: CGFloat) {
        super.init(health: health, textureName: textureName)
        self.movementSpeed = exploderMovementSpeed
        self.baseSpeed = exploderMovementSpeed
        self.baseColor = .purple // Unique color for the exploder
        self.color = baseColor
        configureBlastIndicator()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Configure the circular blast indicator with initial settings
    private func configureBlastIndicator() {
        // Create a circular shape node with the specified explosion range as radius
        blastIndicator = SKShapeNode(circleOfRadius: explosionRange * 2)
        
        // Configure the appearance of the blast indicator
        blastIndicator?.strokeColor = .red
        blastIndicator?.fillColor = .clear
        blastIndicator?.lineWidth = 2
        blastIndicator?.alpha = 0.3
        blastIndicator?.position = .zero // Ensure it's centered on the zombie
        addChild(blastIndicator!)
    }
    
    func update(currentTime: TimeInterval, playerPosition: CGPoint) {
        if isFrozen || isZombiePaused {
            removeAllActions()
            isPreparingToExplode = false
            blastIndicator?.alpha = 0.3
            blastIndicator?.fillColor = .clear
            return
        }
        
        let distanceToPlayer = hypot(playerPosition.x - position.x, playerPosition.y - position.y)
        
        if !isPreparingToExplode && distanceToPlayer < explosionRange && currentTime - lastExplosionAttemptTime > explosionCooldown {
            print("ex", distanceToPlayer, playerPosition, position)
            prepareToExplode()
            lastExplosionAttemptTime = currentTime
        } else if !isPreparingToExplode {
            moveTowards(playerPosition: playerPosition, speed: movementSpeed)
        }
    }
    
    private func prepareToExplode() {
        isPreparingToExplode = true
        
        // Start the blast radius fill-up animation
        blastIndicator?.fillColor = .orange
        let fillAnimation = SKAction.customAction(withDuration: explosionPreparationTime) { [weak self] node, elapsedTime in
            guard let self = self, let blastIndicator = self.blastIndicator else { return }
            let fillPercent = elapsedTime / CGFloat(self.explosionPreparationTime)
            blastIndicator.alpha = fillPercent
        }
        
        // Vibration effect before exploding
        let vibrationAction = SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.05),
            SKAction.moveBy(x: 10, y: 0, duration: 0.1),
            SKAction.moveBy(x: -5, y: 0, duration: 0.05)
        ])
        let vibrationLoop = SKAction.repeat(vibrationAction, count: Int(explosionPreparationTime / 0.2))
        
        // Explosion action after charging up
        let explodeAction = SKAction.run { [weak self] in
            self?.explode()
        }
        
        run(SKAction.group([vibrationLoop, fillAnimation]))
        run(SKAction.sequence([SKAction.wait(forDuration: explosionPreparationTime), explodeAction]))
    }
    
    private func explode() {
        guard let gameScene = scene as? ZPGameScene else { return }
        
        isPreparingToExplode = false
        blastIndicator?.alpha = 0.3
        blastIndicator?.fillColor = .clear
        
        let explosionDamage = self.health
        let explosionCenter = self.position
        //print("Exploding with damage: \(explosionDamage)")
        
        // Apply damage to zombies within the explosion radius
        gameScene.children.compactMap { $0 as? ZPZombie }.forEach { zombie in
            //Exclude self to prevent double handling
            if zombie === self { return }
            let distanceToZombie = hypot(zombie.position.x - explosionCenter.x, zombie.position.y - explosionCenter.y)
            if distanceToZombie <= explosionRange {
                zombie.takeDamage(amount: explosionDamage) // Adjust damage as needed
            }
        }
        // Apply damage to player if within explosion range
        let playerDistance = hypot(gameScene.player.position.x - explosionCenter.x, gameScene.player.position.y - explosionCenter.y)

        if playerDistance <= explosionRange {
            gameScene.playerLives -= explosionDamage
        }
        
        // Remove from parent after exploding
        gameScene.removeZombieFromTracking(self)
        removeFromParent()
        
        //Notify the scene that this enemy has been defeated
        gameScene.handleEnemyDefeat(at: explosionCenter)
        
    }

}

