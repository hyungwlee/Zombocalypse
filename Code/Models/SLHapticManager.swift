//
//  SLHapticManager.swift
//  Zombocalypse
//
//  Created by Sam Richard on 12/20/24.
//


import UIKit
import CoreHaptics

class SLHapticManager {
    static let shared = SLHapticManager()
    
    private var hapticEngine: CHHapticEngine?
    
    private init() {
        prepareHapticEngine()
    }
    
    // MARK: - Simple Haptics
    func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func triggerNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    func triggerSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Core Haptics
    private func prepareHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    func triggerExplosionHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        
        let explosion = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
        
        let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
        ], relativeTime: 0.1, duration: 0.4)
        
        do {
            let pattern = try CHHapticPattern(events: [explosion, rumble], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play explosion haptic: \(error)")
        }
    }
    
    func stopHaptics() {
        hapticEngine?.stop(completionHandler: { error in
            if let error = error {
                print("Error stopping haptic engine: \(error)")
            }
        })
    }
}
