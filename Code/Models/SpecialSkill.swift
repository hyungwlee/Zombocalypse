//
//  SpecialSkill.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/5/24.
//


class SpecialSkill {
    let type: SkillType
    var isActive: Bool = false

    init(type: SkillType) {
        self.type = type
    }

    func activate() {
        isActive = true
    }

    func apply(to player: PlayerState) {
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
