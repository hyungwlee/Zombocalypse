//
//  SLGameContext.swift
//  Zombocalypse
//
//  
//

import Combine
import GameplayKit

class SLGameContext: GameContext {
    var gameScene: SLGameScene? {
        scene as? SLGameScene
    }
    let gameMode: GameModeType
    let gameInfo: SLGameInfo
    var layoutInfo: SLLayoutInfo
        
    init(dependencies: Dependencies, gameMode: GameModeType) {
        _ = SLHapticManager.shared // preload
        _ = SLSoundManager.shared // preload
        
        self.gameMode = gameMode
        self.gameInfo = SLGameInfo()
        self.layoutInfo = SLLayoutInfo(screenSize: UIScreen.main.bounds.size)
        super.init(dependencies: dependencies)
        
        self.scene = SLGameScene(context: self, size: UIScreen.main.bounds.size)
        
        configureLayouts()
        
        gameInfo.scaleValues(scale: layoutInfo.screenScaleFactor)
    }
    
    func configureLayouts() {
        let screenSize = UIScreen.main.bounds.size

        layoutInfo.mapSectionSize = CGSize(width: (screenSize.height * 2.0) * 0.95331, height: screenSize.height * 2.0)
        
        layoutInfo.enemySpawnSafeRadius = screenSize.width * 0.3
        layoutInfo.enemyDespawnDistance = screenSize.height * 0.55
        
        layoutInfo.joystickBaseRadius = screenSize.width * 0.15
        layoutInfo.joystickKnobRadius = layoutInfo.joystickBaseRadius / 2
        layoutInfo.moveJoyStickPosition = CGPoint(x: screenSize.width * -0.5 + layoutInfo.joystickBaseRadius * 1.5, y: screenSize.height * -0.5 + layoutInfo.joystickBaseRadius * 1.5)
        layoutInfo.shootJoyStickPosition = CGPoint(x: screenSize.width * 0.5 - layoutInfo.joystickBaseRadius * 1.5, y: screenSize.height * -0.5 + layoutInfo.joystickBaseRadius * 1.5)
        
        layoutInfo.playerHeight = screenSize.height * 0.0732217573
        let playerYOffset = screenSize.height * -0.5
        layoutInfo.playerStartingPosition = CGPoint(x: screenSize.width * 0.5, y: screenSize.height * 0.5 + playerYOffset)
        layoutInfo.crossBowHeight = layoutInfo.playerHeight * 0.623809542
        
        layoutInfo.healthBarSize = CGSize(width: layoutInfo.playerHeight * 1.14285714, height: layoutInfo.playerHeight * 0.1)
        layoutInfo.healthBarOffset = layoutInfo.playerHeight * 0.714285714
        layoutInfo.progressBarSize = CGSize(width: layoutInfo.healthBarSize.width * 0.9, height: layoutInfo.healthBarSize.height * 0.5)
        
        layoutInfo.scoreNodeHeight = screenSize.height * 0.0460251046
        layoutInfo.waveNodeHeight = screenSize.height * 0.0460251046
        if screenSize.height < 700 {
            layoutInfo.scoreNodePosition = CGPoint(x: screenSize.width * -0.46, y: screenSize.height * 0.48)
            layoutInfo.waveNodePosition = CGPoint(x: screenSize.width * 0.46, y: screenSize.height * 0.48)
        } else {
            layoutInfo.scoreNodePosition = CGPoint(x: screenSize.width * -0.45, y: screenSize.height * 0.43)
            layoutInfo.waveNodePosition = CGPoint(x: screenSize.width * 0.45, y: screenSize.height * 0.43)
        }
        layoutInfo.xpBarNodeWidth = screenSize.width * 0.7
        layoutInfo.xpBarNodePosition = CGPoint(x: 0, y: screenSize.height * 0.35)
        
        layoutInfo.bannerWidth = screenSize.width * 0.79
        layoutInfo.bannerPosition = CGPoint(x: 0, y: screenSize.height * 0.25)
        
        layoutInfo.spinningBladeOrbitRadius = layoutInfo.playerHeight * 1.1
        layoutInfo.spinningBladesheight = layoutInfo.playerHeight * 0.47
        
        layoutInfo.barrierBaseRadius = layoutInfo.playerHeight * 6/7
        layoutInfo.barrierStrokeWidth = layoutInfo.barrierBaseRadius * 3/40
        
        layoutInfo.arenaSize = CGSize(width: screenSize.width * 0.82, height: screenSize.height * 0.79)
        
        layoutInfo.screenScaleFactor = screenSize.width / 440
        
        layoutInfo.projectileHeight = layoutInfo.playerHeight * 0.29
        layoutInfo.freezeGrenadeHeight = layoutInfo.playerHeight * 0.31
        layoutInfo.freezeGrenadeMoveDistance *= layoutInfo.screenScaleFactor
        
        layoutInfo.helpingHandHeight = layoutInfo.playerHeight * 0.29
        layoutInfo.spectralShieldRadius = layoutInfo.playerHeight * 1.14
        
        layoutInfo.knockbackRadius *= layoutInfo.screenScaleFactor
        layoutInfo.knockbackStrength *= layoutInfo.screenScaleFactor
        
        layoutInfo.xpSpawnBuffer = layoutInfo.playerHeight * 1.2
        layoutInfo.xpSpawnBuffer = screenSize.height * 0.05
        
        layoutInfo.gameOverWidth = screenSize.width * 0.86
        layoutInfo.gameOverPosition = CGPoint(x: 0, y: screenSize.height * 0.05)
        
        layoutInfo.skeletonHeight = layoutInfo.playerHeight * 0.8
        layoutInfo.chargerHeight = layoutInfo.playerHeight * 0.96
        layoutInfo.exploderHeight = layoutInfo.playerHeight * 0.8
        layoutInfo.bossHeight = layoutInfo.playerHeight * 1.6
        
        
    }

}
