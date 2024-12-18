//
//  SkillManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/5/24.
//

enum SkillType {
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
            return "sk_attack_damage"
        case .attackSpeed:
            return "sk_attack_speed"
        case .movementSpeed:
            return "sk_movement_speed"
        case .attackRange:
            return "sk_attack_range"
        case .spinningBlades:
            return "sk_spinning_blades"
        case .protectiveBarrier:
            return "sk_protective_barrier"
        case .healthUpgrade:
            return "sk_health_up"
        case .magnet:
            return "sk_xp_magnet"
        case .freeze:
            return "sk_freeze_grenade"
        case .helpingHand:
            return "sk_helping_hand"
        case .reinforcedArrow:
            return "sk_reinforced_arrow"
        case .spectralShield:
            return "sk_spectral_shield"
        case .mightyKnockback:
            return "sk_mighty_knockback"
        case .bonusHealth:
            return "sk_bonus_health"
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
struct SkillLevelEffect {
    var damageIncrement: Double = 0.0
    var attackSpeedIncrement: Double = 0.0
    var movementSpeedIncrement: Double = 0.0
    var rangeIncrement: Double = 0.0

    // Special Skills may need adjusted or additional fields:
    var bladeCountIncrement: Int = 0
    var bladeDamageIncrement: Double = 0.0
    var bladeSpeedIncrement: Double = 0.0

    var barrierSizeIncrement: Double = 0.0
    var barrierDamageFactor: Double = 0.0
    var barrierPulseFrequencyIncrement: Double = 0.0
    var barrierSlowAmountIncrement: Double = 0.0

    var healthIncrement: Double = 0.0
    var coinRadiusIncrement: Double = 0.0

    var freezeGrenadeCooldownReduction: Double = 0.0
    var freezeDurationIncrement: Double = 0.0
    var freezeRadiusIncrement: Double = 0.0
}

struct SkillDefinition {
    let type: SkillType
    let maxLevel: Int
    let levelEffects: [SkillLevelEffect]
    
    // For special skills, maxLevel = 1 and levelEffects[0] can represent the base effect.
    // If you have no incremental stats, you could store minimal data here and handle logic directly in the skill’s apply method.
}

class SkillManager {
    var player: PlayerState
    var allRegularDefinitions: [SkillDefinition] = []
    var allSpecialTypes: [SkillType] = [.helpingHand, .reinforcedArrow, .spectralShield, .mightyKnockback]

    var ownedRegularSkills: [RegularSkill] = []
    var ownedSpecialSkills: [SpecialSkill] = []

    init(player: PlayerState) {
        self.player = player
        setupSkillDefinitions()
    }

    /// Called when opening the shop
    /// Returns 3 random regular choices
    func getRandomRegularChoices() -> [RegularSkill] {
        // find definition of regular skill in allRegularDefinitions
        var available = allRegularDefinitions.compactMap { def -> RegularSkill? in
            // Check if we already own this skill
            if let owned = ownedRegularSkills.first(where: { $0.definition.type == def.type }) {
                return owned.isMaxed ? nil : owned
            } else {
                // Not owned yet, create a new instance of the skill at level 0
                return RegularSkill(definition: def)
            }
        }
        if available.count < 3 {
            for _ in available.count ..< 3 {
                available.append(RegularSkill(definition: SkillDefinition(type: .bonusHealth, maxLevel: 1, levelEffects: [SkillLevelEffect(healthIncrement: 0.0)])))
            }
        }
        return Array(available.shuffled().prefix(3))
    }

    /// Called when tapping on a regular skill in shop
    /// Adds the regular skill at level 1, or upgrades it
    func acquireOrUpgradeRegularSkill(_ skill: RegularSkill) {
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
    func getRandomSpecialSkill() -> SkillType? {
        return allSpecialTypes.randomElement()
    }
    
    /// Returns all available special skills in the pool
    func getAvailableSpecialSkills() -> [SkillType] {
        return allSpecialTypes
    }

    /// Called when tapping on a special skill in shop
    /// Adds the special skill
    func acquireSpecialSkill(_ type: SkillType) {
        let special = SpecialSkill(type: type)
        special.activate()
        ownedSpecialSkills.append(special)
        reapplyAllSkills()

        // Remove skill from the available pool and replace it with bonusScore or bonusHealth
        if let index = allSpecialTypes.firstIndex(of: type) {
            allSpecialTypes.remove(at: index)
            allSpecialTypes.append(SkillType.bonusHealth)
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
    
    func createRegularSkillInstance(for type: SkillType) -> RegularSkill? {
        // Check if the skill type is a regular skill
        if let definition = allRegularDefinitions.first(where: { $0.type == type }) {
            return RegularSkill(definition: definition)
        }
        
        // If the skill type is not found in either category, return nil
        return nil
    }
    
    func createSpecialSkillInstance(for type: SkillType) -> SpecialSkill? {
        // Check if the skill type is a special skill
        if allSpecialTypes.contains(type) {
            return SpecialSkill(type: type)
        }
        
        // If the skill type is not found in either category, return nil
        return nil
    }
}


// MARK: Extended this just to stay organized
extension SkillManager {
    
    /// Hard code the definitions/characteristics of every skill in the SkillDefinition format
    private func setupSkillDefinitions() {
        // MARK: Base Stat Upgrade Regular Skills (4 Skills)
        // 1. Attack Damage
        allRegularDefinitions.append(
            SkillDefinition(
                type: .attackDamage,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(damageIncrement: 1.5),
                    SkillLevelEffect(damageIncrement: 2),
                    SkillLevelEffect(damageIncrement: 2.5),
                    SkillLevelEffect(damageIncrement: 3)
                ]
            )
        )
        
        // 2. Attack Speed
        allRegularDefinitions.append(
            SkillDefinition(
                type: .attackSpeed,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(attackSpeedIncrement: 0.1),
                    SkillLevelEffect(attackSpeedIncrement: 0.15),
                    SkillLevelEffect(attackSpeedIncrement: 0.2),
                    SkillLevelEffect(attackSpeedIncrement: 0.25)
                ]
            )
        )

        // 3. Movement Speed
        allRegularDefinitions.append(
            SkillDefinition(
                type: .movementSpeed,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(movementSpeedIncrement: 0.1),
                    SkillLevelEffect(movementSpeedIncrement: 0.15),
                    SkillLevelEffect(movementSpeedIncrement: 0.2),
                    SkillLevelEffect(movementSpeedIncrement: 0.3)
                ]
            )
        )

        // 4. Attack Range
        allRegularDefinitions.append(
            SkillDefinition(
                type: .attackRange,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(rangeIncrement: 50),
                    SkillLevelEffect(rangeIncrement: 75),
                    SkillLevelEffect(rangeIncrement: 100),
                    SkillLevelEffect(rangeIncrement: 150)
                ]
            )
        )

        // MARK: "Complex" Regular Skills (5 Skills)
        // 1. Spinning Blades
        /// Each upgrade increases all values
        allRegularDefinitions.append(
            SkillDefinition(
                type: .spinningBlades,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(bladeCountIncrement: 1, bladeDamageIncrement: 2, bladeSpeedIncrement: 0.1),
                    SkillLevelEffect(bladeCountIncrement: 2, bladeDamageIncrement: 3, bladeSpeedIncrement: 0.15),
                    SkillLevelEffect(bladeCountIncrement: 3, bladeDamageIncrement: 4, bladeSpeedIncrement: 0.2),
                    SkillLevelEffect(bladeCountIncrement: 4, bladeDamageIncrement: 5, bladeSpeedIncrement: 0.3)
                ]
            )
        )

        // 2. Protective Barrier
        /// Each upgrade increases all values
        allRegularDefinitions.append(
            SkillDefinition(
                type: .protectiveBarrier,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(barrierSizeIncrement: 40, barrierDamageFactor: 0.2, barrierPulseFrequencyIncrement: 0.1, barrierSlowAmountIncrement: 0.05),
                    SkillLevelEffect(barrierSizeIncrement: 15, barrierDamageFactor: 0.5, barrierPulseFrequencyIncrement: 0.15, barrierSlowAmountIncrement: 0.1),
                    SkillLevelEffect(barrierSizeIncrement: 20, barrierDamageFactor: 0.8, barrierPulseFrequencyIncrement: 0.2, barrierSlowAmountIncrement: 0.15),
                    SkillLevelEffect(barrierSizeIncrement: 30, barrierDamageFactor: 1.2, barrierPulseFrequencyIncrement: 0.25, barrierSlowAmountIncrement: 0.2)
                ]
            )
        )

        // 3. Health Upgrade
        /// Each upgrade adds +0.5 max health. Full restore logic handled by PlayerState method.
        allRegularDefinitions.append(
            SkillDefinition(
                type: .healthUpgrade,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(healthIncrement: 0.5),
                    SkillLevelEffect(healthIncrement: 1.0),
                    SkillLevelEffect(healthIncrement: 1.5),
                    SkillLevelEffect(healthIncrement: 2.5)
                ]
            )
        )

        // 4. Magnet
        /// Each level further increases coin pickup radius
        allRegularDefinitions.append(
            SkillDefinition(
                type: .magnet,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(coinRadiusIncrement: 25),
                    SkillLevelEffect(coinRadiusIncrement: 25),
                    SkillLevelEffect(coinRadiusIncrement: 25),
                    SkillLevelEffect(coinRadiusIncrement: 25)
                ]
            )
        )

        // 5. Freeze
        /// Improves grenade cooldown, freeze duration, and radius
        allRegularDefinitions.append(
            SkillDefinition(
                type: .freeze,
                maxLevel: 4,
                levelEffects: [
                    SkillLevelEffect(freezeGrenadeCooldownReduction: 0.1, freezeDurationIncrement: 2.5, freezeRadiusIncrement: 25),
                    SkillLevelEffect(freezeGrenadeCooldownReduction: 0.15, freezeDurationIncrement: 3.5, freezeRadiusIncrement: 30),
                    SkillLevelEffect(freezeGrenadeCooldownReduction: 0.2, freezeDurationIncrement: 4.0, freezeRadiusIncrement: 40),
                    SkillLevelEffect(freezeGrenadeCooldownReduction: 0.3, freezeDurationIncrement: 5.0, freezeRadiusIncrement: 50)
                ]
            )
        )
    }
    
}
