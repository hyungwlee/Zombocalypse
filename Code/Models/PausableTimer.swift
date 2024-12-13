//
//  PausableTimer.swift
//  Zombocalypse
//
//  
//

import Foundation
import QuartzCore

class PausableTimer {
    private var timer: Timer?
    private var interval: TimeInterval
    private var repeats: Bool
    public var callback: () -> Void
    private var remainingTime: TimeInterval
    private var startTime: TimeInterval?
    
    init(interval: TimeInterval, repeats: Bool, callback: @escaping () -> Void) {
        self.interval = interval
        self.repeats = repeats
        self.callback = callback
        self.remainingTime = interval
    }
    
    func start() {
        startTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: repeats) { [weak self] _ in
            self?.callback()
            if self?.repeats == false {
                self?.invalidate()
            }
        }
    }
    
    func pause() {
        guard let startTime = startTime, timer != nil else { return }
        remainingTime -= CACurrentMediaTime() - startTime
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        guard timer == nil, remainingTime > 0 else { return }
        startTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: repeats) { [weak self] _ in
            self?.callback()
            if self?.repeats == false {
                self?.invalidate()
            }
        }
    }
    
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
