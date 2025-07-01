import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - Biometric Data Collection
    func startBiometricMonitoring() {
        guard isAuthorized else {
            Logger.error("HealthKit not authorized", log: Logger.healthKit)
            return
        }
        Logger.info("Starting biometric monitoring", log: Logger.healthKit)
        // Initialize biometric data if needed
        if biometricData == nil {
            biometricData = BiometricData()
        }
        startHeartRateMonitoring()
        startHRVMonitoring()
        startMovementMonitoring()
    }
    
    func stopBiometricMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = hrvQuery {
            healthStore.stop(query)
            hrvQuery = nil
        }
        if let query = movementQuery {
            healthStore.stop(query)
            movementQuery = nil
        }
        Logger.info("Stopped biometric monitoring", log: Logger.healthKit)
    }
    
    // MARK: - Heart Rate Monitoring
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { query, samples, deletedObjects, anchor, error in
            self.processHeartRateSamples(samples)
        }
        
        query.updateHandler = { query, samples, deletedObjects, anchor, error in
            self.processHeartRateSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        let latestSample = samples.last
        let heartRate = latestSample?.quantity.doubleValue(for: HKUnit(from: "count/min")) ?? 0
        
        self.biometricData?.heartRate = heartRate
        self.lastUpdated = Date()
    }
    
    // MARK: - HRV Monitoring
    private func startHRVMonitoring() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let query = HKAnchoredObjectQuery(type: hrvType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { query, samples, deletedObjects, anchor, error in
            self.processHRVSamples(samples)
        }
        
        query.updateHandler = { query, samples, deletedObjects, anchor, error in
            self.processHRVSamples(samples)
        }
        
        hrvQuery = query
        healthStore.execute(query)
    }
    
    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        let latestSample = samples.last
        let hrv = latestSample?.quantity.doubleValue(for: HKUnit(from: "ms")) ?? 0
        
        self.biometricData?.hrv = hrv
        self.lastUpdated = Date()
    }
    
    // MARK: - Movement Monitoring
    private func startMovementMonitoring() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { query, statistics, error in
            self.processMovementData(statistics)
        }
        
        movementQuery = query
        healthStore.execute(query)
    }
    
    private func processMovementData(_ statistics: HKStatistics?) {
        let steps = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
        
        self.biometricData?.movement = steps
        self.lastUpdated = Date()
    }
    
    // MARK: - Sleep Data Management
    func saveSleepSession(_ session: SleepSession) async {
        guard isAuthorized else {
            Logger.error("HealthKit not authorized", log: Logger.healthKit)
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepSample = HKCategorySample(
            type: sleepType,
            value: session.sleepStage.rawValue,
            start: session.startTime,
            end: session.endTime,
            metadata: [
                "duration": session.duration,
                "quality": session.quality,
                "cycles": session.cycleCount
            ]
        )
        
        do {
            try await healthStore.save(sleepSample)
            Logger.success("Sleep session saved to HealthKit", log: Logger.healthKit)
        } catch {
            Logger.error("Failed to save sleep session: \(error.localizedDescription)", log: Logger.healthKit)
        }
    }
    
    // MARK: - Data Retrieval
    func fetchSleepData(from startDate: Date, to endDate: Date) async -> [SleepSession] {
        guard isAuthorized else { return [] }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        do {
            let samples = try await healthStore.samples(of: sleepType, predicate: predicate, sortDescriptors: [sortDescriptor])
            Logger.info("Fetched \(samples.count) sleep data samples from HealthKit", log: Logger.healthKit)
            return samples.compactMap { sample in
                guard let categorySample = sample as? HKCategorySample else { return nil }
                return SleepSession(from: categorySample)
            }
        } catch {
            Logger.error("Failed to fetch sleep data: \(error.localizedDescription)", log: Logger.healthKit)
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAvailability() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        if !isAvailable {
            Logger.warning("HealthKit is not available on this device", log: Logger.healthKit)
        }
    }
    
    private func checkAuthorizationStatus() async {
        guard isAvailable else { return }
        
        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: nil, read: requiredTypes)
            
            await MainActor.run {
                isAuthorized = status == .sharingAuthorized
                
                // Check individual permissions
                checkIndividualPermissions()
            }
            
            Logger.info("HealthKit authorization status: \(status.rawValue)", log: Logger.healthKit)
        } catch {
            Logger.error("Failed to check authorization status: \(error.localizedDescription)", log: Logger.healthKit)
        }
    }
    
    private func checkIndividualPermissions() {
        // Check each permission individually
        heartRatePermission = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRate)!) == .sharingAuthorized
        hrvPermission = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!) == .sharingAuthorized
        respiratoryRatePermission = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .respiratoryRate)!) == .sharingAuthorized
        sleepAnalysisPermission = healthStore.authorizationStatus(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!) == .sharingAuthorized
        oxygenSaturationPermission = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!) == .sharingAuthorized
        bodyTemperaturePermission = healthStore.authorizationStatus(for: HKObjectType.quantityType(forIdentifier: .bodyTemperature)!) == .sharingAuthorized
    }
    
    private func fetchHeartRateData() async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKQuantitySample] {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepAnalysisData() async throws -> [HKCategorySample] {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKCategorySample] {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchBiometricData() async throws -> [String: [HKQuantitySample]] {
        var biometricData: [String: [HKQuantitySample]] = [:]
        
        // Fetch HRV data
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let hrvData = try await fetchQuantityData(for: hrvType)
        biometricData["hrv"] = hrvData
        
        // Fetch respiratory rate data
        let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        let respiratoryData = try await fetchQuantityData(for: respiratoryType)
        biometricData["respiratory"] = respiratoryData
        
        // Fetch oxygen saturation data
        let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let oxygenData = try await fetchQuantityData(for: oxygenType)
        biometricData["oxygen"] = oxygenData
        
        // Fetch body temperature data
        let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!
        let temperatureData = try await fetchQuantityData(for: temperatureType)
        biometricData["temperature"] = temperatureData
        
        return biometricData
    }
    
    private func fetchQuantityData(for quantityType: HKQuantityType) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKQuantitySample] {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func processHealthData(heartRate: [HKQuantitySample], sleep: [HKCategorySample], biometric: [String: [HKQuantitySample]]) async {
        // Process and store the health data
        // This would typically involve saving to Core Data or other local storage
        
        Logger.info("Processed \(heartRate.count) heart rate samples, \(sleep.count) sleep samples", log: Logger.healthKit)
        
        // Update the sleep manager with new data
        await SleepManager.shared.updateWithHealthData(heartRate: heartRate, sleep: sleep, biometric: biometric)
    }
    
