import SpriteKit

class ZPWizard: SKSpriteNode {
    var health: Int {
        didSet {
            healthLabel.text = "\(health)"
        }
    }
    var isDead: Bool {
        return health <= 0
    }

    private let healthLabel: SKLabelNode
    private var isPreparingBeamAttack = false

    init(health: Int) {
        self.health = health
        self.healthLabel = SKLabelNode(text: "\(health)")
        let size = CGSize(width: 40, height: 40)
        super.init(texture: nil, color: .purple, size: size)
        healthLabel.fontSize = 26
        healthLabel.fontColor = .white
        healthLabel.position = CGPoint(x: 0, y: size.height / 2 + 10)
        addChild(healthLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func moveAlongEdges(screenSize: CGSize) {
        // Move the wizard along the edge of the screen in a clockwise direction
        let edgePath = SKAction.sequence([
            SKAction.moveTo(x: screenSize.width - size.width / 2, duration: 2),
            SKAction.moveTo(y: screenSize.height - size.height / 2, duration: 2),
            SKAction.moveTo(x: size.width / 2, duration: 2),
            SKAction.moveTo(y: size.height / 2, duration: 2)
        ])
        run(SKAction.repeatForever(edgePath))
    }

    func castMeteorAttack(scene: ZPGameScene) {
        let numberOfMeteors = 3 // Number of meteors per attack
        for _ in 0..<numberOfMeteors {
            let targetPosition = CGPoint(
                x: CGFloat.random(in: 0...scene.size.width),
                y: CGFloat.random(in: 0...scene.size.height)
            )

            // Telegraph meteor impact with a circle
            let warningCircle = SKShapeNode(circleOfRadius: 30)
            warningCircle.position = targetPosition
            warningCircle.strokeColor = .red
            warningCircle.lineWidth = 3
            scene.addChild(warningCircle)
            
            // Delay before meteor hits
            let delay = SKAction.wait(forDuration: 2.0)
            let removeWarning = SKAction.removeFromParent()
            warningCircle.run(SKAction.sequence([delay, removeWarning]))

            // Meteor impact after warning
            let meteor = SKShapeNode(circleOfRadius: 30)
            meteor.fillColor = .orange
            meteor.position = targetPosition
            meteor.alpha = 0

            scene.addChild(meteor)
            meteor.run(SKAction.sequence([
                delay,
                SKAction.fadeAlpha(to: 1, duration: 0.2),
                SKAction.scale(to: 1.5, duration: 0.1),
                SKAction.run {
                    if meteor.frame.intersects(scene.player.frame) {
                        scene.handlePlayerHit()
                    }
                },
                SKAction.removeFromParent()
            ]))
        }
    }
    
    func castBeamAttack(scene: ZPGameScene) {
        guard !isPreparingBeamAttack else { return } // Prevent multiple simultaneous beams
        isPreparingBeamAttack = true

        let targetPosition = scene.player.position
        let beamWarning = SKShapeNode(rectOf: CGSize(width: 10, height: scene.size.height))
        beamWarning.position = CGPoint(x: targetPosition.x, y: scene.size.height / 2)
        beamWarning.fillColor = .red
        beamWarning.alpha = 0.5
        scene.addChild(beamWarning)

        // Show the warning for a short period before the beam attack
        let delay = SKAction.wait(forDuration: 1.5)
        let removeWarning = SKAction.removeFromParent()
        beamWarning.run(SKAction.sequence([delay, removeWarning]))

        // Beam attack after warning
        let beam = SKShapeNode(rectOf: CGSize(width: 10, height: scene.size.height))
        beam.position = CGPoint(x: targetPosition.x, y: scene.size.height / 2)
        beam.fillColor = .yellow
        beam.alpha = 0

        scene.addChild(beam)
        beam.run(SKAction.sequence([
            delay,
            SKAction.fadeAlpha(to: 1, duration: 0.1),
            SKAction.scaleX(to: 1.5, duration: 0.3),
            SKAction.run {
                if beam.frame.intersects(scene.player.frame) {
                    scene.handlePlayerHit()
                }
            },
            SKAction.removeFromParent(),
            SKAction.run { self.isPreparingBeamAttack = false }
        ]))
    }
}
