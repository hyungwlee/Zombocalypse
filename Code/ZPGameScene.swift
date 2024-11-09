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
    private let attackRange: CGFloat = 150 // ADJUST THIS LATER ON WHEN MORE UPGRADES ARE IMPLEMENTED (range)
    
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
        
        // Clear any existing enemies
        removeZombies()
        startWave(wave: currentWave)
        
        //Set up joystick
        if joystick == nil {
            joystick = ZPJoystick(baseRadius: 50, knobRadius: 25)
            joystick.position = CGPoint(x: 100, y: 100)
            addChild(joystick)
        }
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        for node in tappedNodes {
            if joystick.contains(location) && !gameOver {
                let location = touch.location(in: joystick)
                joystick.startTouch(at: location)
            } else if gameOver {
                for node in tappedNodes where node.name == "retryButton" {
                    restartGame()
                }
            }
        }
        
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if joystick.contains(location) && !gameOver {
            let joystickLocation = touch.location(in: joystick)
            joystick.moveTouch(to: joystickLocation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !gameOver {
            joystick.endTouch()
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard !gameOver else { return }
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
        
        //Update zombies positions to move towards the player
        for (index, zombie) in zombies.enumerated().reversed() {
            zombie.moveTowards(player: player, speed: zombieSpeed)
            
            //PREVENT ZOMBIES FROM OVERLAPPING ONE ANOTHER
            preventZombieOverlap(zombie: zombie, index: index)
            
            if zombie.frame.intersects(player.frame) {
                handlePlayerHit(zombieIndex: index)
            }
        }
        
        autoAttackZombies(currentTime: currentTime)
        
        //Check if all zombies have been defeated before going to next wave.
        if zombies.isEmpty {
            advanceToNextWave()
        }
    }
    func powerUp() {
        //Powerup
        let randomNumber = Int.random(in: 1...10)

        // Check if the random number is 5, and increment the variable if true
        if randomNumber == 5 {
            attackDamage += 1
        }
    }
    func autoAttackZombies(currentTime: TimeInterval){
        //This ensures enough time has passed since last attack
        if currentTime - lastAttackTime >= attackInterval {
            lastAttackTime = currentTime
            
            //Check for nearby zombies within range
            for (index, zombie) in zombies.enumerated().reversed() {
                if zombie.position.distance(to: player.position) <= attackRange {
                    //TEMPORARY VISUAL CUE OF SHOOTING UNTIL WE DO ANIMATIONS IN THE FUTURE
                    let line = SKShapeNode()
                    let path = CGMutablePath()
                    path.move(to: player.position)
                    path.addLine(to: zombie.position)
                    line.path = path
                    line.strokeColor = .green
                    line.lineWidth = 3
                    addChild(line)
                    let fadeOut = SKAction.fadeOut(withDuration: 0.1)
                    let remove = SKAction.removeFromParent()
                    line.run(SKAction.sequence([fadeOut, remove]))
                    //
                    zombie.takeDamage(amount: attackDamage)
                    if zombie.isDead {
                        zombie.removeFromParent()
                        zombies.remove(at: index)
                        score += 1
                        powerUp()
                    }
                    break // only attack one zombie per interval
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
        currentWave = 1
        zombieHealth = 1
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
}
