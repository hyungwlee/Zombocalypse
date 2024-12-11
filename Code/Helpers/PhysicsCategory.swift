//
//  PhysicsCategory.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/10/24.
//


struct PhysicsCategory {
    static let player: UInt32                 = 0x1 << 0
    static let enemy: UInt32                  = 0x1 << 1
    static let boss: UInt32                   = 0x1 << 2
    static let projectile: UInt32             = 0x1 << 3
    static let xp: UInt32                     = 0x1 << 4
    static let protectiveBarrier: UInt32      = 0x1 << 5
    static let border: UInt32                 = 0x1 << 5
    static let blade: UInt32                  = 1 << 6
    static let shield: UInt32                 = 1 << 7
    static let none: UInt32                   = 1 << 8
}
