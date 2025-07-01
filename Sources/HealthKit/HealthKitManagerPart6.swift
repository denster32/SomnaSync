import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - Helper Methods
    
    private func analyzeTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 3 else { return .stable }
        
        // Use linear regression to determine trend
        let trend = calculateLinearTrend(values)
        
        if trend > 0.1 {
            return .increasing
        } else if trend < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateLinearTrend(_ values: [Double]) -> Double {
        let n = Double(values.count)
        let indices = Array(0..<values.count).map { Double($0) }
        
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }
    
    private func calculateCorrelationMatrix(_ data: [BiometricData]) -> [String: Float] {
        var correlations: [String: Float] = [:]
        
        let heartRates = data.map { $0.heartRate }
        let hrvs = data.map { $0.heartRateVariability }
        let respiratoryRates = data.map { $0.respiratoryRate }
        let bloodOxygens = data.map { $0.bloodOxygen }
        let temperatures = data.map { $0.temperature }
        
        correlations["heartRate_hrv"] = calculateCorrelation(heartRates, hrvs)
        correlations["heartRate_respiratory"] = calculateCorrelation(heartRates, respiratoryRates)
        correlations["heartRate_bloodOxygen"] = calculateCorrelation(heartRates, bloodOxygens)
        correlations["hrv_respiratory"] = calculateCorrelation(hrvs, respiratoryRates)
        correlations["hrv_bloodOxygen"] = calculateCorrelation(hrvs, bloodOxygens)
        correlations["respiratory_bloodOxygen"] = calculateCorrelation(respiratoryRates, bloodOxygens)
        
        return correlations
    }
    
    private func calculateCorrelation(_ x: [Double], _ y: [Double]) -> Float {
        guard x.count == y.count && x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        
        return denominator != 0 ? Float(numerator / denominator) : 0.0
    }
    
    private func calculateStatistics(_ values: [Double]) -> (mean: Double, stdDev: Double) {
        guard !values.isEmpty else { return (0, 0) }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return (mean: mean, stdDev: stdDev)
    }
}

// --- PredictiveAnalytics: Real Sleep Prediction ---
class PredictiveAnalytics {
    private var predictionHistory: [SleepPrediction] = []
    private let predictionHorizon: TimeInterval = 7 * 24 * 3600 // 7 days
    
    func predictSleepQuality(_ historicalData: [SleepSession], _ biometricData: [BiometricData]) async -> SleepPrediction {
        guard !historicalData.isEmpty else {
            return SleepPrediction(
                expectedQuality: 0.7,
                expectedDuration: 8.0 * 3600,
                confidence: 0.5,
                factors: [:]
            )
        }
        
        // Analyze recent patterns
        let recentSessions = Array(historicalData.suffix(7))
        let recentBiometrics = Array(biometricData.suffix(24)) // Last 24 hours
        
        // Calculate prediction factors
        let avgQuality = recentSessions.map { $0.sleepQuality }.reduce(0, +) / Double(recentSessions.count)
        let avgDuration = recentSessions.map { $0.duration }.reduce(0, +) / Double(recentSessions.count)
        let consistency = calculateSleepConsistency(recentSessions)
        let biometricHealth = calculateBiometricHealth(recentBiometrics)
        
        // Predict quality based on patterns
        let predictedQuality = predictQualityFromPatterns(
            avgQuality: avgQuality,
            consistency: consistency,
            biometricHealth: biometricHealth
        )
        
        let predictedDuration = predictDurationFromPatterns(
            avgDuration: avgDuration,
            consistency: consistency
        )
        
        let confidence = calculatePredictionConfidence(
            dataPoints: recentSessions.count,
            consistency: consistency,
            biometricHealth: biometricHealth
        )
        
        let factors = [
            "recentQuality": avgQuality,
            "consistency": consistency,
            "biometricHealth": biometricHealth,
            "stressLevel": calculateStressLevel(recentBiometrics),
            "recoveryStatus": calculateRecoveryStatus(recentSessions)
        ]
        
        let prediction = SleepPrediction(
            expectedQuality: predictedQuality,
            expectedDuration: predictedDuration,
            confidence: confidence,
            factors: factors
        )
        
        predictionHistory.append(prediction)
        return prediction
    }
    
    func predictOptimalSleepTime(_ patterns: [SleepPattern], _ currentTime: Date) async -> Date {
        guard !patterns.isEmpty else {
            // Default: 10 PM
            return Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: currentTime) ?? currentTime
        }
        
        // Find most successful sleep times
        let successfulPatterns = patterns.filter { $0.averageQuality > 0.7 }
        
        if let bestPattern = successfulPatterns.max(by: { $0.averageQuality < $1.averageQuality }) {
            // Use the best pattern's timing
            let hour = Calendar.current.component(.hour, from: bestPattern.startDate)
            return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: currentTime) ?? currentTime
        }
        
        // Fallback to average of recent patterns
        let avgHour = patterns.map { Calendar.current.component(.hour, from: $0.startDate) }.reduce(0, +) / patterns.count
        return Calendar.current.date(bySettingHour: avgHour, minute: 0, second: 0, of: currentTime) ?? currentTime
    }
    
