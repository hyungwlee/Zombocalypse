//
//  PlayerState.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/5/24.
//


/// This allows us to use ZPGameScene as our "delegate" (sort of like a parent)
/// We can call only these 5 methods that we will implement in our delegate
protocol PlayerStateDelegate: AnyObject {
    // Regular Skills
    func playerStateDidAddSpinningBlades(_ state: PlayerState)
    func playerStateDidUpgradeBarrier(_ state: PlayerState)
    func playerStateDidUpgradeHealth(_ state: PlayerState, restorePercentage: Double) /// example of something condtional to pass to the GameScene
    func playerStateDidUpgradeMagnet(_ state: PlayerState)
    func playerStateDidUpgradeFreeze(_ state: PlayerState)
    
    // Special Skills
    func playerStateDidActivateHelpingHand(_ state: PlayerState)
    func playerStateDidDeactivateHelpingHand() /// to disable UI effects
    func playerStateDidActivateReinforcedArrow(_ state: PlayerState)
    func playerStateDidActivateSpectralShield(_ state: PlayerState)
    func playerStateDidDeactivateSpectralShield() /// to disable UI effects
    func playerStateDidActivateMightyKnockback(_ state: PlayerState)
    func playerStateDidActivateBonusHealth(_ state: PlayerState, restorePercentage: Double)
}


/// We'll need to make an instance of PlayerState in our ZPGameScene to keep track of these values that are relevant to the player and the Skill Manager
/// Then, we will set ZPGameScene as the delegate
///    [put this with the rest of the variables at the top of ZPGameScene] var playerState = PlayerState()
///    [(probably put this in didMove()] playerState.delegate = self
class PlayerState {
    weak var delegate: PlayerStateDelegate?
    
    var baseDamage: Double = 1
    var baseAttackSpeed: Double = 1.0
    var baseMovementSpeed: Double = 100.0
    var baseRange: Double = 200.0
    var baseMaxHealth: Double = 3.0
    var baseCoinRadius: Double = 50.0

    // Derived stats after skill application:
    var currentDamage: Double = 0
    var currentAttackSpeed: Double = 0
    var currentMovementSpeed: Double = 0
    var currentRange: Double = 0
    var currentMaxHealth: Double = 0
    var currentCoinRadius: Double = 0
    
    // Spinning blades properties
    var spinningBladesCount: Int = 0
    var spinningBladesDamage: Int = 0
    var spinningBladesSpeed: Double = 0.0
    
    // Protective Barrier
    var barrierSize: Double = 0.0
    var barrierDamage: Int = 0
    var barrierPulseFrequency: Double = 0.0
    var barrierSlowAmount: Double = 0.0

    // Freeze Grenade
    var freezeGrenadeCooldown: Double = 0.0
    var freezeDuration: Double = 0.0
    var freezeRadius: Double = 0.0
    
    // Special Skills On/Off
    var hasHelpingHand: Bool = false          // If true, extra projectile logic in scene
    var projectilesPierce: Bool = false       // If true, Reinforced Arrow effect
    var spectralShieldActive: Bool = false    // If true, a shield should appear around player
    var mightyKnockbackActive: Bool = false   // If true, every X seconds we push enemies away

    // This is called every time a new skill is added.
    // It is a refresh to make sure the increments don't stack
    func resetToBaseStats() {
        // Reset Base Stats
        currentDamage = baseDamage
        currentAttackSpeed = baseAttackSpeed
        currentMovementSpeed = baseMovementSpeed
        currentRange = baseRange
        currentMaxHealth = baseMaxHealth
        currentCoinRadius = baseCoinRadius
        
        // Reset Regular Skill Properties
        spinningBladesCount = 0
        spinningBladesDamage = 0
        spinningBladesSpeed = 0.0
        
        barrierSize = 0.0
        barrierDamage = 0
        barrierPulseFrequency = 0.0
        barrierSlowAmount = 0.0

        freezeGrenadeCooldown = 0.0
        freezeDuration = 0.0
        freezeRadius = 0.0
        
        // Reset Special Skill Flags
        hasHelpingHand = false
        delegate?.deactivateHelpingHand()
        projectilesPierce = false
        spectralShieldActive = false
        delegate?.deactivateSpectralShield()
        mightyKnockbackActive = false
    }
    
    
    // MARK: Regular Skills
    func addSpinningBlades(count: Int, damage: Int, speed: Double) {
        spinningBladesCount += count
        spinningBladesDamage += damage
        spinningBladesSpeed += speed

        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidAddSpinningBlades(self)
    }
    
    func upgradeBarrier(sizeIncrement: Double, damageIncrement: Int, pulseFrequencyIncrement: Double, slowAmountIncrement: Double) {
        barrierSize += sizeIncrement
        barrierDamage += damageIncrement
        barrierPulseFrequency += pulseFrequencyIncrement
        barrierSlowAmount += slowAmountIncrement
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidUpgradeBarrier(self)
    }

    func upgradeHealth(by amount: Double, restorePercentage: Double) {
        currentMaxHealth += amount
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidUpgradeHealth(self, restorePercentage: restorePercentage)
    }

    func upgradeMagnet(by amount: Double) {
        currentCoinRadius += amount
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidUpgradeMagnet(self)
    }

    func upgradeFreeze(cooldownReduction: Double, durationIncrement: Double, radiusIncrement: Double) {
        freezeGrenadeCooldown += cooldownReduction
        freezeDuration += durationIncrement
        freezeRadius += radiusIncrement
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidUpgradeFreeze(self)
    }
    
    // MARK: Special Skills
    func activateHelpingHand() {
        hasHelpingHand = true
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidActivateHelpingHand(self)
    }

    func activateReinforcedArrow() {
        projectilesPierce = true
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidActivateReinforcedArrow(self)
    }

    func activateSpectralShield() {
        spectralShieldActive = true
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidActivateSpectralShield(self)
    }

    func activateMightyKnockback() {
        mightyKnockbackActive = true
        
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidActivateMightyKnockback(self)
    }
    
    // MARK: Bonus "Skills"
    func activateBonusHealth() {
        // Calls to logic in GameScene relating to this skill
        delegate?.playerStateDidActivateBonusHealth(self, restorePercentage: 0.5)
    }
}
