//
//  ZPGameScene.swift
//  Zombocalypse
//
//  
//

import SpriteKit
import GameplayKit
import CoreGraphics

extension CGPoint {
    func distance(to otherPoint: CGPoint) -> CGFloat {
        let dx = otherPoint.x - self.x
        let dy = otherPoint.y - self.y
        return sqrt(dx * dx + dy * dy)
    }
}
extension CGVector {
    var normalized: CGVector {
        let length = sqrt(dx * dx + dy * dy)
        return length > 0 ? CGVector(dx: dx / length, dy: dy / length) : .zero
    }
}

class ZPGameScene: SKScene {
    //Inf background settings
    var topBound: CGFloat = 0
    var bottomBound: CGFloat = 0
    var backgroundSections: [SKSpriteNode] = []
    let sectionWidth: CGFloat = 3340 // Example width of each section (Adjust based on image) 1024
    let sectionHeight: CGFloat = 3510 // Example height of each section (Adjust as needed) 768
    let numSections: Int = 5         // Number of sections (Higher = longer before repeated gen., Lower = shorter before repeated gen.)
    
    weak var context: ZPGameContext?
    var joystick: ZPJoystick!
    var shootJoystick: ZPJoystick!
    var player: SKSpriteNode!
    var zombies: [ZPZombie] = [] // Array to hold the zombies
    
    let zombieCount = 3 // 3 For now as we are testing.
    let zombieSpeed: CGFloat = 0.3
    let zombieBufferDistance: CGFloat = 10 // Adjust this value to experiment with zombie spacing w one another
    var playerLivesLabel: SKLabelNode!
    var playerLives: Int = 3 {
        didSet {
            playerLivesLabel.text = "Lives: \(playerLives)"
        }
    }
    var gameOver: Bool = false
    
    // Zombie Wave Settings
    private var currentWave: Int = 1
    private var zombieHealth: Int = 3
    private var wizardHealth: Int = 15 // change to 15 later
    private var wizardBoss: ZPWizard?
    private var bossIsAlive: Bool = false
    var arenaBounds: CGRect?
    private let maxWave: Int = 6
    private let zombiesPerWave: Int = 3
    var waveCounter: Int = 1 {
        didSet {
            waveLabel.text = "Wave: \(waveCounter)"
        }
    }
    var waveLabel: SKLabelNode!
    private let waveMessageLabel = SKLabelNode(fontNamed: "Arial")
    
    //Enemy variation message settings
    private let newEnemyMessages: [Int: String] = [
        3: "New Enemy: Charger!",
        4: "New Enemy: Exploder!",
        6: "New Boss: Wizard!",
    ]
    private var displayedEnemyMessages: Set<Int> = []
    
    // Auto-attack variables
    private var attackDamage: Int = 1
    private var projectileMoveDistance: CGFloat = 200 //attack range of bullet
    private var shootInterval: TimeInterval = 1.0 //attack speed of bullet
    private var attackInterval: TimeInterval = 1.0 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (speed)
    private var lastShootTime: TimeInterval = 0
    private var lastAttackTime: TimeInterval = 0
    
    //Score Settings
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    var scoreLabel: SKLabelNode!
    
    // Track time since the last frame for smoother movement
    private var lastUpdateTime: TimeInterval = 0
    private let centerPosition: CGPoint
    private var activeTouches: [UITouch: ZPJoystick] = [:]
    
    //Upgrades Settings
    private var isGamePaused: Bool = false
    var upgradePopup: SKShapeNode!
    var upgradeStatsLabel: SKLabelNode!

    init(context: ZPGameContext, size: CGSize) {
        self.context = context
        self.centerPosition = CGPoint(x: size.width / 2, y: size.height / 2 - 400) //Added '- 400' to make player spawn down towards center of image
        super.init(size: size)
        self.scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.view?.isMultipleTouchEnabled = true
        //Create and add the camera node
        let cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)
        
        setUpGame()
        //Wave message label (center of screen every round)
        waveMessageLabel.fontSize = 60
        waveMessageLabel.fontColor = .red
        waveMessageLabel.position = CGPoint(x: size.width / 2, y: size.height - 180)
        waveMessageLabel.zPosition = 5
        waveMessageLabel.isHidden = true
        cameraNode.addChild(waveMessageLabel)
        
        //Add camera-related HUD elements
        cameraNode.addChild(playerLivesLabel)
        cameraNode.addChild(scoreLabel)
        cameraNode.addChild(waveLabel)
        cameraNode.addChild(joystick)
        cameraNode.addChild(shootJoystick)
    }
    
    func setUpGame() {
        backgroundColor = .white
        gameOver = false
        
        // Sets up player at fixed start position
        if player == nil {
            player = SKSpriteNode(color: .blue, size: CGSize(width: 25, height: 25))
            addChild(player)
            
            //Player label above head
            let playerLabel = SKLabelNode(fontNamed: "Arial")
            playerLabel.text = "Player"
            playerLabel.fontSize = 20
            playerLabel.fontColor = .black
            playerLabel.position = CGPoint(x: 0, y: player.size.height / 2 + 10)
            playerLabel.name = "playerLabel"
            player.addChild(playerLabel)
        }
        player.position = centerPosition
        
        // Sets up lives label displaying playerLives
        if playerLivesLabel == nil {
            playerLivesLabel = SKLabelNode(fontNamed: "Arial")
            playerLivesLabel.fontSize = 20
            playerLivesLabel.fontColor = .black
            playerLivesLabel.position = CGPoint(x: -size.width / 2 + 80, y: size.height / 2 - 80)
            playerLivesLabel.zPosition = 5
        }
        playerLives = 3 // Reset playerLives
        
        // Set up score label at the top
        if scoreLabel == nil {
            scoreLabel = SKLabelNode(fontNamed: "Arial")
            scoreLabel.fontSize = 20
            scoreLabel.fontColor = .black
            scoreLabel.position = CGPoint(x: size.width / 2 - 80, y: size.height / 2 - 80)
            scoreLabel.zPosition = 5
        }
        score = 0
        
        //Set up wave label at the top
        if waveLabel == nil {
            waveLabel = SKLabelNode(fontNamed: "Arial")
            waveLabel.fontSize = 22
            waveLabel.fontColor = .black
            waveLabel.position = CGPoint(x: 0, y: size.height / 2 - 80)
            waveLabel.zPosition = 5
        }
        waveCounter = 1
        
        //Displaying upgrade stats label
        if upgradeStatsLabel == nil {
            upgradeStatsLabel = SKLabelNode(fontNamed: "Arial")
            upgradeStatsLabel.fontSize = 12
            upgradeStatsLabel.fontColor = .black
            upgradeStatsLabel.position = CGPoint(x: 0, y: player.size.height / 2 + 30)
            player.addChild(upgradeStatsLabel)
        }
        updateUpgradeStatsLabel()
                
        // Clear any existing enemies
        bossIsAlive = false
        childNode(withName: "wizard")?.removeFromParent()
        removeZombies()
        startWave(wave: currentWave)
        
        //Set up joystick
        if joystick == nil {
            joystick = ZPJoystick(baseRadius: 50, knobRadius: 25)
            joystick.position = CGPoint(x: -size.width / 2 + 100, y: -size.height / 2 + 100)
            joystick.zPosition = 5
            //cameraNode?.addChild(joystick)
        }
        
        //Set up shooting joystick
        if shootJoystick == nil {
            shootJoystick = ZPJoystick(baseRadius: 50, knobRadius: 25)
            shootJoystick.position = CGPoint(x: size.width / 2 - 100, y: -size.height / 2 + 100)
            shootJoystick.zPosition = 5
            //cameraNode?.addChild(shootJoystick)
        }
        updateUpgradeStatsLabel()
        setupBackground()
    }
    
    func setupBackground() {
        // Calculate the height needed for the image
        let totalHeight = size.height // The full height of the screen or desired play area
        let aspectRatio = sectionWidth / sectionHeight // Maintain the image's aspect ratio
        
        // Resize the image to fit within the new bounds
        let newHeight = totalHeight * 2 // Can change the multiplier to make bigger or smaller
        let newWidth = newHeight * aspectRatio // Maintain proportions
        
        // Set the top and bottom 'invisible' boundaries
        topBound = newHeight / 2 - 350
        bottomBound = -newHeight / 2 + 50

        // Set up the background sections
        for i in 0..<numSections {
            let section = SKSpriteNode(texture: SKTexture(imageNamed: "infGenTestImgLg"))
            section.size = CGSize(width: newWidth, height: newHeight)
            
            // Position sections starting from the left side
            section.position = CGPoint(x: CGFloat(i) * newWidth - newWidth / 2 + 10, y: 0)
            section.zPosition = -1
            addChild(section)
            backgroundSections.append(section)
        }
    }



    
    func showUpgradePopup() {
        isGamePaused = true
        self.isPaused = true // Pauses all SKAction updates
        //create popup background
        let popupWidth = size.width * 0.6
        let popupHeight = size.height * 0.4
        let popup = SKShapeNode(rectOf: CGSize(width: popupWidth, height: popupHeight), cornerRadius: 10)
        popup.fillColor = .darkGray
        popup.alpha = 0.9
        popup.name = "upgradePopup"
        popup.position = CGPoint(x: 0, y: 0)
        popup.zPosition = 5
        
        //Attack damage button
        let atkDamageButton = SKLabelNode(text: "Increase Attack Damage")
        atkDamageButton.name = "attack"
        atkDamageButton.fontSize = 20
        atkDamageButton.position = CGPoint(x: 0, y:40)
        popup.addChild(atkDamageButton)
        //Attack range button
        let atkRangeButton = SKLabelNode(text: "Increase Attack Range")
        atkRangeButton.name = "range"
        atkRangeButton.fontSize = 20
        atkRangeButton.position = CGPoint(x: 0, y:0)
        popup.addChild(atkRangeButton)
        //Attack speed button
        let atkSpeedButton = SKLabelNode(text: "Increase Attack Speed")
        atkSpeedButton.name = "speed"
        atkSpeedButton.fontSize = 20
        atkSpeedButton.position = CGPoint(x: 0, y:-40)
        popup.addChild(atkSpeedButton)
        //1+ Health option button
        let addHealthButton = SKLabelNode(text: "+1 Health")
        addHealthButton.name = "health"
        addHealthButton.fontSize = 20
        addHealthButton.position = CGPoint(x: 0, y:-80)
        popup.addChild(addHealthButton)
        
        camera?.addChild(popup)
        upgradePopup = popup
    }
    
    func applyUpgrade(_ choice: String) {
        switch choice {
        case "attack":
            attackDamage += 1
        case "range":
            projectileMoveDistance += 100
        case "speed":
            shootInterval = max(0.3, shootInterval - 0.1) //THIS TEMPORARILY ENSURES IT DOES NOT GO BELOW 0.1
            shootInterval = round(shootInterval * 10) / 10 //Deals with float value not showing up as .000001
        case "health":
            playerLives += 1
        default:
            break
        }
        //powerUpAvailable = false
        isGamePaused = false
        self.isPaused = false // Resumes game updates
        upgradePopup?.removeFromParent()
        upgradePopup = nil
        updateUpgradeStatsLabel()
    }
    
    func removeZombies() {
        for zombie in zombies {
            zombie.removeFromParent()
        }
        zombies.removeAll()
    }
    
    func startWave(wave: Int) {
        if !gameOver {
            let zombieCount = wave * zombiesPerWave
            switch wave {
            case 1:
                for _ in 0..<zombieCount {
                    spawnZombies(withHealth: zombieHealth)
                }
            case 2:
                for _ in 0..<zombieCount {
                    spawnZombies(withHealth: zombieHealth)
                }
            case 3:
                for _ in 0..<zombieCount-3 {
                    spawnZombies(withHealth: zombieHealth)
                }
                spawnChargerZombie()
            case 4:
                for _ in 0..<zombieCount-6 {
                    spawnZombies(withHealth: zombieHealth)
                }
                spawnExploderZombie()
            case 5:
                for _ in 0..<zombieCount-6 {
                    spawnZombies(withHealth: zombieHealth)
                }
                spawnChargerZombie()
                spawnExploderZombie()
            case 6:
                for _ in 0..<zombieCount-15 {
                    spawnZombies(withHealth: zombieHealth)
                }
                spawnWizardBoss()
            default:
                break
                
            }
        }
    }

    func spawnZombies(withHealth health: Int) {
        let zombie = ZPZombie(health: health)
        let safeRadius: CGFloat = 100.0
        let zombieSize = zombie.size.width
        var position: CGPoint
        //Ensure zombies do NOT overlap one another on spawn
        repeat{
            position = CGPoint(x: CGFloat.random(in: zombieSize...(size.width - zombieSize)), y: CGFloat.random(in: zombieSize...(size.height - zombieSize)))
        } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: zombie.size)) }) || position.distance(to: player.position) < safeRadius
        zombie.position = position
        addChild(zombie)
        zombies.append(zombie)
    }
    
    func spawnChargerZombie() {
        let chargerZombie = ZPChargerZombieNode(health: zombieHealth, movementSpeed: zombieSpeed)
        let safeRadius: CGFloat = 150.0
        let chargerZombieSize = chargerZombie.size.width
        var position: CGPoint
        repeat {
            position = CGPoint(x: CGFloat.random(in: chargerZombieSize...(size.width - chargerZombieSize)), y: CGFloat.random(in: chargerZombieSize...(size.height - chargerZombieSize)))
        } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: chargerZombie.size)) }) || position.distance(to: player.position) < safeRadius
        chargerZombie.position = position
        addChild(chargerZombie)
        zombies.append(chargerZombie)
    }
        
    func spawnExploderZombie() {
        let exploderZombie = ZPExploderZombieNode(health: zombieHealth, movementSpeed: zombieSpeed)
        let safeRadius: CGFloat = 150.0
        let exploderZombieSize = exploderZombie.size.width
        var position: CGPoint
        repeat {
            position = CGPoint(x: CGFloat.random(in: exploderZombieSize...(size.width - exploderZombieSize)), y: CGFloat.random(in: exploderZombieSize...(size.height - exploderZombieSize)))
        } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: exploderZombie.size)) }) || position.distance(to: player.position) < safeRadius
        exploderZombie.position = position
        addChild(exploderZombie)
        zombies.append(exploderZombie)
    }
    
    func checkAndRespawnZombies(respawnRadius: CGFloat) {
        for zombie in zombies {
            let distanceFromPlayer = zombie.position.distance(to: player.position)
            
            if distanceFromPlayer > respawnRadius {
                let safeRadius: CGFloat = 100.0
                let spawnDistance: CGFloat = 150.0
                
                var newPosition: CGPoint
                repeat {
                    let angle = CGFloat.random(in: 0...2 * .pi)
                    newPosition = CGPoint(
                        x: player.position.x + spawnDistance * cos(angle),
                        y: player.position.y + spawnDistance * sin(angle)
                    )
                } while newPosition.distance(to: player.position) < safeRadius || zombies.contains(where: { $0 !== zombie && $0.frame.contains(newPosition) })
                //Update the zombie's position
                zombie.position = newPosition
            }
        }
    }
    
    func spawnWizardBoss() {
        guard let cameraNode = self.camera else { return }
        let cameraCenter = cameraNode.position
        if let existingWizard = wizardBoss {
            existingWizard.removeFromParent()
        }
        bossIsAlive = true
        wizardBoss = ZPWizard(health: wizardHealth)
        wizardBoss?.position = CGPoint(x: cameraCenter.x, y: cameraCenter.y + size.height / 2 - 150) //Change value so its not in the way of UI
        addChild(wizardBoss!)
        
        arenaBounds = CGRect(
            x: cameraCenter.x - size.width / 2,
            y: cameraCenter.y - size.height / 2,
            width: size.width - 75,
            height: size.height - 200
        )
            
        if let arenaBounds = arenaBounds {
            let outline = SKShapeNode(rectOf: CGSize(width: arenaBounds.width, height: arenaBounds.height))
            outline.position = CGPoint(x: arenaBounds.midX, y: arenaBounds.midY)
            outline.strokeColor = .purple
            outline.fillColor = .clear
            outline.lineWidth = 2.0
            outline.name = "arenaOutline"
            addChild(outline)
        }
        
    }
    
    func updatePlayerMovement() {
        if let bounds = arenaBounds {
            player.position.x = max(bounds.minX, min(bounds.maxX, player.position.x))
            player.position.y = max(bounds.minY, min(bounds.maxY, player.position.y))
        }
    }
    
    func updateCamera() {
        guard let cameraNode = self.camera else { return }
        if arenaBounds == nil {
            //Normal camera-follow behavior
            cameraNode.position = CGPoint(
                x: player.position.x,
                y: player.position.y
            )
        } else {
            //Lock camera at arena's center for when boss spawn
            cameraNode.position = CGPoint(
                x: arenaBounds!.midX,
                y: arenaBounds!.midY
            )
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let cameraNode = self.camera else { continue }
            let touchLocationInCamera = touch.location(in: cameraNode) // Location relative to the camera
            
            // Check if the game is paused and the popup menu is active
            if isGamePaused {
                // Calculate the touch location relative to the popup menu
                if let popupMenu = cameraNode.childNode(withName: "upgradePopup") {
                    let touchLocationInPopup = touch.location(in: popupMenu) // Convert location to popup menu's coordinate space
                    
                    // Check if the touch is on any of the upgrade options
                    let tappedNodes = popupMenu.nodes(at: touchLocationInPopup)
                    for node in tappedNodes {
                        if let nodeName = node.name, ["attack", "range", "speed", "health"].contains(nodeName) {
                            applyUpgrade(nodeName) // Apply the chosen upgrade
                            return
                        }
                    }
                }
                return // Don't allow other interactions when paused
            }

            // Handle joystick interactions
            if joystick.contains(touchLocationInCamera) && activeTouches[touch] == nil && !gameOver {
                joystick.startTouch(at: touch.location(in: joystick))
                activeTouches[touch] = joystick
            } else if shootJoystick.contains(touchLocationInCamera) && activeTouches[touch] == nil && !gameOver {
                shootJoystick.startTouch(at: touch.location(in: shootJoystick))
                shootJoystick.activate()
                activeTouches[touch] = shootJoystick
            }

            // Handle game-over interactions
            if gameOver {
                if let gameOverNode = cameraNode.childNode(withName: "gameOverScreen") {
                    let touchLocationInGameOver = touch.location(in: gameOverNode)
                    let tappedNodes = gameOverNode.nodes(at: touchLocationInGameOver)
                    for node in tappedNodes {
                        if node.name == "retryButton" {
                            restartGame()
                            return
                        } else if node.name == "leaderboardButton" {
                            //LEADERBOARDS LOGIC HERE
                        } else if node.name == "mainMenuButton" {
                            //MAIN MENU LOGIC HERE
                        }
                    }
                }
                return //Stops interaction while gameover screen is active
            }
        }
    }


    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let joystick = activeTouches[touch] {
                let location = touch.location(in: joystick)
                joystick.moveTouch(to: location)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let joystick = activeTouches[touch] {
                joystick.endTouch()
                if joystick === shootJoystick {
                    shootJoystick.deactivate()
                }
                activeTouches[touch] = nil
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        guard !gameOver, !isGamePaused else { return }
        manageBackgroundScrolling()
        
        let respawnRadius: CGFloat = 400 // Define the maximum allowed distance before zombie respawn
        checkAndRespawnZombies(respawnRadius: respawnRadius)
        updatePlayerMovement()
        updateCamera()
        
        if playerLives <= 0 {
            showGameOverScreen()
            return
        }
        
        if bossIsAlive, let arenaBounds = arenaBounds {
            let clampedX = max(arenaBounds.minX, min(player.position.x, arenaBounds.maxX))
            let clampedY = max(arenaBounds.minY, min(player.position.y, arenaBounds.maxY))
            player.position = CGPoint(x: clampedX, y: clampedY)
            wizardBoss?.update(currentTime: currentTime, playerPosition: player.position)
        }
        
        // Calculate time delta for consistent movement
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // Set the movement speed and calculate player velocity
        let moveSpeed: CGFloat = 100 // Adjust speed as needed
        let velocity = joystick.positionDelta
        let dx = velocity.x * moveSpeed * CGFloat(deltaTime)
        let dy = velocity.y * moveSpeed * CGFloat(deltaTime)
        
        //Center the camera on the player
        self.position = CGPoint(
            x: -player.position.x + size.width / 2,
            y: -player.position.y + size.height / 2
        )
        
        //Move the camera to follow the player
        camera?.position = player.position
        
        // Update player position and apply boundaries
        let newPlayerPosition = CGPoint(x: player.position.x + dx, y: player.position.y + dy)
        player.position = boundPosition(for: newPlayerPosition, within: CGSize(width: 1024, height: 768))
        
        //Check shoot joystick to aim and shoot projectiles
        if shootJoystick.isActive {
            let aimDirection = shootJoystick.positionDelta
            //IF ANY ERROR OCCURS WITH SHOOTING, POTENTIAL REASON IS BC WE ARE REUSING CURRENTTIME
            if aimDirection != .zero && currentTime - lastShootTime >= shootInterval{
                lastShootTime = currentTime
                shootProjectile(in: aimDirection)
            }
        }
        
        //Update zombies positions to move towards the player
        for (index, zombie) in zombies.enumerated().reversed() {
            zombie.moveTowards(player: player, speed: zombieSpeed)
            
            //PREVENT ZOMBIES FROM OVERLAPPING ONE ANOTHER
            preventZombieOverlap(zombie: zombie, index: index)
            
            if zombie.frame.intersects(player.frame) {
                handlePlayerHit(zombieIndex: index)
            }
        }
        
        //Update method for each charger/exploder zombie in the scene
        for zombie in zombies {
            if let chargerZombie = zombie as? ZPChargerZombieNode {
                chargerZombie.update(deltaTime: currentTime, playerPosition: player.position)
            }
            if let exploderZombie = zombie as? ZPExploderZombieNode {
                exploderZombie.update(deltaTime: currentTime, playerPosition: player.position)
            }
        }
        
        
        //Check if all zombies have been defeated before going to next wave.
        if zombies.isEmpty {
            advanceToNextWave()
        }
    }
    
    func manageBackgroundScrolling() {
        // Define overlap offset to ensure smooth transition
        let overlapOffset: CGFloat = 300.0

        for section in backgroundSections {
            let sectionLeftEdge = section.position.x - section.size.width / 2
            let sectionRightEdge = section.position.x + section.size.width / 2
            let sectionTopEdge = section.position.y + section.size.height / 2
            let sectionBottomEdge = section.position.y - section.size.height / 2
            
            // **Horizontal Scrolling**
            if player.position.x > sectionRightEdge + overlapOffset {
                // Move section to the right before it leaves the visible area
                section.position.x += CGFloat(numSections) * section.size.width
            } else if player.position.x < sectionLeftEdge - overlapOffset {
                // Move section to the left before it leaves the visible area
                section.position.x -= CGFloat(numSections) * section.size.width
            }

            // **Vertical Scrolling**
            if player.position.y > sectionTopEdge + overlapOffset {
                // Move section downward before it leaves the visible area
                section.position.y -= CGFloat(numSections) * section.size.height
            } else if player.position.y < sectionBottomEdge - overlapOffset {
                // Move section upward before it leaves the visible area
                section.position.y += CGFloat(numSections) * section.size.height
            }
        }
    }


    
    func shootProjectile(in direction: CGPoint) {
        //Create projectile node
        let projectile = SKSpriteNode(color: .green, size: CGSize(width: 10, height: 10))
        projectile.position = player.position
        projectile.name = "projectile"
        addChild(projectile)
        //Set up movement action in the specified direction
        let normalizedDirection = CGVector(dx: direction.x, dy: direction.y).normalized
        //let moveDistance: CGFloat = 800
        let moveAction = SKAction.move(by: CGVector(dx: normalizedDirection.dx * projectileMoveDistance, dy: normalizedDirection.dy * projectileMoveDistance), duration: 2)
        //Collision check
        let collisionAction = SKAction.run {
            self.checkProjectileCollision(projectile)
        }
        let collisionCheckSequence = SKAction.sequence([collisionAction, SKAction.wait(forDuration: 0.05)])
        let repeatCollisionCheck = SKAction.repeat(collisionCheckSequence, count: Int(2.0 / 0.05)) // Run for duration of 'moveAction'
        
        let combinedAction = SKAction.group([moveAction, repeatCollisionCheck])
        projectile.run(SKAction.sequence([combinedAction, SKAction.removeFromParent()]))
    }
    
    func checkProjectileCollision(_ projectile: SKSpriteNode) {
        for (index, zombie) in zombies.enumerated().reversed() {
            if projectile.frame.intersects(zombie.frame) {
                zombie.takeDamage(amount: attackDamage)
                if zombie.isDead {
                    zombie.removeFromParent()
                    zombies.remove(at: index)
                    score += 1
                }
                projectile.removeFromParent()
                break //Ensure projectile stops after hitting first zombie
            }
        }
        //Check collision for wizard
        if let wizard = scene?.childNode(withName: "wizard") as? ZPWizard {
            if projectile.frame.intersects(wizard.frame) {
                wizard.takeDamage(amount: attackDamage)
                projectile.removeFromParent()
                if wizard.health <= 0 {
                    bossIsAlive = false
                    arenaBounds = nil
                    if let outline = childNode(withName: "arenaOutline") as? SKShapeNode {
                        outline.removeFromParent()
                    }
                }
            }
        }
    }
    
    func preventZombieOverlap(zombie: ZPZombie, index: Int){
        for (otherIndex, otherZombie) in zombies.enumerated() where otherIndex != index {
            if zombie.frame.intersects(otherZombie.frame) {
                let zombieCenter = zombie.position
                let otherZombieCenter = otherZombie.position
                
                let direction = CGVector(dx: zombieCenter.x - otherZombieCenter.x, dy: zombieCenter.y - otherZombieCenter.y)
                let distance = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
                let targetDistance = zombie.size.width / 2 + otherZombie.size.width / 2 + zombieBufferDistance
                
                if distance < targetDistance {
                    let overlapDistance = targetDistance - distance
                    let normalizedDirection = CGVector(dx: direction.dx / distance, dy: direction.dy / distance)
                    let adjustment = CGVector(dx: normalizedDirection.dx * overlapDistance * 0.1, dy: normalizedDirection.dy * overlapDistance * 0.1)
                    zombie.position = CGPoint(x: zombie.position.x + adjustment.dx, y: zombie.position.y + adjustment.dy)
                }
            }
        }
    }
    
    func handlePlayerHit(zombieIndex: Int) {
        playerLives -= 1
        zombies[zombieIndex].removeFromParent()
        zombies.remove(at: zombieIndex)
        
        if playerLives <= 0 {
            showGameOverScreen()
        }
    }
    
    func bossHitPlayer() {
        playerLives -= 1
    }
    ///
    ///
    ///
    ///
    ///
    func advanceToNextWave() {
        if bossIsAlive {
            return
        }
        if currentWave < maxWave {
            currentWave += 1
        } else {
            currentWave = 1
            zombieHealth = zombieCount * 2
            wizardHealth += 15
        }
        
        startWave(wave: currentWave)
        waveCounter += 1
        if !gameOver {
            //Determine message
            let isBossWave = currentWave % 6 == 0
            let waveMessage = isBossWave ? "BOSS WAVE" : "Wave \(waveCounter)"
            waveMessageLabel.text = waveMessage
            waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
            //Show message briefly
            waveMessageLabel.isHidden = false
            waveMessageLabel.alpha = 1.0
            let fadeOut = SKAction.sequence([
                SKAction.wait(forDuration: 2.0),
                SKAction.fadeOut(withDuration: 1.0),
                SKAction.run { self.waveMessageLabel.isHidden = true; self.waveMessageLabel.alpha = 1.0 }
            ])
            waveMessageLabel.run(fadeOut)
        }
        
        //Check for new enemy message
        if let enemyMessage = newEnemyMessages[waveCounter] {
            showEnemyIntroductionMessage(enemyMessage)
        }
        
        if !gameOver {
            showUpgradePopup()
        }
    }
    
    private func showEnemyIntroductionMessage(_ message: String) {
        guard let cameraNode = self.camera else { return }
        let enemyMessageLabel = SKLabelNode(text: message)
        enemyMessageLabel.fontSize = 40
        enemyMessageLabel.fontColor = .red
        enemyMessageLabel.position = CGPoint(x: 0, y: size.height * 0.25)
        enemyMessageLabel.zPosition = 5
        cameraNode.addChild(enemyMessageLabel)
        
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.run { enemyMessageLabel.removeFromParent() }
        ])
        enemyMessageLabel.run(fadeOut)
    }
    
    //Note: Can change this at a later time to match HYEL gameoverscreen style
    func showGameOverScreen() {
        gameOver = true
        guard let cameraNode = self.camera else { return }
        
        let gameOverNode = SKShapeNode(rect: CGRect(x: -size.width * 0.4, y: -size.height * 0.2, width: size.width * 0.8, height: size.height * 0.4), cornerRadius: 20)
        gameOverNode.fillColor = .black.withAlphaComponent(0.8)
        gameOverNode.name = "gameOverScreen"
        gameOverNode.zPosition = 5
        cameraNode.addChild(gameOverNode)
        
        let gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: size.height * 0.1)
        gameOverLabel.zPosition = 5
        gameOverNode.addChild(gameOverLabel)
        
        let scoreLabel = SKLabelNode(text: "Score: \(score)") //Placeholder for score to be implemented later
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: size.height * 0.05)
        scoreLabel.zPosition = 5
        gameOverNode.addChild(scoreLabel)
        
        //Main menu and leaderboard buttons are placeholders for now.
        let retryButton = createButton(withText: "Retry", atPosition: CGPoint(x: 0, y: 0))
        retryButton.name = "retryButton"
        retryButton.zPosition = 5
        gameOverNode.addChild(retryButton)
        
        let leaderboardButton = createButton(withText: "Leaderboards", atPosition: CGPoint(x: 0, y: -size.height * 0.05))
        leaderboardButton.name = "leaderboardButton"
        leaderboardButton.zPosition = 5
        gameOverNode.addChild(leaderboardButton)
        
        let mainMenuButton = createButton(withText: "Main Menu", atPosition: CGPoint(x: 0, y: -size.height * 0.1))
        mainMenuButton.name = "mainMenuButton"
        leaderboardButton.zPosition = 5
        gameOverNode.addChild(mainMenuButton)
        
    }
    
    func createButton(withText text: String, atPosition position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontSize = 25
        button.fontColor = .white
        button.position = position
        return button
    }
    
    func restartGame() {
        if let cameraNode = self.camera, let gameOverScreen = cameraNode.childNode(withName: "gameOverScreen") {
            gameOverScreen.removeFromParent()
        }
        player.position = centerPosition
        joystick.endTouch()
        shootJoystick.endTouch()
        currentWave = 1
        waveCounter = 1
        zombieHealth = 3
        wizardHealth = 15
        attackDamage = 1
        shootInterval = 1.0
        projectileMoveDistance = 200
        if let existingWizard = wizardBoss {
            existingWizard.removeFromParent()
            wizardBoss = nil
        }
        setUpGame()
    }
    
    // Keeps player within screen bounds
    private func boundPosition(for position: CGPoint, within imageSize: CGSize) -> CGPoint {
        var newPosition = position

        // Allow free movement horizontally (no bounds on x-axis)
        newPosition.x = position.x

        // Restrict vertical movement within the top and bottom of the resized background
        if newPosition.y > topBound {
            newPosition.y = topBound
        } else if newPosition.y < bottomBound {
            newPosition.y = bottomBound
        }

        return newPosition
    }
    
    func updateUpgradeStatsLabel() {
        upgradeStatsLabel.text = "Dmg: \(attackDamage) | Range: \(projectileMoveDistance) | AtkSpeed: \(shootInterval)"
    }
    
}
