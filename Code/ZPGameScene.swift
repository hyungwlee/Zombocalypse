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
    private var zombieHealth: Int = 1
    private let maxWave: Int = 4
    private let zombiesPerWave: Int = 3
    
    // Auto-attack variables
    private var attackDamage: Int = 1
    private var projectileMoveDistance: CGFloat = 200 //attack range of bullet
    private var shootInterval: TimeInterval = 1.0 //attack speed of bullet
    private var attackInterval: TimeInterval = 1.0 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (speed)
    private var lastShootTime: TimeInterval = 0
    private var lastAttackTime: TimeInterval = 0
    //private var attackRange: CGFloat = 150 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (range)
    
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
    private var enemiesDefeated: Int = 0
    private var nextPowerUpThreshold: Int = 5
    private var powerUpAvailable: Bool = false
    private var isGamePaused: Bool = false
    var upgradePopup: SKShapeNode!
    var upgradeStatsLabel: SKLabelNode!
    var powerUpLabel: SKLabelNode!

    init(context: ZPGameContext, size: CGSize) {
        self.context = context
        self.centerPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        super.init(size: size)
        self.scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        self.view?.isMultipleTouchEnabled = true
        setUpGame()
    }
    
    func setUpGame() {
        backgroundColor = .white
        gameOver = false
        
        // Sets up player at fixed start position
        if player == nil {
            player = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
            addChild(player)
        }
        player.position = centerPosition
        
        // Sets up lives label displaying playerLives
        if playerLivesLabel == nil {
            playerLivesLabel = SKLabelNode(fontNamed: "Arial")
            playerLivesLabel.fontSize = 20
            playerLivesLabel.fontColor = .black
            playerLivesLabel.position = CGPoint(x: size.width - 50, y: size.height - 30)
            addChild(playerLivesLabel)
        }
        playerLives = 3 // Reset playerLives
        
        // Set up score label at the top
        if scoreLabel == nil {
            scoreLabel = SKLabelNode(fontNamed: "Arial")
            scoreLabel.fontSize = 20
            scoreLabel.fontColor = .black
            scoreLabel.position = CGPoint(x: 50, y: size.height - 30)
            addChild(scoreLabel)
        }
        score = 0
        
        //Displaying upgrade stats label
        if upgradeStatsLabel == nil {
            upgradeStatsLabel = SKLabelNode(fontNamed: "Arial")
            upgradeStatsLabel.fontSize = 14
            upgradeStatsLabel.fontColor = .black
            upgradeStatsLabel.position = CGPoint(x: size.width / 2, y: size.height - 80)
            addChild(upgradeStatsLabel)
        }
        updateUpgradeStatsLabel()
        
        //Displaying power up label
        if powerUpLabel == nil {
            powerUpLabel = SKLabelNode(fontNamed: "Arial")
            powerUpLabel.fontSize = 14
            powerUpLabel.fontColor = .black
            powerUpLabel.position = CGPoint(x: size.width / 2, y: size.height - 110)
            addChild(powerUpLabel)
        }
        updatePowerUpLabel()
        
        // Clear any existing enemies
        removeZombies()
        startWave(wave: currentWave)
        
        //Set up joystick
        if joystick == nil {
            joystick = ZPJoystick(baseRadius: 50, knobRadius: 25)
            joystick.position = CGPoint(x: 100, y: 100)
            addChild(joystick)
        }
        
        //Set up shooting joystick
        if shootJoystick == nil {
            shootJoystick = ZPJoystick(baseRadius: 50, knobRadius: 25)
            shootJoystick.position = CGPoint(x: size.width - 100, y: 100)
            addChild(shootJoystick)
        }
        updateUpgradeStatsLabel()
        updatePowerUpLabel()
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
        popup.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
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
        
        addChild(popup)
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
        case "health":
            playerLives += 1
        default:
            break
        }
        powerUpAvailable = false
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
            let zombieCount = wave * zombiesPerWave
            for _ in 0..<zombieCount {
                spawnZombies(withHealth: zombieHealth)
            }
            
            //TESTING. ADD ONE CHARGER ZOMBIE AND EXPLODER ZOMBIE PER WAVE
            spawnChargerZombie()
            spawnExploderZombie()
        }
    
    func spawnZombies(withHealth health: Int) {
        let zombie = ZPZombie(health: health)
        var position: CGPoint
        //Ensure zombies do NOT overlap one another on spawn
        repeat{
            position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: zombie.size)) })
        zombie.position = position
        addChild(zombie)
        zombies.append(zombie)
    }
    
    func spawnChargerZombie() {
            let chargerZombie = ZPChargerZombieNode(health: zombieHealth, movementSpeed: zombieSpeed)
            var position: CGPoint
            repeat {
                position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: chargerZombie.size)) })
            chargerZombie.position = position
            addChild(chargerZombie)
            zombies.append(chargerZombie)
        }
        
        func spawnExploderZombie() {
            let exploderZombie = ZPExploderZombieNode(health: zombieHealth, movementSpeed: zombieSpeed)
            var position: CGPoint
            repeat {
                position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: exploderZombie.size)) })
            exploderZombie.position = position
            addChild(exploderZombie)
            zombies.append(exploderZombie)
        }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let tappedNodes = nodes(at: location)
            
            if isGamePaused {
                for node in tappedNodes {
                    if let nodeName = node.name, ["attack", "range", "speed", "health"].contains(nodeName) {
                        applyUpgrade(nodeName)
                        return
                    }
                }
            }
            
            if joystick.contains(location) && activeTouches[touch] == nil && !gameOver {
                joystick.startTouch(at: touch.location(in: joystick))
                activeTouches[touch] = joystick
            }
            else if shootJoystick.contains(location) && activeTouches[touch] == nil && !gameOver {
                shootJoystick.startTouch(at: touch.location(in: shootJoystick))
                shootJoystick.activate()
                activeTouches[touch] = shootJoystick
            }
            if gameOver {
                for node in tappedNodes where node.name == "retryButton" {
                    restartGame()
                }
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
        
        if powerUpAvailable {
            showUpgradePopup()
        }
        
        // Calculate time delta for consistent movement
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // Set the movement speed and calculate player velocity
        let moveSpeed: CGFloat = 250 // Adjust speed as needed
        let velocity = joystick.positionDelta
        let dx = velocity.x * moveSpeed * CGFloat(deltaTime)
        let dy = velocity.y * moveSpeed * CGFloat(deltaTime)
        
        // Update player position and apply boundaries
        let newPlayerPosition = CGPoint(x: player.position.x + dx, y: player.position.y + dy)
        player.position = boundPosition(newPlayerPosition)
        
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
        //comment out for now just incase we go back to autoattack
        //autoAttackZombies(currentTime: currentTime)
        
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
    
    func shootProjectile(in direction: CGPoint) {
        //Create projectile node
        let projectile = SKSpriteNode(color: .green, size: CGSize(width: 15, height: 15))
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
                    enemiesDefeated += 1
                    updatePowerUpLabel()
                    if enemiesDefeated >= nextPowerUpThreshold {
                        enemiesDefeated = 0
                        powerUpAvailable = true
                        nextPowerUpThreshold += 5
                    }
                }
                projectile.removeFromParent()
                break //Ensure projectile stops after hitting first zombie
            }
        }
    }
    //COMMENT OUT FOR NOW JUST IN CASE WE WANT TO GO BACK TO AUTO ATTACK.
//    func autoAttackZombies(currentTime: TimeInterval){
//        //This ensures enough time has passed since last attack
//        if currentTime - lastAttackTime >= attackInterval {
//            lastAttackTime = currentTime
//            
//            //Check for nearby zombies within range
//            for (index, zombie) in zombies.enumerated().reversed() {
//                if zombie.position.distance(to: player.position) <= attackRange {
//                    //TEMPORARY VISUAL CUE OF SHOOTING UNTIL WE DO ANIMATIONS IN THE FUTURE
//                    let line = SKShapeNode()
//                    let path = CGMutablePath()
//                    path.move(to: player.position)
//                    path.addLine(to: zombie.position)
//                    line.path = path
//                    line.strokeColor = .green
//                    line.lineWidth = 3
//                    addChild(line)
//                    let fadeOut = SKAction.fadeOut(withDuration: 0.1)
//                    let remove = SKAction.removeFromParent()
//                    line.run(SKAction.sequence([fadeOut, remove]))
//                    //
//                    zombie.takeDamage(amount: attackDamage)
//                    if zombie.isDead {
//                        zombie.removeFromParent()
//                        zombies.remove(at: index)
//                        score += 1
//                        enemiesDefeated += 1
//                        updatePowerUpLabel()
//                        if enemiesDefeated >= nextPowerUpThreshold {
//                            enemiesDefeated = 0
//                            powerUpAvailable = true
//                            nextPowerUpThreshold += 5
//                        }
//                    }
//                    break // only attack one zombie per interval
//                }
//            }
//        }
//    }
    
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
    
    func advanceToNextWave() {
        if currentWave < maxWave {
            currentWave += 1
        } else {
            currentWave = 1
            zombieHealth += 2
        }
        
        startWave(wave: currentWave)
    }
    
    //Note: Can change this at a later time to match HYEL gameoverscreen style
    func showGameOverScreen() {
        gameOver = true
        let gameOverNode = SKShapeNode(rect: CGRect(x: size.width * 0.1, y: size.height * 0.3, width: size.width * 0.8, height: size.height * 0.4), cornerRadius: 20)
        gameOverNode.fillColor = .black.withAlphaComponent(0.8)
        gameOverNode.name = "gameOverScreen"
        addChild(gameOverNode)
        
        let gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        gameOverNode.addChild(gameOverLabel)
        
        let scoreLabel = SKLabelNode(text: "Score: \(score)") //Placeholder for score to be implemented later
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        gameOverNode.addChild(scoreLabel)
        
        //Main menu and leaderboard buttons are placeholders for now.
        let retryButton = createButton(withText: "Retry", atPosition: CGPoint(x: size.width / 2, y: size.height * 0.45))
        retryButton.name = "retryButton"
        gameOverNode.addChild(retryButton)
        
        let leaderboardButton = createButton(withText: "Leaderboards", atPosition: CGPoint(x: size.width / 2, y: size.height * 0.4))
        leaderboardButton.name = "leaderboardButton"
        gameOverNode.addChild(leaderboardButton)
        
        let mainMenuButton = createButton(withText: "Main Menu", atPosition: CGPoint(x: size.width / 2, y: size.height * 0.35))
        mainMenuButton.name = "mainMenuButton"
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
        if let gameOverScreen = childNode(withName: "gameOverScreen") {
            gameOverScreen.removeFromParent()
        }
        player.position = centerPosition
        joystick.endTouch()
        shootJoystick.endTouch()
        currentWave = 1
        zombieHealth = 1
        enemiesDefeated = 0
        attackDamage = 1
        shootInterval = 1.0
        projectileMoveDistance = 200
        nextPowerUpThreshold = 5
        setUpGame()
    }
    
    // Keeps player within screen bounds
    private func boundPosition(_ position: CGPoint) -> CGPoint {
        let halfWidth = player.size.width / 2
        let halfHeight = player.size.height / 2
        let clampedX = min(size.width - halfWidth, max(halfWidth, position.x))
        let clampedY = min(size.height - halfHeight, max(halfHeight, position.y))
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    func updateUpgradeStatsLabel() {
        upgradeStatsLabel.text = "Attack Damage: \(attackDamage) | Attack Range: \(projectileMoveDistance) | Attacks/Second: \(shootInterval)"
    }
    
    func updatePowerUpLabel() {
        let enemiesLeft = nextPowerUpThreshold - enemiesDefeated
        if enemiesLeft > 0 {
            powerUpLabel.text = "Defeat \(enemiesLeft) more enemies!"
        } else {
            //STILL DECIDING IF WE WANT TO USE THIS OR NOT. SO FAR, IT IS NOT USED.
            powerUpLabel.text = "Power Up Ready!"
        }
    }
}
