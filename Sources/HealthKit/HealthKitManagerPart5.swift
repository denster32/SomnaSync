import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - Helper Methods
    
    private func groupSessionsByWeek(_ sessions: [SleepSession]) -> [Date: [SleepSession]] {
        var groups: [Date: [SleepSession]] = [:]
        
        for session in sessions {
            let weekStart = getWeekStart(for: session.startTime)
            if groups[weekStart] == nil {
                groups[weekStart] = []
            }
            groups[weekStart]?.append(session)
        }
        
        return groups
    }
    
    private func getWeekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    private func analyzeWeeklyPattern(_ sessions: [SleepSession], weekStart: Date) -> SleepPattern {
        guard !sessions.isEmpty else {
            return SleepPattern(
                type: .irregular,
                startDate: weekStart,
                endDate: weekStart,
                averageDuration: 0,
                averageQuality: 0,
                consistency: 0,
                insights: []
            )
        }
        
        let durations = sessions.map { $0.duration }
        let qualities = sessions.map { calculateQualityScore($0) }
        let startTimes = sessions.map { $0.startTime }
        
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let avgQuality = qualities.reduce(0, +) / Double(qualities.count)
        let consistency = calculateConsistency(startTimes, durations)
        
        let patternType = determinePatternType(
            avgDuration: avgDuration,
            avgQuality: avgQuality,
            consistency: consistency,
            sessionCount: sessions.count
        )
        
        let insights = generatePatternInsights(
            sessions: sessions,
            patternType: patternType,
            avgDuration: avgDuration,
            avgQuality: avgQuality
        )
        
        return SleepPattern(
            type: patternType,
            startDate: weekStart,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart,
            averageDuration: avgDuration,
            averageQuality: avgQuality,
            consistency: consistency,
            insights: insights
        )
    }
    
    private func calculateQualityScore(_ session: SleepSession) -> Double {
        // Multi-factor quality calculation
        let durationScore = min(session.duration / 8.0, 1.0) // Optimal: 8 hours
        let efficiencyScore = session.sleepEfficiency
        let deepSleepScore = session.deepSleepPercentage / 100.0
        let remSleepScore = session.remSleepPercentage / 100.0
        
        // Weighted average
        return durationScore * 0.3 + efficiencyScore * 0.3 + deepSleepScore * 0.2 + remSleepScore * 0.2
    }
    
    private func calculateConsistency(_ startTimes: [Date], _ durations: [TimeInterval]) -> Double {
        guard startTimes.count > 1 else { return 1.0 }
        
        // Calculate consistency of sleep timing
        let sortedTimes = startTimes.sorted()
        var timeDifferences: [TimeInterval] = []
        
        for i in 1..<sortedTimes.count {
            let diff = abs(sortedTimes[i].timeIntervalSince(sortedTimes[i-1]))
            timeDifferences.append(diff)
        }
        
        let avgDifference = timeDifferences.reduce(0, +) / Double(timeDifferences.count)
        let consistency = max(0, 1.0 - (avgDifference / (24 * 3600))) // Normalize to 24 hours
        
        return consistency
    }
    
    private func determinePatternType(avgDuration: TimeInterval, avgQuality: Double, consistency: Double, sessionCount: Int) -> SleepPatternType {
        if sessionCount < 3 {
            return .irregular
        }
        
        if consistency > 0.8 && avgQuality > 0.7 {
            return .consistent
        } else if avgDuration < 6.0 {
            return .shortSleep
        } else if avgDuration > 9.0 {
            return .longSleep
        } else if avgQuality < 0.5 {
            return .poorQuality
        } else if avgQuality > 0.8 {
            return .goodQuality
        } else {
            return .irregular
        }
    }
    
    private func generatePatternInsights(sessions: [SleepSession], patternType: SleepPatternType, avgDuration: TimeInterval, avgQuality: Double) -> [String] {
        var insights: [String] = []
        
        switch patternType {
        case .consistent:
            insights.append("Excellent sleep consistency! Your regular sleep schedule is working well.")
        case .shortSleep:
            insights.append("You're getting less than 6 hours of sleep on average. Consider extending your sleep time.")
        case .longSleep:
            insights.append("You're sleeping more than 9 hours regularly. This might indicate underlying fatigue or health issues.")
        case .poorQuality:
            insights.append("Sleep quality is below optimal levels. Consider improving your sleep environment.")
        case .goodQuality:
            insights.append("Great sleep quality! Your sleep habits are supporting good rest.")
        case .irregular:
            insights.append("Your sleep schedule is irregular. Try to maintain consistent bedtimes.")
        }
        
        if avgDuration < 7.0 {
            insights.append("Consider increasing sleep duration to 7-9 hours for optimal health.")
        }
        
        if avgQuality < 0.6 {
            insights.append("Focus on sleep hygiene practices to improve sleep quality.")
        }
        
        return insights
    }
    
    private func calculateLinearTrend<T: BinaryFloatingPoint>(_ values: [T]) -> Double {
        guard values.count > 1 else { return 0.0 }

        let n = Double(values.count)
        let indices = (0..<values.count).map { Double($0) }

        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0) { $0 + Double($1) }
        let sumXY = zip(indices, values).map { $0 * Double($1) }.reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }
}

// --- BiometricTrendAnalyzer: Real Biometric Trend Analysis ---
class BiometricTrendAnalyzer {
    private var trendHistory: [BiometricTrends] = []
    private let analysisPeriod: TimeInterval = 30 * 24 * 3600 // 30 days
    
    func analyzeBiometricTrends(_ data: [BiometricData]) async -> BiometricTrends {
        guard data.count >= 7 else {
            return BiometricTrends(
                heartRateTrend: .stable,
                hrvTrend: .stable,
                respiratoryRateTrend: .stable,
                correlationMatrix: [:]
            )
        }
        
        // Analyze trends for each biometric
        let heartRateTrend = analyzeTrend(data.map { $0.heartRate })
        let hrvTrend = analyzeTrend(data.map { $0.heartRateVariability })
        let respiratoryTrend = analyzeTrend(data.map { $0.respiratoryRate })
        
        // Calculate correlations
        let correlationMatrix = calculateCorrelationMatrix(data)
        
        let trends = BiometricTrends(
            heartRateTrend: heartRateTrend,
            hrvTrend: hrvTrend,
            respiratoryRateTrend: respiratoryTrend,
            correlationMatrix: correlationMatrix
        )
        
        trendHistory.append(trends)
        return trends
    }
    
    func detectAnomalies(_ data: [BiometricData]) async -> [HealthInsight] {
        var anomalies: [HealthInsight] = []
        
        // Calculate baseline statistics
        let heartRates = data.map { $0.heartRate }
        let hrvs = data.map { $0.heartRateVariability }
        let respiratoryRates = data.map { $0.respiratoryRate }
        let bloodOxygens = data.map { $0.bloodOxygen }
        
        let hrStats = calculateStatistics(heartRates)
        let hrvStats = calculateStatistics(hrvs)
        let rrStats = calculateStatistics(respiratoryRates)
        let spo2Stats = calculateStatistics(bloodOxygens)
        
        // Detect anomalies using 3-sigma rule
        for (i, point) in data.enumerated() {
            if abs(point.heartRate - hrStats.mean) > 3 * hrStats.stdDev {
                anomalies.append(HealthInsight(
                    type: .biometric,
                    title: "Unusual Heart Rate",
                    description: "Heart rate of \(Int(point.heartRate)) BPM is outside normal range",
                    severity: .warning,
                    data: ["value": point.heartRate, "timestamp": point.timestamp]
                ))
            }
            
            if abs(point.heartRateVariability - hrvStats.mean) > 3 * hrvStats.stdDev {
                anomalies.append(HealthInsight(
                    type: .biometric,
                    title: "Unusual HRV",
                    description: "Heart rate variability of \(Int(point.heartRateVariability))ms is outside normal range",
                    severity: .warning,
                    data: ["value": point.heartRateVariability, "timestamp": point.timestamp]
                ))
            }
            
            if point.bloodOxygen < 95 {
                anomalies.append(HealthInsight(
                    type: .biometric,
                    title: "Low Blood Oxygen",
                    description: "Blood oxygen level of \(Int(point.bloodOxygen))% is below optimal range",
                    severity: .critical,
                    data: ["value": point.bloodOxygen, "timestamp": point.timestamp]
                ))
            }
        }
        
        return anomalies
    }
    
