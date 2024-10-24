//
//  ZPBoxNode.swift
//  Zombocalypse
//
//  
//

import SpriteKit

class ZPBoxNode: SKNode {
    var box: SKShapeNode = SKShapeNode()
    func setup(screenSize: CGSize, layoutInfo: ZPLayoutInfo) {
        let boxNode = SKShapeNode(rect: .init(origin: .zero,
                                          size: layoutInfo.boxSize),
                              cornerRadius: 8.0)
        boxNode.fillColor = .red
        addChild(boxNode)
        box = boxNode
    }
}
