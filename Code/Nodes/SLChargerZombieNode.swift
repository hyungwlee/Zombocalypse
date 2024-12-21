//
//  SLChargerZombieNode.swift
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

class SLChargerZombieNode: SLZombie {
    private var isCharging = false
    private var chargeCooldown: TimeInterval = 3.0 // 1-second cooldown after charge
    private var chargePreparationTime: TimeInterval = 2.0 // 2-second delay before charge
    private var lastChargeTime: TimeInterval = 0
    private var arrowNode: SKSpriteNode?
    
    private let scaleFactor: CGFloat
    
    private var swordNode: SKSpriteNode?
    private var chargeTargetPoint: CGPoint?
    
    // Initialize with chargerMovementSpeed, pass it to the super class SLZombie
    init(health: Double, textureName: String, movementSpeed chargerMovementSpeed: CGFloat, desiredHeight: CGFloat, scaleFactor: CGFloat) {
        self.scaleFactor = scaleFactor
        super.init(health: health, textureName: textureName, speed: chargerMovementSpeed, desiredHeight: desiredHeight)
        self.movementSpeed = chargerMovementSpeed
        self.baseSpeed = chargerMovementSpeed

        setupSwordNode()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSwordNode() {
        let swordTexture = SKTexture(imageNamed: "sl_sword")
        swordNode = SKSpriteNode(texture: swordTexture)
        guard let swordNode = swordNode else { return }

        swordNode.setScale(scaleFactor)
        
        swordNode.anchorPoint = CGPoint(x: 0.5, y: 0.25)
        swordNode.position = CGPoint(x: size.width * 0.9, y: size.height * -0.5)
                
        self.addChild(swordNode)
    }
    
    func update(currentTime: TimeInterval, playerPosition: CGPoint) {
        // Freeze grenade interupts and resets
        if isFrozen || isZombiePaused {
            self.removeAction(forKey: "chargeMovement")
            self.removeAction(forKey: "chargeCooldown")
            self.removeAction(forKey: "vibration")

            self.isCharging = false
            let cooldown = SKAction.wait(forDuration: self.chargeCooldown)
            self.run(cooldown, withKey: "chargeCooldown")
        }
        
        updateSwordOrientation(playerPosition: playerPosition)

        // Check if the zombie is close enough to prepare for a charge
        let distanceToPlayer = hypot(playerPosition.x - position.x, playerPosition.y - position.y)
        let chargeRange: CGFloat = 200.0 * scaleFactor

        if !isCharging && distanceToPlayer < chargeRange && currentTime - lastChargeTime > chargeCooldown {
            //print("Charger is preparing to charge! Distance: \(distanceToPlayer)")
            isCharging = true
            lastChargeTime = currentTime
            
            // Determine charge target point
            let chargeVector = vector(from: position, to: playerPosition)
            let chargeDistance: CGFloat = 200.0 * scaleFactor
            let normalizedVector = chargeVector.normalizedCZ
            let targetPoint = CGPoint(x: position.x + normalizedVector.dx * chargeDistance,
                                      y: position.y + normalizedVector.dy * chargeDistance)
            
            chargeTargetPoint = targetPoint

            // Display the indicator at the target point
            let targetIndicator = SKSpriteNode(color: .cyan, size: CGSize(width: 20 * scaleFactor, height: 20 * scaleFactor))
            targetIndicator.position = targetPoint
//            self.parent?.addChild(targetIndicator)
            targetIndicator.run(SKAction.sequence([
                SKAction.wait(forDuration: chargePreparationTime),
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))

            // Vibration effect during charge preparation
            let vibrationAction = SKAction.sequence([
                SKAction.moveBy(x: -5 * scaleFactor, y: 0, duration: 0.05),
                SKAction.moveBy(x: 10 * scaleFactor, y: 0, duration: 0.1),
                SKAction.moveBy(x: -5 * scaleFactor, y: 0, duration: 0.05)
            ])
            let vibrationLoop = SKAction.repeat(vibrationAction, count: Int(chargePreparationTime / 0.2))
            self.run(vibrationLoop, withKey: "vibration")
            
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
        } else {
//            print(distanceToPlayer, chargeRange, lastChargeTime, currentTime)
        }
    }
    
    private func updateSwordOrientation(playerPosition: CGPoint) {
        guard let swordNode = swordNode else { return }
        
        var targetPosition: CGPoint

        if isCharging, let chargeTarget = chargeTargetPoint {
            targetPosition = chargeTarget
        } else {
            targetPosition = playerPosition
        }
        
        let dx = targetPosition.x - position.x
        let dy = targetPosition.y - position.y
        
        let angle = atan2(dy, dx)
        
        let rotationOffset = -CGFloat.pi / 2 // -90 degrees
        
        swordNode.zRotation = angle + rotationOffset
    }
        
    private func moveToChargeTarget(targetPoint: CGPoint) {
        let moveToTarget = SKAction.move(to: targetPoint, duration: 0.5)
        self.run(moveToTarget, withKey: "chargeMovement")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isCharging = false
            let cooldown = SKAction.wait(forDuration: self.chargeCooldown)
            self.run(cooldown, withKey: "chargeCooldown")
        }
    }
    
    // Helper Function to subtract two CGPoints and return a CGVector
    private func vector(from pointA: CGPoint, to pointB: CGPoint) -> CGVector {
        return CGVector(dx: pointB.x - pointA.x, dy: pointB.y - pointA.y)
    }
}
