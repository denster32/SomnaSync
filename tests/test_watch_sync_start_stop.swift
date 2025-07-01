#!/usr/bin/env swift
import Foundation

class MockWatchManager {
    private(set) var backgroundSyncStarted = false

    func startWatchDependentServices() {
        backgroundSyncStarted = true
    }

    func stopWatchDependentServices() {
        backgroundSyncStarted = false
    }
}

let manager = MockWatchManager()
manager.startWatchDependentServices()
assert(manager.backgroundSyncStarted)
manager.stopWatchDependentServices()
assert(!manager.backgroundSyncStarted)
print("Test passed")
