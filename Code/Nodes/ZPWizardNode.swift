import SpriteKit

class ZPWizard: SKSpriteNode {
    private var lastMeteorTime: TimeInterval = 0
    private var lastBeamTime: TimeInterval = 0
    private let meteorInterval: TimeInterval = 5.0
    private let beamInterval: TimeInterval = 8.0
    private let moveSpeed: CGFloat = 150.0
    private var currentDirection: CGVector = .zero
    private(set) var health: Int
    
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
        moveAlongScreenEdge(currentTime: currentTime)
        
        // Handle meteor attack
        if currentTime - lastMeteorTime >= meteorInterval {
            telegraphMeteor(at: playerPosition)
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
    
    private func telegraphMeteor(at targetPosition: CGPoint) {
        let warning = SKShapeNode(circleOfRadius: 30)
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
        let meteor = SKShapeNode(circleOfRadius: 20)
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
        meteor.run(

