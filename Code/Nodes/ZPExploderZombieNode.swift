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
    private var exploderMovementSpeed: CGFloat
    
    // Initialize with movement speed, pass health to the superclass
    init(health: Double, movementSpeed exploderMovementSpeed: CGFloat) {
        self.exploderMovementSpeed = exploderMovementSpeed
        super.init(health: health)
        self.color = .purple // Unique color for the exploder
        configureBlastIndicator()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Configure the circular blast indicator with initial settings
    private func configureBlastIndicator() {
        let circlePath = CGPath(ellipseIn: CGRect(x: -explosionRange, y: -explosionRange, width: explosionRange * 2, height: explosionRange * 2), transform: nil)
        blastIndicator = SKShapeNode(path: circlePath)
        blastIndicator?.strokeColor = .red
        blastIndicator?.fillColor = .clear
        blastIndicator?.lineWidth = 2
        blastIndicator?.alpha = 0.3
        if let blastIndicator = blastIndicator {
            addChild(blastIndicator)
        }
    }
    
    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let distanceToPlayer = hypot(playerPosition.x - position.x, playerPosition.y - position.y)
        
        if !isPreparingToExplode && distanceToPlayer < explosionRange && deltaTime - lastExplosionAttemptTime > explosionCooldown {
            prepareToExplode()
            lastExplosionAttemptTime = deltaTime
        } else if !isPreparingToExplode {
            moveToward(playerPosition)
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
        isPreparingToExplode = false
        blastIndicator?.alpha = 0.3
        blastIndicator?.fillColor = .clear
        
        let explosionDamage = self.health
        let explosionCenter = self.position
        //print("Exploding with damage: \(explosionDamage)")
        
        guard let gameScene = parent as? ZPGameScene else {
            return
        }
        
        // Remove from parent after exploding
        gameScene.removeZombieFromTracking(self)
        removeFromParent()
        
        
        // Apply damage to zombies within the explosion radius
        gameScene.children.compactMap { $0 as? ZPZombie }.forEach { zombie in
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
        
    }
    
    private func moveToward(_ target: CGPoint) {
        // Standard movement toward the target
        let offset = CGPoint(x: target.x - position.x, y: target.y - position.y)
        let direction = CGVector(dx: offset.x, dy: offset.y).normalized
        let movementVector = CGVector(dx: direction.dx * exploderMovementSpeed, dy: direction.dy * exploderMovementSpeed)
        position = CGPoint(x: position.x + movementVector.dx, y: position.y + movementVector.dy)
    }
}

