import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - Background Health Analysis Support
    
    func fetchQuantitySamples(for dataType: HKQuantityTypeIdentifier, startDate: Date, endDate: Date) async -> [HKQuantitySample] {
        guard let healthStore = healthStore else {
            Logger.error("HealthKit store not available", log: Logger.health)
            return []
        }
        
        let quantityType = HKQuantityType.quantityType(forIdentifier: dataType)
        guard let quantityType = quantityType else {
            Logger.error("Invalid quantity type: \(dataType.rawValue)", log: Logger.health)
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        do {
            let samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: quantityType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let quantitySamples = samples as? [HKQuantitySample] ?? []
                        continuation.resume(returning: quantitySamples)
                    }
                }
                healthStore.execute(query)
            }
            
            Logger.info("Fetched \(samples.count) samples for \(dataType.rawValue)", log: Logger.health)
            return samples
            
        } catch {
            Logger.error("Failed to fetch samples for \(dataType.rawValue): \(error.localizedDescription)", log: Logger.health)
            return []
        }
    }
    
    func fetchAllHealthData(startDate: Date, endDate: Date) async -> [String: [HKQuantitySample]] {
        let dataTypes: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .heartRateVariabilitySDNN,
            .respiratoryRate,
            .oxygenSaturation,
            .bodyTemperature,
            .stepCount,
            .activeEnergyBurned,
            .restingHeartRate,
            .bodyMass,
            .bodyFatPercentage,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bloodGlucose,
            .mindfulSession
        ]
        
        var allData: [String: [HKQuantitySample]] = [:]
        
        for dataType in dataTypes {
            let samples = await fetchQuantitySamples(for: dataType, startDate: startDate, endDate: endDate)
            allData[dataType.rawValue] = samples
        }
        
        Logger.info("Fetched health data for \(allData.count) data types", log: Logger.health)
        return allData
    }
    
    func fetchSleepAnalysis(startDate: Date, endDate: Date) async -> [HKCategorySample] {
        guard let healthStore = healthStore else {
            Logger.error("HealthKit store not available", log: Logger.health)
            return []
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        guard let sleepType = sleepType else {
            Logger.error("Sleep analysis type not available", log: Logger.health)
            return []
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        do {
            let samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        let categorySamples = samples as? [HKCategorySample] ?? []
                        continuation.resume(returning: categorySamples)
                    }
                }
                healthStore.execute(query)
            }
            
            Logger.info("Fetched \(samples.count) sleep analysis samples", log: Logger.health)
            return samples
            
        } catch {
            Logger.error("Failed to fetch sleep analysis: \(error.localizedDescription)", log: Logger.health)
            return []
        }
    }
}

// MARK: - NEW: Supporting Classes and Structures

struct SleepPattern {
    let id: UUID
    let type: SleepPatternType
    let frequency: Float
    let duration: TimeInterval
    let quality: Float
    let confidence: Float
}

enum SleepPatternType {
    case consistent
    case irregular
    case shortSleep
    case longSleep
    case poorQuality
    case goodQuality
}

struct BiometricTrends {
    let heartRateTrend: TrendDirection
    let hrvTrend: TrendDirection
    let respiratoryRateTrend: TrendDirection
    let correlationMatrix: [String: Float]
}

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

struct HealthInsight {
    let type: InsightType
    let title: String
    let description: String
    let severity: InsightSeverity
    let data: [String: Any]
}

enum InsightType {
    case sleep
    case biometric
    case recovery
    case stress
    case prediction
    case correlation
}

enum InsightSeverity {
    case info
    case warning
    case critical
    case success
}

struct SleepPrediction {
    let expectedQuality: Float
    let expectedDuration: TimeInterval
    let confidence: Float
    let factors: [String: Float]
}

enum RecoveryStatus {
    case poor
    case fair
    case good
    case excellent
    case unknown
}

enum StressLevel {
    case low
    case moderate
    case high
}

enum SleepQualityTrend {
    case improving
    case declining
    case stable
}

struct HealthSummary {
    let healthScore: Float
    let recoveryStatus: RecoveryStatus
    let stressLevel: StressLevel
    let sleepQualityTrend: SleepQualityTrend
    let insights: [HealthInsight]
    let predictions: SleepPrediction?
}

struct BiometricSummary {
    let heartRate: Double
    let hrv: Double
    let respiratoryRate: Double
    let trends: BiometricTrends?
}

// MARK: - Production-Grade Health Data Analysis Classes

// --- SleepPatternAnalyzer: Real Sleep Pattern Recognition ---
class SleepPatternAnalyzer {
    private var patternHistory: [SleepPattern] = []
    private let analysisWindow: TimeInterval = 7 * 24 * 3600 // 7 days
    
    func identifyPatterns(_ sleepData: [SleepSession]) async -> [SleepPattern] {
        var patterns: [SleepPattern] = []
        
        // Group sleep sessions by week
        let weeklyGroups = groupSessionsByWeek(sleepData)
        
        for (weekStart, sessions) in weeklyGroups {
            let pattern = analyzeWeeklyPattern(sessions, weekStart: weekStart)
            patterns.append(pattern)
        }
        
        // Update pattern history
        patternHistory = patterns
        
        return patterns
    }
    
    func analyzeQualityTrend(_ sleepData: [SleepSession]) async -> SleepQualityTrend {
        guard sleepData.count >= 7 else { return .stable }
        
        // Calculate quality scores for recent sessions
        let recentSessions = Array(sleepData.suffix(7))
        let qualityScores = recentSessions.map { calculateQualityScore($0) }
        
        // Calculate trend using linear regression
        let trend = calculateLinearTrend(qualityScores)
        
        if trend > 0.05 {
            return .improving
        } else if trend < -0.05 {
            return .declining
        } else {
            return .stable
        }
    }
    
