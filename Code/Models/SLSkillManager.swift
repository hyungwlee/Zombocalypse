//
//  SLSkillManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/5/24.
//

enum SLSkillType {
    // Base Stat Upgrade Regular Skills
    case attackDamage          // Increases player's damage output
    case attackSpeed           // Increases the rate of attack
    case movementSpeed         // Increases movement velocity
    case attackRange           // Increases projectile or melee range

    // "Better" Regular Skills
    case spinningBlades        // Rotating blades damaging nearby enemies
    case protectiveBarrier     // Damaging, slowing barrier around player
    case healthUpgrade         // Increase total health & restore
    case magnet                // Increases coin pickup radius
    case freeze                // Periodically launch freeze grenade

    // Special Skills (One-level only)
    case helpingHand           // Extra auto-aimed projectile occasionally
    case reinforcedArrow       // Projectiles now pierce
    case spectralShield        // Rotating shield that blocks collisions
    case mightyKnockback       // Periodic knockback effect

    // Post-Special "Bonus" Option (treated like a special skill)
    case bonusHealth
    
    var displayName: String {
        switch self {
        case .attackDamage:
            return "ATTACK DAMAGE"
        case .attackSpeed:
            return "ATTACK SPEED"
        case .movementSpeed:
            return "MOVEMENT SPEED"
        case .attackRange:
            return "ATTACK RANGE"
        case .spinningBlades:
            return "SPINNING BLADES"
        case .protectiveBarrier:
            return "PROTECTIVE BARRIER"
        case .healthUpgrade:
            return "HEALTH UP"
        case .magnet:
            return "XP MAGNET"
        case .freeze:
            return "FREEZE GRENADE"
        case .helpingHand:
            return "HELPING HAND"
        case .reinforcedArrow:
            return "REINFORCED ARROWS"
        case .spectralShield:
            return "SPECTRAL SHIELD"
        case .mightyKnockback:
            return "MIGHTY KNOCKBACK"
        case .bonusHealth:
            return "BONUS HEALTH"
        }
    }
    
    var iconName: String {
        switch self {
        case .attackDamage:
            return "sl_attack_damage"
        case .attackSpeed:
            return "sl_attack_speed"
        case .movementSpeed:
            return "sl_movement_speed"
        case .attackRange:
            return "sl_attack_range"
        case .spinningBlades:
            return "sl_spinning_blades"
        case .protectiveBarrier:
            return "sl_protective_barrier"
        case .healthUpgrade:
            return "sl_health_up"
        case .magnet:
            return "sl_xp_magnet"
        case .freeze:
            return "sl_freeze_grenade"
        case .helpingHand:
            return "sl_helping_hand"
        case .reinforcedArrow:
            return "sl_reinforced_arrow"
        case .spectralShield:
            return "sl_spectral_shield"
        case .mightyKnockback:
            return "sl_mighty_knockback"
        case .bonusHealth:
            return "sl_bonus_health"
        }
    }
    
    var skillDescription: String {
        switch self {
        case .attackDamage:
            return "Increase main weapon attack damage."
        case .attackSpeed:
            return "Conquer your foes even more swiftly."
        case .movementSpeed:
            return "Better off running than fighting... right?"
        case .attackRange:
            return "Boost your base attack radius."
        case .spinningBlades:
            return "Spinning death circling around you!"
        case .protectiveBarrier:
            return "Damages and slows all who near."
        case .healthUpgrade:
            return "Restores health and boosts capacity."
        case .magnet:
            return "Increase xp pickup radius."
        case .freeze:
            return "Stop enemies cold... literally!"
        case .helpingHand:
            return "A trusty companion firing on your behalf."
        case .reinforcedArrow:
            return "Projectiles pierce through enemies."
        case .spectralShield:
            return "A mystical shield that blocks attacks."
        case .mightyKnockback:
            return "Forcefully repel approaching foes."
        case .bonusHealth:
            return "A well deserved top-up."
        }
    }
}

/// This should be all fields adjusted by upgrading regular skills
struct SLSkillLevelEffect {
    var damageIncrement: Double = 0.0
    var attackSpeedIncrement: Double = 0.0
    var movementSpeedIncrement: Double = 0.0
    var rangeIncrement: Double = 0.0

    // Special Skills may need adjusted or additional fields:
    var bladeCountIncrement: Int = 0
    var bladeDamageIncrement: Double = 0.0
    var bladeSpeedIncrement: Double = 0.0

    var barrierScaleIncrement: Double = 0.0
    var barrierDamageFactor: Double = 0.0
    var barrierPulseFrequencyIncrement: Double = 0.0
    var barrierSlowAmountIncrement: Double = 0.0

    var healthIncrement: Double = 0.0
    var coinRadiusIncrement: Double = 0.0

    var freezeGrenadeCooldownReduction: Double = 0.0
    var freezeDurationIncrement: Double = 0.0
    var freezeRadiusIncrement: Double = 0.0
}

struct SLSkillDefinition {
    let type: SLSkillType
    let maxLevel: Int
    let levelEffects: [SLSkillLevelEffect]
    
    // For special skills, maxLevel = 1 and levelEffects[0] can represent the base effect.
    // If you have no incremental stats, you could store minimal data here and handle logic directly in the skill’s apply method.
}

class SLSkillManager {
    var player: SLPlayerState
    var allRegularDefinitions: [SLSkillDefinition] = []
    var allSpecialTypes: [SLSkillType] = [.helpingHand, .reinforcedArrow, .spectralShield, .mightyKnockback]

    var ownedRegularSkills: [SLRegularSkill] = []
    var ownedSpecialSkills: [SLSpecialSkill] = []

    init(player: SLPlayerState) {
        self.player = player
        setupSkillDefinitions()
    }

    /// Called when opening the shop
    /// Returns 3 random regular choices
    func getRandomRegularChoices() -> [SLRegularSkill] {
        // find definition of regular skill in allRegularDefinitions
        var available = allRegularDefinitions.compactMap { def -> SLRegularSkill? in
            // Check if we already own this skill
            if let owned = ownedRegularSkills.first(where: { $0.definition.type == def.type }) {
                return owned.isMaxed ? nil : owned
            } else {
                // Not owned yet, create a new instance of the skill at level 0
                return SLRegularSkill(definition: def)
            }
        }
        if available.count < 3 {
            for _ in available.count ..< 3 {
                available.append(SLRegularSkill(definition: SLSkillDefinition(type: .bonusHealth, maxLevel: 1, levelEffects: [SLSkillLevelEffect(healthIncrement: 0.0)])))
            }
        }
        return Array(available.shuffled().prefix(3))
    }

    /// Called when tapping on a regular skill in shop
    /// Adds the regular skill at level 1, or upgrades it
    func acquireOrUpgradeRegularSkill(_ skill: SLRegularSkill) {
        if let owned = ownedRegularSkills.first(where: { $0.definition.type == skill.definition.type }) {
            // Already owned, upgrade it
            owned.upgrade()
        } else {
            // Not owned, set level to 1
            skill.upgrade()
            ownedRegularSkills.append(skill)
        }

        reapplyAllSkills()
    }
    
    /// Returns a random special skill choice from the available pool
    func getRandomSpecialSkill() -> SLSkillType? {
        return allSpecialTypes.randomElement()
    }
    
    /// Returns all available special skills in the pool
    func getAvailableSpecialSkills() -> [SLSkillType] {
        return allSpecialTypes
    }

    /// Called when tapping on a special skill in shop
    /// Adds the special skill
    func acquireSpecialSkill(_ type: SLSkillType) {
        let special = SLSpecialSkill(type: type)
        special.activate()
        ownedSpecialSkills.append(special)
        reapplyAllSkills()

        // Remove skill from the available pool and replace it with bonusScore or bonusHealth
        if let index = allSpecialTypes.firstIndex(of: type) {
            allSpecialTypes.remove(at: index)
            allSpecialTypes.append(SLSkillType.bonusHealth)
        }
    }

    /// Calls apply() in each owned special and regular skill
    func reapplyAllSkills() {
        player.resetToBaseStats()
        for skill in ownedRegularSkills {
            skill.apply(to: player)
        }
        for special in ownedSpecialSkills {
            special.apply(to: player)
        }
    }
    
    func createRegularSkillInstance(for type: SLSkillType) -> SLRegularSkill? {
        // Check if the skill type is a regular skill
        if let definition = allRegularDefinitions.first(where: { $0.type == type }) {
            return SLRegularSkill(definition: definition)
        }
        
        // If the skill type is not found in either category, return nil
        return nil
    }
    
    func createSpecialSkillInstance(for type: SLSkillType) -> SLSpecialSkill? {
        // Check if the skill type is a special skill
        if allSpecialTypes.contains(type) {
            return SLSpecialSkill(type: type)
        }
        
        // If the skill type is not found in either category, return nil
        return nil
    }
}


// MARK: Extended this just to stay organized
extension SLSkillManager {
    
    /// Hard code the definitions/characteristics of every skill in the SkillDefinition format
    private func setupSkillDefinitions() {
        // MARK: Base Stat Upgrade Regular Skills (4 Skills)
        // 1. Attack Damage
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .attackDamage,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(damageIncrement: 3),
                    SLSkillLevelEffect(damageIncrement: 5),
                    SLSkillLevelEffect(damageIncrement: 7),
                    SLSkillLevelEffect(damageIncrement: 10)
                ]
            )
        )
        
        // 2. Attack Speed
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .attackSpeed,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(attackSpeedIncrement: 0.1),
                    SLSkillLevelEffect(attackSpeedIncrement: 0.15),
                    SLSkillLevelEffect(attackSpeedIncrement: 0.2),
                    SLSkillLevelEffect(attackSpeedIncrement: 0.25)
                ]
            )
        )

        // 3. Movement Speed
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .movementSpeed,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(movementSpeedIncrement: 15),
                    SLSkillLevelEffect(movementSpeedIncrement: 20),
                    SLSkillLevelEffect(movementSpeedIncrement: 20),
                    SLSkillLevelEffect(movementSpeedIncrement: 25)
                ]
            )
        )

        // 4. Attack Range
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .attackRange,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(rangeIncrement: 50),
                    SLSkillLevelEffect(rangeIncrement: 75),
                    SLSkillLevelEffect(rangeIncrement: 100),
                    SLSkillLevelEffect(rangeIncrement: 150)
                ]
            )
        )

        // MARK: "Complex" Regular Skills (5 Skills)
        // 1. Spinning Blades
        /// Each upgrade increases all values
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .spinningBlades,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(bladeCountIncrement: 1, bladeDamageIncrement: 1, bladeSpeedIncrement: 0.1),
                    SLSkillLevelEffect(bladeCountIncrement: 1, bladeDamageIncrement: 2, bladeSpeedIncrement: 0.15),
                    SLSkillLevelEffect(bladeCountIncrement: 2, bladeDamageIncrement: 3, bladeSpeedIncrement: 0.1),
                    SLSkillLevelEffect(bladeCountIncrement: 2, bladeDamageIncrement: 4, bladeSpeedIncrement: 0.15)
                ]
            )
        )

        // 2. Protective Barrier
        /// Each upgrade increases all values
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .protectiveBarrier,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(barrierScaleIncrement: 1.0, barrierDamageFactor: 0.2, barrierPulseFrequencyIncrement: 0.1, barrierSlowAmountIncrement: 0.1),
                    SLSkillLevelEffect(barrierScaleIncrement: 1.1, barrierDamageFactor: 0.5, barrierPulseFrequencyIncrement: 0.15, barrierSlowAmountIncrement: 0.2),
                    SLSkillLevelEffect(barrierScaleIncrement: 1.2, barrierDamageFactor: 0.8, barrierPulseFrequencyIncrement: 0.2, barrierSlowAmountIncrement: 0.3),
                    SLSkillLevelEffect(barrierScaleIncrement: 1.3, barrierDamageFactor: 1.2, barrierPulseFrequencyIncrement: 0.25, barrierSlowAmountIncrement: 0.4)
                ]
            )
        )

        // 3. Health Upgrade
        /// Each upgrade adds +0.5 max health. Full restore logic handled by PlayerState method.
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .healthUpgrade,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(healthIncrement: 0.5),
                    SLSkillLevelEffect(healthIncrement: 1.0),
                    SLSkillLevelEffect(healthIncrement: 1.5),
                    SLSkillLevelEffect(healthIncrement: 2.5)
                ]
            )
        )

        // 4. Magnet
        /// Each level further increases coin pickup radius
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .magnet,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(coinRadiusIncrement: 5),
                    SLSkillLevelEffect(coinRadiusIncrement: 15),
                    SLSkillLevelEffect(coinRadiusIncrement: 20),
                    SLSkillLevelEffect(coinRadiusIncrement: 30)
                ]
            )
        )

        // 5. Freeze
        /// Improves grenade cooldown, freeze duration, and radius
        allRegularDefinitions.append(
            SLSkillDefinition(
                type: .freeze,
                maxLevel: 4,
                levelEffects: [
                    SLSkillLevelEffect(freezeGrenadeCooldownReduction: 0.1, freezeDurationIncrement: 2.5, freezeRadiusIncrement: 25),
                    SLSkillLevelEffect(freezeGrenadeCooldownReduction: 0.15, freezeDurationIncrement: 3.5, freezeRadiusIncrement: 30),
                    SLSkillLevelEffect(freezeGrenadeCooldownReduction: 0.2, freezeDurationIncrement: 4.0, freezeRadiusIncrement: 40),
                    SLSkillLevelEffect(freezeGrenadeCooldownReduction: 0.3, freezeDurationIncrement: 5.0, freezeRadiusIncrement: 50)
                ]
            )
        )
    }
    
}
