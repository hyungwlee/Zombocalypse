//
//  ZPLayoutInfo.swift
//  Zombocalypse
//
//  
//

import Foundation
import SwiftUI
import SpriteKit


struct ZPLayoutInfo {
    let screenSize: CGSize
    
    // MARK: Constants
    
    let enemyDamageInterval: CGFloat = 1.0
    let numberOfMapSections: Int = 5
    
    // MARK: Adjusted based screenSize in SLGameContext, these values are just around what they should be on Pro Max, but they are all overwritten in configureLayouts()
    
    var mapSectionSize: CGSize = .zero

    var skeletonHeight: CGFloat = 56
    var chargerHeight: CGFloat = 67.2
    var exploderHeight: CGFloat = 56
    var bossHeight: CGFloat = 113
    var enemySpawnSafeRadius: CGFloat = 150
    var enemyDespawnDistance: CGFloat = 956 * 0.75
    
    var joystickBaseRadius: CGFloat = 50
    var joystickKnobRadius: CGFloat = 25
    var moveJoyStickPosition: CGPoint = .zero
    var shootJoyStickPosition: CGPoint = .zero
    var screenScaleFactor: CGFloat = 1.0
    
    var playerHeight: CGFloat = 70
    var playerStartingPosition: CGPoint = .zero
    var crossBowHeight: CGFloat = 1.0
    
    var healthBarSize: CGSize = CGSize(width: 80, height: 7)
    var healthBarOffset: CGFloat = 50
    var progressBarSize: CGSize = .zero
    
    var scoreNodeHeight: CGFloat = 44
    var scoreNodePosition: CGPoint = .zero
    var waveNodeHeight: CGFloat = 44
    var waveNodePosition: CGPoint = .zero
    
    var xpBarNodeWidth: CGFloat = 150
    var xpBarNodePosition: CGPoint = .zero
    
    /// add top overlay rect?
    
    var bannerWidth: CGFloat = 348
    var bannerPosition: CGPoint = .zero
    
    var spinningBladeOrbitRadius: CGFloat = 75.0
    var spinningBladesheight: CGFloat = 100
    
    var barrierBaseRadius: CGFloat = 60
    var barrierStrokeWidth: CGFloat = 3
    
    var arenaSize: CGSize = .zero
    
    var projectileHeight: CGFloat = 20
    var freezeGrenadeHeight: CGFloat = 22
    var freezeGrenadeMoveDistance: CGFloat = 100
    
    var helpingHandHeight: CGFloat = 22
    var spectralShieldRadius: CGFloat = 80
    var knockbackRadius: CGFloat = 100
    var knockbackStrength: CGFloat = 200
    
    
    var xpSpawnBuffer: CGFloat = 80
    var xpSpawnRadius: CGFloat = 478
    var xpSpawnSize: CGSize = CGSize(width: 20, height: 20)
    
    var gameOverWidth: CGFloat = 100
    var gameOverPosition: CGPoint = .zero
}

