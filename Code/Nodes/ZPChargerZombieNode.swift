//
//  ZPChargerZombieNode.swift
//  Zombocalypse
//
//  
//

import SpriteKit
import CoreGraphics

// CGVector extension for vector calculations
extension CGVector {
    var magnitude: CGFloat {
        return sqrt(dx * dx + dy * dy)
    }
    var normalizedCZ: CGVector {
        let mag = magnitude
        return mag == 0 ? CGVector(dx: 0, dy: 0) : CGVector(dx: dx / mag, dy: dy / mag)
    }
}

class ZPChargerZombieNode: ZPZombie {
    private var isCharging = false
    private var chargeCooldown: TimeInterval = 1.0 // 1-second cooldown after charge
    private var chargePreparationTime: TimeInterval = 2.0 // 2-second delay before charge
    private var lastChargeTime: TimeInterval = 0
    private var arrowNode: SKSpriteNode?
    
    // Initialize with chargerMovementSpeed, pass it to the super class ZPZombie
    init(health: Double, movementSpeed chargerMovementSpeed: CGFloat) {
        super.init(health: health)
        self.movementSpeed = chargerMovementSpeed
        self.baseSpeed = chargerMovementSpeed
        self.baseColor = .orange // Set the color to indicate it's a charger zombie
        self.color = baseColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        // Freeze grenade interupts and resets
        if isFrozen {
            self.removeAllActions()
            self.isCharging = false
            let cooldown = SKAction.wait(forDuration: self.chargeCooldown)
            self.run(cooldown)
        }

        // Check if the zombie is close enough to prepare for a charge
        let distanceToPlayer = hypot(playerPosition.x - position.x, playerPosition.y - position.y)
        let chargeRange: CGFloat = 200.0 // Adjust this value as needed

        if !isCharging && distanceToPlayer < chargeRange && deltaTime - lastChargeTime > chargeCooldown {
            //print("Charger is preparing to charge! Distance: \(distanceToPlayer)")
            isCharging = true
            lastChargeTime = deltaTime
            
            // Determine charge target point
            let chargeVector = vector(from: position, to: playerPosition)
            let chargeDistance: CGFloat = 200.0 // Adjust charge distance as needed
            let normalizedVector = chargeVector.normalizedCZ
            let targetPoint = CGPoint(x: position.x + normalizedVector.dx * chargeDistance,
                                      y: position.y + normalizedVector.dy * chargeDistance)

            // Display the indicator at the target point
            let targetIndicator = SKSpriteNode(color: .cyan, size: CGSize(width: 20, height: 20))
            targetIndicator.position = targetPoint
            self.parent?.addChild(targetIndicator)
            targetIndicator.run(SKAction.sequence([
                SKAction.wait(forDuration: chargePreparationTime),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))

            // Vibration effect during charge preparation
            let vibrationAction = SKAction.sequence([
                SKAction.moveBy(x: -5, y: 0, duration: 0.05),
                SKAction.moveBy(x: 10, y: 0, duration: 0.1),
                SKAction.moveBy(x: -5, y: 0, duration: 0.05)
            ])
            let vibrationLoop = SKAction.repeat(vibrationAction, count: Int(chargePreparationTime / 0.2))
            self.run(vibrationLoop)

            // Prepare and perform charge
            let prepareToCharge = SKAction.wait(forDuration: chargePreparationTime)
            let chargeAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.removeAllActions() // Stop vibration before charging
                self.moveToChargeTarget(targetPoint: targetPoint)
            }
            run(SKAction.sequence([prepareToCharge, chargeAction]))
        } else if !isCharging {
            // Regular zombie movement if not in charging mode
            moveTowards(playerPosition: playerPosition, speed: movementSpeed)
        }
    }
        
    private func moveToChargeTarget(targetPoint: CGPoint) {
        let moveToTarget = SKAction.move(to: targetPoint, duration: 0.5)
        self.run(moveToTarget) {
            self.isCharging = false
            let cooldown = SKAction.wait(forDuration: self.chargeCooldown)
            self.run(cooldown)
        }
    }
    
    // Helper Function to subtract two CGPoints and return a CGVector
    private func vector(from pointA: CGPoint, to pointB: CGPoint) -> CGVector {
        return CGVector(dx: pointB.x - pointA.x, dy: pointB.y - pointA.y)
    }
}
