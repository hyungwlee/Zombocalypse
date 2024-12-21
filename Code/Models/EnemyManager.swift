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

    func spawnRegularZombie(health: Double, speed: CGFloat) {
        guard let scene else { return }
        
        let zombie = ZPZombie(health: health, textureName: "sk_skeleton", speed: speed, desiredHeight: scene.layoutInfo.skeletonHeight)
        zombie.physicsBody = SKPhysicsBody(texture: zombie.texture!, size: zombie.size)
        zombie.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        zombie.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        zombie.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        zombie.physicsBody?.affectedByGravity = false
        zombie.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: scene.layoutInfo.enemySpawnSafeRadius, around: playerPosition, size: zombie.size) {
            zombie.position = spawnPosition
            zombie.alpha = 0.0
            
            scene.addChild(zombie)
            enemies.append(zombie)
            
            let fadeInDuration: TimeInterval = 0.3
            let fadeIn = SKAction.fadeIn(withDuration: fadeInDuration)
            zombie.run(fadeIn)
        }
    }
    
    func spawnChargerZombie(health: Double, speed: CGFloat) {
        guard let scene else { return }

        let charger = ZPChargerZombieNode(health: health, textureName: "sl_charger", movementSpeed: speed, desiredHeight: scene.layoutInfo.chargerHeight, scaleFactor: scene.layoutInfo.screenScaleFactor)
        charger.physicsBody = SKPhysicsBody(texture: charger.texture!, size: charger.size)
        charger.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        charger.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        charger.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        charger.physicsBody?.affectedByGravity = false
        charger.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: scene.layoutInfo.enemySpawnSafeRadius * 1.6, around: playerPosition, size: charger.size) {
            charger.position = spawnPosition
            charger.alpha = 0.0
            
            scene.addChild(charger)
            enemies.append(charger)
            
            let fadeInDuration: TimeInterval = 0.3
            let fadeIn = SKAction.fadeIn(withDuration: fadeInDuration)
            charger.run(fadeIn)
        }
    }
    
    func spawnExploderZombie(health: Double, speed: CGFloat) {
        guard let scene else { return }

        let exploder = ZPExploderZombieNode(health: health, textureName: "sk_exploder", movementSpeed: speed, desiredHeight: scene.layoutInfo.exploderHeight, scaleFactor: scene.layoutInfo.screenScaleFactor)
        exploder.physicsBody = SKPhysicsBody(texture: exploder.texture!, size: exploder.size)
        exploder.physicsBody?.categoryBitMask = PhysicsCategory.exploder
        exploder.physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.protectiveBarrier | PhysicsCategory.shield | PhysicsCategory.blade | PhysicsCategory.freeze
        exploder.physicsBody?.collisionBitMask = PhysicsCategory.border | PhysicsCategory.shield
        exploder.physicsBody?.affectedByGravity = false
        exploder.physicsBody?.allowsRotation = false
        
        if let spawnPosition = randomSpawnPosition(avoidingRadius: scene.layoutInfo.enemySpawnSafeRadius * 1.6, around: playerPosition, size: exploder.size){
            exploder.position = spawnPosition
            exploder.alpha = 0.0
            
            scene.addChild(exploder)
            enemies.append(exploder)
            
            let fadeInDuration: TimeInterval = 0.3
            let fadeIn = SKAction.fadeIn(withDuration: fadeInDuration)
            exploder.run(fadeIn)
        }
    }
    
    func spawnWizardBoss(health: Double, at spawnLocation: CGPoint) {
        guard let scene = scene else { return }

        wizardBoss?.removeFromParent()
        
        let wizard = ZPWizard(health: health, desiredHeight: scene.layoutInfo.bossHeight, spawnLocation: spawnLocation, screenScaleFactor: scene.layoutInfo.screenScaleFactor)
        
        wizard.physicsBody = SKPhysicsBody(rectangleOf: wizard.size)
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
    
    // MARK: - Update

    func updateEnemies(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint) {
        // Update each enemy
        for (index, enemy) in enemies.enumerated().reversed() {
            // Enemy-type specific update logic:
            if let charger = enemy as? ZPChargerZombieNode {
                charger.update(currentTime: currentTime, playerPosition: playerPosition)
            } else if let exploder = enemy as? ZPExploderZombieNode {
                exploder.update(currentTime: currentTime, playerPosition: playerPosition)
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
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.none
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.none
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let scale = enemy.xScale
        let scaleDown = SKAction.scale(to: scale * 0.5, duration: 0.1)
        let group = SKAction.group([fadeOut, scaleDown])
        
        enemy.run(group) {
            if let index = self.enemies.firstIndex(where: { $0 === enemy }) {
                self.enemies.remove(at: index)
            }
            enemy.removeFromParent()
        }
        
        let animationTimeout: TimeInterval = 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + animationTimeout) {
            if self.enemies.contains(where: { $0 === enemy }) {
                if let index = self.enemies.firstIndex(where: { $0 === enemy }) {
                    self.enemies.remove(at: index)
                }
                enemy.removeFromParent()
            }
        }
        
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
        guard let scene = scene else { return .zero }
        return scene.player.position
    }

    private func randomSpawnPosition(avoidingRadius: CGFloat, around point: CGPoint, size: CGSize) -> CGPoint? {
        guard let scene = scene else { return nil }
        var position: CGPoint
        let minY = scene.mapManager.bottomBound
        let maxY = scene.mapManager.topBound
        let minX = -scene.size.width / 2 + size.width / 2
        let maxX = scene.size.width / 2 - size.width / 2

        let despawnRadius = scene.layoutInfo.enemyDespawnDistance
        let maxAttempts = 100
        var attempts = 0

        while attempts < maxAttempts {
            position = CGPoint(
                x: CGFloat.random(in: minX...maxX),
                y: CGFloat.random(in: minY...maxY)
            )

            let clearOfEnemies = !enemies.contains(where: { $0.frame.contains(position) })
            let outsideSafeRadius = position.distance(to: point) >= avoidingRadius
            let outsideDespawnRadius = position.distance(to: point) <= despawnRadius
            let clearOfObstacles = scene.mapManager.positionIsClear(position: position, entitySize: size)
            
            if outsideSafeRadius && outsideDespawnRadius && clearOfEnemies && clearOfObstacles {
                return position
            }

            attempts += 1
        }

        return nil
    }
}
