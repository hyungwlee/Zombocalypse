//
//  SLSoundManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/20/24.
//


import AVFoundation

enum SLSoundEffect: String {
    
    case openShop = "sl_open_shop"
    case openSpinner = "sl_open_spinner"
    case buttonPress = "sl_button_press"
    case horn = "sl_horde_horn"
    
    case arrowShot = "sl_arrow"
    case playerDamage = "sl_player_damage"
    
    case freezeSound = "sl_freeze_sound"
    case grenadeToss = "sl_grenade_toss"
    case helpingHand = "sl_helping_hand"
    case knockback = "sl_knockback"
    case shieldBreak = "sl_shield_break"
    
    case bossAlarm = "sl_boss_alarm"
    case wizardSpawn = "sl_wizard_spawn"
    case laserFiring = "sl_laser_firing"
    

    
    case gameOver = "sl_game_over"
    
    
    var fileExtension: String {
        return "mp3" // Default file extension
    }
}

class SLSoundManager {
    static let shared = SLSoundManager()
    
    private var soundEffects: [SLSoundEffect: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?

    private init() {}
    
    // MARK: - Play Sound Effect
    func playSoundEffect(_ soundEffect: SLSoundEffect) {
        if let player = soundEffects[soundEffect] {
            player.stop()
            player.currentTime = 0
            player.play()
        } else if let url = Bundle.main.url(forResource: soundEffect.rawValue, withExtension: soundEffect.fileExtension) {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                soundEffects[soundEffect] = player
                player.play()
            } catch {
                print("Failed to play sound effect: \(soundEffect.rawValue). Error: \(error)")
            }
        }
    }
    
    // MARK: - Stop Sound Effect
    func stopSoundEffect(_ soundEffect: SLSoundEffect) {
        if let player = soundEffects[soundEffect] {
            player.stop()
        }
    }

    // MARK: - Play Background Music
    func playBackgroundMusic(named fileName: String, withExtension fileExtension: String = "mp3", loop: Bool = true) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            do {
                musicPlayer = try AVAudioPlayer(contentsOf: url)
                musicPlayer?.numberOfLoops = loop ? -1 : 0
                musicPlayer?.volume = 0.5
                musicPlayer?.prepareToPlay()
                musicPlayer?.play()
            } catch {
                print("Failed to play background music: \(fileName). Error: \(error)")
            }
        }
    }

    // MARK: - Stop Background Music
    func stopBackgroundMusic() {
        musicPlayer?.stop()
    }
    
    // MARK: - Pause and Resume Background Music
    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        musicPlayer?.play()
    }
    
    // MARK: - Adjust Volume
    func setBackgroundMusicVolume(_ volume: Float) {
        musicPlayer?.volume = volume
    }
    
    func setSoundEffectVolume(_ soundEffect: SLSoundEffect, volume: Float) {
        soundEffects[soundEffect]?.volume = volume
    }
}
