//
//  SLMapManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/16/24.
//


import SpriteKit

class SLMapManager {
    weak var scene: SKScene?
    
    private var mainSections: [SKSpriteNode] = []
    private var topSections: [SKSpriteNode] = []
    private var bottomSections: [SKSpriteNode] = []

    private var topFences: [SKSpriteNode] = []
    private var bottomFences: [SKSpriteNode] = []
    private var topStumps: [SKSpriteNode] = []
    private var topTombstones: [SKSpriteNode] = []
    private var bottomStumps: [SKSpriteNode] = []
    private var bottomTombstones: [SKSpriteNode] = []
    
    private let sectionWidth: CGFloat
    private let sectionHeight: CGFloat
    private let numSections: Int
    private let fenceTextureName: String = "sl_fence"
    
    public var topBound: CGFloat = 0
    public var bottomBound: CGFloat = 0
    public var topFenceY: CGFloat = 0
    public var bottomFenceY: CGFloat = 0
    
    public var fenceWidthFactor: CGFloat = 1.067
    public var fenceHeightFactor: CGFloat = 0.19048
    public var fenceEdgeFactor: CGFloat = 0.006122448898
    public var stumpWidthFactor: CGFloat = 0.0544217687
    public var stumpHeightFactor: CGFloat = 0.0491972789
    public var tombWidthFactor: CGFloat = 0.0530612245
    public var tombHeightFactor: CGFloat = 0.066666666667
    
    private var bottomBoundary: SKNode?
    
    init(sectionWidth: CGFloat, sectionHeight: CGFloat, numSections: Int, scene: SLGameScene) {
        self.sectionWidth = sectionWidth
        self.sectionHeight = sectionHeight
        self.numSections = numSections
        self.scene = scene
    }

    /// Sets up the background sections and fences
    func setupBackground(in scene: SKScene, withTexture textureName: String) {
        let totalHeight = scene.size.height * 2
        let aspectRatio = sectionWidth / sectionHeight
        let newHeight = totalHeight
        let newWidth = newHeight * aspectRatio
        
        // Set vertical bounds based on background size
        topBound = newHeight / 2 - (sectionWidth * fenceEdgeFactor)
        topFenceY = newHeight / 2 + (sectionWidth * fenceHeightFactor) / 2 - (sectionWidth * fenceEdgeFactor)
        bottomBound = -newHeight / 2 + (sectionWidth * fenceEdgeFactor)
        bottomFenceY = -newHeight / 2 + (sectionWidth * fenceHeightFactor) / 2 - (sectionWidth * fenceEdgeFactor)

        // Add background sections
        for i in 0..<numSections {
            let section = SKSpriteNode(texture: SKTexture(imageNamed: textureName))
            section.size = CGSize(width: newWidth, height: newHeight)
            section.position = CGPoint(x: CGFloat(i) * newWidth - newWidth / 2, y: 0)
            section.zPosition = -2
            scene.addChild(section)
            mainSections.append(section)
        }
        
        // Add top background sections
        for i in 0..<numSections {
            let topSection = SKSpriteNode(texture: SKTexture(imageNamed: textureName))
            topSection.size = CGSize(width: newWidth, height: newHeight)
            topSection.position = CGPoint(x: CGFloat(i) * newWidth - newWidth / 2, y: topBound + (newHeight / 2))
            topSection.zPosition = -3
            scene.addChild(topSection)
            topSections.append(topSection)
        }
        
        // Add bottom background sections
        for i in 0..<numSections {
            let bottomSection = SKSpriteNode(texture: SKTexture(imageNamed: textureName))
            bottomSection.size = CGSize(width: newWidth, height: newHeight)
            bottomSection.position = CGPoint(x: CGFloat(i) * newWidth - newWidth / 2, y: bottomBound - (newHeight / 2))
            bottomSection.zPosition = -3
            scene.addChild(bottomSection)
            bottomSections.append(bottomSection)
        }
        
        setupTopFences(in: scene, width: newWidth)
        setupBottomFences(in: scene, width: newWidth)
        addPhysicalObjects(to: scene)
    }
    
    /// Sets up the top fences with physics bodies
    private func setupTopFences(in scene: SKScene, width: CGFloat) {
        topFences.removeAll() // Clear existing fences if any

        for (index, section) in mainSections.enumerated() {
            let fence = SKSpriteNode(texture: SKTexture(imageNamed: fenceTextureName))
            fence.size = CGSize(width: sectionWidth * fenceWidthFactor, height: sectionWidth * fenceHeightFactor)
            fence.position = CGPoint(x: section.position.x, y: topFenceY)
            fence.zPosition = -1 // Just above background
            fence.name = "topFence_\(index)"
            
            fence.physicsBody = SKPhysicsBody(texture: fence.texture!, size: fence.size)
            fence.physicsBody?.categoryBitMask = SLPhysicsCategory.border
            fence.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
            fence.physicsBody?.collisionBitMask = SLPhysicsCategory.player
            fence.physicsBody?.affectedByGravity = false
            fence.physicsBody?.isDynamic = false
            
            scene.addChild(fence)
            topFences.append(fence)
        }
    }
    
    /// Sets up the bottom fences visually and an invisible physics boundary
    private func setupBottomFences(in scene: SKScene, width: CGFloat) {
        bottomFences.removeAll()

        for (index, section) in mainSections.enumerated() {
            let fence = SKSpriteNode(texture: SKTexture(imageNamed: fenceTextureName))
            fence.size = CGSize(width: sectionWidth * fenceWidthFactor, height: sectionWidth * fenceHeightFactor)
            fence.position = CGPoint(x: section.position.x, y: bottomFenceY)
            fence.zPosition = 2
            fence.name = "bottomFence_\(index)"
            
            scene.addChild(fence)
            bottomFences.append(fence)
        }
        
        if bottomBoundary == nil {
            let boundary = SKNode()
            boundary.position = CGPoint(x: 0, y: bottomFenceY - (sectionWidth * fenceHeightFactor) / 2 + (sectionWidth * fenceEdgeFactor * 2))
            boundary.name = "bottomBoundary"
            
            boundary.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -sectionWidth * CGFloat(numSections) / 2, y: 0),
                                                to: CGPoint(x: sectionWidth * CGFloat(numSections) / 2, y: 0))
            boundary.physicsBody?.categoryBitMask = SLPhysicsCategory.border
            boundary.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
            boundary.physicsBody?.collisionBitMask = SLPhysicsCategory.player
            boundary.physicsBody?.affectedByGravity = false
            boundary.physicsBody?.isDynamic = false
            
            scene.addChild(boundary)
            bottomBoundary = boundary
        }
    }
    
    /// Adds physical objects ("sl_stump" and "sl_tombstone") around each main section
    private func addPhysicalObjects(to scene: SKScene) {
        for (_, section) in mainSections.enumerated() {
            
            let stumpTopXOffsets: [CGFloat] = [-sectionWidth * 0.24, -sectionWidth * 0.0, sectionWidth * 0.21]
            let stumpTopYOffsets: [CGFloat] = [sectionWidth * 0.18, sectionWidth * 0.45, sectionWidth * 0.21]
            let tombTopXOffsets: [CGFloat] = [-sectionWidth * 0.35, -sectionWidth * 0.17, sectionWidth * 0.36]
            let tombTopYOffsets: [CGFloat] = [sectionWidth * 0.23, sectionWidth * 0.485, sectionWidth * 0.34]
            
            for (index, xOffset) in stumpTopXOffsets.enumerated() {
                // Add "sl_stump"
                let stump = SKSpriteNode(imageNamed: "sl_stump")
                stump.size = CGSize(width: sectionWidth * stumpWidthFactor, height: sectionWidth * stumpHeightFactor)
                stump.position = CGPoint(x: xOffset, y: stumpTopYOffsets[index]) // Relative to section's center
                stump.zPosition = 1
                
                stump.physicsBody = SKPhysicsBody(texture: stump.texture!, size: stump.size)
                stump.physicsBody?.categoryBitMask = SLPhysicsCategory.border
                stump.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
                stump.physicsBody?.collisionBitMask = SLPhysicsCategory.player
                stump.physicsBody?.affectedByGravity = false
                stump.physicsBody?.isDynamic = false
                
                section.addChild(stump)
                topStumps.append(stump)
            }
            
            for (index, xOffset) in tombTopXOffsets.enumerated() {
                
                // Add "sl_tombstone"
                let tombstone = SKSpriteNode(imageNamed: "sl_tombstone")
                tombstone.size = CGSize(width: sectionWidth * tombWidthFactor, height: sectionWidth * tombHeightFactor)
                tombstone.position = CGPoint(x: xOffset, y: tombTopYOffsets[index]) // Slight Y offset to avoid overlap
                tombstone.zPosition = 1
                
                // Configure Physics Body
                tombstone.physicsBody = SKPhysicsBody(texture: tombstone.texture!, size: tombstone.size)
                tombstone.physicsBody?.categoryBitMask = SLPhysicsCategory.border
                tombstone.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
                tombstone.physicsBody?.collisionBitMask = SLPhysicsCategory.player
                tombstone.physicsBody?.affectedByGravity = false
                tombstone.physicsBody?.isDynamic = false
                
                // Attach to Section
                section.addChild(tombstone)
                topTombstones.append(tombstone)
            }
            
            // **Bottom Half: 2 "sl_stump" and 2 "sl_tombstone"**
            let bottomHalfY = -sectionHeight / 4
            
            // Define horizontal offsets for bottom objects (spread evenly)
            let stumpBottomXOffsets: [CGFloat] = [-sectionWidth * 0.1, sectionWidth * 0.19]
            let stumpBottomYOffsets: [CGFloat] = [-sectionWidth * 0.21, -sectionWidth * 0.42]
            let tombBottomXOffsets: [CGFloat] = [-sectionWidth * 0.35, sectionWidth * 0.33]
            let tombBottomYOffsets: [CGFloat] = [-sectionWidth * 0.38, -sectionWidth * 0.28]
            
            for (index, xOffset) in stumpBottomXOffsets.enumerated() {
                // Add "sl_stump"
                let stump = SKSpriteNode(imageNamed: "sl_stump")
                stump.size = CGSize(width: sectionWidth * tombWidthFactor, height: sectionWidth * tombHeightFactor)
                stump.position = CGPoint(x: xOffset, y: stumpBottomYOffsets[index])
                stump.zPosition = 1
                
                stump.physicsBody = SKPhysicsBody(texture: stump.texture!, size: stump.size)
                stump.physicsBody?.categoryBitMask = SLPhysicsCategory.border
                stump.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
                stump.physicsBody?.collisionBitMask = SLPhysicsCategory.player
                stump.physicsBody?.affectedByGravity = false
                stump.physicsBody?.isDynamic = false
                
                section.addChild(stump)
                bottomStumps.append(stump)
            }
            
            for (index, xOffset) in tombBottomXOffsets.enumerated() {
                // Add "sl_tombstone"
                let tombstone = SKSpriteNode(imageNamed: "sl_tombstone")
                tombstone.size = CGSize(width: sectionWidth * tombWidthFactor, height: sectionWidth * tombHeightFactor)
                tombstone.position = CGPoint(x: xOffset, y: tombBottomYOffsets[index])
                tombstone.zPosition = 1
                
                tombstone.physicsBody = SKPhysicsBody(texture: tombstone.texture!, size: tombstone.size)
                tombstone.physicsBody?.categoryBitMask = SLPhysicsCategory.border
                tombstone.physicsBody?.contactTestBitMask = SLPhysicsCategory.player
                tombstone.physicsBody?.collisionBitMask = SLPhysicsCategory.player
                tombstone.physicsBody?.affectedByGravity = false
                tombstone.physicsBody?.isDynamic = false
                
                section.addChild(tombstone)
                bottomTombstones.append(tombstone)
            }
            
        }
    }
    
    /// Manages the scrolling of background sections and fences based on player's position
    func manageScrolling(playerPosition: CGPoint) {
        let overlapOffset: CGFloat = 300.0
        
        // Manage Background Sections
        for section in mainSections {
            let leftEdge = section.position.x - section.size.width / 2
            let rightEdge = section.position.x + section.size.width / 2

            if playerPosition.x > rightEdge + overlapOffset {
                section.position.x += CGFloat(numSections) * section.size.width
            } else if playerPosition.x < leftEdge - overlapOffset {
                section.position.x -= CGFloat(numSections) * section.size.width
            }
        }
        
        for section in topSections {
            let leftEdge = section.position.x - section.size.width / 2
            let rightEdge = section.position.x + section.size.width / 2

            if playerPosition.x > rightEdge + overlapOffset {
                section.position.x += CGFloat(numSections) * section.size.width
            } else if playerPosition.x < leftEdge - overlapOffset {
                section.position.x -= CGFloat(numSections) * section.size.width
            }
        }
        
        // Manage Bottom Sections
        for section in bottomSections {
            let leftEdge = section.position.x - section.size.width / 2
            let rightEdge = section.position.x + section.size.width / 2

            if playerPosition.x > rightEdge + overlapOffset {
                section.position.x += CGFloat(numSections) * section.size.width
            } else if playerPosition.x < leftEdge - overlapOffset {
                section.position.x -= CGFloat(numSections) * section.size.width
            }
        }
        
        // Manage Top Fences
        for fence in topFences {
            let leftEdge = fence.position.x - fence.size.width / 2
            let rightEdge = fence.position.x + fence.size.width / 2

            if playerPosition.x > rightEdge + overlapOffset {
                fence.position.x += CGFloat(topFences.count) * sectionWidth
            } else if playerPosition.x < leftEdge - overlapOffset {
                fence.position.x -= CGFloat(topFences.count) * sectionWidth
            }
        }
        
        // Manage Bottom Fences
        for fence in bottomFences {
            let leftEdge = fence.position.x - fence.size.width / 2
            let rightEdge = fence.position.x + fence.size.width / 2

            if playerPosition.x > rightEdge + overlapOffset {
                fence.position.x += CGFloat(bottomFences.count) * sectionWidth
            } else if playerPosition.x < leftEdge - overlapOffset {
                fence.position.x -= CGFloat(bottomFences.count) * sectionWidth
            }
        }
    }
    
    /// Clamps the player's position within the vertical bounds defined by fences
    func boundPosition(for position: CGPoint) -> CGPoint {
        var newPosition = position
        if newPosition.y > topBound { newPosition.y = topBound }
        else if newPosition.y < bottomBound { newPosition.y = bottomBound }
        return newPosition
    }
    
    /// Removes all fence nodes (useful for resetting the map)
    func removeAllFences() {
        for fence in topFences {
            fence.removeFromParent()
        }
        topFences.removeAll()
        
        for fence in bottomFences {
            fence.removeFromParent()
        }
        bottomFences.removeAll()
        
        bottomBoundary?.removeFromParent()
        bottomBoundary = nil
    }

    func positionIsClear(position: CGPoint, entitySize: CGSize) -> Bool {
        guard let scene = self.scene else { return false }
        
        let halfWidth = entitySize.width / 2
        let halfHeight = entitySize.height / 2
        let entityFrame = CGRect(x: position.x - halfWidth, y: position.y - halfHeight, width: entitySize.width, height: entitySize.height)
        
        // Check against all stumps and tombstones
        let obstacles = topStumps + bottomStumps + topTombstones + bottomTombstones
        
        for obstacle in obstacles {
            let obstacleFrame = obstacleFrameInScene(obstacle: obstacle, scene: scene)
            if entityFrame.intersects(obstacleFrame) {
                return false
            }
        }
        
        return true
    }
    
    // Helper to calculate obstacle frame in scene coordinates
    private func obstacleFrameInScene(obstacle: SKSpriteNode, scene: SKScene) -> CGRect {
        // Convert obstacle's frame to scene coordinates using convert()
        let obstacleParent = obstacle.parent ?? scene
        let obstaclePositionInScene = obstacleParent.convert(obstacle.position, to: scene)
        
        // Since obstacle.frame gives local coordinates, let's construct the frame manually
        let halfWidth = obstacle.size.width / 2
        let halfHeight = obstacle.size.height / 2
        return CGRect(x: obstaclePositionInScene.x - halfWidth,
                      y: obstaclePositionInScene.y - halfHeight,
                      width: obstacle.size.width,
                      height: obstacle.size.height)
    }
    
}

