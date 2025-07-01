import Foundation
import HealthKit
import SwiftUI
import os.log

    // MARK: - NEW: Advanced Health Data Analysis
    
    func performComprehensiveHealthAnalysis() async {
        Logger.info("Starting comprehensive health data analysis", log: Logger.healthKit)
        
        // Step 1: Sleep Pattern Recognition
        await analyzeSleepPatterns()
        
        // Step 2: Biometric Trend Analysis
        await analyzeBiometricTrends()
        
        // Step 3: Health Correlation Analysis
        await analyzeHealthCorrelations()
        
        // Step 4: Predictive Analytics
        await performPredictiveAnalytics()
        
        // Step 5: Recovery Status Analysis
        await analyzeRecoveryStatus()
        
        // Step 6: Stress Level Analysis
        await analyzeStressLevel()
        
        // Step 7: Generate Health Insights
        await generateHealthInsights()
        
        // Step 8: Calculate Health Score
        await calculateHealthScore()
        
        Logger.success("Comprehensive health analysis completed", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Sleep Pattern Recognition
    
    private func analyzeSleepPatterns() async {
        guard let sleepPatternAnalyzer = sleepPatternAnalyzer else { return }
        
        let sleepData = await fetchSleepData(from: Date().addingTimeInterval(-trendWindow), to: Date())
        
        let patterns = await sleepPatternAnalyzer.identifyPatterns(sleepData)
        
        await MainActor.run {
            self.sleepPatterns = patterns
        }
        
        // Analyze sleep quality trends
        let qualityTrend = await sleepPatternAnalyzer.analyzeQualityTrend(sleepData)
        
        await MainActor.run {
            self.sleepQualityTrend = qualityTrend
        }
        
        Logger.info("Identified \(patterns.count) sleep patterns", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Biometric Trend Analysis
    
    private func analyzeBiometricTrends() async {
        guard let biometricAnalyzer = biometricAnalyzer else { return }
        
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-trendWindow)
        
        // Collect biometric data
        let heartRateData = await fetchHeartRateData(from: startDate, to: endDate)
        let hrvData = await fetchHRVData(from: startDate, to: endDate)
        let respiratoryData = await fetchRespiratoryRateData(from: startDate, to: endDate)
        
        // Analyze trends
        let trends = await biometricAnalyzer.analyzeTrends(
            heartRate: heartRateData,
            hrv: hrvData,
            respiratoryRate: respiratoryData
        )
        
        await MainActor.run {
            self.biometricTrends = trends
        }
        
        Logger.info("Biometric trends analyzed", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Health Correlation Analysis
    
    private func analyzeHealthCorrelations() async {
        guard let biometricAnalyzer = biometricAnalyzer else { return }
        
        let correlations = await biometricAnalyzer.analyzeCorrelations(
            sleepData: sleepData,
            biometricTrends: biometricTrends
        )
        
        // Store correlations for insights
        await MainActor.run {
            // Update insights with correlation data
            let correlationInsight = HealthInsight(
                type: .correlation,
                title: "Health Correlations",
                description: "Analysis of relationships between sleep and biometric data",
                severity: .info,
                data: correlations
            )
            self.healthInsights.append(correlationInsight)
        }
        
        Logger.info("Health correlations analyzed", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Predictive Analytics
    
    private func performPredictiveAnalytics() async {
        guard let healthPredictor = healthPredictor else { return }
        
        let prediction = await healthPredictor.predictSleepQuality(
            sleepPatterns: sleepPatterns,
            biometricTrends: biometricTrends,
            historicalData: sleepData
        )
        
        await MainActor.run {
            self.sleepPredictions = prediction
        }
        
        Logger.info("Sleep predictions generated", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Recovery Status Analysis
    
    private func analyzeRecoveryStatus() async {
        guard let recoveryAnalyzer = recoveryAnalyzer else { return }
        
        let recoveryStatus = await recoveryAnalyzer.analyzeRecoveryStatus(
            heartRate: currentHeartRate,
            hrv: currentHRV,
            sleepQuality: sleepData.last?.quality ?? 0.0,
            sleepDuration: sleepData.last?.duration ?? 0.0
        )
        
        await MainActor.run {
            self.recoveryStatus = recoveryStatus
        }
        
        Logger.info("Recovery status analyzed: \(recoveryStatus)", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Stress Level Analysis
    
    private func analyzeStressLevel() async {
        guard let stressAnalyzer = stressAnalyzer else { return }
        
        let stressLevel = await stressAnalyzer.analyzeStressLevel(
            heartRate: currentHeartRate,
            hrv: currentHRV,
            respiratoryRate: currentRespiratoryRate,
            sleepQuality: sleepData.last?.quality ?? 0.0
        )
        
        await MainActor.run {
            self.stressLevel = stressLevel
        }
        
        Logger.info("Stress level analyzed: \(stressLevel)", log: Logger.healthKit)
    }
    
    // MARK: - NEW: Health Insights Generation
    
    private func generateHealthInsights() async {
        var insights: [HealthInsight] = []
        
        // Sleep pattern insights
        if let sleepInsight = generateSleepInsight() {
            insights.append(sleepInsight)
        }
        
        // Biometric insights
        if let biometricInsight = generateBiometricInsight() {
            insights.append(biometricInsight)
        }
        
        // Recovery insights
        if let recoveryInsight = generateRecoveryInsight() {
            insights.append(recoveryInsight)
        }
        
        // Stress insights
        if let stressInsight = generateStressInsight() {
            insights.append(stressInsight)
        }
        
        // Prediction insights
        if let predictionInsight = generatePredictionInsight() {
            insights.append(predictionInsight)
        }
        
        await MainActor.run {
            self.healthInsights = insights
        }
        
        Logger.info("Generated \(insights.count) health insights", log: Logger.healthKit)
    }
    
    private func generateSleepInsight() -> HealthInsight? {
        guard let lastSleep = sleepData.last else { return nil }
        
        let quality = lastSleep.quality
        let duration = lastSleep.duration / 3600 // Convert to hours
        
        if quality < 0.6 {
            return HealthInsight(
                type: .sleep,
                title: "Sleep Quality Alert",
                description: "Your sleep quality was below optimal levels. Consider improving your sleep environment or routine.",
                severity: .warning,
                data: ["quality": quality, "duration": duration]
            )
        } else if duration < 7 {
            return HealthInsight(
                type: .sleep,
                title: "Sleep Duration Notice",
                description: "You slept for \(String(format: "%.1f", duration)) hours. Aim for 7-9 hours for optimal health.",
                severity: .info,
                data: ["quality": quality, "duration": duration]
            )
        }
        
        return nil
    }
    
    private func generateBiometricInsight() -> HealthInsight? {
        guard let trends = biometricTrends else { return nil }
        
        if trends.heartRateTrend == .increasing {
            return HealthInsight(
                type: .biometric,
                title: "Heart Rate Trend",
                description: "Your resting heart rate has been increasing. This may indicate stress or poor recovery.",
                severity: .warning,
                data: ["trend": "increasing"]
            )
        }
        
        if trends.hrvTrend == .decreasing {
            return HealthInsight(
                type: .biometric,
                title: "HRV Decline",
                description: "Your heart rate variability has been decreasing. Focus on stress management and recovery.",
                severity: .warning,
                data: ["trend": "decreasing"]
            )
        }
        
        return nil
    }
    
    private func generateRecoveryInsight() -> HealthInsight? {
        switch recoveryStatus {
        case .poor:
            return HealthInsight(
                type: .recovery,
                title: "Poor Recovery Detected",
                description: "Your body shows signs of poor recovery. Consider rest days and stress reduction.",
                severity: .warning,
                data: ["status": "poor"]
            )
        case .excellent:
            return HealthInsight(
                type: .recovery,
                title: "Excellent Recovery",
                description: "Your recovery metrics are excellent! You're ready for high-intensity activities.",
                severity: .success,
                data: ["status": "excellent"]
            )
        default:
            return nil
        }
    }
    
    private func generateStressInsight() -> HealthInsight? {
        switch stressLevel {
        case .high:
            return HealthInsight(
                type: .stress,
                title: "High Stress Detected",
                description: "Your biometric data indicates high stress levels. Consider relaxation techniques.",
                severity: .warning,
                data: ["level": "high"]
            )
        case .moderate:
            return HealthInsight(
                type: .stress,
                title: "Moderate Stress",
                description: "You're experiencing moderate stress. Monitor your stress management strategies.",
                severity: .info,
                data: ["level": "moderate"]
            )
        default:
            return nil
        }
    }
    
    private func generatePredictionInsight() -> HealthInsight? {
        guard let prediction = sleepPredictions else { return nil }
        
        if prediction.confidence > predictionConfidenceThreshold {
            return HealthInsight(
                type: .prediction,
                title: "Sleep Quality Prediction",
                description: "Based on your patterns, tonight's sleep quality is predicted to be \(String(format: "%.1f", prediction.expectedQuality * 100))%.",
                severity: .info,
                data: ["predictedQuality": prediction.expectedQuality, "confidence": prediction.confidence]
            )
        }
        
        return nil
    }
    
    // MARK: - NEW: Health Score Calculation
    
    private func calculateHealthScore() async {
        var score: Float = 0.0
        
        // Sleep quality component
        let sleepQuality = sleepData.last?.quality ?? 0.0
        score += sleepQuality * healthScoreWeights["sleepQuality"]!
        
        // Heart rate component
        let heartRateScore = calculateHeartRateScore(currentHeartRate)
        score += heartRateScore * healthScoreWeights["heartRate"]!
        
        // HRV component
        let hrvScore = calculateHRVScore(currentHRV)
        score += hrvScore * healthScoreWeights["hrv"]!
        
        // Respiratory rate component
        let respiratoryScore = calculateRespiratoryScore(currentRespiratoryRate)
        score += respiratoryScore * healthScoreWeights["respiratoryRate"]!
        
        // Stress level component
        let stressScore = calculateStressScore(stressLevel)
        score += stressScore * healthScoreWeights["stressLevel"]!
        
        await MainActor.run {
            self.healthScore = min(max(score, 0.0), 1.0)
        }
        
        Logger.info("Health score calculated: \(healthScore)", log: Logger.healthKit)
    }
    
    private func calculateHeartRateScore(_ heartRate: Double) -> Float {
        // Optimal resting heart rate is 60-100 BPM
        if heartRate >= 60 && heartRate <= 100 {
            return 1.0
        } else if heartRate >= 50 && heartRate <= 110 {
            return 0.8
        } else if heartRate >= 40 && heartRate <= 120 {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func calculateHRVScore(_ hrv: Double) -> Float {
        // Higher HRV is generally better
        if hrv >= 50 {
            return 1.0
        } else if hrv >= 30 {
            return 0.8
        } else if hrv >= 20 {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func calculateRespiratoryScore(_ respiratoryRate: Double) -> Float {
        // Normal respiratory rate is 12-20 breaths per minute
        if respiratoryRate >= 12 && respiratoryRate <= 20 {
            return 1.0
        } else if respiratoryRate >= 10 && respiratoryRate <= 25 {
            return 0.8
        } else if respiratoryRate >= 8 && respiratoryRate <= 30 {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func calculateStressScore(_ stressLevel: StressLevel) -> Float {
        switch stressLevel {
        case .low:
            return 1.0
        case .moderate:
            return 0.7
        case .high:
            return 0.4
        }
    }
    
    // MARK: - Enhanced Data Fetching
    
    func fetchHeartRateData(from startDate: Date, to endDate: Date) async -> [HeartRateData] {
        guard isAuthorized else { return [] }
        
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let samples = try await healthStore.samples(of: heartRateType, predicate: predicate)
            return samples.compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HeartRateData(
                    value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    timestamp: quantitySample.startDate
                )
            }
        } catch {
            Logger.error("Failed to fetch heart rate data: \(error.localizedDescription)", log: Logger.healthKit)
            return []
        }
    }
    
    func fetchHRVData(from startDate: Date, to endDate: Date) async -> [HRVData] {
        guard isAuthorized else { return [] }
        
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let samples = try await healthStore.samples(of: hrvType, predicate: predicate)
            return samples.compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return HRVData(
                    value: quantitySample.quantity.doubleValue(for: .secondUnit(with: .milli)),
                    timestamp: quantitySample.startDate
                )
            }
        } catch {
            Logger.error("Failed to fetch HRV data: \(error.localizedDescription)", log: Logger.healthKit)
            return []
        }
    }
    
    func fetchRespiratoryRateData(from startDate: Date, to endDate: Date) async -> [RespiratoryRateData] {
        guard isAuthorized else { return [] }
        
        let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        do {
            let samples = try await healthStore.samples(of: respiratoryType, predicate: predicate)
            return samples.compactMap { sample in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                return RespiratoryRateData(
                    value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    timestamp: quantitySample.startDate
                )
            }
        } catch {
            Logger.error("Failed to fetch respiratory rate data: \(error.localizedDescription)", log: Logger.healthKit)
            return []
        }
    }
    
    // MARK: - Public Interface
    
    func getHealthSummary() -> HealthSummary {
        return HealthSummary(
            healthScore: healthScore,
            recoveryStatus: recoveryStatus,
            stressLevel: stressLevel,
            sleepQualityTrend: sleepQualityTrend,
            insights: healthInsights,
            predictions: sleepPredictions
        )
    }
    
    func getBiometricSummary() -> BiometricSummary {
        return BiometricSummary(
            heartRate: currentHeartRate,
            hrv: currentHRV,
            respiratoryRate: currentRespiratoryRate,
            trends: biometricTrends
        )
    }
    
