//
//  ZPGameScene.swift
//  Zombocalypse
//
//  
//

import SpriteKit
import GameplayKit

class ZPGameScene: SKScene {
    weak var context: ZPGameContext?
    var joystick: ZPJoystick!
    var player: SKSpriteNode!
    var zombies: [ZPZombie] = [] // Array to hold the zombies
    
    let zombieCount = 3 // 3 For now as we are testing.
    let zombieSpeed: CGFloat = 0.3
    var playerLivesLabel: SKLabelNode!
    var playerLives: Int = 3 {
        didSet {
            playerLivesLabel.text = "Lives: \(playerLives)"
        }
    }
    var gameOver: Bool = false
    
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
        
        // Clear any existing enemies
        removeZombies()
        spawnZombies(count: zombieCount)
        
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
    
    func spawnZombies(count: Int) {
        while zombies.count < count {
            let zombie = ZPZombie()
            zombie.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            addChild(zombie)
            zombies.append(zombie)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if joystick.contains(location) && !gameOver {
            let location = touch.location(in: joystick)
            joystick.startTouch(at: location)
            
        } else if gameOver {
            let tappedNodes = nodes(at: location)
            for node in tappedNodes {
                if node.name == "retryButton" {
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
            if zombie.frame.intersects(player.frame) {
                handlePlayerHit(zombieIndex: index)
            }
        }
    }
    
    func handlePlayerHit(zombieIndex: Int) {
        playerLives -= 1
        zombies[zombieIndex].removeFromParent()
        zombies.remove(at: zombieIndex)
        
        if playerLives <= 0 {
            showGameOverScreen()
        } else {
            // Respawn an enemy to keep the count of enemies consistent. Can change later on.
            spawnZombies(count: zombieCount)
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
        
        let scoreLabel = SKLabelNode(text: "Score: 0") //Placeholder for score to be implemented later
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
