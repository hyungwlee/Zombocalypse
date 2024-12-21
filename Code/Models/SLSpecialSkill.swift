//
//  SLSpecialSkill.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/5/24.
//


class SLSpecialSkill {
    let type: SLSkillType
    var isActive: Bool = false

    init(type: SLSkillType) {
        self.type = type
    }

    func activate() {
        isActive = true
    }

    func apply(to player: SLPlayerState) {
        guard isActive else { return }
        
        switch type {
        case .helpingHand:
            player.activateHelpingHand()

        case .reinforcedArrow:
            player.activateReinforcedArrow()

        case .spectralShield:
            player.activateSpectralShield()

        case .mightyKnockback:
            player.activateMightyKnockback()
            
        case .bonusHealth:
            player.activateBonusHealth()

        default:
            break
        }
    }
}
