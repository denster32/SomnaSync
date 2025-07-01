#!/usr/bin/env swift
import Foundation

// Regression test for issue: volume fails to update when immediate change occurs with auto-change mode enabled.

class MockAudioEngine {
    var volume: Float = 0.5
    var autoChangeEnabled: Bool = true

    // Simulates volume update logic with a known bug.
    func setVolume(_ newVolume: Float, immediate: Bool) {
        if autoChangeEnabled && immediate {
            // BUG: Volume should update immediately but does not.
            return
        }
        volume = newVolume
    }
}

let engine = MockAudioEngine()
engine.autoChangeEnabled = true
engine.setVolume(0.8, immediate: true)

// Expected: volume should update to 0.8 when auto-change mode is on
if engine.volume != 0.8 {
    print("Test failed: volume did not update correctly when auto-change mode is enabled")
    exit(1)
}
print("Test passed")
