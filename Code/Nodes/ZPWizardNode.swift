//
//  ZPWizardNode.swift
//  Zombocalypse
//
//
//


import SpriteKit
import Foundation

class ZPWizard: SKSpriteNode {
    //Texture settings
    private let textureLeft: SKTexture
    private let textureRight: SKTexture
    private let spawnImage: SKSpriteNode
    private var spawnAnimationStarted: Bool = false
    private var hasSpawned: Bool = false
    private var isFlashing: Bool = false
    
    private var iceNode: SKSpriteNode?

    
    var lastSpinningBladeDamageTime: TimeInterval = 0
    var lastBarrierDamageTime: TimeInterval = 0
    var isFrozen: Bool = false
    var isBossPaused: Bool = false
    var freezeEndTime: TimeInterval = 0
    private var lastMeteorTime: TimeInterval = 0
    private var lastBeamTime: TimeInterval = 0
    private let meteorInterval: TimeInterval = 5.0
    private let beamInterval: TimeInterval = 8.0
    public var movementSpeed: CGFloat = 150.0
    public let baseSpeed: CGFloat
    private var currentDirection: CGVector = .zero
    var health: Double {
        didSet {
            healthBar.setHealth(health)
        }
    }
    private let healthBar: HealthBarNode
    private var isChargingBeam: Bool = false
    private var playerHitByBeam: Bool = false
    public var isAlive: Bool = true
    var baseColor: SKColor = .clear
    var isSlowedByBarrier: Bool = false
    private var fireballFrames: [SKTexture] = []
    
    private let bossScale: CGFloat
    private let screenScaleFactor: CGFloat
    private let spawnLocation: CGPoint

    init(health: Double, desiredHeight: CGFloat, spawnLocation: CGPoint, screenScaleFactor: CGFloat) {
        self.health = health
        self.textureLeft = SKTexture(imageNamed: "sk_wizard_left")
        self.textureRight = SKTexture(imageNamed: "sk_wizard_right")
        self.spawnImage = SKSpriteNode(imageNamed: "sk_wizard_spawn")
        self.spawnImage.size = CGSize(width: spawnImage.size.width, height: spawnImage.size.height)
        self.spawnImage.position = CGPoint(x: 0, y: 0)
        self.spawnImage.zPosition = 11
        
        let barSize = CGSize(width: textureRight.size().width * 0.885, height: textureRight.size().width * 0.133)
        
        self.healthBar = HealthBarNode(size: barSize, maxHealth: health, foregroundColor: .red, backgroundColor: .darkGray)
        healthBar.position = CGPoint(x: 0, y: textureRight.size().height * 0.6)
        
        self.movementSpeed *= screenScaleFactor
        self.baseSpeed = movementSpeed
        self.bossScale = desiredHeight / textureRight.size().height
        self.screenScaleFactor = screenScaleFactor
        self.spawnLocation = spawnLocation

        
        //Set initial texture to facing right
        super.init(texture: textureRight, color: baseColor, size: textureRight.size())
        
        self.setScale(bossScale)
        
        self.name = "wizard"
        self.addChild(healthBar)
        
        loadFireballAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(currentTime: TimeInterval, deltaTime: TimeInterval, playerPosition: CGPoint) {
        let cappedDeltaTime = min(deltaTime, 1.0 / 60.0 * 2) // max 2 frames worth // Used to prevent weird movement while paused
        updateFreezeState(currentTime: currentTime)
        
        //Trigger spawn animation once when the wizard is added to the scene
        if !spawnAnimationStarted && scene != nil {
            startSpawnAnimation()
        }

        if !hasSpawned || isFrozen || isBossPaused {
            self.removeAllActions()
            self.isChargingBeam = false
            return
        }
        
        
        if !isChargingBeam {
            moveSideToSide(deltaTime: cappedDeltaTime)
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
    
    private func startSpawnAnimation() {
        spawnAnimationStarted = true
        
        // Add spawnImage to the wizard node
        self.addChild(spawnImage)
        
        //Define Rotation Action
        let spawnRotationSpeed: CGFloat = CGFloat.pi * 2 // Makes 1 circle rotation per second
        let rotationDuration = 2 * CGFloat.pi / spawnRotationSpeed
        let rotateAction = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: Double(rotationDuration))
        let rotateForever = SKAction.repeatForever(rotateAction)
        
        
        // Define Grow Action
        let growAction = SKAction.scale(to: bossScale * 1.5, duration: 2.0)
        
        // Define Shrink Action
        let shrinkAction = SKAction.scale(to: 0.0, duration: 1.0)
        
        // Define Remove Action
        let removeSpawnImage = SKAction.removeFromParent()
        
        spawnImage.run(rotateForever)
        
        // Define the complete spawn animation sequence
        let spawnSequence = SKAction.sequence([
            growAction,
            shrinkAction,
            removeSpawnImage,
            SKAction.run { [weak self] in
                self?.hasSpawned = true
            }
        ])
        
        // Run the spawn animation
        spawnImage.run(spawnSequence)
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

    func takeDamage(amount: Double) {
        health -= amount
        flashRed()
        if health <= 0 {
            die()
        }
    }
    
    private func loadFireballAnimation() {
        let frameCount = 15
        fireballFrames = (1...frameCount).map { frameNumber in
            SKTexture(imageNamed: "fireball_\(frameNumber)")
        }
    }

    private func die() {
        isAlive = false
        let explosion = SKEmitterNode(fileNamed: "Explosion")
        explosion?.setScale(screenScaleFactor)
        explosion?.position = self.position
        scene?.addChild(explosion ?? SKNode())
        self.removeFromParent()
    }
    
    private func moveSideToSide(deltaTime: TimeInterval) {
        guard let scene = scene as? ZPGameScene,
              let arenaBounds = scene.arenaBounds else { return }
        
        if isFrozen || isBossPaused { return }
        
        //Define movement boundaries
        let minX = arenaBounds.minX
        let maxX = arenaBounds.maxX
        
        //Fixed Y-position
        let spawnY = spawnLocation.y
        position.y = spawnY
        
        if currentDirection == .zero {
            currentDirection = CGVector(dx: movementSpeed, dy: 0)
            self.texture = textureRight // Start moving right
        }
        
        let movement = CGVector(dx: currentDirection.dx * CGFloat(deltaTime), dy: 0)
        position.x += movement.dx
        
        //Reverse direction upon reaching movement boundaries
        if position.x <= minX || position.x >= maxX {
            currentDirection.dx *= -1
            //Update texture based on direction
            if currentDirection.dx > 0 {
                self.texture = textureRight
            } else {
                self.texture = textureLeft
            }
        }
    }

    private func spawnRandomMeteors() {
        guard let scene = scene as? ZPGameScene,
              let arenaBounds = scene.arenaBounds else { return }
        for _ in 0..<3 {
            let randomX = CGFloat.random(in: arenaBounds.minX...arenaBounds.maxX)
            let randomY = CGFloat.random(in: arenaBounds.minY...arenaBounds.maxY)
            let targetPosition = CGPoint(x: randomX, y: randomY)
            //telegraphMeteor(at: targetPosition)
            animateFireball(at: targetPosition)
        }
    }
    
    private func animateFireball(at targetPosition: CGPoint) {
        //Create the fireball sprite node
        let fireball = SKSpriteNode(texture: fireballFrames.first)
        fireball.setScale(screenScaleFactor)
        fireball.position = targetPosition
        fireball.zPosition = 10
        fireball.name = "fireball"
        scene?.addChild(fireball)
        
        let animationDuration = 1.5 // Total duration of the animation
        let animate = SKAction.animate(with: fireballFrames, timePerFrame: animationDuration / Double(fireballFrames.count))
        
        let checkCollision = SKAction.run { [weak self, weak fireball] in
            guard let self = self, let fireball = fireball, let scene = scene as? ZPGameScene else { return }
            if fireball.frame.intersects(scene.player.frame) {
                scene.bossHitPlayer()
            }
        }
        
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([animate, checkCollision, remove])
        
        fireball.run(sequence)
    }

    private func telegraphMeteor(at targetPosition: CGPoint) {
        let warning = SKShapeNode(circleOfRadius: 80) // Larger warning size
        warning.position = targetPosition
        warning.strokeColor = .red
        warning.lineWidth = 2
        
        //Add a label for the warning circle
        let warningLabel = SKLabelNode(text: "MOVE AWAY!")
        warningLabel.fontSize = 20
        warningLabel.fontColor = .black
        warningLabel.position = CGPoint(x: 0, y: -70)
        warning.addChild(warningLabel)
        
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
        guard let scene = scene as? ZPGameScene else { return }
        
        let meteor = SKShapeNode(circleOfRadius: 80) // Larger meteor size
        meteor.position = position
        meteor.fillColor = .orange
        meteor.strokeColor = .red
        meteor.lineWidth = 3
        
        //Add a label for 'BOOM'
        let bombLabel = SKLabelNode(text: "FIREBALL BOOM!")
        bombLabel.fontSize = 20
        bombLabel.fontColor = .black
        bombLabel.position = CGPoint(x: 0, y: -70)
        meteor.addChild(bombLabel)
        
        scene.addChild(meteor)

        // Deal damage to the player if the meteor lands
        if meteor.frame.intersects(scene.player.frame) {
            scene.bossHitPlayer()
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
        print("size", self.size)
        warning.strokeColor = .red
        warning.lineWidth = size.width * 0.0177
        warning.alpha = 0.5
        scene?.addChild(warning)

        // Animate the warning to flash
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: 0.3)
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
        guard let scene = scene as? ZPGameScene else { return }
        
        if isFrozen || isBossPaused { return }
        
        //Calculate the beam's end point
        let beamEnd = extendedBeamEnd(from: position, to: targetPosition)
        
        //Create the beam as a thin rectanlge for physics detection
        let beamLength = hypot(beamEnd.x - position.x, beamEnd.y - position.y)
        let beamWidth: CGFloat = size.width * 0.0885 // Adjust thickness as needed
        
        let beam = SKSpriteNode(color: .yellow, size: CGSize(width: beamLength, height: beamWidth))
        beam.position = CGPoint(x: (position.x + beamEnd.x) / 2, y: (position.y + beamEnd.y) / 2)
        beam.zRotation = atan2(beamEnd.y - position.y, beamEnd.x - position.x)
        beam.alpha = 0.7
        beam.zPosition = 5
        beam.name = "beam"
        
        //Configure physics body
        beam.physicsBody = SKPhysicsBody(rectangleOf: beam.size)
        beam.physicsBody?.isDynamic = true
        beam.physicsBody?.categoryBitMask = PhysicsCategory.bossBeam
        beam.physicsBody?.contactTestBitMask = PhysicsCategory.player
        beam.physicsBody?.collisionBitMask = PhysicsCategory.none
        beam.physicsBody?.affectedByGravity = false
        beam.physicsBody?.allowsRotation = false
        beam.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        beam.physicsBody?.angularVelocity = 0
        
        scene.addChild(beam)
        
        let beamDuration: TimeInterval = 1.0
        let removeBeam = SKAction.removeFromParent()
        let sequence = SKAction.sequence([SKAction.wait(forDuration: beamDuration), removeBeam])
        beam.run(sequence)
    }
        
    private func isPlayerOnBeamPath(beamStart: CGPoint, beamEnd: CGPoint, playerPosition: CGPoint) -> Bool {
        let distanceTolerance: CGFloat = 100
        let beamVector = CGVector(dx: beamEnd.x - beamStart.x, dy: beamEnd.y - beamStart.y)
        let playerVector = CGVector(dx: playerPosition.x - beamStart.x, dy: playerPosition.y - beamStart.y)
        
        //Cross product determines how far 'off-path' the player is
        let crossProduct = abs(beamVector.dx * playerVector.dy - beamVector.dy * playerVector.dx)
        //Dot product ensures the player is between beamStart and beamEnd
        let dotProduct = beamVector.dx * playerVector.dx + beamVector.dy * playerVector.dy
        let beamLengthSquared = beamVector.dx * beamVector.dx + beamVector.dy * beamVector.dy
        
        return crossProduct <= distanceTolerance && dotProduct >= 0 && dotProduct <= beamLengthSquared
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
    
    
    func pause() {
        isBossPaused = true
    }
    
    func resume() {
        isBossPaused = false
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
    
    private func addIceNode() {
        if iceNode != nil { return }
        
        let ice = SKSpriteNode(imageNamed: "sk_ice")
        let iceScale = (self.size.height * 2.3) / ice.size.height
        ice.name = "iceNode"
        ice.setScale(0.0)
        ice.zPosition = self.zPosition + 1
        ice.position = CGPoint.zero
        
        addChild(ice)
        self.iceNode = ice
        
        let scaleUp = SKAction.scale(to: iceScale, duration: 0.1)
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
}
