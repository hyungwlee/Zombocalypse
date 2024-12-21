//
//  SLXPNode.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/7/24.
//


import SpriteKit

class SLXPNode: SKSpriteNode {
    var xpAmount: Int

    init(xpAmount: Int = 5, scaleFactor: CGFloat) {
        self.xpAmount = xpAmount
        let texture = SKTexture(imageNamed: "sl_xp")
        super.init(texture: texture, color: .clear, size: CGSize(width: 11 * scaleFactor, height: 11 * scaleFactor))
        self.name = "xpNode"
        self.zPosition = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
