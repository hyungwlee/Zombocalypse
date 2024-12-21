//
//  SLGameInfo.swift
//  Zombocalypse
//
//  
//

import Foundation

class SLGameInfo {
    
    var scale: CGFloat = 1.0
    
    var score = 0
    
    var zombieSpeed: CGFloat = 0.5
    var zombieHealth: CGFloat = 2.0
    var wizardHealth: CGFloat = 400.0
    
    var waveGracePeriod: CGFloat = 7.0
    var currentWaveIndex: Int = 0
    var pendingEnemies: Int = 0
    var enemiesToSpawn: Int = 0
    
    

    
    // MARK: Functions
    
    func scaleValues(scale: CGFloat) {
        self.scale = scale
        zombieSpeed = zombieSpeed * scale
    }
    
    func reset() {
        score = 0
        zombieSpeed = 0.5 * scale
        zombieHealth = 2.0
        wizardHealth = 400.0
        waveGracePeriod = 7.0
        currentWaveIndex = 0
        pendingEnemies = 0
        enemiesToSpawn = 0
    }
    
    func incrementScore(by score: Int) {
        self.score += score
    }
    
    func incrementZombieSpeed(by speed: CGFloat) {
        zombieSpeed += (speed * scale)
    }
    
    func incrementZombieHealth(by health: CGFloat) {
        zombieHealth += health
    }

    func incrementWizardHealth(by health: CGFloat) {
        wizardHealth += health
    }
    
    func updateWaveGracePeriod(to period: CGFloat) {
        waveGracePeriod = period
    }
    
    func incrementWaveIndex() {
        currentWaveIndex += 1
    }
    
    func resetWaveIndex() {
        currentWaveIndex = 0
    }
    
    func incrementPendingEnemies(by enemies: Int) {
        pendingEnemies += enemies
        
        if pendingEnemies < 0 {
            pendingEnemies = 0
        }
    }
    
    func updatePendingEnemies(to enemies: Int) {
        pendingEnemies = enemies
        
        if pendingEnemies < 0 {
            pendingEnemies = 0
        }
    }
    
    func resetPendingEnemies() {
        pendingEnemies = 0
    }
    
    func incrementEnemiesToSpawn(by enemies: Int) {
        enemiesToSpawn += enemies
        
        if enemiesToSpawn < 0 {
            enemiesToSpawn = 0
        }
    }
    
    func updateEnemiesToSpawn(to enemies: Int) {
        enemiesToSpawn = enemies
        
        if enemiesToSpawn < 0 {
            enemiesToSpawn = 0
        }
    }
    
    func resetEnemiesToSpawn() {
        enemiesToSpawn = 0
    }
    
}
