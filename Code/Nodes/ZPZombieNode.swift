//
//  ZPZombieNode.swift
//  Zombocalypse
//
//
//

import SpriteKit

class ZPZombie: SKSpriteNode {
    
    init() {
        let size = CGSize(width: 30, height: 30)
        super.init(texture: nil, color: .red, size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func moveTowards(player: SKSpriteNode, speed: CGFloat) {
        let direction = CGVector(dx: player.position.x - self.position.x, dy: player.position.y - self.position.y)
        let length = hypot(direction.dx, direction.dy)
        
        if length > 0 { // Check if the enemy is not at the player's position
            let normalizedDirection = CGVector(dx: direction.dx / length, dy: direction.dy / length)
            self.position = CGPoint(x: self.position.x + normalizedDirection.dx * speed, y: self.position.y + normalizedDirection.dy * speed)
        }
    }
}
