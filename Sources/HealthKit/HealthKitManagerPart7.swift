import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - Helper Methods
    
    private func calculateSleepConsistency(_ sessions: [SleepSession]) -> Double {
        guard sessions.count > 1 else { return 1.0 }
        
        let startTimes = sessions.map { $0.startTime }
        let sortedTimes = startTimes.sorted()
        
        var timeDifferences: [TimeInterval] = []
        for i in 1..<sortedTimes.count {
            let diff = abs(sortedTimes[i].timeIntervalSince(sortedTimes[i-1]))
            timeDifferences.append(diff)
        }
        
        let avgDifference = timeDifferences.reduce(0, +) / Double(timeDifferences.count)
        return max(0, 1.0 - (avgDifference / (24 * 3600)))
    }
    
    private func calculateBiometricHealth(_ data: [BiometricData]) -> Double {
        guard !data.isEmpty else { return 0.5 }
        
        let heartRates = data.map { $0.heartRate }
        let hrvs = data.map { $0.heartRateVariability }
        let bloodOxygens = data.map { $0.bloodOxygen }
        
        let hrHealth = heartRates.map { hr in
            if hr >= 60 && hr <= 100 { return 1.0 }
            else if hr >= 50 && hr <= 110 { return 0.8 }
            else { return 0.5 }
        }.reduce(0, +) / Double(heartRates.count)
        
        let hrvHealth = hrvs.map { hrv in
            if hrv >= 20 && hrv <= 60 { return 1.0 }
            else if hrv >= 15 && hrv <= 80 { return 0.8 }
            else { return 0.5 }
        }.reduce(0, +) / Double(hrvs.count)
        
        let spo2Health = bloodOxygens.map { spo2 in
            if spo2 >= 95 { return 1.0 }
            else if spo2 >= 90 { return 0.8 }
            else { return 0.3 }
        }.reduce(0, +) / Double(bloodOxygens.count)
        
        return (hrHealth + hrvHealth + spo2Health) / 3.0
    }
    
    private func predictQualityFromPatterns(avgQuality: Double, consistency: Double, biometricHealth: Double) -> Double {
        // Weighted prediction based on historical patterns
        let baseQuality = avgQuality * 0.6
        let consistencyBonus = consistency * 0.2
        let biometricBonus = biometricHealth * 0.2
        
        return min(1.0, baseQuality + consistencyBonus + biometricBonus)
    }
    
    private func predictDurationFromPatterns(avgDuration: TimeInterval, consistency: Double) -> TimeInterval {
        // Predict duration with some variation based on consistency
        let variation = (1.0 - consistency) * 0.5 // Less consistent = more variation
        let predictedDuration = avgDuration * (1.0 + Double.random(in: -variation...variation))
        
        return max(6.0 * 3600, min(10.0 * 3600, predictedDuration)) // 6-10 hours
    }
    
    private func calculatePredictionConfidence(dataPoints: Int, consistency: Double, biometricHealth: Double) -> Double {
        let dataConfidence = min(1.0, Double(dataPoints) / 7.0) // More data = higher confidence
        let consistencyConfidence = consistency
        let biometricConfidence = biometricHealth
        
        return (dataConfidence + consistencyConfidence + biometricConfidence) / 3.0
    }
    
    private func calculateStressLevel(_ data: [BiometricData]) -> Double {
        guard !data.isEmpty else { return 0.5 }
        
        let heartRates = data.map { $0.heartRate }
        let hrvs = data.map { $0.heartRateVariability }
        
        let hrStress = heartRates.map { hr in
            if hr > 80 { return 1.0 }
            else if hr > 70 { return 0.7 }
            else if hr > 60 { return 0.4 }
            else { return 0.2 }
        }.reduce(0, +) / Double(heartRates.count)
        
        let hrvStress = hrvs.map { hrv in
            if hrv < 20 { return 1.0 }
            else if hrv < 30 { return 0.7 }
            else if hrv < 40 { return 0.4 }
            else { return 0.2 }
        }.reduce(0, +) / Double(hrvs.count)
        
        return (hrStress + hrvStress) / 2.0
    }
    
    private func calculateRecoveryStatus(_ sessions: [SleepSession]) -> Double {
        guard !sessions.isEmpty else { return 0.5 }
        
        let recentSessions = Array(sessions.suffix(3))
        let avgDeepSleep = recentSessions.map { $0.deepSleepPercentage }.reduce(0, +) / Double(recentSessions.count)
        let avgQuality = recentSessions.map { $0.sleepQuality }.reduce(0, +) / Double(recentSessions.count)
        
        let deepSleepScore = avgDeepSleep / 100.0
        return (deepSleepScore + avgQuality) / 2.0
    }
}

// --- HealthInsightGenerator: Real Health Insights ---
class HealthInsightGenerator {
    private var insightHistory: [HealthInsight] = []
    
    func generateInsights(_ sleepData: [SleepSession], _ biometricData: [BiometricData], _ patterns: [SleepPattern]) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Sleep quality insights
        insights.append(contentsOf: generateSleepInsights(sleepData))
        
        // Biometric insights
        insights.append(contentsOf: generateBiometricInsights(biometricData))
        
        // Pattern insights
        insights.append(contentsOf: generatePatternInsights(patterns))
        
        // Recovery insights
        insights.append(contentsOf: generateRecoveryInsights(sleepData, biometricData))
        
        // Stress insights
        insights.append(contentsOf: generateStressInsights(biometricData))
        
        insightHistory.append(contentsOf: insights)
        return insights
    }
    
    // MARK: - Helper Methods
    
    private func generateSleepInsights(_ sleepData: [SleepSession]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        guard !sleepData.isEmpty else { return insights }
        
        let recentSessions = Array(sleepData.suffix(7))
        let avgQuality = recentSessions.map { $0.sleepQuality }.reduce(0, +) / Double(recentSessions.count)
        let avgDuration = recentSessions.map { $0.duration }.reduce(0, +) / Double(recentSessions.count)
        let avgDeepSleep = recentSessions.map { $0.deepSleepPercentage }.reduce(0, +) / Double(recentSessions.count)
        
        if avgQuality < 0.6 {
            insights.append(HealthInsight(
                type: .sleep,
                title: "Sleep Quality Needs Improvement",
                description: "Your average sleep quality is \(Int(avgQuality * 100))%. Focus on sleep hygiene practices.",
                severity: .warning,
                data: ["quality": avgQuality]
            ))
        }
        
        if avgDuration < 7.0 * 3600 {
            insights.append(HealthInsight(
                type: .sleep,
                title: "Insufficient Sleep Duration",
                description: "You're averaging \(Int(avgDuration / 3600)) hours of sleep. Aim for 7-9 hours.",
                severity: .warning,
                data: ["duration": avgDuration]
            ))
        }
        
        if avgDeepSleep < 15 {
            insights.append(HealthInsight(
                type: .sleep,
                title: "Low Deep Sleep",
                description: "Deep sleep is only \(Int(avgDeepSleep))%. This is crucial for recovery.",
                severity: .warning,
                data: ["deepSleep": avgDeepSleep]
            ))
        }
        
        return insights
    }
    
    private func generateBiometricInsights(_ biometricData: [BiometricData]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        guard !biometricData.isEmpty else { return insights }
        
        let recentData = Array(biometricData.suffix(24))
        let avgHR = recentData.map { $0.heartRate }.reduce(0, +) / Double(recentData.count)
        let avgHRV = recentData.map { $0.heartRateVariability }.reduce(0, +) / Double(recentData.count)
        let avgSPO2 = recentData.map { $0.bloodOxygen }.reduce(0, +) / Double(recentData.count)
        
        if avgHR > 80 {
            insights.append(HealthInsight(
                type: .biometric,
                title: "Elevated Heart Rate",
                description: "Average heart rate is \(Int(avgHR)) BPM. Consider stress management techniques.",
                severity: .warning,
                data: ["heartRate": avgHR]
            ))
        }
        
        if avgHRV < 25 {
            insights.append(HealthInsight(
                type: .biometric,
                title: "Low Heart Rate Variability",
                description: "HRV of \(Int(avgHRV))ms suggests reduced recovery capacity.",
                severity: .warning,
                data: ["hrv": avgHRV]
            ))
        }
        
        if avgSPO2 < 95 {
            insights.append(HealthInsight(
                type: .biometric,
                title: "Blood Oxygen Below Optimal",
                description: "Blood oxygen at \(Int(avgSPO2))%. Consider sleep position or breathing exercises.",
                severity: .critical,
                data: ["bloodOxygen": avgSPO2]
            ))
        }
        
        return insights
    }
    
    private func generatePatternInsights(_ patterns: [SleepPattern]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        guard !patterns.isEmpty else { return insights }
        
        let recentPatterns = Array(patterns.suffix(4))
        let avgConsistency = recentPatterns.map { $0.consistency }.reduce(0, +) / Double(recentPatterns.count)
        
        if avgConsistency < 0.6 {
            insights.append(HealthInsight(
                type: .sleep,
                title: "Irregular Sleep Schedule",
                description: "Your sleep schedule is inconsistent. Try to maintain regular bedtimes.",
                severity: .warning,
                data: ["consistency": avgConsistency]
            ))
        }
        
        return insights
    }
    
    private func generateRecoveryInsights(_ sleepData: [SleepSession], _ biometricData: [BiometricData]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        guard !sleepData.isEmpty && !biometricData.isEmpty else { return insights }
        
        let recentSessions = Array(sleepData.suffix(3))
        let recentBiometrics = Array(biometricData.suffix(12))
        
        let avgDeepSleep = recentSessions.map { $0.deepSleepPercentage }.reduce(0, +) / Double(recentSessions.count)
        let avgHRV = recentBiometrics.map { $0.heartRateVariability }.reduce(0, +) / Double(recentBiometrics.count)
        
        if avgDeepSleep > 20 && avgHRV > 40 {
            insights.append(HealthInsight(
                type: .recovery,
                title: "Excellent Recovery",
                description: "High deep sleep (\(Int(avgDeepSleep))%) and HRV (\(Int(avgHRV))ms) indicate good recovery.",
                severity: .success,
                data: ["deepSleep": avgDeepSleep, "hrv": avgHRV]
            ))
        }
        
        return insights
    }
    
    private func generateStressInsights(_ biometricData: [BiometricData]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        guard !biometricData.isEmpty else { return insights }
        
        let recentData = Array(biometricData.suffix(12))
        let avgHR = recentData.map { $0.heartRate }.reduce(0, +) / Double(recentData.count)
        let avgHRV = recentData.map { $0.heartRateVariability }.reduce(0, +) / Double(recentData.count)
        
        if avgHR > 75 && avgHRV < 30 {
            insights.append(HealthInsight(
                type: .stress,
                title: "Elevated Stress Indicators",
                description: "High heart rate (\(Int(avgHR)) BPM) and low HRV (\(Int(avgHRV))ms) suggest elevated stress.",
                severity: .warning,
                data: ["heartRate": avgHR, "hrv": avgHRV]
            ))
        }
        
        return insights
    }
}

// MARK: - Data Models
struct BiometricData: Codable {
    let timestamp: Date
    var heartRate: Double
    var hrv: Double
    var movement: Double
    var oxygenSaturation: Double
    var respiratoryRate: Double
    
    init(timestamp: Date = Date(), heartRate: Double = 0, hrv: Double = 0, movement: Double = 0, oxygenSaturation: Double = 0, respiratoryRate: Double = 0) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.hrv = hrv
        self.movement = movement
        self.oxygenSaturation = oxygenSaturation
        self.respiratoryRate = respiratoryRate
    }
}

// MARK: - SleepSession Extension
extension SleepSession {
    init(from sample: HKCategorySample) {
        let sleepStage: SleepStage
        switch sample.value {
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            sleepStage = .awake
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            sleepStage = .light
        case HKCategoryValueSleepAnalysis.asleep.rawValue:
            sleepStage = .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            sleepStage = .rem
        default:
            sleepStage = .awake
        }
        
        self.init(
            startTime: sample.startDate,
            endTime: sample.endDate,
            sleepStage: sleepStage,
            quality: 0.0,
            cycleCount: 0
        )
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
