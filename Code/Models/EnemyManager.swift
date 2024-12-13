//
//  EnemyManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/10/24.
//


import SpriteKit

class EnemyManager {
    // References
    weak var scene: ZPGameScene?  // The scene in which enemies are placed
    var enemies: [ZPZombie] = []
    var wizardBoss: ZPWizard?  // If you have only one boss at a time
    
    init(scene: ZPGameScene) {
        self.scene = scene
    }
    
    // MARK: - Spawning

    func spawnRegularZombie(health: Double) {
        let zombie = ZPZombie(health: health)
        zombie.physicsBody = SKPhysicsBody(circleOfRadius: zombie.size.width / 2)
        zombie.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        zombie.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        zombie.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        zombie.physicsBody?.affectedByGravity = false
        zombie.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: 200, around: playerPosition, size: zombie.size) {
            zombie.position = spawnPosition
            scene?.addChild(zombie)
            enemies.append(zombie)
        }
    }
    
    func spawnChargerZombie(health: Double, speed: CGFloat) {
        let charger = ZPChargerZombieNode(health: health, movementSpeed: speed)
        charger.physicsBody = SKPhysicsBody(circleOfRadius: charger.size.width / 2)
        charger.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        charger.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        charger.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        charger.physicsBody?.affectedByGravity = false
        charger.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: 250, around: playerPosition, size: charger.size) {
            charger.position = spawnPosition
            scene?.addChild(charger)
            enemies.append(charger)
        }
    }
    
    func spawnExploderZombie(health: Double, speed: CGFloat) {
        let exploder = ZPExploderZombieNode(health: health, movementSpeed: speed)
        exploder.physicsBody = SKPhysicsBody(circleOfRadius: exploder.size.width / 2)
        exploder.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        exploder.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        exploder.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        exploder.physicsBody?.affectedByGravity = false
        exploder.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: 250, around: playerPosition, size: exploder.size) {
            exploder.position = spawnPosition
            scene?.addChild(exploder)
            enemies.append(exploder)
        }
    }
    
    func spawnWizardBoss(health: Double, at spawnLocation: CGPoint) {
        guard let scene = scene else { return }

        wizardBoss?.removeFromParent()
        
        let wizard = ZPWizard(health: health)
        
        wizard.physicsBody = SKPhysicsBody(circleOfRadius: wizard.size.width / 2)
        wizard.physicsBody?.categoryBitMask = PhysicsCategory.boss
        wizard.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        wizard.physicsBody?.collisionBitMask = PhysicsCategory.shield
        wizard.physicsBody?.affectedByGravity = false
        wizard.physicsBody?.allowsRotation = false
        
        wizard.position = spawnLocation
        scene.addChild(wizard)
        wizardBoss = wizard
    }
    
    func pauseAll() {
        for enemy in enemies {
            enemy.pause()
        }
        wizardBoss?.pause()
    }
    
    func resumeAll() {
        for enemy in enemies {
            enemy.resume()
        }
        wizardBoss?.resume()
    }

//    func pauseAll() {
//        guard !isPaused else { return }
//        isPaused = true
//        for enemy in enemies {
//            enemy.speed = 0
//            enemy.removeAllActions()
//        }
//    }
//    
//    func resumeAll() {
//        guard isPaused else { return }
//        isPaused = false
//        for enemy in enemies {
//            enemy.speed = 1
//            if !enemy.isDead {
//                enemy.moveTowards(playerPosition: playerPosition)
//            }
//        }
//    }
    
    // MARK: - Update

    func updateEnemies(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint) {
        // Update each enemy
        for (index, enemy) in enemies.enumerated().reversed() {
            // Enemy-type specific update logic:
            if let charger = enemy as? ZPChargerZombieNode {
                charger.update(deltaTime: currentTime, playerPosition: playerPosition)
            } else if let exploder = enemy as? ZPExploderZombieNode {
                exploder.update(deltaTime: currentTime, playerPosition: playerPosition)
            } else {
                // Regular zombies use their default movement
                enemy.moveTowards(playerPosition: playerPosition)
            }
            
            // Handle freezing logic for general zombie types
            enemy.updateFreezeState(currentTime: currentTime)
            
            preventZombieOverlap(for: enemy, at: index)
        }
        
        // Update Wizard Boss if present
        if let wizard = wizardBoss, wizard.isAlive {
            wizard.update(currentTime: currentTime, deltaTime: deltaTime, playerPosition: playerPosition)
        } else if wizardBoss?.isAlive == false {
            handleBossDefeat()
        }
    }
    
    // MARK: - Collision and Removal

    func removeEnemy(_ enemy: ZPZombie) {
        if let index = enemies.firstIndex(where: { $0 === enemy }) {
            enemies.remove(at: index)
        }
        enemy.removeFromParent()
        
        //Notify the scene to stop damaging if necessary
        scene?.damagingEnemies.remove(enemy)
    }
    
    func removeAllEnemies() {
        for enemy in enemies {
            enemy.removeFromParent()
        }
        enemies.removeAll()
        wizardBoss?.removeFromParent()
        wizardBoss = nil
    }
    
    // MARK: - Boss Management

    func handleBossDefeat() {
        // Inform scene or wave manager that boss has been defeated
        wizardBoss = nil
        // Handle any drops, overlays, or progression here
    }
    
    // MARK: - Helpers
    
    private func preventZombieOverlap(for zombie: ZPZombie, at index: Int) {
        for (otherIndex, otherZombie) in enemies.enumerated() where otherIndex != index {
            if zombie.frame.intersects(otherZombie.frame) {
                let zombieCenter = zombie.position
                let otherCenter = otherZombie.position
                let direction = CGVector(dx: zombieCenter.x - otherCenter.x, dy: zombieCenter.y - otherCenter.y)
                let distance = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
                let targetDistance = zombie.size.width / 2 + otherZombie.size.width / 2 + 10
                
                if distance < targetDistance {
                    let overlapDistance = targetDistance - distance
                    let normalizedDirection = CGVector(dx: direction.dx / distance, dy: direction.dy / distance)
                    let adjustment = CGVector(dx: normalizedDirection.dx * overlapDistance * 0.1, dy: normalizedDirection.dy * overlapDistance * 0.1)
                    zombie.position = CGPoint(x: zombie.position.x + adjustment.dx, y: zombie.position.y + adjustment.dy)
                }
            }
        }
    }
    
    private var playerPosition: CGPoint {
        // You can store a reference to the player or 
        // get it from the scene if player is publicly accessible.
        guard let gameScene = scene as? ZPGameScene else { return .zero }
        return gameScene.player.position
    }

    private func randomSpawnPosition(avoidingRadius: CGFloat, around point: CGPoint, size: CGSize) -> CGPoint? {
        guard let scene = scene else { return nil }
        var position: CGPoint
        let width = scene.size.width
        let height = scene.size.height

        repeat {
            position = CGPoint(x: CGFloat.random(in: size.width...width - size.width),
                               y: CGFloat.random(in: size.height...height - size.height))
        } while position.distance(to: point) < avoidingRadius || enemies.contains(where: { $0.frame.contains(position) })
        
        return position
    }
}
