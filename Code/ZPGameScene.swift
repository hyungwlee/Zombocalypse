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


class ZPGameScene: SKScene, PlayerStateDelegate {
    //Player Properties
    var playerState = PlayerState()
    var skillManager: SkillManager!
    
    //Skills related settings
    var bladesContainer: SKNode?
    var barrierContainer: SKNode?
    var shieldContainer: SKNode?
    var spectralShield: SKShapeNode?
    var shieldHitsRemaining: Int = 3
    let shieldMaxHits: Int = 3
    let shieldCooldown: TimeInterval = 10.0
    var lastGrenadeTime: TimeInterval = 0
    var grenadeShootInterval: TimeInterval = 5.0
    
    //Inf background settings
    var topBound: CGFloat = 0
    var bottomBound: CGFloat = 0
    var backgroundSections: [SKSpriteNode] = []
    let sectionWidth: CGFloat = 3340 // Example width of each section (Adjust based on image) 1024
    let sectionHeight: CGFloat = 3510 // Example height of each section (Adjust as needed) 768
    let numSections: Int = 5         // Number of sections (Higher = longer before repeated gen., Lower = shorter before repeated gen.)
    
    var currentGameTime: TimeInterval = 0
    weak var context: ZPGameContext?
    var joystick: ZPJoystick!
    var shootJoystick: ZPJoystick!
    var player: SKSpriteNode!
    var zombies: [ZPZombie] = [] // Array to hold the zombies
    
    let zombieCount = 3
    var zombieSpeed: CGFloat = 0.4
    let zombieBufferDistance: CGFloat = 10 // Adjust this value to experiment with zombie spacing w one another
    var playerLivesLabel: SKLabelNode!
    var playerLives: Double = 3.0 {
        didSet {
            playerLivesLabel.text = "Lives: \(playerLives)"
        }
    }
    var gameOver: Bool = false
    
    //Revamp wave settings
    var enemiesToDefeat = 3
    var miniWaveInterval: TimeInterval = 3.0
    var maxEnemiesOnScreen: Int = 3
    var progressLabel: SKLabelNode!
    var spawningInProgress: Bool = false
    var isTransitioningWave: Bool = false
    
    var maxRegularZombies: Int = 3
    var maxChargerZombies: Int = 0
    var maxExploderZombies: Int = 0
    var isBossStage: Bool = false
    
    //New wave settings
    var waveCycle: [Wave] = []
    var currentWaveIndex: Int = 0
    var gracePeriod: TimeInterval = 7.0 // Initial grace period
    var pendingEnemies: Int = 0
    var enemiesToSpawn: Int = 0
    var waveProgressionWorkItem: DispatchWorkItem?
    
    // Zombie Wave Settings
    private var waveCounter: Int = 0
    private var zombieHealth: Double = 3.0
    private var wizardHealth: Double = 15.0
    private var wizardBoss: ZPWizard?
    private var bossIsAlive: Bool = false
    var arenaBounds: CGRect?
    var waveLabel: SKLabelNode!
    private let waveMessageLabel = SKLabelNode(fontNamed: "Arial")
    
    //Enemy variation message settings
    private let newEnemyMessages: [Int: String] = [
        4: "New Enemy: Charger!",
        5: "New Enemy: Exploder!",
        7: "New Boss: Wizard!",
    ]
    private var displayedEnemyMessages: Set<Int> = []
    
    // Auto-attack variables
    /// these are stored and tracked in PlayerState
//    private var attackDamage: Double!
//    private var projectileMoveDistance: CGFloat!
//    private var shootInterval: TimeInterval!
    private var lastShootTime: TimeInterval = 0
//    private var playerMoveSpeed: CGFloat!
    
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
//    var upgradePopup: SKShapeNode!
    var upgradeStatsLabel: SKLabelNode!
//    var currentUpgradeChoices: [RegularSkill] = []
    
    var upgradeShopManager: UpgradeShopManager!
    var overlayManager: OverlayManager!
    private var upgradeOverlay: UpgradeShopOverlayNode?
    
    var xpBarNode: XPBarNode!
    var xpNodes: [XPNode] = []
    var xpSpawnTimer: Timer?
    let xpSpawnInterval: TimeInterval = 1.0

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
        playerState.delegate = self
        skillManager = SkillManager(player: playerState)
        upgradeShopManager = UpgradeShopManager(scene: self, skillManager: skillManager)
        overlayManager = OverlayManager(scene: self)
                
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.view?.isMultipleTouchEnabled = true
        //Create and add the camera node
        let cameraNode = SKCameraNode()
        self.camera = cameraNode
        addChild(cameraNode)
        
        setUpGame()
        //Wave message label (center of screen every round)
        waveMessageLabel.fontSize = 40
        waveMessageLabel.fontColor = .red
        waveMessageLabel.position = CGPoint(x: size.width / 2, y: size.height - 180)
        waveMessageLabel.zPosition = 5
        waveMessageLabel.isHidden = true
        cameraNode.addChild(waveMessageLabel)
        
        //Add camera-related HUD elements
        cameraNode.addChild(playerLivesLabel)
        cameraNode.addChild(scoreLabel)
        cameraNode.addChild(waveLabel)
        cameraNode.addChild(progressLabel)
        cameraNode.addChild(joystick)
        cameraNode.addChild(shootJoystick)
    }
    
    func setUpGame() {
        backgroundColor = .white
        gameOver = false
        playerState.resetToBaseStats()
        
        // Sets up player at fixed start position
        if player == nil {
            player = SKSpriteNode(color: .blue, size: CGSize(width: 25, height: 25))
            addChild(player)
            
            //Initialize blades container
            bladesContainer = SKNode()
            bladesContainer?.position = CGPoint.zero
            bladesContainer?.zPosition = 1
            player.addChild(bladesContainer!)
            
            //Initialize barrier container
            barrierContainer = SKNode()
            barrierContainer?.position = CGPoint.zero
            barrierContainer?.zPosition = 2 // Above blades for now but can change
            player.addChild(barrierContainer!)
            
            shieldContainer = SKNode()
            shieldContainer?.position = CGPoint.zero
            shieldContainer?.zPosition = 3
            player.addChild(shieldContainer!)
            
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
        
        //TEST 'HARDSET' VALUES FOR BLADE
//        playerState.spinningBladesCount = 2
//        playerState.spinningBladesDamage = 3
//        playerState.spinningBladesSpeed = 1.0
//        skillManager.acquireOrUpgradeRegularSkill(
//            RegularSkill(definition: skillManager.allRegularDefinitions.first { $0.type == .spinningBlades }!)
//        )
//        playerState.barrierSize = 1000
//        playerState.barrierDamage = 1
//        playerState.barrierPulseFrequency = 2.0
//        skillManager.acquireOrUpgradeRegularSkill(
//            RegularSkill(definition: skillManager.allRegularDefinitions.first { $0.type == .protectiveBarrier }!))
        
        
        // Sets up lives label displaying playerLives
        if playerLivesLabel == nil {
            playerLivesLabel = SKLabelNode(fontNamed: "Arial")
            playerLivesLabel.fontSize = 20
            playerLivesLabel.fontColor = .black
            playerLivesLabel.position = CGPoint(x: -size.width / 2 + 80, y: size.height / 2 - 80)
            playerLivesLabel.zPosition = 5
        }
        playerLives = playerState.baseMaxHealth // Reset playerLives  
        
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
            waveLabel.text = "Wave: \(waveCounter)"
            waveLabel.fontSize = 22
            waveLabel.fontColor = .black
            waveLabel.position = CGPoint(x: 0, y: size.height / 2 - 80)
            waveLabel.zPosition = 5
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
            upgradeStatsLabel.position = CGPoint(x: 0, y: player.size.height / 2 + 30)
            player.addChild(upgradeStatsLabel)
        }
        updateUpgradeStatsLabel()
                
        // Clear any existing enemies
        bossIsAlive = false
        childNode(withName: "wizard")?.removeFromParent()
        removeZombies()

        //Wave function
        //maintainEnemyCount()
        initializeWaves()
        startNextWave()
        
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
        showUpgradePopup()   // TEST TO SHOW UPGRADE WHEN GAME STARTS IN CASE WE WANT TO TEST SKILLS.
        
        let xpBar = XPBarNode(width: 150, height: 20)
        xpBar.position = CGPoint(x: 0, y: size.height/2 - 230)
        xpBar.zPosition = 5
        camera?.addChild(xpBar)
        self.xpBarNode = xpBar
        startXPSpawnTimer()
    }
    
    func initializeWaves() {
        //Define waves 1 through 7
        waveCycle = [
            Wave(waveNumber: 1, totalEnemies: 10, regularEnemies: 10, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 3.0, requiresFullClearance: false),
            Wave(waveNumber: 2, totalEnemies: 15, regularEnemies: 15, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 2.8, requiresFullClearance: false),
            Wave(waveNumber: 3, totalEnemies: 30, regularEnemies: 30, chargerEnemies: 0, exploderEnemies: 0, isHorde: true, isBoss: false, spawnInterval: 1.0, requiresFullClearance: false),
            Wave(waveNumber: 4, totalEnemies: 35, regularEnemies: 30, chargerEnemies: 5, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 2.3, requiresFullClearance: false),
            Wave(waveNumber: 5, totalEnemies: 40, regularEnemies: 30, chargerEnemies: 5, exploderEnemies: 5, isHorde: false, isBoss: false, spawnInterval: 2.1, requiresFullClearance: false),
            Wave(waveNumber: 6, totalEnemies: 46, regularEnemies: 30, chargerEnemies: 8, exploderEnemies: 8, isHorde: true, isBoss: false, spawnInterval: 1.0, requiresFullClearance: true),
            Wave(waveNumber: 7, totalEnemies: 1, regularEnemies: 0, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: true, spawnInterval: 0.0, requiresFullClearance: false)
        ]
    }
    
    func startNextWave() {
        guard currentWaveIndex < waveCycle.count else {
            //All waves in the cycle completed, restart cycle with increased difficulty
            restartCycleWithIncreasedDifficulty()
            return
        }
        
        waveCounter += 1
        waveLabel.text = "Wave \(waveCounter)"
        
        let wave = waveCycle[currentWaveIndex]
        pendingEnemies += wave.totalEnemies
        enemiesToSpawn += wave.totalEnemies
        updateProgressLabel()
        
        isTransitioningWave = true
        
        //Display wave start message
        if wave.isBoss {
            waveMessageLabel.text = "Boss Stage"
            waveMessageLabel.fontSize = 40
            waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
            waveMessageLabel.zPosition = 5
        } else if wave.isHorde {
            waveMessageLabel.text = "A horde is approaching.."
            waveMessageLabel.fontSize = 30
            waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
            waveMessageLabel.zPosition = 5
        } else {
            waveMessageLabel.text = "Wave \(waveCounter) starting.."
            waveMessageLabel.fontSize = 30
            waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
            waveMessageLabel.zPosition = 5
        }
        waveMessageLabel.isHidden = false
        
        if let enemyMessage = newEnemyMessages[wave.waveNumber], !displayedEnemyMessages.contains(wave.waveNumber) {
            showEnemyIntroductionMessage(enemyMessage)
            displayedEnemyMessages.insert(wave.waveNumber)
        }
        
        if wave.isBoss {
            clearAllEnemies() //Clear existing enemies only for boss waves
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
    
    func spawnNextEnemy() {
        guard currentWaveIndex < waveCycle.count else { return }
        var wave = waveCycle[currentWaveIndex]
        
        // Check if all enemies have been spawned
        if wave.allEnemiesSpawned {
            handleWaveProgression()
            waveCycle[currentWaveIndex] = wave // Update the wave with new spawn counts
            return
        }
        
        // Decide which enemy to spawn next
        let spawnDecision = decideNextEnemyType(for: wave)
        
        switch spawnDecision {
        case .regular:
            spawnZombies(withHealth: zombieHealth)
            wave.spawnedRegular += 1
        case .charger:
            spawnChargerZombie()
            wave.spawnedCharger += 1
        case .exploder:
            spawnExploderZombie()
            wave.spawnedExploder += 1
        }
        
        // Update the wave in the cycle
        waveCycle[currentWaveIndex] = wave
        
        //Decrement enemiesToSpawn as an enemy has been spawned
        enemiesToSpawn -= 1
        
        // Schedule the next enemy spawn
        let currentWaveObject = waveCycle[currentWaveIndex]
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
    }

    
    func spawnEnemyTypes(regular: Int, charger: Int, exploder: Int) {
        for _ in 0..<regular {
            spawnZombies(withHealth: zombieHealth)
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
        else if pendingEnemies > 0 {
            progressLabel.text = "Enemies left: \(pendingEnemies)"
        }
        else {
            progressLabel.text = "Waiting for next wave..."
        }
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
    
    func showUpgradeShopOverlay(with choices: [RegularSkill]) {
        let upgradeOverlay = UpgradeShopOverlayNode(choices: choices, manager: upgradeShopManager, overlayManager: overlayManager, skillManager: skillManager)
        overlayManager.enqueueOverlay(upgradeOverlay)
    }
    
    
    // MARK: OLD showUpgradePopup
//    func showUpgradePopup() {
//        isGamePaused = true
//        self.isPaused = true // Pauses all SKAction updates
//        //create popup background
//        let popupWidth = size.width * 0.6
//        let popupHeight = size.height * 0.4
//        let popup = SKShapeNode(rectOf: CGSize(width: popupWidth, height: popupHeight), cornerRadius: 10)
//        popup.fillColor = .darkGray
//        popup.alpha = 0.9
//        popup.name = "upgradePopup"
//        popup.position = CGPoint(x: 0, y: 0)
//        popup.zPosition = 5
//        
//        //Attack damage button
//        let atkDamageButton = SKLabelNode(text: "Increase Attack Damage")
//        atkDamageButton.name = "attack"
//        atkDamageButton.fontSize = 20
//        atkDamageButton.position = CGPoint(x: 0, y:40)
//        popup.addChild(atkDamageButton)
//        //Attack range button
//        let atkRangeButton = SKLabelNode(text: "Increase Attack Range")
//        atkRangeButton.name = "range"
//        atkRangeButton.fontSize = 20
//        atkRangeButton.position = CGPoint(x: 0, y:0)
//        popup.addChild(atkRangeButton)
//        //Attack speed button
//        let atkSpeedButton = SKLabelNode(text: "Increase Attack Speed")
//        atkSpeedButton.name = "speed"
//        atkSpeedButton.fontSize = 20
//        atkSpeedButton.position = CGPoint(x: 0, y:-40)
//        popup.addChild(atkSpeedButton)
//        //1+ Health option button
//        let addHealthButton = SKLabelNode(text: "Health Upgrade")
//        addHealthButton.name = "health"
//        addHealthButton.fontSize = 20
//        addHealthButton.position = CGPoint(x: 0, y:-80)
//        popup.addChild(addHealthButton)
//        
//        camera?.addChild(popup)
//        upgradePopup = popup
//    }
    
    // MARK: NEW showUpgradePopup
    func showUpgradePopup() {
//        isGamePaused = true
//        self.isPaused = true // Pauses all SKAction updates
//
//        // Get up to 3 random regular skill choices
//        let randomChoices = skillManager.getRandomRegularChoices()
//        guard !randomChoices.isEmpty else {
//            // No upgrades available
//            isGamePaused = false
//            self.isPaused = false
//            return
//        }
//
//        // Store these choices so we can reference them later
//        currentUpgradeChoices = randomChoices
//
//        // Create popup background
//        let popupWidth = size.width * 0.6
//        let popupHeight = size.height * 0.4
//        let popup = SKShapeNode(rectOf: CGSize(width: popupWidth, height: popupHeight), cornerRadius: 10)
//        popup.fillColor = .darkGray
//        popup.alpha = 0.9
//        popup.name = "upgradePopup"
//        popup.position = CGPoint(x: 0, y: 0)
//        popup.zPosition = 5
//
//        let startY: CGFloat = 40
//        let spacing: CGFloat = -40
//        // Each skill will get its own button
//        for (index, skill) in currentUpgradeChoices.enumerated() {
//            let buttonLabel = SKLabelNode(text: skill.definition.type.displayName)
//            buttonLabel.name = "skillButton"
//            buttonLabel.fontSize = 20
//            buttonLabel.position = CGPoint(x: 0, y: startY + CGFloat(index) * spacing)
//            buttonLabel.zPosition = 6
//
//            // Store the skill's index so we can retrieve it easily in touchesBegan
//            buttonLabel.userData = NSMutableDictionary()
//            buttonLabel.userData?["skillIndex"] = index
//
//            popup.addChild(buttonLabel)
//        }
//
//        camera?.addChild(popup)
//        upgradePopup = popup
    }
    
    // MARK: don't need these
//    func attackDamageUpgrade() {
//        if let attackDamageUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .attackDamage }) {
//            let attackDamageUpgradeSkill = RegularSkill(definition: attackDamageUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(attackDamageUpgradeSkill)
//        }
//    }
//    
//    func attackSpeedUpgrade() {
//        if let attackSpeedUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .attackSpeed }) {
//            let attackSpeedUpgradeSkill = RegularSkill(definition: attackSpeedUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(attackSpeedUpgradeSkill)
//        }
//    }
//    
//    func attackRangeUpgrade() {
//        if let attackRangeUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .attackRange }) {
//            let attackRangeUpgradeSkill = RegularSkill(definition: attackRangeUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(attackRangeUpgradeSkill)
//        }
//    }
//    
//    func movementSpeedUpgrade() {
//        if let movementSpeedUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .movementSpeed }) {
//            let movementSpeedUpgradeSkill = RegularSkill(definition: movementSpeedUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(movementSpeedUpgradeSkill)
//        }
//    }
//        
//    func bladesUpgrade() {
//        if let bladesUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .spinningBlades }) {
//            let bladesUpgradeSkill = RegularSkill(definition: bladesUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(bladesUpgradeSkill)
//        }
//    }
//    
//    func barrierUpgrade() {
//        if let barrierUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .protectiveBarrier }) {
//            let barrierUpgradeSkill = RegularSkill(definition: barrierUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(barrierUpgradeSkill)
//        }
//    }
//    
//    func healthUpgrade() {
//        if let healthUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .healthUpgrade }) {
//            let healthUpgradeSkill = RegularSkill(definition: healthUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(healthUpgradeSkill)
//        }
//    }
//    
//    func magnetUpgrade() {
//        if let magnetUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .magnet }) {
//            let magnetUpgradeSkill = RegularSkill(definition: magnetUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(magnetUpgradeSkill)
//        }
//    }
//    
//    func freezeGrenadeUpgrade() {
//        if let freezeGrenadeUpgradeSkillDef = skillManager.allRegularDefinitions.first(where: { $0.type == .freeze }) {
//            let freezeGrenadeUpgradeSkill = RegularSkill(definition: freezeGrenadeUpgradeSkillDef)
//            skillManager.acquireOrUpgradeRegularSkill(freezeGrenadeUpgradeSkill)
//        }
//    }
//    
//    func handsSpecialUpgrade() {
//        if let helpingHandDef = skillManager.allSpecialTypes.first(where: { $0 == .helpingHand }) {
//            skillManager.acquireSpecialSkill(helpingHandDef)
//        }
//    }
//    
//    func shieldSpecialUpgrade() {
//        if let spectralShieldDef = skillManager.allSpecialTypes.first(where: { $0 == .spectralShield }) {
//            skillManager.acquireSpecialSkill(spectralShieldDef)
//        }
//    }
//    
//    func reinforcedArrowsSpecialUpgrade() {
//        if let reinforcedArrowDef = skillManager.allSpecialTypes.first(where: { $0 == .reinforcedArrow }) {
//            skillManager.acquireSpecialSkill(reinforcedArrowDef)
//        }
//    }
//    
//    func knockbackSpecialUpgrade() {
//        if let mightyKnockbackDef = skillManager.allSpecialTypes.first(where: { $0 == .mightyKnockback }) {
//            skillManager.acquireSpecialSkill(mightyKnockbackDef)
//        }
//    }
//    
//    func bonusHealthSpecialUpgrade() {
//        //LOGIC NEEDS TO BE FIXED.
//        if let bonusHealthDef = skillManager.allSpecialTypes.first(where: { $0 == .bonusHealth }) {
//            skillManager.acquireSpecialSkill(bonusHealthDef)
//        }
//    }
    
    // MARK: OLD applyUpgrade
//    func applyUpgrade(_ choice: String) {
//        switch choice {
//        case "attack":
//            //attackDamageUpgrade()
//            attackDamage += playerState.currentDamage
//            //attackDamage += 1.0
//            //bladesUpgrade()                               // WORKING AT TIME OF TEST.
//            //barrierUpgrade()                              // WORKING AT TIME OF TEST.
//            //healthUpgrade()                               // WORKING AT TIME OF TEST.
//            //freezeGrenadeUpgrade()                        // WORKING AT TIME OF TEST.
//            //magnetUpgrade()                               //    *NEED TO IMPLEMENT*
//            //handsSpecialUpgrade()                         // WORKING AT TIME OF TEST.
//            //shieldSpecialUpgrade()                        // WORKING AT TIME OF TEST.
//            //reinforcedArrowsSpecialUpgrade()              // WORKING AT TIME OF TEST.
//            //knockbackSpecialUpgrade()                     // WORKING AT TIME OF TEST.
//            //bonusHealthSpecialUpgrade()                   //    *NEED TO IMPLEMENT*
//        case "range":
//            projectileMoveDistance += 100
//        case "speed":
//            shootInterval = max(0.3, shootInterval - 0.1) //THIS TEMPORARILY ENSURES IT DOES NOT GO BELOW 0.1
//            shootInterval = round(shootInterval * 10) / 10 //Deals with float value not showing up as .000001
//        case "health":
//            healthUpgrade()
//        default:
//            break
//        }
//        //powerUpAvailable = false
//        isGamePaused = false
//        self.isPaused = false // Resumes game updates
//        upgradePopup?.removeFromParent()
//        upgradePopup = nil
//        updateUpgradeStatsLabel()
//    }
    
    // MARK: NEW applyUpgrade
    func applyUpgrade(skill: RegularSkill) {
        // Directly use the skill instance to upgrade
        skillManager.acquireOrUpgradeRegularSkill(skill)

        // Close the popup and resume the game
        isGamePaused = false
        self.isPaused = false
//        upgradePopup?.removeFromParent()
//        upgradePopup = nil

        updateUpgradeStatsLabel()
    }
    //MARK: - PlayerStateDelegate Methods
    
    //REGULAR SKILLS
    func playerStateDidAddSpinningBlades(_ state: PlayerState) {
        guard let bladesContainer = bladesContainer else { return }
        
        // Remove existing blades
        bladesContainer.removeAllChildren()
        
        // Define blade properties
        let bladeSize = CGSize(width: 20, height: 5)
        let bladeColor = SKColor.green
        
        // Calculate the angle between each blade
        let bladeCount = state.spinningBladesCount
        guard bladeCount > 0 else { return }
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(bladeCount)
        
        // Define the radius at which blades orbit
        let orbitRadius: CGFloat = 75.0 // Adjust as needed
        
        // Create and position each blade
        for i in 0..<bladeCount {
            let blade = SKSpriteNode(color: bladeColor, size: bladeSize)
            blade.name = "spinningBlade"
            
            // Calculate the position of the blade around the container
            let angle = CGFloat(i) * angleIncrement
            let xPosition = orbitRadius * cos(angle)
            let yPosition = orbitRadius * sin(angle)
            blade.position = CGPoint(x: xPosition, y: yPosition)
            
            bladesContainer.addChild(blade)
        }
        
        // Remove any existing rotation action
        bladesContainer.removeAction(forKey: "rotate")
        
        // Define rotation speed
        let baseDuration: TimeInterval = 0.5
        let rotationDuration = baseDuration / state.spinningBladesSpeed
        
        // Create a rotation action
        let rotateAction = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: rotationDuration)
        let repeatRotate = SKAction.repeatForever(rotateAction)
        
        // Run the rotation action on the container
        bladesContainer.run(repeatRotate, withKey: "rotate")
        
    }

    
    func playerStateDidUpgradeBarrier(_ state: PlayerState) {
        guard let barrierContainer = barrierContainer else { return }
        
        //Remove existing barrier
        barrierContainer.removeAllChildren()
        
        //Define barrier properties
        let barrierRadius: CGFloat = 20.0 + state.barrierSize   // CAN CHANGE
        let barrierColor = SKColor.blue.withAlphaComponent(0.3) // Semi-transparent blue
        
        //Create barrier shape
        let barrier = SKShapeNode(circleOfRadius: barrierRadius)
        barrier.name = "protectiveBarrier"
        barrier.strokeColor = barrierColor
        barrier.lineWidth = 3.0
        barrier.zPosition = 2 // CURRENTLY ABOVE BLADES. Can change.
        
        //Position barrier at the center of the container
        barrier.position = CGPoint.zero
        
        //Create pulsing action
        let pulseUp = SKAction.scale(to: 1.2, duration: 1.0 - state.barrierPulseFrequency) // CAN CHANGE
        let pulseDown = SKAction.scale(to: 1.0, duration: 1.0 - state.barrierPulseFrequency) // CAN CHANGE
        let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
        let repeatPulse = SKAction.repeatForever(pulseSequence)
        barrier.run(repeatPulse)
        
        //Add barrier to the barrierContainer
        barrierContainer.addChild(barrier)
        
    }
        
    func playerStateDidUpgradeHealth(_ state: PlayerState, restorePercentage: Double) {
        // Just need to restore health based on the restorePercentage passed in
        // currentMaxHealth is already updated in PlayerState
        let restorationAmount = state.currentMaxHealth * restorePercentage
        playerLives = max(playerLives + restorationAmount, state.currentMaxHealth)
    }
    
    func playerStateDidUpgradeMagnet(_ state: PlayerState) {
        // Only need this if we add UI effects after activation
        print("Magnet Radius increased!")
    }
    
    func playerStateDidUpgradeFreeze(_ state: PlayerState) {
        grenadeShootInterval = max(1.0, 5.0 - state.freezeGrenadeCooldown)
    }
    
    // SPECIAL SKILLS
    func playerStateDidActivateHelpingHand(_ state: PlayerState) { /// ACTIVATE
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
    
    func playerStateDidActivateReinforcedArrow(_ state: PlayerState) {
        // Only need this if we add UI effects after activation
        print("Reinforced Arrow activated!")
    }
    
    func playerStateDidActivateSpectralShield(_ state: PlayerState) { /// ACTIVATE
        addSpectralShield()
    }
    
    func playerStateDidDeactivateSpectralShield() { /// DEACTIVATE
        removeSpectralShield()
    }
    
    func playerStateDidActivateMightyKnockback(_ state: PlayerState) {
        // Only need this if we add UI effects after activation
        print("Mightyknockback activated!")
    }
    
    func playerStateDidActivateBonusHealth(_ state: PlayerState, restorePercentage: Double) {
        // Restores player HP back to full health
        playerLives = state.currentMaxHealth
    }
    
    func activateHelpingHand() {
        playerState.hasHelpingHand = true
    }
    
    func removeZombies() {
        for zombie in zombies {
            zombie.removeFromParent()
        }
        zombies.removeAll()
    }

    func spawnZombies(withHealth health: Double) {
        let zombie = ZPZombie(health: health)
        let safeRadius: CGFloat = 200.0
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
        let safeRadius: CGFloat = 250.0
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
        let safeRadius: CGFloat = 250.0
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
                let safeRadius: CGFloat = 150.0
                let spawnDistance: CGFloat = 250.0
                
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
        guard let cameraNode = self.camera else { return }
        
        // MARK: NEW OVERLAY
         // If there's currently an overlay shown, we handle touches there
        if let overlay = cameraNode.children.first(where: { $0 is UpgradeShopOverlayNode || $0 is BossSpinnerOverlayNode }) {
            if let spinnerOverlay = overlay as? BossSpinnerOverlayNode {
                for touch in touches {
                    let location = touch.location(in: cameraNode)
                    spinnerOverlay.touchBegan(at: location)
                }
                return
            } else if let upgradeOverlay = overlay as? UpgradeShopOverlayNode {
                for touch in touches {
                    let location = touch.location(in: cameraNode)
                    upgradeOverlay.touchBegan(at: location)
                }
                return
            }
        }
        
        for touch in touches {
            let touchLocationInCamera = touch.location(in: cameraNode) // Location relative to the camera
            
            // MARK: OLD upgrade popup logic
//            // Check if the game is paused and the popup menu is active
//            if isGamePaused {
//                // Calculate the touch location relative to the popup menu
//                if let popupMenu = cameraNode.childNode(withName: "upgradePopup") {
//                    let touchLocationInPopup = touch.location(in: popupMenu) // Convert location to popup menu's coordinate space
//                    
//                    // Check if the touch is on any of the upgrade options
//                    let tappedNodes = popupMenu.nodes(at: touchLocationInPopup)
//                    for node in tappedNodes {
//                        if let nodeName = node.name, ["attack", "range", "speed", "health"].contains(nodeName) {
//                            applyUpgrade(nodeName) // Apply the chosen upgrade
//                            return
//                        }
//                    }
//                }
//                return // Don't allow other interactions when paused
//            }
            
            // MARK: NEW upgrade popup logic
//            if isGamePaused, let popupMenu = cameraNode.childNode(withName: "upgradePopup") {
//                let touchLocationInPopup = touch.location(in: popupMenu)
//                let tappedNodes = popupMenu.nodes(at: touchLocationInPopup)
//                for node in tappedNodes {
//                    if node.name == "skillButton" {
//                        if let index = node.userData?["skillIndex"] as? Int,
//                           index >= 0 && index < currentUpgradeChoices.count {
//                            let chosenSkill = currentUpgradeChoices[index]
//                            applyUpgrade(skill: chosenSkill)
//                            return
//                        }
//                    }
//                }
//                return
//            }


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
        checkSpinningBladesCollision()
        checkBarrierCollision()
        checkSpectralShieldCollision()
        checkXPCollection()
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
        let moveSpeed: CGFloat = playerState.currentMovementSpeed // Adjust speed as needed
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

            if aimDirection != .zero && currentTime - lastShootTime >= playerState.currentAttackSpeed{
                lastShootTime = currentTime
                shootProjectile(in: aimDirection)
                
                //Perhaps can add check here to disable grenades on boss stage.
                if playerState.freezeGrenadeCooldown > 0.0 && currentTime - lastGrenadeTime >= grenadeShootInterval {
                    lastGrenadeTime = currentTime
                    shootGrenade(in: aimDirection)
                }
            }
        }
        
        //Collision detection for freeze grenades
        for grenade in self.children.filter({ $0.name == "freezeGrenade" }) {
            guard let grenadeNode = grenade as? SKSpriteNode else { continue }
            guard let hasCollided = grenadeNode.userData?["hasCollided"] as? Bool, !hasCollided else { continue }
            
            //Check collision for enemies
            for zombie in zombies {
                if grenadeNode.frame.intersects(zombie.frame) {
                    grenadeNode.userData?["hasCollided"] = true
                    grenadeNode.removeAllActions() //Stops grenade movement by removing all actions
                    
                    //Schedule explosion after 1 second
                    let waitAction = SKAction.wait(forDuration: 1.0)
                    let explodeAction = SKAction.run {
                        self.explodeGrenade(grenadeNode)
                    }
                    let removeAction = SKAction.removeFromParent()
                    let sequence = SKAction.sequence([waitAction, explodeAction, removeAction])
                    grenadeNode.run(sequence)
                    //Exit loop after collision
                    break
                }
            }
            
            //Check collision for wizard
            if let wizard = wizardBoss, bossIsAlive, grenadeNode.frame.intersects(wizard.frame) {
                grenadeNode.userData?["hasCollided"] = true
                grenadeNode.removeAllActions()
                //Schedule explosion after 1 second
                let waitAction = SKAction.wait(forDuration: 1.0)
                let explodeAction = SKAction.run {
                    self.explodeGrenade(grenadeNode)
                }
                let removeAction = SKAction.removeFromParent()
                let sequence = SKAction.sequence([waitAction, explodeAction, removeAction])
                grenadeNode.run(sequence)
                //Exit loop after collision
                break
            }
            
            //Only wizard logic here, enemies logic is elsewhere
            if let wizard = wizardBoss, wizard.isFrozen {
                if currentGameTime >= wizard.freezeEndTime {
                    wizard.unfreeze()
                }
            }
        }
        
        //Update zombies positions to move towards the player and adjust speed based on barrier proximity
        for (index, zombie) in zombies.enumerated().reversed() {
            var speed = zombieSpeed
            
            //Determine if the zombie is within any barrier's radius
            if let barrierContainer = barrierContainer {
                for barrier in barrierContainer.children where barrier.name == "protectiveBarrier" {
                    guard let barrierShape = barrier as? SKShapeNode else { continue }
                    
                    let barrierScenePosition = barrierShape.convert(CGPoint.zero, to: self)
                    let barrierRadius = barrierShape.frame.size.width / 2
                    let distance = hypot(barrierScenePosition.x - zombie.position.x, barrierScenePosition.y - zombie.position.y)
                    let collisionDistance = barrierRadius + (zombie.size.width / 2)
                    
                    if distance < collisionDistance {
                        speed = zombieSpeed - playerState.barrierSlowAmount
                        //Change color of slowed enemies.
                        zombie.color = SKColor.gray
                        zombie.colorBlendFactor = 0.5
                        speed = max(speed, 0.05)
                        break //Assuming one barrier; remove if multiple barriers can affect the same zombie
                    }
                }
            }
            zombie.moveTowards(player: player, speed: speed)
            
            //PREVENT ZOMBIES FROM OVERLAPPING ONE ANOTHER
            preventZombieOverlap(zombie: zombie, index: index)
            
            if zombie.frame.intersects(player.frame) {
                handlePlayerHit(zombieIndex: index)
            }
        }
        
        //Update method for each zombie in the scene
        for zombie in zombies {
            if let chargerZombie = zombie as? ZPChargerZombieNode {
                chargerZombie.update(deltaTime: currentTime, playerPosition: player.position)
            }
            if let exploderZombie = zombie as? ZPExploderZombieNode {
                exploderZombie.update(deltaTime: currentTime, playerPosition: player.position)
            }
            //Handle frozen enemies
            zombie.updateFreezeState(currentTime: currentGameTime)
        }
        
        if currentWaveIndex < waveCycle.count {
            let wave = waveCycle[currentWaveIndex]
            if wave.allEnemiesSpawned && pendingEnemies <= 0 && !isBossStage {
                handleWaveProgression()
            }
        }
        
    }
    
    
    func countActiveChargers() -> Int {
        return zombies.filter { $0 is ZPChargerZombieNode }.count
    }
    func countActiveExploders() -> Int {
        return zombies.filter { $0 is ZPExploderZombieNode }.count
    }
    
    func handleWaveProgression() {
        guard !isTransitioningWave else { return }
        isTransitioningWave = true
        
        //Start grace period timer
        waveMessageLabel.text = "Wave Over. Defeat remaining enemies.."
        waveMessageLabel.fontSize = 20
        waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
        waveMessageLabel.zPosition = 5
        waveMessageLabel.isHidden = false
        
        waveProgressionWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.waveCycle[currentWaveIndex].requiresFullClearance {
                if self.pendingEnemies > 0 {
                    //Do not proceed. Wait until all enemies are defeated
                    self.waveMessageLabel.text = "Defeat all enemies to proceed.."
                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                    self.waveMessageLabel.zPosition = 5
                } else {
                    self.transitionToNextWave()
                }
            } else {
                //Regular wave progression
                if self.pendingEnemies > 0 {
                    self.waveMessageLabel.text = "Next wave starting.."
                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                    self.waveMessageLabel.zPosition = 5
                } else {
                    self.waveMessageLabel.text = "Wave Cleared. Next wave starting.."
                    self.waveMessageLabel.position = CGPoint(x: 0, y: size.height * 0.3)
                    self.waveMessageLabel.zPosition = 5
                }
                self.transitionToNextWave()
                self.showUpgradePopup()
            }
            self.waveMessageLabel.isHidden = false
        }
        //Schedule the wave progression after graceperiod
        if let workItem = waveProgressionWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + gracePeriod, execute: workItem)
        }
    }
    
    func transitionToNextWave() {
        self.currentWaveIndex += 1
        if self.currentWaveIndex >= self.waveCycle.count {
            self.restartCycleWithIncreasedDifficulty()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.waveMessageLabel.isHidden = true
                self.isTransitioningWave = false
                self.startNextWave()
            }
        }
    }
    
    func clearAllEnemies() {
        for zombie in zombies {
            zombie.removeFromParent()
        }
        zombies.removeAll()
    }
    
    
    func startBossStage() {
        guard currentWaveIndex < waveCycle.count else { return }
        let wave = waveCycle[currentWaveIndex]
        guard wave.isBoss else { return }
        
        isBossStage = true
        isTransitioningWave = true //Prevents regular enemy spawning during boss stage
        clearAllEnemies()
        
        progressLabel.text = "Defeat the boss!"
        waveMessageLabel.text = "Boss Stage Starting.."
        waveMessageLabel.isHidden = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.waveMessageLabel.isHidden = true
            self.isTransitioningWave = false
            self.spawnWizardBoss()
        }
    }
    
    func handleBossDefeat() {
         // Create the special skill spinner overlay
        let spinnerOverlay = BossSpinnerOverlayNode(skillManager: skillManager, overlayManager: overlayManager)
        overlayManager.enqueueOverlay(spinnerOverlay)
        
        isBossStage = false
        isTransitioningWave = true
        currentWaveIndex += 1 // Move to next wave in cycle
        waveLabel.text = "Wave \(waveCounter)"
        
        //No enemies to carry over from boss stage
        //pendingEnemies reset
        pendingEnemies = 0
        enemiesToSpawn = 0
        updateProgressLabel()
        
        //Increase difficulty variables
        zombieSpeed += 0.1
        zombieHealth += 3
        wizardHealth += 15
        gracePeriod = max(1.0, gracePeriod - 2.0) // Decrease grace period, minimum 5 seconds
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
        waveCycle.removeAll()
        
        //Define increased difficulty waves
        //For simplicity, we'll increase the number of enemies and adjust spawn intervals
        //Can further customize here based on game's balance needs later on
        
        let cycleMultiplier = 2
        //*******************************************************************************************
        //*******************************************************************************************
        //*******************************************************************************************
        // SEE NOTE ABOVE ^
        
        for waveNumber in 1...7 {
            switch waveNumber {
            case 1:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 10 * Int(cycleMultiplier), regularEnemies: 10 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 3.0 - 1.0, requiresFullClearance: false))
            case 2:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 15 * Int(cycleMultiplier), regularEnemies: 15 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 2.8 - 1.0, requiresFullClearance: false))
            case 3:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 30 * Int(cycleMultiplier), regularEnemies: 30 * Int(cycleMultiplier), chargerEnemies: 0, exploderEnemies: 0, isHorde: true, isBoss: false, spawnInterval: 0.5, requiresFullClearance: false))
            case 4:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 35 * Int(cycleMultiplier), regularEnemies: 30 * Int(cycleMultiplier), chargerEnemies: 5 * Int(cycleMultiplier), exploderEnemies: 0, isHorde: false, isBoss: false, spawnInterval: 2.3 - 1.0, requiresFullClearance: false))
            case 5:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 40 * Int(cycleMultiplier), regularEnemies: 30 * Int(cycleMultiplier), chargerEnemies: 5 * Int(cycleMultiplier), exploderEnemies: 5 * Int(cycleMultiplier), isHorde: false, isBoss: false, spawnInterval: 2.1 - 1.0, requiresFullClearance: false))
            case 6:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 46 * Int(cycleMultiplier), regularEnemies: 30 * Int(cycleMultiplier), chargerEnemies: 8 * Int(cycleMultiplier), exploderEnemies: 8 * Int(cycleMultiplier), isHorde: true, isBoss: false, spawnInterval: 0.5, requiresFullClearance: true))
            case 7:
                waveCycle.append(Wave(waveNumber: waveNumber, totalEnemies: 1, regularEnemies: 0, chargerEnemies: 0, exploderEnemies: 0, isHorde: false, isBoss: true, spawnInterval: 0.0, requiresFullClearance: false))
            default:
                break
            }
        }
        currentWaveIndex = 0
        pendingEnemies = 0
        enemiesToSpawn = 0
        updateProgressLabel()
        startNextWave()
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
        projectile.userData = NSMutableDictionary()
        projectile.userData?.setValue(playerState.projectilesPierce, forKey: "pierce")
        projectile.userData?.setValue([], forKey: "hitEnemies")
        addChild(projectile)
        //Set up movement action in the specified direction
        let normalizedDirection = CGVector(dx: direction.x, dy: direction.y).normalized
        //let moveDistance: CGFloat = 800
        let moveAction = SKAction.move(by: CGVector(dx: normalizedDirection.dx * playerState.currentRange, dy: normalizedDirection.dy * playerState.currentRange), duration: 2)
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
        guard let hitEnemies = projectile.userData?.value(forKey: "hitEnemies") as? [SKSpriteNode] else { return }
        let shouldPierce = playerState.projectilesPierce   // This gets triggered to true when the skill is selected as upgrade
        var updatedHitEnemies = hitEnemies
        //var didHitEnemy = false
        for (index, zombie) in zombies.enumerated().reversed() {
            if projectile.frame.intersects(zombie.frame) {
                if !updatedHitEnemies.contains(where: { $0 === zombie }) {
                    zombie.takeDamage(amount: playerState.currentDamage)
                    if zombie.isDead {
                        // MARK: OLD
//                        zombie.removeFromParent()
//                        zombies.remove(at: index)
//                        handleEnemyDefeat()
                        // MARK: NEW
                        let lastHitZombiePosition = zombie.position
                        zombie.removeFromParent()
                        zombies.remove(at: index)
                        handleEnemyDefeat(at: lastHitZombiePosition)
                    }
                    updatedHitEnemies.append(zombie)
                    
                    //Apply knockback if mightyknockback is active
                    if playerState.mightyKnockbackActive {
                        applyKnockback(to: zombie, strength: 50, duration: 0.2)
                    }
                }
                
                //If projectiles do NOT pierce, remove the projectile after hitting
                if !shouldPierce {
                    projectile.removeFromParent()
                    break
                }
                //If projectiles DO pierce, continue checking other enemies
            }
        }
        //Check collision for wizard
        if let wizard = scene?.childNode(withName: "wizard") as? ZPWizard, projectile.frame.intersects(wizard.frame) {
            //Check if the wizard has already been hit by this projectile
            if !updatedHitEnemies.contains(where: { $0 === wizard }) {
                wizard.takeDamage(amount: playerState.currentDamage)
                updatedHitEnemies.append(wizard)
                if wizard.health <= 0 {
                    bossIsAlive = false
                    arenaBounds = nil
                    handleBossDefeat()
                    if let outline = childNode(withName: "arenaOutline") as? SKShapeNode {
                        outline.removeFromParent()
                    }
                }
                
                if !shouldPierce {
                    projectile.removeFromParent()
                }
            }
        }
             
        //Update hitEnemies list
        projectile.userData?.setValue(updatedHitEnemies, forKey: "hitEnemies")
    }
    
    func shootGrenade(in direction: CGPoint) {
        // Create grenade node (placeholder as a small cyan block)
        let grenade = SKSpriteNode(color: .cyan, size: CGSize(width: 15, height: 15))
        grenade.position = player.position
        grenade.name = "freezeGrenade"
        grenade.userData = NSMutableDictionary()
        grenade.userData?["hasCollided"] = false
        addChild(grenade)
        
        // Set up movement action in the specified direction
        let normalizedDirection = CGVector(dx: direction.x, dy: direction.y).normalized
        let grenadeMoveDistance: CGFloat = 150.0  // Example distance
        let moveAction = SKAction.move(by: CGVector(dx: normalizedDirection.dx * grenadeMoveDistance, dy: normalizedDirection.dy * grenadeMoveDistance), duration: 1.0)
        
        let waitAction = SKAction.wait(forDuration: 1.0)
        let explodeAction = SKAction.run {
            self.explodeGrenade(grenade)
        }
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([moveAction, waitAction, explodeAction, removeAction])
        grenade.run(sequence)
            
    }
        
    func explodeGrenade(_ grenade: SKSpriteNode) {
        // Visual explosion placeholder (e.g., scaling up and fading out)
        let explosionRadius = playerState.freezeRadius + 25.0
        let explode = SKShapeNode(circleOfRadius: playerState.freezeRadius + 25.0)
        explode.position = grenade.position
        explode.strokeColor = .cyan
        explode.lineWidth = 1.0
        explode.glowWidth = 2.0
        explode.zPosition = 4
        addChild(explode)
        
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        let explodeSequence = SKAction.sequence([group, remove])
        explode.run(explodeSequence)
        
        //Handle freeze effect on zombies within radius
        for zombie in zombies {
            let distance = hypot(grenade.position.x - zombie.position.x, grenade.position.y - zombie.position.y)
            if distance <= explosionRadius {
                //Apply freeze effect
                zombie.isFrozen = true
                zombie.freezeEndTime =  currentGameTime + 2.0 + playerState.freezeDuration //playerState.freezeDuration
                zombie.color = .cyan
                zombie.colorBlendFactor = 1.0
//                zombie.freeze(currentTime: currentGameTime, freezeDuration: 2.0 + playerState.freezeDuration)
            }
        }
        
        //Handle freeze effect on boss if within radius
        if let wizard = wizardBoss, bossIsAlive {
            let distanceToWizard = hypot(grenade.position.x - wizard.position.x, grenade.position.y - wizard.position.y)
            if distanceToWizard <= explosionRadius {
                wizard.freeze(currentTime: currentGameTime, freezeDuration: 2.0 + playerState.freezeDuration)
            }
        }
    }
    
    func checkSpinningBladesCollision() {
        let currentTime = CACurrentMediaTime()
        let damageCooldown: TimeInterval = 1.0 // 1 second cooldown

        guard let bladesContainer = bladesContainer else { return }

        for blade in bladesContainer.children where blade.name == "spinningBlade" {
            // Safely cast blade to SKSpriteNode
            guard let bladeSprite = blade as? SKSpriteNode else {
                continue
            }

            let bladePosition = bladeSprite.convert(CGPoint.zero, to: self)

            // Check collision with zombies
            for (index, zombie) in zombies.enumerated().reversed() {
                let zombiePosition = zombie.position
                let distance = hypot(bladePosition.x - zombiePosition.x, bladePosition.y - zombiePosition.y)

                // Calculate collision distance based on blade and zombie sizes
                let collisionDistance = (bladeSprite.size.width / 2) + (zombie.size.width / 2)

                if distance < collisionDistance {
                    if currentTime - zombie.lastSpinningBladeDamageTime > damageCooldown {
                        zombie.takeDamage(amount: Double(playerState.spinningBladesDamage))
                        zombie.lastSpinningBladeDamageTime = currentTime

                        if zombie.isDead {
                            let lastHitZombiePosition = zombie.position
                            zombie.removeFromParent()
                            zombies.remove(at: index)
                            handleEnemyDefeat(at: lastHitZombiePosition)
                        }

                        // Optional: Add visual or audio feedback here
                    }
                }
            }

            // Check collision with wizard
            if let wizard = scene?.childNode(withName: "wizard") as? ZPWizard {
                let wizardPosition = wizard.position
                let distance = hypot(bladePosition.x - wizardPosition.x, bladePosition.y - wizardPosition.y)

                // Calculate collision distance based on blade and wizard sizes
                let collisionDistance = (bladeSprite.size.width / 2) + (wizard.size.width / 2)

                if distance < collisionDistance {
                    if currentTime - wizard.lastSpinningBladeDamageTime > damageCooldown {
                        wizard.takeDamage(amount: Double(playerState.spinningBladesDamage))
                        wizard.lastSpinningBladeDamageTime = currentTime

                        if wizard.health <= 0 {
                            bossIsAlive = false
                            arenaBounds = nil
                            handleBossDefeat()

                            if let outline = childNode(withName: "arenaOutline") as? SKShapeNode {
                                outline.removeFromParent()
                            }

                        }

                        // Optional: Add visual or audio feedback here
                    }
                }
            }
        }
    }

    func checkBarrierCollision() {
        let currentTime = CACurrentMediaTime()
        let damageCooldown: TimeInterval = max(0.3,1.0 - playerState.barrierPulseFrequency)
        
        guard let barrierContainer = barrierContainer else { return }
        
        for barrier in barrierContainer.children where barrier.name == "protectiveBarrier" {
            // Safely cast barrier to SKShapeNode
            guard let barrierShape = barrier as? SKShapeNode else {
                continue
            }
            
            // Convert barrier's position to scene coordinates
            let barrierScenePosition = barrierShape.convert(CGPoint.zero, to: self)
            
            // Get barrier size (radius)
            let barrierRadius = barrierShape.frame.size.width / 2
            
            // Check collision with zombies
            for (index, zombie) in zombies.enumerated().reversed() {
                let zombiePosition = zombie.position
                let distance = hypot(barrierScenePosition.x - zombiePosition.x, barrierScenePosition.y - zombiePosition.y)
                
                // Calculate collision distance based on barrier and zombie sizes
                let collisionDistance = barrierRadius + (zombie.size.width / 2)
                
                if distance < collisionDistance {
                    if currentTime - zombie.lastBarrierDamageTime > damageCooldown {
                        zombie.takeDamage(amount: Double(playerState.barrierDamage))
                        zombie.lastBarrierDamageTime = currentTime
                        
                        if zombie.isDead {
                            let lastHitZombiePosition = zombie.position
                            zombie.removeFromParent()
                            zombies.remove(at: index)
                            handleEnemyDefeat(at: lastHitZombiePosition)
                        }
                        
                        // Optional: Add visual or audio feedback here
                    }
                }
            }
            
            // Check collision with wizard
            if let wizard = scene?.childNode(withName: "wizard") as? ZPWizard {
                let wizardPosition = wizard.position
                let distance = hypot(barrierScenePosition.x - wizardPosition.x, barrierScenePosition.y - wizardPosition.y)
                
                // Calculate collision distance based on barrier and wizard sizes
                let collisionDistance = barrierRadius + (wizard.size.width / 2)
                
                if distance < collisionDistance {
                    if currentTime - wizard.lastBarrierDamageTime > damageCooldown {
                        wizard.takeDamage(amount: Double(playerState.barrierDamage))
                        wizard.lastBarrierDamageTime = currentTime
                        
                        if wizard.health <= 0 {
                            bossIsAlive = false
                            arenaBounds = nil
                            handleBossDefeat()
                            
                            if let outline = childNode(withName: "arenaOutline") as? SKShapeNode {
                                outline.removeFromParent()
                            }
                            
                        }
                        
                        // Optional: Add visual or audio feedback here
                    }
                }
            }
        }
    }
    
    func checkSpectralShieldCollision() {
        guard let shieldContainer = shieldContainer else { return }
        
        for shield in shieldContainer.children where shield.name == "spectralShield" {
            guard let shieldShape = shield as? SKShapeNode else { continue }
            //Convert shield position to scene coordinates
            let shieldScenePosition = shieldShape.convert(CGPoint.zero, to: self)
            //Get shieldSize
            let shieldSize = shieldShape.frame.size.width / 2
            
            //Check collision with zombies
            for (index, zombie) in zombies.enumerated().reversed(){
                let zombiePosition = zombie.position
                let distance = hypot(shieldScenePosition.x - zombiePosition.x, shieldScenePosition.y - zombiePosition.y)
                //Calculate collision distance based on shield and zombie size
                let collisionDistance = shieldSize + (zombie.size.width / 2)
                
                if distance < collisionDistance {
                    absorbShieldHit()
                    zombie.removeFromParent()
                    zombies.remove(at: index)
                    pendingEnemies -= 1
                    updateProgressLabel()
                    
                    if pendingEnemies < 0 {
                        pendingEnemies = 0
                    }
                    if currentWaveIndex < waveCycle.count {
                        let wave = waveCycle[currentWaveIndex]
                        if wave.allEnemiesSpawned && pendingEnemies <= 0 && !isBossStage {
                            handleWaveProgression()
                        }
                    }
                }
            }
        }
    }
    
    func absorbShieldHit() {
        shieldHitsRemaining -= 1
        updateShieldAppearance()
        
        if shieldHitsRemaining <= 0 {
            removeSpectralShield()
            playerState.spectralShieldActive = false
        }
    }
    
    func updateShieldAppearance() {
        guard let shield = spectralShield else { return }
        switch shieldHitsRemaining {
        case shieldMaxHits:
            shield.strokeColor = UIColor.green.withAlphaComponent(0.7)
        case shieldMaxHits - 1:
            shield.strokeColor = UIColor.orange.withAlphaComponent(0.7)
        case 1:
            shield.strokeColor = UIColor.red.withAlphaComponent(0.7)
        default:
            shield.strokeColor = UIColor.gray //Default or error color
        }
    }

    
    func fireHelpingHandProjectile() {
        guard let target = findNearestEnemy(within: 200.0) else {
            return
        }
        
        // Create projectile
        let projectile = SKSpriteNode(color: .gray, size: CGSize(width: 10, height: 10))
        projectile.position = player.position
        projectile.name = "helpingHandProjectile"
        addChild(projectile)
        
        // Calculate direction vector towards the target
        let direction = CGVector(dx: target.position.x - player.position.x, dy: target.position.y - player.position.y).normalized
        
        // Set up movement action (adjust `playerState.currentRange` as needed)
        let moveDistance: CGFloat = 400
        let moveAction = SKAction.move(by: CGVector(dx: direction.dx * moveDistance, dy: direction.dy * moveDistance), duration: 2.0)
        
        // Placeholder for collision check (to be implemented later)
        let collisionAction = SKAction.run {
            self.checkProjectileCollision(projectile) // Uncomment when collision is implemented
        }
        let collisionCheckSequence = SKAction.sequence([collisionAction, SKAction.wait(forDuration: 0.05)])
        let repeatCollisionCheck = SKAction.repeat(collisionCheckSequence, count: Int(2.0 / 0.05)) // Runs for duration of moveAction
        
        let combinedAction = SKAction.group([moveAction, repeatCollisionCheck])
        projectile.run(SKAction.sequence([combinedAction, SKAction.removeFromParent()]))
        
    }

    /// Finds the nearest enemy (zombie or wizard) within a specified radius.
    func findNearestEnemy(within radius: CGFloat) -> SKSpriteNode? {
        var nearestEnemy: SKSpriteNode?
        var shortestDistance = radius
        
        // Iterate through zombies to find the nearest one within the radius
        for zombie in zombies {
            let distance = hypot(zombie.position.x - player.position.x, zombie.position.y - player.position.y)
            if distance < shortestDistance {
                shortestDistance = distance
                nearestEnemy = zombie
            }
        }
        
        // Check if the wizard is within the radius and closer than any zombie
        if let wizard = scene?.childNode(withName: "wizard") as? ZPWizard {
            let distanceToWizard = hypot(wizard.position.x - player.position.x, wizard.position.y - player.position.y)
            if distanceToWizard < shortestDistance {
                shortestDistance = distanceToWizard
                nearestEnemy = wizard
            }
        }
        
        return nearestEnemy
    }
    
    func addSpectralShield() {
        // Avoid adding multiple shields
        if spectralShield != nil { return }
        guard let shieldContainer = shieldContainer else { return }
        
        //Remove existing shield
        shieldContainer.removeAllChildren()
        
        //Create the shield node
        let shield = SKShapeNode(circleOfRadius: 35)
        shield.alpha = 0.7
        shield.lineWidth = 2
        shield.position = CGPoint.zero
        shield.zPosition = 2 //  Ontop of player
        shield.name = "spectralShield"
        
        shieldContainer.addChild(shield)
        spectralShield = shield
        
        //Reset shield durability
        shieldHitsRemaining = shieldMaxHits
        updateShieldAppearance()
    }
    
    func removeSpectralShield() {
        if let shield = spectralShield {
            shield.removeAllActions()
            shield.removeFromParent()
            spectralShield = nil
        }
        
        //Start cooldown timer to reactivate the shield after 'shieldCooldown'
        DispatchQueue.main.asyncAfter(deadline: .now() + shieldCooldown) { [weak self] in
            guard let self = self else { return }
            if playerState.spectralShieldActive {
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
        pendingEnemies -= 1
        updateProgressLabel()
        
        if pendingEnemies < 0 {
            pendingEnemies = 0 // Safeguard against negative values
        }
        //Check if grace period should start
        if currentWaveIndex < waveCycle.count {
            let wave = waveCycle[currentWaveIndex]
            if wave.allEnemiesSpawned && pendingEnemies <= 0 && !isBossStage {
                handleWaveProgression()
            }
        }
        
        if playerLives <= 0 {
            showGameOverScreen()
        }
    }
    
    func updateXPBar() {
        xpBarNode.setXP(currentXP: upgradeShopManager.XPCount,
                        xpToNextLevel: upgradeShopManager.XPToNextLevel,
                        xpThreshold: upgradeShopManager.nextShopXPThreshold)
    }
    
    func handleEnemyDefeat(at lastHitZombiePosition: CGPoint) {
        spawnXPNode(at: lastHitZombiePosition)
        
        // MARK: Delete later, just for testing purposes
        let spinnerOverlay = BossSpinnerOverlayNode(skillManager: skillManager, overlayManager: overlayManager)
        overlayManager.enqueueOverlay(spinnerOverlay)
        
        score += 1
        pendingEnemies -= 1
        if pendingEnemies < 0 {
            pendingEnemies = 0
        }
        updateProgressLabel()
        
        //If pendingEnemies is zero and wave progression is not already ongoing
        if pendingEnemies == 0 {
            if waveCycle[currentWaveIndex].requiresFullClearance {
                //proceed to next wave immediately
                //cancel any scheduled wave progression
                waveProgressionWorkItem?.cancel()
                waveProgressionWorkItem = nil
                transitionToNextWave()
            } else if waveCycle[currentWaveIndex].allEnemiesSpawned {
                handleWaveProgression()
            }
        }
    }
    
    func checkXPCollection() {
        for (index, xpNode) in xpNodes.enumerated().reversed() {
            let distance = player.position.distance(to: xpNode.position)
            if distance < playerState.xpPickupRadius {

                playerState.currentXP += xpNode.xpAmount
                upgradeShopManager.incrementXPCount()
                updateXPBar()
    
                // add a sound/animation
    
                xpNode.removeFromParent()
                xpNodes.remove(at: index)
            }
        }
    }
    
    func spawnXPNode(at position: CGPoint) {
        let xpNode = XPNode(xpAmount: Int.random(in: 3...10))
        xpNode.position = position
        addChild(xpNode)
        xpNodes.append(xpNode)
    }
    
    func spawnRandomXPNode() {
        let spawnBuffer: CGFloat = 30.0 // Buffer to prevent spawning too close to the edges

        // Define the minimum and maximum Y based on vertical bounds and buffer
        let minY = bottomBound + spawnBuffer
        let maxY = topBound - spawnBuffer

        // Define the minimum and maximum X based on scene size and buffer
        let minX = -size.width / 2 - spawnBuffer
        let maxX = size.width / 2 + spawnBuffer

        let randomX = CGFloat.random(in: minX...maxX)
        let randomY = CGFloat.random(in: minY...maxY)
        let randomPosition = CGPoint(x: randomX, y: randomY)

        spawnXPNode(at: randomPosition)
    }
    
    func startXPSpawnTimer() {
        // Ensure only one timer is active
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
        playerLives -= 1
    }
    
    private func showEnemyIntroductionMessage(_ message: String) {
        guard let cameraNode = self.camera else { return }
        let enemyMessageLabel = SKLabelNode(text: message)
        enemyMessageLabel.fontName = "Arial"
        enemyMessageLabel.fontSize = 40
        enemyMessageLabel.fontColor = .red
        enemyMessageLabel.position = CGPoint(x: 0, y: size.height * 0.25)
        enemyMessageLabel.zPosition = 5
        cameraNode.addChild(enemyMessageLabel)
        
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.fadeOut(withDuration: 0.5),
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
        waveCounter = 0
        currentWaveIndex = 0
        zombieHealth = 3
        zombieSpeed = 0.3
        wizardHealth = 15
        enemiesToDefeat = 3
        maxRegularZombies = 3
        maxChargerZombies = 0
        maxExploderZombies = 0
        miniWaveInterval = 3.0
        isBossStage = false
        arenaBounds = nil
        gracePeriod = 10.0
        pendingEnemies = 0
        enemiesToSpawn = 0
        
        playerState.currentXP = 0
        playerState.resetToBaseStats()
        
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
        upgradeStatsLabel.text = "Dmg: \(playerState.currentDamage) | Range: \(playerState.currentRange) | AtkSpeed: \(playerState.currentAttackSpeed)"
    }
    
    //Function used to handle removing zombies from tracking structure (in exploder class)
    func removeZombieFromTracking(_ zombie: ZPExploderZombieNode) {
        if let index = zombies.firstIndex(where: { $0 === zombie }) {
            zombies.remove(at: index)
        }
    }
    
}
