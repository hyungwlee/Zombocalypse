//
//  SLRegularSkill 2.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/20/24.
//


class SLRegularSkill {
    let definition: SLSkillDefinition
    let displayName: String
    private(set) var currentLevel: Int = 0
    

    init(definition: SLSkillDefinition) {
        self.definition = definition
        self.displayName = definition.type.displayName
    }

    var isMaxed: Bool {
        return currentLevel >= definition.maxLevel
    }

    func upgrade() {
        guard currentLevel < definition.maxLevel else { return }
        currentLevel += 1
    }

    func apply(to player: SLPlayerState) {
        guard currentLevel > 0 else { return }
        let effect = definition.levelEffects[currentLevel - 1]
        
        // Apply increments for base regular skills:
        player.currentDamage += effect.damageIncrement
        player.currentAttackSpeed -= effect.attackSpeedIncrement
        player.currentMovementSpeed += effect.movementSpeedIncrement
        player.currentRange += effect.rangeIncrement

        // For more complex regular skills
        switch definition.type {
        case .spinningBlades:
            player.addSpinningBlades(
                count: effect.bladeCountIncrement,
                damage: effect.bladeDamageIncrement,
                speed: effect.bladeSpeedIncrement
            )

        case .protectiveBarrier:
            player.upgradeBarrier(
                sizeIncrement: effect.barrierScaleIncrement,
                damageIncrement: effect.barrierDamageFactor,
                pulseFrequencyIncrement: effect.barrierPulseFrequencyIncrement,
                slowAmountIncrement: effect.barrierSlowAmountIncrement
            )

        case .healthUpgrade:
            player.upgradeHealth(by: effect.healthIncrement, restorePercentage: 1.0)

        case .magnet:
            player.upgradeMagnet(by: effect.coinRadiusIncrement)

        case .freeze:
            player.upgradeFreeze(
                cooldownReduction: effect.freezeGrenadeCooldownReduction,
                durationIncrement: effect.freezeDurationIncrement,
                radiusIncrement: effect.freezeRadiusIncrement
            )

        default:
            // called for simple base regular skills
            break
        }
    }
}
