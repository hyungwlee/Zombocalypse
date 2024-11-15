//
//  ZPJoystick.swift
//  Zombocalypse
//
//
//

import SpriteKit

class ZPJoystick: SKNode {
    private let base: SKShapeNode
    private let knob: SKShapeNode
    var positionDelta = CGPoint.zero
    var isActive: Bool = false
    var direction: CGVector = .zero

    init(baseRadius: CGFloat, knobRadius: CGFloat) {
        base = SKShapeNode(circleOfRadius: baseRadius)
        base.fillColor = .gray
        base.alpha = 0.4
        
        knob = SKShapeNode(circleOfRadius: knobRadius)
        knob.fillColor = .darkGray
        knob.alpha = 0.6

        super.init()
        addChild(base)
        addChild(knob)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startTouch(at point: CGPoint) {
        knob.position = point
        updatePositionDelta()
    }

    func moveTouch(to point: CGPoint) {
        let length = sqrt(point.x * point.x + point.y * point.y)
        let maxDistance = base.frame.size.width / 2

        if length <= maxDistance {
            knob.position = point
        } else {
            let angle = atan2(point.y, point.x)
            knob.position = CGPoint(x: cos(angle) * maxDistance, y: sin(angle) * maxDistance)
        }
        updatePositionDelta()
    }

    func endTouch() {
        knob.position = .zero
        positionDelta = .zero
    }
    
    func activate() {
        isActive = true
    }
    
    func deactivate() {
        isActive = false
    }
    
    func updateDirection(newDirection: CGVector) {
        direction = newDirection
    }

    private func updatePositionDelta() {
        positionDelta = CGPoint(x: knob.position.x / (base.frame.size.width / 2),
                                y: knob.position.y / (base.frame.size.height / 2))
    }
}

