import SpriteKit

class ZPWizard: SKSpriteNode {
    private var lastMeteorTime: TimeInterval = 0
    private var lastBeamTime: TimeInterval = 0
    private let meteorInterval: TimeInterval = 5.0
    private let beamInterval: TimeInterval = 8.0
    private let moveSpeed: CGFloat = 150.0
    private var currentDirection: CGVector = .zero
    private(set) var health: Int
    private var isChargingBeam: Bool = false // Prevents movement during beam charging

    init(health: Int = 100) {
        let texture = SKTexture(imageNamed: "wizard")
        self.health = health
        super.init(texture: texture, color: .clear, size: CGSize(width: 50, height: 50))
        self.name = "wizard"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(currentTime: TimeInterval, playerPosition: CGPoint) {
        if !isChargingBeam {
            moveAlongScreenEdge(currentTime: currentTime)
        }

        // Handle meteor attack
        if currentTime - lastMeteorTime >= meteorInterval {
            spawnRandomMeteors()
            lastMeteorTime = currentTime
        }

        // Handle beam attack
        if currentTime - lastBeamTime >= beamInterval {
            performBeamAttack(towards: playerPosition)
            lastBeamTime = currentTime
        }
    }

    func takeDamage(amount: Int) {
        health -= amount
        if health <= 0 {
            die()
        }
    }

    private func die() {
        let explosion = SKEmitterNode(fileNamed: "Explosion") // Optional: Add a visual effect
        explosion?.position = self.position
        scene?.addChild(explosion ?? SKNode())
        self.removeFromParent()
    }

    private func moveAlongScreenEdge(currentTime: TimeInterval) {
        if currentDirection == .zero {
            currentDirection = CGVector(dx: moveSpeed, dy: 0)
        }

        position.x += currentDirection.dx * CGFloat(1 / 60.0) // Assuming a frame rate of 60 FPS
        position.y += currentDirection.dy * CGFloat(1 / 60.0)

        // Check bounds and reverse direction if hitting the screen edge
        if position.x <= 0 || position.x >= scene!.size.width {
            currentDirection.dx *= -1
        }
        if position.y <= 0 || position.y >= scene!.size.height {
            currentDirection.dy *= -1
        }
    }

    private func spawnRandomMeteors() {
        for _ in 0..<3 {
            let randomX = CGFloat.random(in: 0...scene!.size.width)
            let randomY = CGFloat.random(in: 0...scene!.size.height)
            let targetPosition = CGPoint(x: randomX, y: randomY)
            telegraphMeteor(at: targetPosition)
        }
    }

    private func telegraphMeteor(at targetPosition: CGPoint) {
        let warning = SKShapeNode(circleOfRadius: 40) // Larger warning size
        warning.position = targetPosition
        warning.strokeColor = .red
        warning.lineWidth = 2
        scene?.addChild(warning)

        // Fade out the warning circle over 2 seconds and then drop the meteor
        let fadeOut = SKAction.fadeOut(withDuration: 2.0)
        let remove = SKAction.removeFromParent()
        let dropMeteor = SKAction.run { [weak self] in
            self?.spawnMeteor(at: targetPosition)
        }
        let sequence = SKAction.sequence([fadeOut, dropMeteor, remove])
        warning.run(sequence)
    }

    private func spawnMeteor(at position: CGPoint) {
        let meteor = SKShapeNode(circleOfRadius: 50) // Larger meteor size
        meteor.position = position
        meteor.fillColor = .orange
        meteor.strokeColor = .red
        meteor.lineWidth = 3
        scene?.addChild(meteor)

        // Deal damage to the player if the meteor lands
        if let scene = scene as? ZPGameScene, meteor.frame.intersects(scene.player.frame) {
            scene.playerLives -= 1
        }

        // Remove the meteor after a short delay
        let remove = SKAction.removeFromParent()
        let wait = SKAction.wait(forDuration: 0.5)
        meteor.run(SKAction.sequence([wait, remove]))
    }

    private func performBeamAttack(towards targetPosition: CGPoint) {
        isChargingBeam = true // Stop moving while charging the beam

        // Telegraph the beam attack
        let warning = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: position)
        path.addLine(to: extendedBeamEnd(from: position, to: targetPosition))
        warning.path = path
        warning.strokeColor = .red
        warning.lineWidth = 2
        warning.alpha = 0.5
        scene?.addChild(warning)

        // Animate the warning to flash
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.3)
        let flash = SKAction.sequence([fadeIn, fadeOut])
        let repeatFlash = SKAction.repeat(flash, count: 5)

        // After telegraphing, spawn the actual beam
        let spawnBeam = SKAction.run { [weak self] in
            self?.spawnBeam(towards: targetPosition)
        }

        // Remove the telegraphing warning
        let removeWarning = SKAction.removeFromParent()
        let resumeMovement = SKAction.run { [weak self] in
            self?.resumeMovementAfterDelay()
        }
        let sequence = SKAction.sequence([repeatFlash, spawnBeam, removeWarning, resumeMovement])
        warning.run(sequence)
    }

    private func spawnBeam(towards targetPosition: CGPoint) {
        let beam = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: position)
        path.addLine(to: extendedBeamEnd(from: position, to: targetPosition))
        beam.path = path
        beam.strokeColor = .yellow
        beam.lineWidth = 5
        beam.alpha = 0.7
        scene?.addChild(beam)

        // Continuously check for collision while the beam exists
        let dealDamage = SKAction.run { [weak self] in
            if let scene = self?.scene as? ZPGameScene, beam.frame.intersects(scene.player.frame) {
                scene.playerLives -= 1
            }
        }

        // Remove the beam after a short delay
        let remove = SKAction.removeFromParent()
        let wait = SKAction.wait(forDuration: 1.0)
        beam.run(SKAction.sequence([SKAction.repeat(dealDamage, count: 10), wait, remove]))
    }

    private func extendedBeamEnd(from start: CGPoint, to target: CGPoint) -> CGPoint {
        let dx = target.x - start.x
        let dy = target.y - start.y
        let magnitude = sqrt(dx * dx + dy * dy)
        let normalized = CGPoint(x: dx / magnitude, y: dy / magnitude)
        let extendedDistance: CGFloat = 1000 // Extend the beam far beyond the target
        return CGPoint(x: start.x + normalized.x * extendedDistance, y: start.y + normalized.y * extendedDistance)
    }

    private func resumeMovementAfterDelay() {
        let delay = SKAction.wait(forDuration: 1.0) // 1 second delay
        let resume = SKAction.run { [weak self] in
            self?.isChargingBeam = false // Resume movement
        }
        self.run(SKAction.sequence([delay, resume]))
    }
}
