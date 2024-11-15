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

class ZPGameScene: SKScene {
    weak var context: ZPGameContext?
    var joystick: ZPJoystick!
    var player: SKSpriteNode!
    var zombies: [ZPZombie] = [] // Array to hold the zombies
    var wizard: ZPWizard! // The wizard enemy

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
    private var attackInterval: TimeInterval = 1.0 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (speed)
    private var lastAttackTime: TimeInterval = 0
    private var attackRange: CGFloat = 150 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (range)
    
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
        
        // Spawn the wizard enemy if not already present
        if wizard == nil {
            wizard = ZPWizard()
            addChild(wizard)
            wizard.position = CGPoint(x: size.width / 2, y: size.height - 50)
        }
        
        updateUpgradeStatsLabel()
        updatePowerUpLabel()
    }

    // Other methods here (e.g., showUpgradePopup, applyUpgrade, etc.)

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
    }
    
    func spawnZombies(withHealth health: Int) {
        let zombie = ZPZombie(health: health)
        var position: CGPoint
        //Ensure zombies do NOT overlap one another on spawn
        repeat {
            position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        } while zombies.contains(where: { $0.frame.intersects(CGRect(origin: position, size: zombie.size)) })
        zombie.position = position
        addChild(zombie)
        zombies.append(zombie)
    }
    
    override func update(_ currentTime: TimeInterval) {
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
        
        // Update wizard's actions
        wizard.update(currentTime: currentTime, playerPosition: player.position)
        
        // Update zombie positions and actions
        for (index, zombie) in zombies.enumerated().reversed() {
            zombie.moveTowards(player: player, speed: zombieSpeed)
            preventZombieOverlap(zombie: zombie, index: index)
            if zombie.frame.intersects(player.frame) {
                handlePlayerHit(zombieIndex: index)
            }
        }
        
        autoAttackZombies(currentTime: currentTime)
        
        // Check if all zombies have been defeated before going to the next wave
        if zombies.isEmpty {
            advanceToNextWave()
        }
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
        currentWave = 1
        zombieHealth = 1
        enemiesDefeated = 0
        attackDamage = 1
        attackInterval = 1.0
        attackRange = 150
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
        upgradeStatsLabel.text = "Attack Damage: \(attackDamage) | Attack Range: \(attackRange) | Attacks/Second: \(attackInterval)"
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
