//
//  SLGameScene.swift
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

struct Wave {
    let waveNumber: Int
    let totalEnemies: Int
    let regularEnemies: Int
    let chargerEnemies: Int
    let exploderEnemies: Int
    let isHorde: Bool
    let isBoss: Bool
    let spawnInterval: TimeInterval
    let requiresFullClearance: Bool
    
    // Track spawned enemies
    var spawnedRegular: Int = 0
    var spawnedCharger: Int = 0
    var spawnedExploder: Int = 0
    
    // Determine if all enemies have been spawned
    var allEnemiesSpawned: Bool {
        return (spawnedRegular >= regularEnemies) &&
               (spawnedCharger >= chargerEnemies) &&
               (spawnedExploder >= exploderEnemies)
    }
    
    // Initialize without default values for spawned counts
    init(waveNumber: Int, totalEnemies: Int, regularEnemies: Int, chargerEnemies: Int, exploderEnemies: Int, isHorde: Bool, isBoss: Bool, spawnInterval: TimeInterval, requiresFullClearance: Bool) {
        self.waveNumber = waveNumber
        self.totalEnemies = totalEnemies
        self.regularEnemies = regularEnemies
        self.chargerEnemies = chargerEnemies
        self.exploderEnemies = exploderEnemies
        self.isHorde = isHorde
        self.isBoss = isBoss
        self.spawnInterval = spawnInterval
        self.requiresFullClearance = requiresFullClearance
    }
}


class SLGameScene: SKScene, SLPlayerStateDelegate {
    
    unowned let context: SLGameContext
    var gameInfo: SLGameInfo { return context.gameInfo }
    var layoutInfo: SLLayoutInfo { return context.layoutInfo }

    var playerState = SLPlayerState()
    var skillManager: SLSkillManager!
    var enemyManager: SLEnemyManager!
    var mapManager: SLMapManager!
    var upgradeShopManager: SLUpgradeShopManager!
    var overlayManager: SLOverlayManager!
    private var upgradeOverlay: SLUpgradeShopOverlayNode?
    
    var joystick: SLJoystick!
    var shootJoystick: SLJoystick!
    private var activeTouches: [UITouch: SLJoystick] = [:]
    
    var player: SKSpriteNode!
    var crossbowNode: SKSpriteNode!
    var bladesContainer: SKNode?
    var barrierContainer: SKNode?
    var shieldContainer: SKNode?
    var spectralShield: SKShapeNode?
    var upgradeStatsLabel: SKLabelNode!
    var playerHealthBar: SLHealthBarNode!
    var playerLivesLabel: SKLabelNode!
    var playerLives: Double = 3.0 {
        didSet {
            playerLivesLabel.text = "Lives: \(playerLives)"
            playerHealthBar.setHealth(playerLives)
        }
    }
    var playerShootingProgressBar: SLHealthBarNode!
    var shootingProgress: CGFloat = 1.0 {
        didSet {
            playerShootingProgressBar.setProgress(shootingProgress)
        }
    }
    private var isPlayerFlashing: Bool = false
    
    var damagingEnemies: Set<SLZombie> = []
    private var wizardBoss: SLWizard?
    var activeBeamContacts: Set<SKPhysicsBody> = []
    var beamDamageTimer: Timer?
    var arenaBounds: CGRect?
    
    var gameOver: Bool = false
    var isGamePaused: Bool = false
    
    private var lastShootTime: TimeInterval = 0.0
    var currentGameTime: TimeInterval = 0.0
    var lastDamageTime: TimeInterval = 0.0
    var lastGrenadeTime: TimeInterval = 0.0
    var lastFreezeSound: TimeInterval = 0.0
    private var lastUpdateTime: TimeInterval = 0.0

        
    var waveCycle: [Wave] = []
    var waveProgressionWorkItem: DispatchWorkItem?
    
    private var waveTransitionTimer: SLPausableTimer?
    private var remainingGracePeriod: TimeInterval = 0.0
    private var isGracePeriodActive: Bool = false
    var progressLabel: SKLabelNode!
    var miniWaveInterval: TimeInterval = 3.0
    var isTransitioningWave: Bool = false
    var isBossStage: Bool = false
    
    private var displayedEnemyMessages: Set<Int> = []
    private let newEnemyMessages: [Int: String] = [
        4: "New Enemy: Charger!",
        5: "New Enemy: Exploder!",
        7: "New Boss: Wizard!",
    ]
    private let newEnemyBannerMapping: [Int: String] = [
        4: "sl_charger_banner",
        5: "sl_exploder_banner"
    ]
    private let waveMessageLabel = SKLabelNode(fontNamed: "Arial")
        
    var scoreNode: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    var waveNode: SKSpriteNode!
    var waveLabel: SKLabelNode!
    var topOverlayNode: SKShapeNode!
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "\(score)"
        }
    }
    private var waveCounter: Int = 0 {
        didSet {
            waveLabel.text = "\(waveCounter)"
        }
    }
    
    var xpBarNode: SLXPBarNode!
    var xpNodes: [SLXPNode] = []
    var xpNodesToRemove: [SLXPNode] = []
    var xpSpawnTimer: Timer?
    let xpSpawnInterval: TimeInterval = 5.0
    
    var hordeSpawnInterval: TimeInterval = 0.1
    var normalSpawnInterval: TimeInterval = 1.0
    
    // -----

    init(context: SLGameContext, size: CGSize) {
        self.context = context
        super.init(size: size)
        self.scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        
        playerState.delegate = self
        skillManager = SLSkillManager(player: playerState)
        upgradeShopManager = SLUpgradeShopManager(scene: self, skillManager: skillManager)
        overlayManager = SLOverlayManager(scene: self)
        enemyManager = SLEnemyManager(scene: self)
        mapManager = SLMapManager(sectionWidth: layoutInfo.mapSectionSize.width, sectionHeight: layoutInfo.mapSectionSize.height, numSections: layoutInfo.numberOfMapSections, scene: self)
        mapManager.setupBackground(in: self, withTexture: "sl_map")
        
        self.physicsWorld.contactDelegate = self
                
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.view?.isMultipleTouchEnabled = true
        let cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)
        
        //Initialize HealthBar for player
        let healthBarSize = layoutInfo.healthBarSize
        playerHealthBar = SLHealthBarNode(
            size: healthBarSize,
            maxHealth: playerState.baseMaxHealth,
            foregroundColor: UIColor(hex: "#00C300") ?? .green,
            backgroundColor: UIColor(hex: "#004500") ?? .black
        )
        playerHealthBar.position = CGPoint(x: 0, y: layoutInfo.healthBarOffset)
        playerHealthBar.zPosition = 5
        
        playerShootingProgressBar = SLHealthBarNode(
            size: layoutInfo.progressBarSize,
            maxHealth: 1.0,
            foregroundColor: UIColor(hex: "#01403D") ?? .darkGray, //This changes the color that is behind the shootprogressbar
            backgroundColor: .black,
            showProgressBar: true,
            progressColor: UIColor(hex: "#00DCD1") ?? .blue
        )
        playerShootingProgressBar.position = CGPoint(x: 0, y: -healthBarSize.height) // Positioned below the health bar
        playerHealthBar.addChild(playerShootingProgressBar)
        
        setUpGame()
        //Wave message label (center of screen every round)
        waveMessageLabel.fontSize = 40
        waveMessageLabel.fontColor = .red
        waveMessageLabel.position = CGPoint(x: size.width / 2, y: size.height - 180)
        waveMessageLabel.zPosition = 5
        waveMessageLabel.isHidden = true
//        cameraNode.addChild(waveMessageLabel)
        
        //Add camera-related HUD elements
//        cameraNode.addChild(playerLivesLabel)
        cameraNode.addChild(playerHealthBar)
        cameraNode.addChild(scoreNode)
        cameraNode.addChild(waveNode)
        cameraNode.addChild(topOverlayNode)
//        cameraNode.addChild(progressLabel)
        cameraNode.addChild(joystick)
        cameraNode.addChild(shootJoystick)
        
        beamDamageTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.applyBeamDamage()
        }
        
//        let spinningBladesSkill = skillManager.createRegularSkillInstance(for: .spinningBlades)
//        skillManager.acquireOrUpgradeRegularSkill(spinningBladesSkill!)
        
//        let protectiveBarrierSkill = skillManager.createRegularSkillInstance(for: .protectiveBarrier)
//        skillManager.acquireOrUpgradeRegularSkill(protectiveBarrierSkill!)
        
//        let freezeSkill = skillManager.createRegularSkillInstance(for: .freeze)
//        skillManager.acquireOrUpgradeRegularSkill(freezeSkill!)

//        skillManager.acquireSpecialSkill(.helpingHand)
//        skillManager.acquireSpecialSkill(.spectralShield)
//        skillManager.acquireSpecialSkill(.reinforcedArrow)
//        skillManager.acquireSpecialSkill(.mightyKnockback)
    }
    
    deinit {
        beamDamageTimer?.invalidate()
    }
    
    func setUpGame() {
        SLSoundManager.shared.playBackgroundMusic(named: "sl_bg_music")
        SLSoundManager.shared.setBackgroundMusicVolume(0.5)
        
        backgroundColor = .white
        gameOver = false
        playerState.resetToBaseStats()
        
        // Sets up player at fixed start position
        if player == nil {
            player = SKSpriteNode(imageNamed: "sl_player_right")
            let playerScale = layoutInfo.playerHeight / player.size.height
            player.setScale(playerScale)
            player.position = layoutInfo.playerStartingPosition
            player.color = .white // Default color
            player.colorBlendFactor = 0.0
            
            // MARK: Physics
            let playerPhysicsSize = CGSize(width: player.size.width, height: player.size.height * 0.7)
            player.physicsBody = SKPhysicsBody(texture: player.texture!, size: playerPhysicsSize)
//            player.physicsBody = SKPhysicsBody(texture: player.texture!, size: player.size)
            player.physicsBody?.categoryBitMask = SLPhysicsCategory.player
            player.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.xp | SLPhysicsCategory.bossBeam | SLPhysicsCategory.border | SLPhysicsCategory.bossArenaBorder
            player.physicsBody?.collisionBitMask = SLPhysicsCategory.border | SLPhysicsCategory.bossArenaBorder
            player.physicsBody?.affectedByGravity = false
            player.physicsBody?.allowsRotation = false
            player.physicsBody?.isDynamic = true
            addChild(player)
            
            let crossbowNode = SKSpriteNode(imageNamed: "sl_crossbow")
            let crossBowScale = layoutInfo.crossBowHeight / crossbowNode.size.height
            crossbowNode.setScale(crossBowScale)
            crossbowNode.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            crossbowNode.position = CGPoint(x: 0, y: player.size.height * -0.32)
            crossbowNode.zPosition = player.zPosition + 1
            crossbowNode.zRotation = .pi / -1.75
            player.addChild(crossbowNode)
            self.crossbowNode = crossbowNode
            
            //Initialize blades container
            bladesContainer = SKNode()
            bladesContainer?.position = CGPoint.zero
            bladesContainer?.zPosition = 1
            bladesContainer?.name = "bladesContainer"
            camera?.addChild(bladesContainer!)
            
            //Initialize barrier container
            barrierContainer = SKNode()
            barrierContainer?.position = CGPoint.zero
            barrierContainer?.zPosition = 2
            barrierContainer?.name = "barrierContainer"
            camera?.addChild(barrierContainer!)
            
            shieldContainer = SKNode()
            shieldContainer?.position = CGPoint.zero
            shieldContainer?.zPosition = 3
            shieldContainer?.name = "shieldContainer"
            camera?.addChild(shieldContainer!)
            
            //Player label above head
            let playerLabel = SKLabelNode(fontNamed: "Arial")
            playerLabel.text = "Player"
            playerLabel.fontSize = 20
            playerLabel.fontColor = .black
            playerLabel.position = CGPoint(x: 0, y: player.size.height / 2 + 30)
            playerLabel.name = "playerLabel"
//            player.addChild(playerLabel)
        }

        
//        TEST 'HARDSET' VALUES FOR BLADE
//        playerState.spinningBladesCount = 2
//        playerState.spinningBladesDamage = 3
//        playerState.spinningBladesSpeed = 1.0
//        skillManager.acquireOrUpgradeRegularSkill(
//            RegularSkill(definition: skillManager.allRegularDefinitions.first { $0.type == .spinningBlades }!)
//        )
//        playerState.barrierSize = 1000
////        playerState.barrierDamage = 1
//        playerState.barrierPulseFrequency = 2.0
//        skillManager.acquireOrUpgradeRegularSkill(
//            RegularSkill(definition: skillManager.allRegularDefinitions.first { $0.type == .protectiveBarrier }!))
        
        
        // Sets up lives label displaying playerLives
        if playerLivesLabel == nil {
            playerLivesLabel = SKLabelNode(fontNamed: "Arial")
            playerLivesLabel.fontSize = 20
            playerLivesLabel.fontColor = .black
            playerLivesLabel.position = CGPoint(x: -size.width / 2 + 80, y: size.height / 2 - 180)
            playerLivesLabel.zPosition = 5
        }
        playerLives = playerState.baseMaxHealth // Reset playerLives
        
        setupTopOverlay()
        
        // Set up score label at the top
        if scoreLabel == nil {
            scoreNode = SKSpriteNode(imageNamed: "sl_score_node")
            let scoreNodeScale = layoutInfo.scoreNodeHeight / scoreNode.size.height
            scoreNode.setScale(scoreNodeScale)
            scoreNode.position = CGPoint(x: layoutInfo.scoreNodePosition.x + scoreNode.size.width / 2, y: layoutInfo.scoreNodePosition.y - scoreNode.size.height / 2)
            scoreNode.zPosition = 6 // Above the overlay
            
            // This label only shows the number
            scoreLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
            scoreLabel.fontSize = scoreNode.size.height * 0.36363636364
            scoreLabel.fontColor = .black
            scoreLabel.position = CGPoint(x: 0, y: scoreNode.size.height * -0.35 - scoreLabel.frame.height)
            scoreLabel.zPosition = 7
            
            scoreNode.addChild(scoreLabel)
        }
        score = 0
        
        //Set up wave label at the top
        if waveLabel == nil {
            waveNode = SKSpriteNode(imageNamed: "sl_wave_node")
            let waveNodeScale = layoutInfo.waveNodeHeight / scoreNode.size.height
            scoreNode.setScale(waveNodeScale)
            waveNode.position = CGPoint(x: layoutInfo.waveNodePosition.x - waveNode.size.width / 2, y: layoutInfo.waveNodePosition.y - waveNode.size.height / 2)
            waveNode.zPosition = 6 // Above the overlay
            
            // This label only shows the wave number
            waveLabel = SKLabelNode(fontNamed: "InknutAntiqua-ExtraBold")
            waveLabel.fontSize = waveNode.size.height * 0.36363636364
            waveLabel.fontColor = .black
            waveLabel.position = CGPoint(x: 0, y: waveNode.size.height * -0.35 - waveLabel.frame.height)
            waveLabel.zPosition = 7
            
            waveNode.addChild(waveLabel)
        }
        //Set up progress label at the top
        if progressLabel == nil {
            progressLabel = SKLabelNode(fontNamed:"Arial")
            progressLabel.fontSize = 20
            progressLabel.fontColor = .black
            progressLabel.position = CGPoint(x: 0, y: size.height / 2 - 130)
            progressLabel.zPosition = 5
        }
        
        //Displaying upgrade stats label
        if upgradeStatsLabel == nil {
            upgradeStatsLabel = SKLabelNode(fontNamed: "Arial")
            upgradeStatsLabel.fontSize = 12
            upgradeStatsLabel.fontColor = .black
            upgradeStatsLabel.position = CGPoint(x: 0, y: player.size.height / 2 + 50)
//            player.addChild(upgradeStatsLabel)
        }
        updateUpgradeStatsLabel()
                
        // Clear any existing enemies
        wizardBoss?.isAlive = false
        childNode(withName: "wizard")?.removeFromParent()
        removeZombies()
        
        //Clear any existing boundaries/barriers from boss
        if let arenaOutline = self.childNode(withName: "arenaOutline") {
            arenaOutline.removeFromParent()
        }
        if let arenaBarrier = self.childNode(withName: "arenaBarrier") {
            arenaBarrier.removeFromParent()
        }

        //Wave function
        //maintainEnemyCount()
        initializeWaves()
        startNextWave()
        
        //Set up joystick
        if joystick == nil {
            joystick = SLJoystick(baseRadius: layoutInfo.joystickBaseRadius, knobRadius: layoutInfo.joystickKnobRadius)
            joystick.position = layoutInfo.moveJoyStickPosition
            joystick.zPosition = 5
            //cameraNode?.addChild(joystick)
        }
        
        //Set up shooting joystick
        if shootJoystick == nil {
            shootJoystick = SLJoystick(baseRadius: layoutInfo.joystickBaseRadius, knobRadius: layoutInfo.joystickKnobRadius)
            shootJoystick.position = layoutInfo.shootJoyStickPosition
            shootJoystick.zPosition = 5
            //cameraNode?.addChild(shootJoystick)
        }
        updateUpgradeStatsLabel()
        
        let xpBar = SLXPBarNode(width: layoutInfo.xpBarNodeWidth)
        xpBar.position = layoutInfo.xpBarNodePosition
        xpBar.zPosition = 6
        camera?.addChild(xpBar)
        self.xpBarNode = xpBar
        startXPSpawnTimer()
    }
    
    func setupTopOverlay() {
        guard let cameraNode = self.camera else { return }
        
        // Create a semi-opaque black rectangle covering the top 1/6 of the screen
        let overlayHeight = size.height / 5.5
        let overlayRect = CGRect(
            x: -size.width / 2,
            y: size.height/2 - overlayHeight,
            width: size.width,
            height: overlayHeight
        )
        
        topOverlayNode = SKShapeNode(rect: overlayRect)
        topOverlayNode.fillColor = .black
        topOverlayNode.alpha = 0.4
        topOverlayNode.strokeColor = .clear
        topOverlayNode.zPosition = 5
    }
    
    // MARK: - Player Flash Effect

    /// Triggers a flashing red effect to indicate the player has taken damage.
    public func flashPlayer() {
        // Prevent overlapping flash animations
        guard !isPlayerFlashing else { return }
        isPlayerFlashing = true
        
        // Define the flash color and duration
        let flashColor = SKColor.red
        let flashDuration: TimeInterval = 0.2
        
        // Create color change actions
        let colorizeToFlash = SKAction.colorize(with: flashColor, colorBlendFactor: 1.0, duration: 0.05)
        let colorizeBack = SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
        
        // Sequence of flashing
        let flashSequence = SKAction.sequence([colorizeToFlash, colorizeBack])
        
        // Repeat the flash sequence a few times for a more noticeable effect
        let repeatFlash = SKAction.repeat(flashSequence, count: 1)
        
        // Completion action to reset the flashing flag
        let completion = SKAction.run { [weak self] in
            self?.isPlayerFlashing = false
            self?.player.colorBlendFactor = 0.0
        }
        
        // Run the flash sequence followed by the completion
        player.run(SKAction.sequence([repeatFlash, completion]))
    }
    
    func pauseGame() {
        guard !isGamePaused else { return }
        isGamePaused = true
        
        enemyManager.pauseAll()
        waveTransitionTimer?.pause()
        stopXPSpawnTimer()
        
        removeAction(forKey: "spawnNextEnemy")
        
        player.physicsBody?.velocity = .zero
    }
    
    func unpauseGame() {
        guard isGamePaused else { return }
        isGamePaused = false
        
        enemyManager.resumeAll()
        waveTransitionTimer?.resume()
        startXPSpawnTimer()
        
        let currentWaveObject = waveCycle[gameInfo.currentWaveIndex]
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnNextEnemy()
        }
        let waitAction = SKAction.wait(forDuration: currentWaveObject.spawnInterval)
        let sequence = SKAction.sequence([waitAction, spawnAction])
        run(sequence, withKey: "spawnNextEnemy")
        
        for xpNode in xpNodesToRemove {
            self.playerState.currentXP += xpNode.xpAmount
            self.upgradeShopManager.incrementXPCount()
            self.updateXPBar()
            xpNode.removeFromParent()
        }
        
        // If you have any labels or banners currently showing that should vanish soon after resume,
        // you can find them and run a fade-out.
        if let cameraNode = self.camera {
            if !waveMessageLabel.isHidden {
                waveMessageLabel.removeAllActions()
                let fadeOut = SKAction.sequence([
                    SKAction.wait(forDuration: 2.0),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.run { [weak self] in self?.waveMessageLabel.isHidden = true }
                ])
                waveMessageLabel.run(fadeOut)
            }

            for banner in cameraNode.children where banner.name == "banner" {
                banner.removeAllActions()
                let fadeOut = SKAction.sequence([
                    SKAction.wait(forDuration: 2.0),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.removeFromParent()
                ])
                banner.run(fadeOut)
            }
        }
    }
    
    func initializeWaves() {
        //Define waves 1 through 7
//        waveCycle = [
//            Wave(waveNumber: 1, totalEnemies: 10, regularEnemies: 10, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
//            Wave(waveNumber: 2, totalEnemies: 15, regularEnemies: 15, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
//            Wave(waveNumber: 3, totalEnemies: 25, regularEnemies: 25, chargerEnemies: 0, exploderEnemies: 0, isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: false),
//            Wave(waveNumber: 4, totalEnemies: 20, regularEnemies: 15, chargerEnemies: 5, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
//            Wave(waveNumber: 5, totalEnemies: 20, regularEnemies: 15, chargerEnemies: 0, exploderEnemies: 5, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
//            Wave(waveNumber: 6, totalEnemies: 35, regularEnemies: 20, chargerEnemies: 8, exploderEnemies: 7, isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: true),
//            Wave(waveNumber: 7, totalEnemies: 1, regularEnemies: 0, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: true, spawnInterval: 0.0, requiresFullClearance: false)
//        ]
        
        waveCycle = [
            Wave(waveNumber: 1, totalEnemies: 20, regularEnemies: 20, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
            Wave(waveNumber: 2, totalEnemies: 30, regularEnemies: 30, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
            Wave(waveNumber: 3, totalEnemies: 40, regularEnemies: 40, chargerEnemies: 0, exploderEnemies: 0, isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: false),
            Wave(waveNumber: 4, totalEnemies: 25, regularEnemies: 20, chargerEnemies: 5, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
            Wave(waveNumber: 5, totalEnemies: 25, regularEnemies: 20, chargerEnemies: 0, exploderEnemies: 5, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false),
            Wave(waveNumber: 6, totalEnemies: 65, regularEnemies: 50, chargerEnemies: 8, exploderEnemies: 7, isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: true),
            Wave(waveNumber: 7, totalEnemies: 1, regularEnemies: 0, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: true, spawnInterval: 0.0, requiresFullClearance: false)
        ]
        
    }
    
    func startNextWave() {
        guard gameInfo.currentWaveIndex < waveCycle.count else {
            //All waves in the cycle completed, restart cycle with increased difficulty
            restartCycleWithIncreasedDifficulty()
            return
        }
        
        waveCounter += 1
        
        normalSpawnInterval = max(0.1, normalSpawnInterval - 0.1)
//        gameInfo.incrementZombieSpeed(by: 0.25)
        
        let newGracePeriod = max(1.0, gameInfo.waveGracePeriod - 1.0) // Decrease grace period, minimum 1 seconds
        gameInfo.updateWaveGracePeriod(to: newGracePeriod)
        
        let wave = waveCycle[gameInfo.currentWaveIndex]
//        print("before", gameInfo.pendingEnemies)
//        gameInfo.incrementPendingEnemies(by: wave.totalEnemies)
//        print("after", gameInfo.pendingEnemies)

        gameInfo.updateEnemiesToSpawn(to: wave.totalEnemies)
        gameInfo.incrementZombieHealth(by: 1.0)
//        zombieHealth += 2

        updateProgressLabel()
        
        isTransitioningWave = true
        
        //Display wave start message
        if wave.isBoss {
            // Use the boss warning image
            SLSoundManager.shared.playSoundEffect(.bossAlarm)
            SLSoundManager.shared.setSoundEffectVolume(.bossAlarm, volume: 0.2)
            
            showBannerNode(imageName: "sl_boss_warning", duration: 3.0)
        } else if wave.isHorde {
            // Use the horde incoming image
            SLSoundManager.shared.playSoundEffect(.horn)
            SLSoundManager.shared.setSoundEffectVolume(.horn, volume: 0.2)
            
            showBannerNode(imageName: "sl_horde_incoming", duration: 3.0)
        } else {
            // Normal wave start message can remain text-based or also be replaced.
            // If you want to keep text-based messages for normal waves:
//            waveMessageLabel.text = "Wave \(waveCounter) starting.."
//            waveMessageLabel.fontSize = 30
//            waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
//            waveMessageLabel.zPosition = 5
//            waveMessageLabel.isHidden = false
//
//            // Hide it after a short delay
//            let hideAction = SKAction.sequence([
//                SKAction.wait(forDuration: 3.0),
//                SKAction.run { [weak self] in self?.waveMessageLabel.isHidden = true }
//            ])
//            self.run(hideAction)
        }

        // Check for new enemy messages and show corresponding banners
        if let enemyMessage = newEnemyMessages[wave.waveNumber], !displayedEnemyMessages.contains(wave.waveNumber) {
            // Instead of using text, we use banner nodes:
            // Determine if we have a charger or exploder message
            if enemyMessage.contains("Charger") {
                // Show charger banner
                showBannerNode(imageName: "sl_charger_banner", duration: 5.0)
            } else if enemyMessage.contains("Exploder") {
                // Show exploder banner
                showBannerNode(imageName: "sl_exploder_banner", duration: 5.0)
            }
            displayedEnemyMessages.insert(wave.waveNumber)
        }
        
        if wave.isBoss {
            waveTransitionTimer?.callback = {}
            clearAllEnemies()
            startBossStage()
            
        } else {
            //Regular wave: do not clear existing enemies
            removeAction(forKey: "spawnNextEnemy")
            //FIGURE OUT THIS BELOW TO MAKE MESSAGES WORK
            waveMessageLabel.isHidden = true
            isTransitioningWave = false
            spawnNextEnemy()
        }
        
    }
    
    func showBannerNode(imageName: String, duration: TimeInterval = 4.0) {
        
        guard let cameraNode = self.camera else { return }
        let banner = SKSpriteNode(imageNamed: imageName)
        let bannerScale = layoutInfo.bannerWidth / banner.size.width
        banner.setScale(bannerScale)
        banner.position = layoutInfo.bannerPosition
        banner.zPosition = 5
        banner.alpha = 0.0
        banner.name = "banner"
        cameraNode.addChild(banner)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        
        let pulseIn = SKAction.scale(to: bannerScale * 1.03, duration: 1.0)
        let pulseOut = SKAction.scale(to: bannerScale, duration: 1.0)
        let pulseSequence = SKAction.sequence([pulseOut, pulseIn])
        let pulse = SKAction.repeat(pulseSequence, count: 2)
        
        let sequence = SKAction.sequence([
            fadeIn,
            pulse,
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        
        
        banner.run(sequence)
    }
    
    
    func spawnNextEnemy() {
        guard gameInfo.currentWaveIndex < waveCycle.count else { return }
        var wave = waveCycle[gameInfo.currentWaveIndex]
        
        // Check if all enemies have been spawned
        if wave.allEnemiesSpawned {
            print("spawn and all enemies spawned")

            handleWaveProgression()
            waveCycle[gameInfo.currentWaveIndex] = wave // Update the wave with new spawn counts
            return
        }
        
        // Decide which enemy to spawn next
        let spawnDecision = decideNextEnemyType(for: wave)
        
        switch spawnDecision {
        case .regular:
            spawnZombies(withHealth: gameInfo.zombieHealth)
            wave.spawnedRegular += 1
        case .charger:
            spawnChargerZombie()
            wave.spawnedCharger += 1
        case .exploder:
            spawnExploderZombie()
            wave.spawnedExploder += 1
        }
        
        // Update the wave in the cycle
        waveCycle[gameInfo.currentWaveIndex] = wave
        
        //Decrement enemiesToSpawn as an enemy has been spawned
        gameInfo.incrementEnemiesToSpawn(by: -1)
        
        // Schedule the next enemy spawn
        let currentWaveObject = waveCycle[gameInfo.currentWaveIndex]
        if currentWaveObject.spawnInterval > 0 {
            let spawnAction = SKAction.run { [weak self] in
                self?.spawnNextEnemy()
            }
            let waitAction = SKAction.wait(forDuration: currentWaveObject.spawnInterval)
            let sequence = SKAction.sequence([waitAction, spawnAction])
            run(sequence, withKey: "spawnNextEnemy")
        }
        updateProgressLabel()
    }
    
    enum EnemyType {
        case regular
        case charger
        case exploder
    }

    func decideNextEnemyType(for wave: Wave) -> EnemyType {
        var possibleTypes: [EnemyType] = []
        
        if wave.spawnedRegular < wave.regularEnemies {
            possibleTypes.append(.regular)
        }
        if wave.spawnedCharger < wave.chargerEnemies {
            possibleTypes.append(.charger)
        }
        if wave.spawnedExploder < wave.exploderEnemies {
            possibleTypes.append(.exploder)
        }
        
        // Randomly select one of the possible types
        return possibleTypes.randomElement() ?? .regular
        //return .regular
    }

    
    func spawnEnemyTypes(regular: Int, charger: Int, exploder: Int) {
        for _ in 0..<regular {
            spawnZombies(withHealth: gameInfo.zombieHealth)
        }
        for _ in 0..<charger {
            spawnChargerZombie()
        }
        for _ in 0..<exploder {
            spawnExploderZombie()
        }
    }
    
    func updateProgressLabel() {
        if isBossStage {
            progressLabel.text = "Defeat the boss!"
        }
        else if enemyManager.enemies.count > 0 {
            progressLabel.text = "Enemies left: \(gameInfo.pendingEnemies)"
        }
        else {
            progressLabel.text = "Waiting for next wave..."
        }
    }
    
    func showUpgradeShopOverlay(with choices: [SLRegularSkill]) {
        let overlaySize = CGSize(width: size.width, height: size.height)
        let upgradeOverlay = SLUpgradeShopOverlayNode(choices: choices, manager: upgradeShopManager, overlayManager: overlayManager, skillManager: skillManager, overlaySize: overlaySize, scaleFactor: layoutInfo.screenScaleFactor)
        overlayManager.enqueueOverlay(upgradeOverlay)
    }
    
    //MARK: - PlayerStateDelegate Methods
    
    //REGULAR SKILLS
    func playerStateDidAddSpinningBlades(_ state: SLPlayerState) {
        guard let bladesContainer = bladesContainer else { return }
        
        // Remove existing blades
        bladesContainer.removeAllChildren()
        
        // Define blade properties
        let bladeTexture = SKTexture(imageNamed: "sl_spinning_blades")
        let bladeSize = bladeTexture.size()
        let bladeColor = SKColor.green
        
        // Calculate the angle between each blade
        let bladeCount = state.spinningBladesCount
        guard bladeCount > 0 else { return }
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(bladeCount)
        
        
        // Create and position each blade
        for i in 0..<bladeCount {
            let blade = SKSpriteNode(texture: bladeTexture)
            blade.size = bladeSize
            let bladeScale = layoutInfo.spinningBladesheight / blade.size.height
            blade.setScale(bladeScale)
            blade.name = "spinningBlade"
            
            blade.physicsBody = SKPhysicsBody(rectangleOf: bladeSize)
            blade.physicsBody?.categoryBitMask = SLPhysicsCategory.blade
            blade.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.exploder
            blade.physicsBody?.collisionBitMask = SLPhysicsCategory.none
            blade.physicsBody?.affectedByGravity = false
            blade.physicsBody?.allowsRotation = false
            blade.physicsBody?.isDynamic = false
            
            // Calculate the position of the blade around the container
            let angle = CGFloat(i) * angleIncrement
            let xPosition = layoutInfo.spinningBladeOrbitRadius * cos(angle)
            let yPosition = layoutInfo.spinningBladeOrbitRadius * sin(angle)
            blade.position = CGPoint(x: xPosition, y: yPosition)
            
            bladesContainer.addChild(blade)
        }
        
        // Remove any existing rotation action
        bladesContainer.removeAction(forKey: "rotate")
        
        // Define rotation speed
        let baseDuration: TimeInterval = 0.5
        let rotationDuration = baseDuration / (state.spinningBladesSpeed * layoutInfo.screenScaleFactor)
        
        // Create a rotation action
        let rotateAction = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: rotationDuration)
        let repeatRotate = SKAction.repeatForever(rotateAction)
        
        // Run the rotation action on the container
        bladesContainer.run(repeatRotate, withKey: "rotate")
        
    }

    
    func playerStateDidUpgradeBarrier(_ state: SLPlayerState) {
        guard let barrierContainer = barrierContainer else { return }
        
        barrierContainer.removeAllChildren()
        
        let barrierRadius: CGFloat = layoutInfo.barrierBaseRadius * state.barrierScale
        let barrierColor = UIColor(hex: "#B5BFFF")?.withAlphaComponent(0.1) // Semi-transparent blue
        let strokeColor = UIColor(hex: "#2500C9")?.withAlphaComponent(0.1) // Semi-transparent blue
        
        let barrier = SKShapeNode(circleOfRadius: barrierRadius)
        barrier.name = "protectiveBarrier"
        
        barrier.physicsBody = SKPhysicsBody(circleOfRadius: barrierRadius)
        barrier.physicsBody?.categoryBitMask = SLPhysicsCategory.protectiveBarrier
        barrier.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.exploder
        barrier.physicsBody?.collisionBitMask = SLPhysicsCategory.none
        barrier.physicsBody?.affectedByGravity = false
        barrier.physicsBody?.allowsRotation = false
        barrier.physicsBody?.isDynamic = false
        
        barrier.fillColor = barrierColor ?? .blue.withAlphaComponent(0.1)
        barrier.strokeColor = strokeColor ?? .blue.withAlphaComponent(0.1)
        barrier.lineWidth = layoutInfo.barrierStrokeWidth
        barrier.zPosition = player.zPosition - 1 // CURRENTLY ABOVE BLADES. Can change.
        barrier.position = CGPoint.zero
        
        let boltNode = SKSpriteNode(imageNamed: "sl_protective_bolt")
        boltNode.position = CGPoint(x: 0, y: barrier.frame.height * -0.025)
        boltNode.zPosition = barrier.zPosition
        boltNode.alpha = 0.1
        let scale = (barrier.frame.height * 0.7) / boltNode.size.height
        boltNode.setScale(scale)
        barrier.addChild(boltNode)
        
        //Create pulsing action
        let pulseUp = SKAction.scale(to: 1.2, duration: 1.0 - state.barrierPulseFrequency) // CAN CHANGE
        let pulseDown = SKAction.scale(to: 1.0, duration: 1.0 - state.barrierPulseFrequency) // CAN CHANGE
        let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
        let repeatPulse = SKAction.repeatForever(pulseSequence)
        barrier.run(repeatPulse)
        
        //Add barrier to the barrierContainer
        barrierContainer.addChild(barrier)
        
    }
        
    func playerStateDidUpgradeHealth(_ state: SLPlayerState, restorePercentage: Double) {
        //
    }
    
    func restoreHealth(_ restorePercentage: Double) {
        let restorationAmount = playerState.currentMaxHealth * restorePercentage
        playerLives = min(playerLives + restorationAmount, playerState.currentMaxHealth)
    }
    
    func playerStateDidUpgradeMagnet(_ state: SLPlayerState) {
        // Only need this if we add UI effects after activation
//        print("Magnet Radius increased!")
    }
    
    func playerStateDidUpgradeFreeze(_ state: SLPlayerState) {
        // Only need this if we add UI effects after activation
//        print("Freeze Grenade Activated!")
    }
    
    // SPECIAL SKILLS
    func playerStateDidActivateHelpingHand(_ state: SLPlayerState) { /// ACTIVATE
        //Start firing additional projectiles every 4 seconds
        let fireAction = SKAction.run { [weak self] in
            self?.fireHelpingHandProjectile()
        }
        let waitAction = SKAction.wait(forDuration: 2.0)
        let sequence = SKAction.sequence([fireAction, waitAction])
        let repeatForever = SKAction.repeatForever(sequence)
        run(repeatForever, withKey: "helpingHandFire")
    }
    
    func playerStateDidDeactivateHelpingHand() { /// DEACTIVATE
        removeAction(forKey: "helpingHandFire")
    }
    
    func playerStateDidActivateReinforcedArrow(_ state: SLPlayerState) {
        // Only need this if we add UI effects after activation
//        print("Reinforced Arrow activated!")
    }
    
    func playerStateDidActivateSpectralShield(_ state: SLPlayerState) { /// ACTIVATE
        addSpectralShield()
    }
    
    func playerStateDidDeactivateSpectralShield() { /// DEACTIVATE
        removeSpectralShield()
    }
    
    func playerStateDidActivateMightyKnockback(_ state: SLPlayerState) {
//        print("Mightyknockback activated!")
        activateMightyKnockback()
    }
    
    func playerStateDidDeactivateMightyKnockback() {
        deactivateMightyKnockback()
    }
    
    func playerStateDidActivateBonusHealth(_ state: SLPlayerState, restorePercentage: Double) {
        // Restores player HP back to full health
        //
    }
    
    func activateHelpingHand() {
        playerState.hasHelpingHand = true
    }
    
    func removeZombies() {
        for zombie in enemyManager.enemies {
            zombie.removeFromParent()
        }
        enemyManager.enemies.removeAll()
    }

    func spawnZombies(withHealth health: Double) {
        enemyManager.spawnRegularZombie(health: health, speed: gameInfo.zombieSpeed)
    }
    
    func spawnChargerZombie() {
        enemyManager.spawnChargerZombie(health: gameInfo.zombieHealth, speed: gameInfo.zombieSpeed)
    }
        
    func spawnExploderZombie() {
        enemyManager.spawnExploderZombie(health: gameInfo.zombieHealth, speed: gameInfo.zombieSpeed)
    }
    
    func checkAndRespawnZombies() {
        for zombie in enemyManager.enemies {
            let distanceFromPlayer = zombie.position.distance(to: player.position)
            if distanceFromPlayer > layoutInfo.enemyDespawnDistance {
                print("ENEMY FAR AWAY: \(zombie) at distance \(distanceFromPlayer)")
                
                if let newPosition = enemyManager.randomSpawnPosition(avoidingRadius: layoutInfo.enemySpawnSafeRadius, around: player.position, size: zombie.size) {
                    // Optionally, add additional checks or animations here
                    zombie.position = newPosition
                    print("Zombie respawned at \(newPosition)")
                } else {
                    // Handle failure to find a valid position
                    print("Failed to respawn zombie after maximum attempts.")
                    // Optionally, remove the zombie from the scene or reposition it to a default location
                    enemyManager.removeEnemy(zombie)
                    handleEnemyDefeat(at: zombie.position)
                }
            }
        }
    }
    
    func spawnWizardBoss() {
        waveTransitionTimer?.callback = {}
        
        teleportPlayerToCenter { [weak self] in
            guard let self = self else { return }
            guard let cameraNode = self.camera else { return }
            
            arenaBounds = CGRect(
                x: cameraNode.position.x - size.width / 2,
                y: cameraNode.position.y - size.height / 2,
                width: layoutInfo.arenaSize.width,
                height: layoutInfo.arenaSize.height
            )
            
            if let arenaBounds = arenaBounds {
                let outline = SKShapeNode(rectOf: CGSize(width: arenaBounds.width, height: arenaBounds.height))
                outline.position = CGPoint(x: arenaBounds.midX, y: arenaBounds.midY)
                outline.strokeColor = .purple
                outline.fillColor = .clear
                outline.lineWidth = 4.0
                outline.name = "arenaOutline"
                addChild(outline)
            }
            
            setupArenaBarrier()
            
            //Define boss spawn position outside the arena
            let spawnOffsetY: CGFloat = (arenaBounds?.size.height ?? 756) / 7.56
            let spawnY = arenaBounds!.maxY + spawnOffsetY
            let spawnX = arenaBounds!.minX
            let spawnPosition = CGPoint(x: spawnX, y: spawnY)
            
            wizardBoss?.isAlive = true
            enemyManager.spawnWizardBoss(health: gameInfo.wizardHealth, at: spawnPosition)
        }
        
    }
    
    func teleportPlayerToCenter(completion: (() -> Void)? = nil) {
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let teleport = SKAction.run {
            self.player.position = self.layoutInfo.playerStartingPosition
        }
        let sequence = SKAction.sequence([fadeOut, teleport, fadeIn])
        
        self.run(sequence) {
            completion?()
        }
    }
    
    func updateCamera() {
        guard let cameraNode = self.camera else { return }
        if arenaBounds == nil {
            cameraNode.position = CGPoint(
                x: player.position.x,
                y: player.position.y
            )
        } else {
            //Lock camera at arena's center for when boss spawn
//            cameraNode.position = CGPoint(
//                x: arenaBounds!.midX,
//                y: arenaBounds!.midY
//            )
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let cameraNode = self.camera else { return }
        
        // MARK: NEW OVERLAY
         // If there's currently an overlay shown, we handle touches there
        if let overlay = cameraNode.children.first(where: { $0 is SLUpgradeShopOverlayNode || $0 is SLBossSpinnerOverlayNode }) {
            if let spinnerOverlay = overlay as? SLBossSpinnerOverlayNode {
                for touch in touches {
                    let location = touch.location(in: cameraNode)
                    spinnerOverlay.touchBegan(at: location)
                }
                return
            } else if let upgradeOverlay = overlay as? SLUpgradeShopOverlayNode {
                for touch in touches {
                    let location = touch.location(in: cameraNode)
                    upgradeOverlay.touchBegan(at: location)
                }
                return
            }
        }
        
        for touch in touches {
            let touchLocationInCamera = touch.location(in: cameraNode)

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
        currentGameTime = currentTime
        
        camera?.position = player.position
//        updateCamera()
    
        checkXPCollection()
        
        guard !gameOver, !isGamePaused else { return }
        
        mapManager.manageScrolling(playerPosition: player.position)
        
        checkAndRespawnZombies()
        applyContinuousDamage(currentTime: currentGameTime)
        
        if playerLives <= 0 {
            showGameOverScreen()
            return
        }
        
        //Update shooting progress bar
        let timeSinceLastShot = currentGameTime - lastShootTime
        

        let attackSpeed = (playerState.currentAttackSpeed > 0 ? playerState.currentAttackSpeed : 2.0)
        shootingProgress = CGFloat(timeSinceLastShot / attackSpeed)
        shootingProgress = min(shootingProgress, 1.0) // Clamp to 1.0
        
        // Calculate time delta for consistent movement
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        updatePlayerVelocity()
        
        let aimDirection = shootJoystick.positionDelta
        // Only update facing if there's a noticeable direction
        if abs(aimDirection.x) > 0.1 || abs(aimDirection.y) > 0.1 {
            // Calculate angle from aim direction
            let angle = atan2(aimDirection.y, aimDirection.x) - CGFloat.pi / 2
            
            // Rotate the crossbow to face aim direction
            crossbowNode.zRotation = angle
        }
        
        //Check shoot joystick to aim and shoot projectiles
        if shootJoystick.isActive {
            let aimDirection = shootJoystick.positionDelta
            if aimDirection != .zero && currentTime - lastShootTime >=  playerState.currentAttackSpeed {
                shootingProgress = 0.0
                lastShootTime = currentTime
                shootProjectile(in: aimDirection)
                
                if playerState.freezeGrenadeActive {
                    let freezeGrenadeInterval = playerState.freezeGrenadeBaseCooldown - playerState.freezeGrenadeCooldownReduction
                    if  currentTime - lastGrenadeTime >= freezeGrenadeInterval {
                        lastGrenadeTime = currentTime
                        shootGrenade(in: aimDirection)
                    }
                }
            }
        }
        
        
        enemyManager.updateEnemies(currentTime: currentTime, deltaTime: deltaTime, playerPosition: player.position)
        
        if gameInfo.currentWaveIndex < waveCycle.count {
            let wave = waveCycle[gameInfo.currentWaveIndex]
            if wave.allEnemiesSpawned && enemyManager.enemies.count <= 0 && !isBossStage {

                    handleWaveProgression()
                }
        }
        
    }
    
    func updatePlayerVelocity() {
        let maxVelocity = playerState.currentMovementSpeed * layoutInfo.screenScaleFactor
        let inputVector = joystick.positionDelta
        let desiredVelocity = CGVector(dx: inputVector.x * maxVelocity, dy: inputVector.y * maxVelocity)
        player.physicsBody?.velocity = desiredVelocity
        
        if desiredVelocity.dx < -0.1 {
            player.texture = SKTexture(imageNamed: "sl_player_left")
        } else if desiredVelocity.dx > 0.1 {
            player.texture = SKTexture(imageNamed: "sl_player_right")
        }
    }
    
    
    func countActiveChargers() -> Int {
        return enemyManager.enemies.filter { $0 is SLChargerZombieNode }.count
    }
    func countActiveExploders() -> Int {
        return enemyManager.enemies.filter { $0 is SLExploderZombieNode }.count
    }
    
    func handleWaveProgression() {
        guard !isTransitioningWave else { return }
        isTransitioningWave = true
        
        //Start grace period timer
//        waveMessageLabel.text = "Wave Over. Defeat remaining enemies.."
//        waveMessageLabel.fontSize = 20
//        waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
//        waveMessageLabel.zPosition = 5
//        waveMessageLabel.isHidden = false
        
        isGracePeriodActive = true
        remainingGracePeriod = gameInfo.waveGracePeriod
        
        waveTransitionTimer = SLPausableTimer(interval: gameInfo.waveGracePeriod, repeats: false) { [weak self] in
            self?.afterGracePeriodEnds()
        }
        waveTransitionTimer?.start()
        
//        waveProgressionWorkItem = DispatchWorkItem { [weak self] in
//            guard let self = self else { return }
//            if self.waveCycle[currentWaveIndex].requiresFullClearance {
//                if self.pendingEnemies > 0 {
//                    //Do not proceed. Wait until all enemies are defeated
//                    self.waveMessageLabel.text = "Defeat all enemies to proceed.."
//                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
//                    self.waveMessageLabel.zPosition = 5
//                } else {
//                    self.transitionToNextWave()
//                }
//            } else {
//                //Regular wave progression
//                if self.pendingEnemies > 0 {
//                    self.waveMessageLabel.text = "Next wave starting.."
//                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
//                    self.waveMessageLabel.zPosition = 5
//                } else {
//                    self.waveMessageLabel.text = "Wave Cleared. Next wave starting.."
//                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
//                    self.waveMessageLabel.zPosition = 5
//                }
//                self.transitionToNextWave()
//            }
//            self.waveMessageLabel.isHidden = false
//        }
//        //Schedule the wave progression after graceperiod
//        if let workItem = waveProgressionWorkItem {
//            DispatchQueue.main.asyncAfter(deadline: .now() + gracePeriod, execute: workItem)
//        }
    }
    
    func transitionToNextWave() {
        gameInfo.incrementWaveIndex()
        if self.gameInfo.currentWaveIndex >= self.waveCycle.count {
            self.restartCycleWithIncreasedDifficulty()
        } else {
            //DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                //guard let self = self else { return }
            self.waveMessageLabel.isHidden = true
            self.isTransitioningWave = false
            self.startNextWave()
            //}
        }
    }
    
    func afterGracePeriodEnds() {
        waveTransitionTimer?.callback = {}
        if self.waveCycle[gameInfo.currentWaveIndex].requiresFullClearance {

            if self.enemyManager.enemies.count > 0 {
                // Do not proceed. Wait until all enemies are defeated
                self.waveMessageLabel.text = "Defeat all enemies to proceed.."
                self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                self.waveMessageLabel.zPosition = 5
                self.waveMessageLabel.isHidden = false
                // Maintain isGracePeriodActive and isTransitioningWave to prevent further progression
            } else {
                self.transitionToNextWave()
            }
        } else {
            // Regular wave progression
            if self.enemyManager.enemies.count > 0 {
                self.waveMessageLabel.text = "Next wave starting.."
                self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                self.waveMessageLabel.zPosition = 5
            } else {
                self.waveMessageLabel.text = "Wave Cleared. Next wave starting.."
                self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                self.waveMessageLabel.zPosition = 5
            }
            self.waveMessageLabel.isHidden = false
            self.transitionToNextWave()
        }

        // Reset wave progression status
        self.isGracePeriodActive = false
        self.isTransitioningWave = false
    }
    
    func clearAllEnemies() {
//        gameInfo.pendingEnemies = 0
        enemyManager.removeAllEnemies()
    }
    
    
    func startBossStage() {
//        print("startBossStage", gameInfo.currentWaveIndex, "<", waveCycle.count)
        guard gameInfo.currentWaveIndex < waveCycle.count else { return }
        let wave = waveCycle[gameInfo.currentWaveIndex]
        guard wave.isBoss else { return }
        
        isBossStage = true
        isTransitioningWave = true //Prevents regular enemy spawning during boss stage
        clearAllEnemies()
        
        progressLabel.text = "Defeat the boss!"
        waveMessageLabel.text = "Boss Stage Starting.."
        waveMessageLabel.isHidden = false
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//            self.waveMessageLabel.isHidden = true
//            self.isTransitioningWave = false
//            self.spawnWizardBoss()
//        }
        waveTransitionTimer = SLPausableTimer(interval: 3.0, repeats: false) { [weak self] in
            self?.waveMessageLabel.isHidden = true
            self?.isTransitioningWave = false
            self?.spawnWizardBoss()
        }
        waveTransitionTimer?.start()
    }
    
    
    func setupArenaBarrier() {
        guard let arenaBounds = arenaBounds else { return }
        
        let arenaBarrier = SKSpriteNode(color: .clear, size: CGSize(width: arenaBounds.width, height: arenaBounds.height))
        arenaBarrier.position = CGPoint(x: arenaBounds.midX, y: arenaBounds.midY)
        arenaBarrier.name = "arenaBarrier"
        
        //Configure physics body as an edge loop to prevent the player from leaving
        arenaBarrier.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: -arenaBounds.width / 2, y: -arenaBounds.height / 2, width: arenaBounds.width, height: arenaBounds.height))
        arenaBarrier.physicsBody?.categoryBitMask = SLPhysicsCategory.bossArenaBorder
        arenaBarrier.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
        arenaBarrier.physicsBody?.collisionBitMask = SLPhysicsCategory.player
        arenaBarrier.physicsBody?.affectedByGravity = false
        arenaBarrier.physicsBody?.allowsRotation = false
        arenaBarrier.physicsBody?.isDynamic = false
        addChild(arenaBarrier)
    }
    
    func handleBossDefeat() {
        
        wizardBoss?.isAlive = false
        arenaBounds = nil

        if let outline = childNode(withName: "arenaOutline") as? SKShapeNode {
            outline.removeFromParent()
        }
        if let arenaBarrier = self.childNode(withName: "arenaBarrier") {
            arenaBarrier.removeFromParent()
        }
        
         // Create the special skill spinner overlay
        let spinnerOverlay = SLBossSpinnerOverlayNode(skillManager: skillManager, overlayManager: overlayManager, overlaySize: size, scaleFactor: layoutInfo.screenScaleFactor)
        overlayManager.enqueueOverlay(spinnerOverlay)
        
        isBossStage = false
        isTransitioningWave = true
        gameInfo.incrementWaveIndex()
        waveLabel.text = "Wave \(waveCounter)"
        
        //No enemies to carry over from boss stage
        //pendingEnemies reset
        gameInfo.resetPendingEnemies()
        gameInfo.resetEnemiesToSpawn()
        updateProgressLabel()
        
        //Increase difficulty variables
        gameInfo.incrementWizardHealth(by: gameInfo.wizardHealth)
        
        gameInfo.updateWaveGracePeriod(to: max(1.0, gameInfo.waveGracePeriod - 2.0)) // Decrease grace period, minimum 5 seconds
        miniWaveInterval = max(1.0, miniWaveInterval - 0.1)
        
        //Show post boss message
        waveMessageLabel.text = "Enemies getting stronger.."
        waveMessageLabel.fontSize = 30
        waveMessageLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.waveMessageLabel.isHidden = true
            self.waveMessageLabel.fontSize = 40
            self.isTransitioningWave = false // Allow regular spawning again
            self.startNextWave()
        }
    
    }
    
    func restartCycleWithIncreasedDifficulty() {
        //Remove existing waves

        
        //Define increased difficulty waves
        //For simplicity, we'll increase the number of enemies and adjust spawn intervals
        //Can further customize here based on game's balance needs later on
        hordeSpawnInterval = max(0.1, hordeSpawnInterval - 0.2)

        
        let cycleMultiplier = 1.5
        //*******************************************************************************************
        //*******************************************************************************************
        //*******************************************************************************************
        // SEE NOTE ABOVE ^
        var tempWaveCycle: [Wave] = []
        for wave in waveCycle {
            tempWaveCycle.append(Wave(waveNumber: wave.waveNumber, totalEnemies: wave.totalEnemies * Int(cycleMultiplier), regularEnemies: wave.regularEnemies * Int(cycleMultiplier), chargerEnemies: wave.chargerEnemies * Int(cycleMultiplier), exploderEnemies: wave.exploderEnemies * Int(cycleMultiplier), isHorde: wave.isHorde, isBoss: wave.isBoss, spawnInterval: wave.spawnInterval, requiresFullClearance: wave.requiresFullClearance))
        }
        waveCycle.removeAll()
        waveCycle = tempWaveCycle
        
//        for waveNumber in 1...7 {
//            switch waveNumber {
//            case 1:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 10 * Int(cycleMultiplier), regularEnemies: 10 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false))
//            case 2:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 15 * Int(cycleMultiplier), regularEnemies: 15 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false))
//            case 3:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 25 * Int(cycleMultiplier), regularEnemies: 25 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: false))
//            case 4:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 20 * Int(cycleMultiplier), regularEnemies: 15 * Int(cycleMultiplier), chargerEnemies: 5 * Int(cycleMultiplier), exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false))
//            case 5:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 20 * Int(cycleMultiplier), regularEnemies: 15 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 5 * Int(cycleMultiplier), isHorde: false, isBoss: false, spawnInterval: normalSpawnInterval, requiresFullClearance: false))
//            case 6:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 35 * Int(cycleMultiplier), regularEnemies: 20 * Int(cycleMultiplier), chargerEnemies: 8 * Int(cycleMultiplier), exploderEnemies: 7 * Int(cycleMultiplier), isHorde: true, isBoss: false, spawnInterval: hordeSpawnInterval, requiresFullClearance: true))
//            case 7:
//                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 1, regularEnemies: 0, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: true, spawnInterval: 0.0, requiresFullClearance: false))
//            default:
//                break
//            }
//        }
        
        gameInfo.resetWaveIndex()
        gameInfo.resetPendingEnemies()
        gameInfo.resetEnemiesToSpawn()
        updateProgressLabel()
        startNextWave()
    }

    func shootProjectile(in direction: CGPoint) {
        let projectileTextureName = playerState.projectilesPierce ? "sl_arrow_reinforced" : "sl_arrow"

        let projectile = SKSpriteNode(imageNamed: projectileTextureName)
        let projectileScale = layoutInfo.projectileHeight / projectile.size.height
        projectile.setScale(projectileScale)
        projectile.position = player.position
        projectile.zPosition = player.zPosition - 1
        projectile.name = "projectile"
        projectile.userData = NSMutableDictionary()
        projectile.userData?.setValue(playerState.projectilesPierce, forKey: "pierce")
        
        projectile.physicsBody = SKPhysicsBody(texture: projectile.texture!, size: projectile.size)
        projectile.physicsBody?.categoryBitMask = SLPhysicsCategory.projectile
        projectile.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.border | SLPhysicsCategory.exploder
        projectile.physicsBody?.collisionBitMask = SLPhysicsCategory.none
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.allowsRotation = false
        
        addChild(projectile)

        let normalizedDirection = CGVector(dx: direction.x, dy: direction.y).normalized
        projectile.zRotation = atan2(normalizedDirection.dy, normalizedDirection.dx) - CGFloat.pi / 2

        let moveDistance: CGFloat = playerState.currentRange * layoutInfo.screenScaleFactor
        let speed: CGFloat = playerState.projectileSpeed * layoutInfo.screenScaleFactor
        let duration = TimeInterval(moveDistance / speed)

        let moveAction = SKAction.move(by: CGVector(dx: normalizedDirection.dx * moveDistance,
                                                    dy: normalizedDirection.dy * moveDistance),
                                       duration: duration)

        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let removeAction = SKAction.removeFromParent()
        let fadeOutAndRemove = SKAction.sequence([fadeOut, removeAction])

        projectile.run(SKAction.sequence([moveAction, fadeOutAndRemove]))
        
        let shootSoundAction = SKAction.playSoundFileNamed("sl_arrow.mp3", waitForCompletion: false)
        run(shootSoundAction)
    }
    
    func shootGrenade(in direction: CGPoint) {
        let grenade = SKSpriteNode(imageNamed: "sl_freeze_grenade")
        let grenadeScale = layoutInfo.freezeGrenadeHeight / grenade.size.height
        grenade.setScale(grenadeScale)
        grenade.position = player.position
        grenade.name = "freezeGrenade"
        grenade.userData = NSMutableDictionary()
        grenade.userData?["hasCollided"] = false
        
        // MARK: Physics
        grenade.physicsBody = SKPhysicsBody(texture: grenade.texture!, size: grenade.size)
        grenade.physicsBody?.categoryBitMask = SLPhysicsCategory.grenade
        grenade.physicsBody?.contactTestBitMask = SLPhysicsCategory.border
        grenade.physicsBody?.collisionBitMask = SLPhysicsCategory.none
        grenade.physicsBody?.affectedByGravity = false
        grenade.physicsBody?.allowsRotation = false
        
        addChild(grenade)
        
        let normalizedDirection = CGVector(dx: direction.x, dy: direction.y).normalized
        let grenadeMoveDistance: CGFloat = layoutInfo.freezeGrenadeMoveDistance
        let moveAction = SKAction.move(by: CGVector(dx: normalizedDirection.dx * grenadeMoveDistance, dy: normalizedDirection.dy * grenadeMoveDistance), duration: 1.0)
        
        let waitAction = SKAction.wait(forDuration: 1.0)
        let explodeAction = SKAction.run {
            self.explodeGrenade(grenade)
        }
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let removeAction = SKAction.removeFromParent()
        let fadeOutAndRemove = SKAction.sequence([fadeOut, removeAction])
        
        let sequence = SKAction.sequence([moveAction, waitAction, explodeAction, fadeOutAndRemove])
        grenade.run(sequence)
        
        let shootSoundAction = SKAction.playSoundFileNamed("sl_grenade_toss.mp3", waitForCompletion: false)
        run(shootSoundAction)
            
    }
        
    func explodeGrenade(_ grenade: SKSpriteNode) {
        let explosionRadius = playerState.freezeRadius * layoutInfo.screenScaleFactor
        
        let freezeExplosion = SKShapeNode(circleOfRadius: explosionRadius)
        freezeExplosion.position = grenade.position
        freezeExplosion.zPosition = 4
        
        freezeExplosion.fillColor = UIColor(hex: "#18A0FB")?.withAlphaComponent(0.3) ?? .cyan.withAlphaComponent(0.3)
        freezeExplosion.strokeColor = UIColor(hex: "#18A0FB") ?? .cyan
        freezeExplosion.lineWidth = explosionRadius * 0.04
        freezeExplosion.glowWidth = freezeExplosion.lineWidth * 2.0
        freezeExplosion.alpha = 0.0
        
        freezeExplosion.physicsBody = SKPhysicsBody(circleOfRadius: explosionRadius)
        freezeExplosion.physicsBody?.categoryBitMask = SLPhysicsCategory.freeze
        freezeExplosion.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.exploder
        freezeExplosion.physicsBody?.collisionBitMask = SLPhysicsCategory.none
        freezeExplosion.physicsBody?.affectedByGravity = false
        freezeExplosion.physicsBody?.allowsRotation = false
        freezeExplosion.physicsBody?.isDynamic = false
        
        addChild(freezeExplosion)
        
        freezeExplosion.setScale(0.1)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.05)
        let fadeIn = SKAction.fadeIn(withDuration: 0.05)
        let wait = SKAction.wait(forDuration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([scaleUp, fadeIn])
        let remove = SKAction.removeFromParent()
        let explodeSequence = SKAction.sequence([group, wait, fadeOut, remove])
        freezeExplosion.run(explodeSequence)
    }
        
    func absorbShieldHit() {
        let shootSoundAction = SKAction.playSoundFileNamed("sl_shield_break.mp3", waitForCompletion: false)
        run(shootSoundAction)
        
        playerState.shieldHitsRemaining -= 1
        updateShieldAppearance()
        
        if playerState.shieldHitsRemaining <= 0 {
            removeSpectralShield()
        }
    }
    
//    func updateShieldAppearance() {
//        guard let shield = spectralShield else { return }
//        switch playerState.shieldHitsRemaining {
//        case playerState.shieldMaxHits:
//            shield.strokeColor = UIColor.green.withAlphaComponent(0.7)
//        case playerState.shieldMaxHits - 1:
//            shield.strokeColor = UIColor.orange.withAlphaComponent(0.7)
//        case 1:
//            shield.strokeColor = UIColor.red.withAlphaComponent(0.7)
//        default:
//            shield.strokeColor = UIColor.gray //Default or error color
//        }
//    }

    
    func fireHelpingHandProjectile() {
        guard let target = findNearestEnemy(within: 200.0 * layoutInfo.screenScaleFactor) else {
            return
        }
        
        let helpingHandProjectile = SKSpriteNode(imageNamed: "sl_helping_hand")
        let helpingHandScale = layoutInfo.helpingHandHeight / helpingHandProjectile.size.height
        helpingHandProjectile.setScale(helpingHandScale)
        helpingHandProjectile.position = player.position
        helpingHandProjectile.name = "helpingHandProjectile"

        // MARK: Physics
        helpingHandProjectile.physicsBody = SKPhysicsBody(texture: helpingHandProjectile.texture!, size: helpingHandProjectile.size)
        helpingHandProjectile.physicsBody?.categoryBitMask = SLPhysicsCategory.projectile
        helpingHandProjectile.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.border | SLPhysicsCategory.exploder
        helpingHandProjectile.physicsBody?.collisionBitMask = SLPhysicsCategory.none // Let's make helping hand not collide, just pass through
        helpingHandProjectile.physicsBody?.affectedByGravity = false
        helpingHandProjectile.physicsBody?.allowsRotation = false
        
        addChild(helpingHandProjectile)
        
        // Calculate direction vector towards the target
        let direction = CGVector(dx: target.position.x - player.position.x, dy: target.position.y - player.position.y).normalized
        helpingHandProjectile.zRotation = atan2(direction.dy, direction.dx)
        

        let moveDistance: CGFloat = (playerState.currentRange * layoutInfo.screenScaleFactor) * 3.0
        let moveAction = SKAction.move(by: CGVector(dx: direction.dx * moveDistance, dy: direction.dy * moveDistance), duration: 2.0)
        
        // Placeholder for collision check (to be implemented later)
        let collisionAction = SKAction.run {
//            self.checkProjectileCollision(projectile)  Uncomment when collision is implemented
        }
        let collisionCheckSequence = SKAction.sequence([collisionAction, SKAction.wait(forDuration: 0.05)])
        let repeatCollisionCheck = SKAction.repeat(collisionCheckSequence, count: Int(2.0 / 0.05)) // Runs for duration of moveAction
        
        let combinedAction = SKAction.group([moveAction, repeatCollisionCheck])
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let removeAction = SKAction.removeFromParent()
        let fadeOutAndRemove = SKAction.sequence([fadeOut, removeAction])
        
        helpingHandProjectile.run(SKAction.sequence([combinedAction, fadeOutAndRemove]))
        
        let shootSoundAction = SKAction.playSoundFileNamed("sl_helping_hand.mp3", waitForCompletion: false)
        run(shootSoundAction)
    }

    /// Finds the nearest enemy (zombie or wizard) within a specified radius.
    func findNearestEnemy(within radius: CGFloat) -> SKSpriteNode? {
        var nearestEnemy: SKSpriteNode?
        var shortestDistance = radius
        
        // Iterate through zombies to find the nearest one within the radius
        for zombie in enemyManager.enemies {
            let distance = hypot(zombie.position.x - player.position.x, zombie.position.y - player.position.y)
            if distance < shortestDistance {
                shortestDistance = distance
                nearestEnemy = zombie
            }
        }
        
        // Check if the wizard is within the radius and closer than any zombie
        if let wizard = scene?.childNode(withName: "wizard") as? SLWizard {
            let distanceToWizard = hypot(wizard.position.x - player.position.x, wizard.position.y - player.position.y)
            if distanceToWizard < shortestDistance {
                shortestDistance = distanceToWizard
                nearestEnemy = wizard
            }
        }
        
        return nearestEnemy
    }
    
    func addSpectralShield() {
        if spectralShield != nil { return }
        guard let shieldContainer = shieldContainer else { return }
        
        shieldContainer.removeAllChildren()
        
        let shield = SKShapeNode(circleOfRadius: layoutInfo.spectralShieldRadius)
        shield.alpha = 0.7
        shield.lineWidth = layoutInfo.spectralShieldRadius * 0.025
        shield.position = CGPoint.zero
        shield.zPosition = 2
        shield.name = "spectralShield"
        
        shield.physicsBody = SKPhysicsBody(circleOfRadius: layoutInfo.spectralShieldRadius)
        shield.physicsBody?.categoryBitMask = SLPhysicsCategory.shield
        shield.physicsBody?.contactTestBitMask = SLPhysicsCategory.enemy | SLPhysicsCategory.boss | SLPhysicsCategory.exploder
        shield.physicsBody?.collisionBitMask = SLPhysicsCategory.none
        shield.physicsBody?.affectedByGravity = false
        shield.physicsBody?.allowsRotation = false
        shield.physicsBody?.isDynamic = false
        
        shieldContainer.addChild(shield)
        spectralShield = shield
        
        playerState.shieldHitsRemaining = playerState.shieldMaxHits
        updateShieldAppearance()
        
        addShieldInstances()
    }

    private func addShieldInstances() {
        guard let shield = spectralShield else { return }

        shield.removeAllChildren()

        let shieldHits = playerState.shieldHitsRemaining
        let radius: CGFloat = layoutInfo.spectralShieldRadius
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(shieldHits)

        for i in 0..<shieldHits {


            let shieldInstance = SKSpriteNode(imageNamed: "sl_shield_instance")
            let shieldInstanceScale = (radius * 0.5) / shieldInstance.size.height
            shieldInstance.setScale(shieldInstanceScale)
            
            let angle = CGFloat(i) * angleIncrement
            let xPosition = (radius - shieldInstance.size.width / 2)  * cos(angle)
            let yPosition = (radius - shieldInstance.size.height / 2)  * sin(angle)
            shieldInstance.position = CGPoint(x: xPosition, y: yPosition)
            
            shieldInstance.zPosition = shield.zPosition + 1
            shieldInstance.name = "shieldInstance"
            
            // Ensure shield instance stays upright
            shieldInstance.zRotation = 0
            
            shield.addChild(shieldInstance)
        }

        animateShieldInstances(shield)
    }

    private func animateShieldInstances(_ shield: SKShapeNode) {
        let radius: CGFloat = layoutInfo.spectralShieldRadius
        let duration: TimeInterval = 2.0 // Time for a full rotation
        let shieldHits = playerState.shieldHitsRemaining
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(shieldHits)

        let rotateAction = SKAction.customAction(withDuration: duration) { _, elapsedTime in
            let currentAngle = (2 * CGFloat.pi) * (elapsedTime / CGFloat(duration))

            for (index, child) in shield.children.enumerated() {
                guard let shieldInstance = child as? SKSpriteNode else { continue }
                let angle = currentAngle + (CGFloat(index) * angleIncrement)
                let xPosition = (radius - shieldInstance.size.width / 2) * cos(angle)
                let yPosition = (radius - shieldInstance.size.height / 2) * sin(angle)

                shieldInstance.position = CGPoint(x: xPosition, y: yPosition)
                shieldInstance.zRotation = 0 // Keep upright
            }
        }

        let repeatRotation = SKAction.repeatForever(rotateAction)
        shield.run(repeatRotation, withKey: "rotateShieldInstances")
    }
    
    func updateShieldAppearance() {
        guard let shield = spectralShield else { return }
        
//        switch playerState.shieldHitsRemaining {
//        case playerState.shieldMaxHits:
//            shield.strokeColor = UIColor.green.withAlphaComponent(0.7)
//        case playerState.shieldMaxHits - 1:
//            shield.strokeColor = UIColor.orange.withAlphaComponent(0.7)
//        case 1:
//            shield.strokeColor = UIColor.red.withAlphaComponent(0.7)
//        default:
//            shield.strokeColor = UIColor.gray // Default or error color
//        }
        
        shield.strokeColor = UIColor(hex: "#FFF700")?.withAlphaComponent(0.25) ?? .yellow.withAlphaComponent(0.25)
        
        addShieldInstances()
    }
    
    func removeSpectralShield() {
        if let shield = spectralShield {
            shield.removeAllActions()
            shield.removeFromParent()
            spectralShield = nil
        }

        playerState.spectralShieldActive = false
        
        //Start cooldown timer to reactivate the shield after 'shieldCooldown'
        DispatchQueue.main.asyncAfter(deadline: .now() + playerState.shieldCooldown) { [weak self] in
            guard let self = self else { return }
            let ownsSpectralShield = self.skillManager.ownedSpecialSkills.contains { $0.type == .spectralShield }
            if ownsSpectralShield {
                self.playerState.activateSpectralShield()
            }
        }
    }
    
    func applyKnockback(to enemy: SKSpriteNode, strength: CGFloat, duration: TimeInterval) {
        // Calculate the direction vector from player to enemy
        let dx = enemy.position.x - player.position.x
        let dy = enemy.position.y - player.position.y
        let magnitude = sqrt(dx * dx + dy * dy)
        
        // Avoid division by zero
        guard magnitude != 0 else { return }
        
        // Normalize the direction vector
        let normalizedDx = dx / magnitude
        let normalizedDy = dy / magnitude
        
        // Determine the knockback vector based on strength
        let knockbackVector = CGVector(dx: normalizedDx * strength, dy: normalizedDy * strength)
        
        // Calculate the new position by adding the knockback vector
        var newPosition = CGPoint(x: enemy.position.x + knockbackVector.dx,
                                  y: enemy.position.y + knockbackVector.dy)
        
        // Clamp the new position within scene bounds to prevent enemies from moving off-screen
        newPosition.x = max(enemy.size.width / 2, min(newPosition.x, size.width - enemy.size.width / 2))
        newPosition.y = max(enemy.size.height / 2, min(newPosition.y, size.height - enemy.size.height / 2))
        
        // Create the move action
        let moveAction = SKAction.move(to: newPosition, duration: duration)
        moveAction.timingMode = .easeOut
        
        // Optionally, add a visual feedback (e.g., flash)
        let flashAction = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.05),
            SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        ])
        
        // Run the actions on the enemy
        enemy.run(SKAction.sequence([flashAction, moveAction]), withKey: "knockback")
    }
    
    func performMightyKnockback() {
        let shootSoundAction = SKAction.playSoundFileNamed("sl_knockback.mp3", waitForCompletion: false)
        run(shootSoundAction)
        
        // Radius of the knockback
        let knockbackRadius: CGFloat = layoutInfo.knockbackRadius
        let knockbackStrength: CGFloat = layoutInfo.knockbackStrength
        let knockbackDuration: TimeInterval = 0.3

        // Apply knockback to all enemies in range
        for enemy in enemyManager.enemies {
            let distance = player.position.distance(to: enemy.position)
            if distance <= knockbackRadius {
                applyKnockback(to: enemy, strength: knockbackStrength, duration: knockbackDuration)
            }
        }

        // Add visual effect
        let knockbackEmitter = SKEmitterNode(fileNamed: "SLKnockBack")
        knockbackEmitter?.position = player.position
        knockbackEmitter?.zPosition = player.zPosition - 1

        // Add the emitter to the scene
        addChild(knockbackEmitter!)

        // Remove emitter after its effect ends
        let removeEmitter = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ])
        knockbackEmitter!.run(removeEmitter)
    }
    
    func activateMightyKnockback() {
        guard playerState.mightyKnockbackActive else { return }
        playerState.mightyKnockbackActive = true

        let knockbackAction = SKAction.run { [weak self] in
            self?.performMightyKnockback()
        }
        let waitAction = SKAction.wait(forDuration: 7.0)
        let knockbackSequence = SKAction.sequence([knockbackAction, waitAction])
        let repeatKnockback = SKAction.repeatForever(knockbackSequence)
        
        run(repeatKnockback, withKey: "mightyKnockback")
    }

    func deactivateMightyKnockback() {
        playerState.mightyKnockbackActive = false
        removeAction(forKey: "mightyKnockback")
    }
    
    func applyContinuousDamage(currentTime: TimeInterval) {
        //Initialize lastDamageTime if it's the first call
        if lastDamageTime == 0.0 {
            lastDamageTime = currentTime
            return
        }
        
        //Check if enough time has passed to apply damage
        if currentTime - lastDamageTime >= layoutInfo.enemyDamageInterval {
            //Create temporary array to iterate
            let enemiesToProcess = Array(damagingEnemies)
            
            for enemy in enemiesToProcess {
                guard !enemy.isDead, enemy.parent != nil else {
                    damagingEnemies.remove(enemy)
                    continue
                }
                
                if isPlayerStillInContact(with: enemy) {
                    applyDamageToPlayer(from: enemy)
                    //Can add visual feedback here
                } else {
                    resumeEnemyMovement(enemy)
                    damagingEnemies.remove(enemy)
                }
            }
            lastDamageTime = currentTime
        }
    }
    
    func applyBeamDamage() {
        //Identify beams that are no longer in the scene
        var beamsToRemove: [SKPhysicsBody] = []
        for beamBody in activeBeamContacts {
            if beamBody.node?.parent == nil {
                beamsToRemove.append(beamBody)
            }
        }
        //Remove beams that are no longer present
        for beamBody in beamsToRemove {
            activeBeamContacts.remove(beamBody)
        }
        if !activeBeamContacts.isEmpty {
            bossHitPlayer()
        }
    }
    
    func isPlayerStillInContact(with enemy: SLZombie) -> Bool {
        //Can use either physics contact info or distance check
        let distance = player.position.distance(to: enemy.position)
        let contactRadius: CGFloat = (player.size.width + enemy.size.width) / 2
        
        return distance <= contactRadius
    }
    
    func updateXPBar() {
        xpBarNode.setXP(currentXP: upgradeShopManager.XPCount,
                        xpToNextLevel: upgradeShopManager.XPToNextLevel,
                        xpThreshold: upgradeShopManager.nextShopXPThreshold)
    }
    
    func handleEnemyDefeat(at lastHitZombiePosition: CGPoint) {
        spawnXPNode(at: lastHitZombiePosition)
        
        // MARK: Delete later, just for testing purposes
//        let spinnerOverlay = BossSpinnerOverlayNode(skillManager: skillManager, overlayManager: overlayManager, overlaySize: size)
//        overlayManager.enqueueOverlay(spinnerOverlay)
        
        score += 1
        gameInfo.incrementPendingEnemies(by: -1)
        updateProgressLabel()
        
        //If pendingEnemies is zero and wave progression is not already ongoing
        if enemyManager.enemies.count == 0 {
            if waveCycle[gameInfo.currentWaveIndex].requiresFullClearance {
                //proceed to next wave immediately
                //cancel any scheduled wave progression
                waveProgressionWorkItem?.cancel()
                waveProgressionWorkItem = nil
                transitionToNextWave()
            } else if waveCycle[gameInfo.currentWaveIndex].allEnemiesSpawned {
                handleWaveProgression()
            }
        }
    }
    
    func checkXPCollection() {
        for (_, xpNode) in xpNodes.enumerated().reversed() {
            let distance = player.position.distance(to: xpNode.position)
            if distance < (playerState.currentXPRadius * layoutInfo.screenScaleFactor) {
                
                if let idx = self.xpNodes.firstIndex(where: { $0 === xpNode }) {
                    self.xpNodes.remove(at: idx)
                }
                xpNodesToRemove.append(xpNode)
                
                let moveAction = SKAction.move(to: player.position, duration: 0.1)
                let scaleAction = SKAction.scale(to: 0.0, duration: 0.1)
                let groupAction = SKAction.group([moveAction, scaleAction])
                                
                
                let removeAction = SKAction.run { [weak self, weak xpNode] in
                    guard let self = self, let xpNode = xpNode else { return }
                    
                    if let idx = self.xpNodesToRemove.firstIndex(where: { $0 === xpNode }) {
                        self.xpNodesToRemove.remove(at: idx)
                    }
                    
                    // Update player XP
                    self.playerState.currentXP += xpNode.xpAmount
                    self.upgradeShopManager.incrementXPCount()
                    self.updateXPBar()
                    self.upgradeShopManager.checkForShop()
                    
                    // Remove the XP node from the scene
                    xpNode.removeFromParent()

                }
                
                let sequence = SKAction.sequence([groupAction, removeAction])
                
                xpNode.run(sequence)
            }
        }
    }
    
    func spawnXPNode(at position: CGPoint) {
        let timeUntilDespawn: TimeInterval = 25
        
        let xpValue = 1
        let xpNode = SLXPNode(xpAmount: xpValue, scaleFactor: layoutInfo.screenScaleFactor)
        xpNode.position = position
        xpNode.zPosition = player.zPosition - 1
        
        xpNode.alpha = 0.0
        xpNode.setScale(0.0)
        
        addChild(xpNode)
        xpNodes.append(xpNode)
        
        // Spawn animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let spawnGroup = SKAction.group([scaleUp, fadeIn])
        let spawnSequence = SKAction.sequence([spawnGroup, scaleDown])
        
        xpNode.run(spawnSequence)
        
        // Despawn animation
        let despawnDelay = SKAction.wait(forDuration: timeUntilDespawn)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let shrink = SKAction.scale(to: 0.0, duration: 0.2)
        let group = SKAction.group([fadeOut, shrink])
        let removeFromScene = SKAction.removeFromParent()
        let removeFromArray = SKAction.run { [weak self, weak xpNode] in
            guard let self = self, let node = xpNode else { return }
            if let index = self.xpNodes.firstIndex(where: { $0 === node }) {
                self.xpNodes.remove(at: index)
            }
        }
        
        let sequence = SKAction.sequence([despawnDelay, group, removeFromScene, removeFromArray])
        xpNode.run(sequence)
    }
    
    func spawnRandomXPNode() {
        guard let player = player else { return }

        let spawnBuffer: CGFloat = layoutInfo.xpSpawnBuffer + playerState.currentXPRadius
        let spawnRadius: CGFloat = layoutInfo.xpSpawnRadius
        let xpSize = layoutInfo.xpSpawnSize
        
        var attempts = 0
        let maxAttempts = 100
        var validPosition: CGPoint?
        
        while attempts < maxAttempts {
            let angle = CGFloat.random(in: 0...2 * .pi)
            let distance = CGFloat.random(in: spawnBuffer...spawnRadius)
            
            let offsetX = distance * cos(angle)
            let offsetY = distance * sin(angle)
            var randomPosition = CGPoint(x: player.position.x + offsetX, y: player.position.y + offsetY)
            randomPosition.y = min(max(randomPosition.y, mapManager.bottomBound + spawnBuffer), mapManager.topBound - spawnBuffer)
            
            // Check if position is clear of obstacles
            if mapManager.positionIsClear(position: randomPosition, entitySize: xpSize) {
                validPosition = randomPosition
                break
            }
            
            attempts += 1
        }
        // If no valid position found, do not spawn XP
        guard let spawnPosition = validPosition else { return }
        
        spawnXPNode(at: spawnPosition)
    }
    
    func startXPSpawnTimer() {
        guard xpSpawnTimer == nil else { return }
        
        xpSpawnTimer = Timer.scheduledTimer(withTimeInterval: xpSpawnInterval, repeats: true) { [weak self] _ in
            self?.spawnRandomXPNode()
        }
    }
    
    func stopXPSpawnTimer() {
        xpSpawnTimer?.invalidate()
        xpSpawnTimer = nil
    }
    
    func bossHitPlayer() {
        flashPlayer()
        playerLives -= 1
    }
    
//    private func showEnemyIntroductionMessage(_ message: String) {
//        guard let cameraNode = self.camera else { return }
//        let enemyMessageLabel = SKLabelNode(text: message)
//        enemyMessageLabel.fontName = "Arial"
//        enemyMessageLabel.fontSize = 40
//        enemyMessageLabel.fontColor = .red
//        enemyMessageLabel.position = CGPoint(x: 0, y: size.height * 0.25)
//        enemyMessageLabel.zPosition = 5
//        cameraNode.addChild(enemyMessageLabel)
//
//        let fadeOut = SKAction.sequence([
//            SKAction.wait(forDuration: 5.0),
//            SKAction.fadeOut(withDuration: 0.5),
//            SKAction.run { enemyMessageLabel.removeFromParent() }
//        ])
//        enemyMessageLabel.run(fadeOut)
//    }
    
    func showEnemyIntroductionMessage(forWaveNumber waveNumber: Int) {
        // Map the wave number to the appropriate banner
        if let bannerName = newEnemyBannerMapping[waveNumber] {
            SLSoundManager.shared.playSoundEffect(.horn)
            SLSoundManager.shared.setSoundEffectVolume(.horn, volume: 0.2)
            showBannerNode(imageName: bannerName, duration: 5.0)
        }
    }

    
    func showGameOverScreen() {
        gameOver = true
        guard let cameraNode = self.camera else { return }
        
        player.physicsBody?.velocity = .init(dx: 0, dy: 0)
        
        SLHapticManager.shared.triggerExplosionHaptic()
        SLSoundManager.shared.playSoundEffect(.gameOver)
        SLSoundManager.shared.setSoundEffectVolume(.gameOver, volume: 0.2)
        
        let redOverlay = SKSpriteNode(color: UIColor(hex: "#200000") ?? .red, size: self.size)
        redOverlay.position = CGPoint(x: 0, y: 0)
        redOverlay.zPosition = 10
        redOverlay.alpha = 0.0
        redOverlay.name = "redOverlay"
        cameraNode.addChild(redOverlay)
        
        let fadeInRed = SKAction.fadeAlpha(to: 0.7, duration: 0.5)
        redOverlay.run(fadeInRed)
        
        let gameOverTitle = SKSpriteNode(imageNamed: "sl_game_over")
        let gameOverScale = layoutInfo.gameOverWidth / gameOverTitle.size.width
        gameOverTitle.setScale(gameOverScale)
        gameOverTitle.position = layoutInfo.gameOverPosition
        gameOverTitle.zPosition = 11
        gameOverTitle.alpha = 0.0
        gameOverTitle.name = "gameOverImage"
        cameraNode.addChild(gameOverTitle)
        
        let fadeInGameOverImage = SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        gameOverTitle.run(fadeInGameOverImage)
        
        let wait = SKAction.wait(forDuration: 2.5)
        let showGameOverFlow = SKAction.run { [weak self] in
            self?.presentGameOverFlow()
        }
        let sequence = SKAction.sequence([wait, showGameOverFlow])
        cameraNode.run(sequence)
    }
    
    func presentGameOverFlow() {
        guard let cameraNode = self.camera else { return }
        
        //Prevent adding multiple gameOverScreens
        if cameraNode.childNode(withName: "gameOverScreen") != nil { return }
        
        // 4. Create the game over node with buttons
        let gameOverNode = SKShapeNode(rect: CGRect(x: -size.width * 0.4, y: -size.height * 0.2, width: size.width * 0.8, height: size.height * 0.4), cornerRadius: 20)
        gameOverNode.fillColor = .black.withAlphaComponent(0.8)
        gameOverNode.name = "gameOverScreen"
        gameOverNode.zPosition = 12 // Above everything else
        gameOverNode.alpha = 0.0 // Start invisible
        cameraNode.addChild(gameOverNode)
        
        // Fade in the game over node
        let fadeInGameOverNode = SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        gameOverNode.run(fadeInGameOverNode)
        
        // Add "Game Over" label with a slight delay
        let gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontName = "Arial"
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .white
        gameOverLabel.position = CGPoint(x: 0, y: gameOverNode.frame.height * 0.3)
        gameOverLabel.zPosition = 13
        gameOverLabel.alpha = 0.0
        gameOverNode.addChild(gameOverLabel)
        
        let fadeInLabel = SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 1.0)
        let labelAction = SKAction.group([fadeInLabel, moveUp])
        gameOverLabel.run(labelAction)
        
        // Add Score label
        let scoreLabel = SKLabelNode(text: "Score: \(score)")
        scoreLabel.fontName = "Arial"
        scoreLabel.fontSize = 30
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: gameOverNode.frame.height * 0.1)
        scoreLabel.zPosition = 13
        scoreLabel.alpha = 0.0
        gameOverNode.addChild(scoreLabel)
        
        let fadeInScoreLabel = SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        scoreLabel.run(fadeInScoreLabel)
        
        // Add Retry button with animation
        let retryButton = createButton(withText: "Retry", atPosition: CGPoint(x: 0, y: -gameOverNode.frame.height * 0.1))
        retryButton.name = "retryButton"
        retryButton.alpha = 0.0
        gameOverNode.addChild(retryButton)
        
        let fadeInRetry = SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        let scaleUpRetry = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDownRetry = SKAction.scale(to: 1.0, duration: 0.5)
        let pulseRetry = SKAction.sequence([scaleUpRetry, scaleDownRetry])
        let retryAction = SKAction.group([fadeInRetry, pulseRetry])
        retryButton.run(retryAction)
    }
    
    func createButton(withText text: String, atPosition position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontSize = 25
        button.fontColor = .white
        button.position = position
        return button
    }
    
    func restartGame() {
        guard let cameraNode = self.camera else { return }
        
        let overlayNames = ["gameOverScreen", "redOverlay", "gameOverImage"]
        for name in overlayNames {
            cameraNode.childNode(withName: name)?.removeFromParent()
        }
        
        xpBarNode?.removeFromParent()
        xpBarNode = nil
        
        //Reset containers for skills
        bladesContainer?.removeAllChildren()
        barrierContainer?.removeAllChildren()
        shieldContainer?.removeAllChildren()
        
        player.position = layoutInfo.playerStartingPosition
        joystick.endTouch()
        shootJoystick.endTouch()
        waveCounter = 0
        
        gameInfo.reset()
//        currentWaveIndex = 0
//        xombieSpeed = 0.3
//        xombieHealth = 3.0
//        wizardHealth = 15.0
//        gracePeriod = 7.0
//        pendingEnemies = 0
//        enemiesToSpawn = 0
        hordeSpawnInterval = 1.0
        normalSpawnInterval = 3.0

        miniWaveInterval = 3.0
        isBossStage = false
        arenaBounds = nil
        
        playerState.currentXP = 0
        playerState.resetToBaseStats()
        upgradeShopManager.resetXP()
        skillManager.reset()
        
        if let existingWizard = wizardBoss {
            existingWizard.removeFromParent()
            wizardBoss = nil
        }
        
        SLSoundManager.shared.stopBackgroundMusic()
        setUpGame()
    }
    
    func updateUpgradeStatsLabel() {
        upgradeStatsLabel.text = "Dmg: \(playerState.currentDamage) | Range: \(playerState.currentRange) | AtkSpeed: \( playerState.currentAttackSpeed)"
    }
    
    //Function used to handle removing zombies from tracking structure (in exploder class)
    func removeZombieFromTracking(_ zombie: SLExploderZombieNode) {
        if let index = enemyManager.enemies.firstIndex(where: { $0 === zombie }) {
            enemyManager.enemies.remove(at: index)
        }
    }
    
    func stopEnemyMovement(_ enemy: SLZombie) {
        enemy.removeAllActions()
        enemy.isAttacking = true
    }
    
    func resumeEnemyMovement(_ enemy: SLZombie) {
        enemy.isAttacking = false
        enemy.moveTowards(playerPosition: player.position)
    }
    
}



extension SLGameScene: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB

        let categoryA = bodyA.categoryBitMask
        let categoryB = bodyB.categoryBitMask

        // Sort so we always have lower category first for easier logic
        let firstBody: SKPhysicsBody
        let secondBody: SKPhysicsBody

        if categoryA < categoryB {
           firstBody = bodyA
           secondBody = bodyB
        } else {
           firstBody = bodyB
           secondBody = bodyA
        }
        
        if (firstBody.categoryBitMask == SLPhysicsCategory.player && secondBody.categoryBitMask == SLPhysicsCategory.border) {
//            print("🔴 Player collided with Border")
        }

        // Player & Enemy collision
        if (firstBody.categoryBitMask == SLPhysicsCategory.player && secondBody.categoryBitMask == SLPhysicsCategory.enemy) {
            if let enemyNode = secondBody.node as? SLZombie {
                if enemyNode.lastHitPlayerTime + enemyNode.hitPlayerCooldown < currentGameTime {
                    startDamagingPlayer(with: enemyNode, currentTime: currentGameTime)
                    enemyNode.lastHitPlayerTime = currentGameTime
                }
            }
        }

        // Projectile & Enemy/Boss collision
        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss || firstBody.categoryBitMask == SLPhysicsCategory.exploder) && secondBody.categoryBitMask == SLPhysicsCategory.projectile) {
            if let projectileNode = secondBody.node as? SKSpriteNode {
                if let enemyNode = firstBody.node as? SLZombie {
                    if shouldDamageEnemy(projectile: projectileNode, enemy: enemyNode) {
                        handleProjectileCollision(with: enemyNode)
                    }
                } else if let bossNode = firstBody.node as? SLWizard {
                    if shouldDamageEnemy(projectile: projectileNode, enemy: bossNode) {
                        handleProjectileCollision(with: bossNode)
                    }
                }
                if !playerState.projectilesPierce {
                    projectileNode.removeFromParent()
                }
            }
        }
        
        //Player & Beam Collision
        if (firstBody.categoryBitMask == SLPhysicsCategory.bossBeam && secondBody.categoryBitMask == SLPhysicsCategory.player) || (firstBody.categoryBitMask == SLPhysicsCategory.player && secondBody.categoryBitMask == SLPhysicsCategory.bossBeam) {
            if let beamNode = firstBody.categoryBitMask == SLPhysicsCategory.bossBeam ? firstBody.node : secondBody.node,
               let beamBody = beamNode.physicsBody {
                activeBeamContacts.insert(beamBody)
            }
            
        }
        
        // remove projectile if it hits border
        if ((firstBody.categoryBitMask == SLPhysicsCategory.border) && secondBody.categoryBitMask == SLPhysicsCategory.projectile) {
            if let projectileNode = secondBody.node as? SKSpriteNode {
                if !playerState.projectilesPierce {
                    projectileNode.removeFromParent()
                }
            }
        }
        
        let freezeSoundCoolDown = playerState.freezeDuration + playerState.freezeDuration
        // Freeze Explosion & Enemy/Boss collision
        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss || firstBody.categoryBitMask == SLPhysicsCategory.exploder) && secondBody.categoryBitMask == SLPhysicsCategory.freeze) {
            let currentTime = CACurrentMediaTime()
            
            if currentTime > lastFreezeSound + freezeSoundCoolDown  {
                lastFreezeSound = currentTime
                let shootSoundAction = SKAction.playSoundFileNamed("sl_freeze_sound.mp3", waitForCompletion: false)
                run(shootSoundAction)
            }
            
            if let enemyNode = firstBody.node as? SLZombie {
                enemyNode.freeze(currentTime: currentTime, duration: playerState.freezeDuration)
            } else if let bossNode = firstBody.node as? SLWizard {
                bossNode.freeze(currentTime: currentTime, duration: playerState.freezeDuration)
            }
        }

        // Blade & Enemy/Boss collision
        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss || firstBody.categoryBitMask == SLPhysicsCategory.exploder) && secondBody.categoryBitMask == SLPhysicsCategory.blade) {
            if let enemyNode = firstBody.node as? SLZombie {
                handleBladeCollision(with: enemyNode)
            } else if let bossNode = firstBody.node as? SLWizard {
                handleBladeCollision(with: bossNode)
            }
        }
        
        // Barrier & Enemy/Boss collision
        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss || firstBody.categoryBitMask == SLPhysicsCategory.exploder) && secondBody.categoryBitMask == SLPhysicsCategory.protectiveBarrier) {
            if let enemyNode = firstBody.node as? SLZombie {
                handleBarrierCollision(withEnemy: enemyNode)
            } else if let bossNode = firstBody.node as? SLWizard {
                handleBarrierCollision(withBoss: bossNode)
            }
        }
        
        // Shield & Enemy/Boss collision
        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss || firstBody.categoryBitMask == SLPhysicsCategory.exploder) && secondBody.categoryBitMask == SLPhysicsCategory.shield) {
            if let enemyNode = firstBody.node as? SLZombie {
                handleShieldCollision(withEnemy: enemyNode)
            } else if let bossNode = firstBody.node as? SLWizard {
                handleShieldCollision(withBoss: bossNode)
            }
        }

    }
    
    func didEnd(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB

        let categoryA = bodyA.categoryBitMask
        let categoryB = bodyB.categoryBitMask

        let firstBody: SKPhysicsBody
        let secondBody: SKPhysicsBody

        if categoryA < categoryB {
           firstBody = bodyA
           secondBody = bodyB
        } else {
           firstBody = bodyB
           secondBody = bodyA
        }

        if ((firstBody.categoryBitMask == SLPhysicsCategory.enemy || firstBody.categoryBitMask == SLPhysicsCategory.boss) &&
            secondBody.categoryBitMask == SLPhysicsCategory.protectiveBarrier) {
            
            if let enemyNode = firstBody.node as? SLZombie {
                enemyNode.isSlowedByBarrier = false
                enemyNode.movementSpeed = enemyNode.baseSpeed
            } else if let bossNode = firstBody.node as? SLWizard {
                bossNode.isSlowedByBarrier = false
                bossNode.movementSpeed = bossNode.baseSpeed
            }
        }
        
        //Player and beam collision end
        if (firstBody.categoryBitMask == SLPhysicsCategory.bossBeam && secondBody.categoryBitMask == SLPhysicsCategory.player) || (firstBody.categoryBitMask == SLPhysicsCategory.player && secondBody.categoryBitMask == SLPhysicsCategory.bossBeam) {
            if let beamNode = firstBody.categoryBitMask == SLPhysicsCategory.bossBeam ? firstBody.node : secondBody.node,
               let beamBody = beamNode.physicsBody {
                activeBeamContacts.remove(beamBody)
            }
        }
    }
    
    // MARK: Collision Methods
    
    /// Handles collisions between the Projectile and a SLZombie (enemy).
    func handleProjectileCollision(with enemy: SLZombie) {
        applyDamageToEnemy(enemy, damage: playerState.currentDamage)
    }
    
    /// Handles collisions between the Projectile and the SLWizard (boss).
    func handleProjectileCollision(with boss: SLWizard) {
        applyDamageToBoss(boss, damage: playerState.currentDamage)
    }
    
    /// Handles collisions between the Blade and a SLZombie (enemy).
    func handleBladeCollision(with enemy: SLZombie) {
        let currentTime = CACurrentMediaTime()
        
        if currentTime - enemy.lastSpinningBladeDamageTime > playerState.spinningBladesDamageCooldown {
            enemy.lastSpinningBladeDamageTime = currentTime
            applyDamageToEnemy(enemy, damage: playerState.spinningBladesDamage)
        }
    }
    
    /// Handles collisions between the Blade and the SLWizard (boss).
    func handleBladeCollision(with boss: SLWizard) {
        let currentTime = CACurrentMediaTime()
        
        if currentTime - boss.lastSpinningBladeDamageTime > playerState.spinningBladesDamageCooldown {
            boss.lastSpinningBladeDamageTime = currentTime
            applyDamageToBoss(boss, damage: playerState.spinningBladesDamage)
        }
    }
    
    /// Handles collision between protective barrier and an enemy.
    func handleBarrierCollision(withEnemy enemy: SLZombie) {
        let currentTime = CACurrentMediaTime()
        let damageCooldown: TimeInterval = max(0.3, 1.0 - playerState.barrierPulseFrequency)
        
        if currentTime - enemy.lastBarrierDamageTime > damageCooldown {
            enemy.lastBarrierDamageTime = currentTime
            applyDamageToEnemy(enemy, damage: playerState.currentDamage * playerState.barrierDamageFactor)
        }
        
        if !enemy.isSlowedByBarrier {
            enemy.isSlowedByBarrier = true
            enemy.movementSpeed = max(enemy.movementSpeed - playerState.barrierSlowAmount, 0.05)
        }
    }
    
    /// Handles collision between protective barrier and the boss.
    func handleBarrierCollision(withBoss boss: SLWizard) {
        let currentTime = CACurrentMediaTime()
        let damageCooldown: TimeInterval = max(0.3, 1.0 - playerState.barrierPulseFrequency)
        
        if currentTime - boss.lastBarrierDamageTime > damageCooldown {
            boss.lastBarrierDamageTime = currentTime
            applyDamageToBoss(boss, damage: playerState.currentDamage * playerState.barrierDamageFactor)
        }
        
        if !boss.isSlowedByBarrier {
            boss.isSlowedByBarrier = true
            boss.movementSpeed = max(boss.movementSpeed - playerState.barrierSlowAmount, 0.05)
        }
    }
    
    /// Handles collision between the shield and a regular enemy
    func handleShieldCollision(withEnemy enemy: SLZombie) {
        let currentTime = CACurrentMediaTime()
        let shieldHitCooldown: TimeInterval = 1.0
        
        if currentTime - enemy.lastShieldHitTime > shieldHitCooldown {
            enemy.lastShieldHitTime = currentTime
            absorbShieldHit()
            applyKnockback(to: enemy, strength: 50, duration: 0.3)
        }
    }

    /// Handles collision between the shield and the boss
    func handleShieldCollision(withBoss boss: SLWizard) {
        absorbShieldHit()
        applyDamageToBoss(boss, damage: boss.health * playerState.spectralShieldDamageFactor)
    }
    
    
    // MARK: Helpers for collisions
    func startDamagingPlayer(with enemy: SLZombie, currentTime: TimeInterval) {
        damagingEnemies.insert(enemy)
        stopEnemyMovement(enemy)
        applyDamageToPlayer(from: enemy)
        lastDamageTime = currentTime
    }
    
    func startDamagingPlayerWithBeam(withBeam beamNode: SKNode) {
        //Add beam's physics body to activeBeamContacts
        if let beamBody = beamNode.physicsBody {
            activeBeamContacts.insert(beamBody)
        }
        
        //Start applying damage every 0.5 seconds
        let damageAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run { [weak self] in
                    self?.bossHitPlayer()
                },
                SKAction.wait(forDuration: 0.5)
            ])
        )
        beamNode.run(damageAction, withKey: "damagePlayerWithBeam")
    }
    
    func stopDamagingPlayerWithBeam(withBeam beamNode: SKNode) {
        //Remove beam's physics body from activeBeamContacts
        if let beamBody = beamNode.physicsBody {
            activeBeamContacts.remove(beamBody)
        }
        //Stop the damage action
        beamNode.removeAction(forKey: "damagePlayerWithBeam")
    }
    
    // Used to checking if piercing arrow should keep damaging same enemy or not
    func shouldDamageEnemy(projectile: SKSpriteNode, enemy: SKNode) -> Bool {
        guard let damagedEnemies = projectile.userData?.object(forKey: "damagedEnemies") as? NSMutableSet else {
            // Create a new set if it doesn't exist
            let newSet = NSMutableSet()
            projectile.userData?.setValue(newSet, forKey: "damagedEnemies")
            newSet.add(enemy)
            return true
        }
        
        if damagedEnemies.contains(enemy) {
            return false // Already damaged this enemy
        } else {
            damagedEnemies.add(enemy)
            return true // Enemy not yet damaged by this projectile
        }
    }
    
    func applyDamageToPlayer(from enemy: SLZombie) {
        SLHapticManager.shared.triggerImpact(style: .heavy)
        let shootSoundAction = SKAction.playSoundFileNamed("sl_player_damage.mp3", waitForCompletion: false)
        run(shootSoundAction)

        
        flashPlayer()
        playerLives -= 1
        updateProgressLabel()
        
        if playerLives <= 0 {
            showGameOverScreen()
        }
    }
    
    func applyDamageToBoss(_ boss: SLWizard, damage: Double) {
        boss.takeDamage(amount: damage)
        if boss.health <= 0 {
            handleBossDefeat()
        }
    }
    
    func applyDamageToEnemy(_ enemy: SLZombie, damage: Double) {
        enemy.takeDamage(amount: damage)
    }

}
