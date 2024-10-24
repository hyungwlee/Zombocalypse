//
//  ZPGameContext.swift
//  Zombocalypse
//
//  
//

import Combine
import GameplayKit

class ZPGameContext: GameContext {
    var gameScene: ZPGameScene? {
        scene as? ZPGameScene
    }
    let gameMode: GameModeType
    let gameInfo: ZPGameInfo
    var layoutInfo: ZPLayoutInfo = .init(screenSize: .zero)
    
    private(set) var stateMachine: GKStateMachine?
    
    init(dependencies: Dependencies, gameMode: GameModeType) {
        self.gameInfo = ZPGameInfo()
        self.gameMode = gameMode
        super.init(dependencies: dependencies)
    }
    
    func configureStates() {
        guard let gameScene else { return }
        print("did configure states")
        stateMachine = GKStateMachine(states: [
            ZPGameIdleState(scene: gameScene, context: self)
        ])
    }

}
