//
//  ZPGameIdleState.swift
//  Zombocalypse
//
//
//

import GameplayKit

class ZPGameIdleState: GKState {
    weak var scene: ZPGameScene?
    weak var context: ZPGameContext?
    
    init(scene: ZPGameScene, context: ZPGameContext) {
        self.scene = scene
        self.context = context
        super.init()
    }
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return true
    }
    
    override func didEnter(from previousState: GKState?) {
        print("did enter idle state")
    }
    
    func handleTouch(_ touch: UITouch) {
        guard let scene, let context else { return }
        print("touched \(touch)")
        let touchLocation = touch.location(in: scene)
    }
    
    func handleTouchMoved(_ touch: UITouch) {
        guard let scene, let context else { return }
        let touchLocation = touch.location(in: scene)
    }
    
    func handleTouchEnded(_ touch: UITouch) {
        print("touched ended \(touch)")
    }
}
