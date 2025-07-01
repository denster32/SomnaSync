import Foundation
import HealthKit
import SwiftUI
import os.log

/// Enhanced HealthKitManager - Advanced health data analysis and predictive analytics
@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    @Published var biometricData: BiometricData?
    @Published var isAuthorized = false
    @Published var isAvailable = false
    @Published var lastUpdated = Date()
    @Published var lastSyncDate: Date?
    @Published var syncStatus = "Not synced"
    
    // NEW: Individual permission status properties
    @Published var heartRatePermission = false
    @Published var hrvPermission = false
    @Published var respiratoryRatePermission = false
    @Published var sleepAnalysisPermission = false
    @Published var oxygenSaturationPermission = false
    @Published var bodyTemperaturePermission = false
    
    // MARK: - Computed Properties for UI
    
    var lastSleepDuration: String {
        guard let lastSession = sleepData.last else {
            return "No data"
        }
        
        let duration = lastSession.endDate.timeIntervalSince(lastSession.startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    var averageSleepDuration: String {
        guard !sleepData.isEmpty else {
            return "No data"
        }
        
        let totalDuration = sleepData.reduce(0) { total, session in
            total + session.endDate.timeIntervalSince(session.startDate)
        }
        
        let averageDuration = totalDuration / Double(sleepData.count)
        let hours = Int(averageDuration) / 3600
        let minutes = Int(averageDuration) % 3600 / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    var sleepEfficiency: Double {
        guard let lastSession = sleepData.last else {
            return 0.0
        }
        
        let totalDuration = lastSession.endDate.timeIntervalSince(lastSession.startDate)
        let timeInBed = lastSession.timeInBed ?? totalDuration
        
        return timeInBed > 0 ? (totalDuration / timeInBed) * 100 : 0.0
    }
    
    var sleepQualityScore: Double {
        guard let lastSession = sleepData.last else {
            return 0.0
        }
        
        // Calculate sleep quality based on multiple factors
        let durationScore = calculateDurationScore(lastSession)
        let efficiencyScore = sleepEfficiency / 100.0
        let consistencyScore = calculateConsistencyScore()
        let biometricScore = calculateBiometricScore()
        
        // Weighted average
        let qualityScore = (durationScore * 0.3 + 
                           efficiencyScore * 0.3 + 
                           consistencyScore * 0.2 + 
                           biometricScore * 0.2)
        
        return min(100.0, max(0.0, qualityScore * 100))
    }
    
    private func calculateDurationScore(_ session: SleepSession) -> Double {
        let duration = session.endDate.timeIntervalSince(session.startDate)
        let hours = duration / 3600
        
        // Optimal sleep duration is 7-9 hours
        if hours >= 7.0 && hours <= 9.0 {
            return 1.0
        } else if hours >= 6.0 && hours <= 10.0 {
            return 0.8
        } else if hours >= 5.0 && hours <= 11.0 {
            return 0.6
        } else {
            return 0.3
        }
    }
    
    private func calculateConsistencyScore() -> Double {
        guard sleepData.count >= 7 else {
            return 0.5 // Default score for insufficient data
        }
        
        // Calculate consistency of sleep times over the last week
        let recentSessions = Array(sleepData.suffix(7))
        let bedTimes = recentSessions.map { session in
            Calendar.current.component(.hour, from: session.startDate)
        }
        
        let averageBedTime = bedTimes.reduce(0, +) / bedTimes.count
        let variance = bedTimes.reduce(0) { total, hour in
            total + pow(Double(hour - averageBedTime), 2)
        } / Double(bedTimes.count)
        
        let standardDeviation = sqrt(variance)
        
        // Lower standard deviation = higher consistency
        if standardDeviation <= 1.0 {
            return 1.0
        } else if standardDeviation <= 2.0 {
            return 0.8
        } else if standardDeviation <= 3.0 {
            return 0.6
        } else {
            return 0.4
        }
    }
    
    private func calculateBiometricScore() -> Double {
        guard let biometricData = biometricData else {
            return 0.5
        }
        
        // Calculate score based on current biometric readings
        let heartRateScore = calculateHeartRateScore(biometricData.heartRate)
        let hrvScore = calculateHRVScore(biometricData.hrv)
        let respiratoryScore = calculateRespiratoryScore(biometricData.respiratoryRate)
        
        return (heartRateScore + hrvScore + respiratoryScore) / 3.0
    }
    
    private func calculateHeartRateScore(_ heartRate: Double) -> Double {
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
    
    private func calculateHRVScore(_ hrv: Double) -> Double {
        // Higher HRV generally indicates better health
        if hrv >= 50 {
            return 1.0
        } else if hrv >= 30 {
            return 0.8
        } else if hrv >= 20 {
            return 0.6
        } else {
            return 0.4
        }
    }
    
    private func calculateRespiratoryScore(_ respiratoryRate: Double) -> Double {
        // Normal respiratory rate is 12-20 breaths per minute
        if respiratoryRate >= 12 && respiratoryRate <= 20 {
            return 1.0
        } else if respiratoryRate >= 10 && respiratoryRate <= 24 {
            return 0.8
        } else if respiratoryRate >= 8 && respiratoryRate <= 28 {
            return 0.6
        } else {
            return 0.4
        }
    }
    
    // MARK: - Published Properties
    @Published var currentHeartRate: Double = 0.0
    @Published var currentHRV: Double = 0.0
    @Published var currentRespiratoryRate: Double = 0.0
    @Published var sleepData: [SleepSession] = []
    
    // NEW: Advanced Health Analysis Features
    @Published var sleepPatterns: [SleepPattern] = []
    @Published var biometricTrends: BiometricTrends?
    @Published var healthInsights: [HealthInsight] = []
    @Published var sleepPredictions: SleepPrediction?
    @Published var healthScore: Float = 0.0
    @Published var recoveryStatus: RecoveryStatus = .unknown
    @Published var stressLevel: StressLevel = .low
    @Published var sleepQualityTrend: SleepQualityTrend = .stable
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var hrvQuery: HKQuery?
    private var movementQuery: HKQuery?
    
    // NEW: Advanced Analysis Components
    private var sleepPatternAnalyzer: SleepPatternAnalyzer?
    private var biometricAnalyzer: BiometricAnalyzer?
    private var healthPredictor: HealthPredictor?
    private var recoveryAnalyzer: RecoveryAnalyzer?
    private var stressAnalyzer: StressAnalyzer?
    private var trendAnalyzer: TrendAnalyzer?
    
    // MARK: - Configuration
    private let updateInterval: TimeInterval = 60 // 1 minute
    private let analysisWindow: TimeInterval = 24 * 60 * 60 // 24 hours
    private let trendWindow: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // NEW: Enhanced Configuration
    private let sleepPatternThreshold: Float = 0.7
    private let biometricCorrelationThreshold: Float = 0.6
    private let predictionConfidenceThreshold: Float = 0.8
    private let healthScoreWeights: [String: Float] = [
        "sleepQuality": 0.3,
        "heartRate": 0.2,
        "hrv": 0.25,
        "respiratoryRate": 0.15,
        "stressLevel": 0.1
    ]
    
    private init() {
        checkAvailability()
        checkAuthorizationStatus()
        setupAdvancedAnalyzers()
    }
    
    deinit {
        stopObserving()
    }
    
    // MARK: - Enhanced HealthKit Setup
    
    private func setupHealthKitManager() {
        checkAuthorizationStatus()
        Logger.success("HealthKit manager initialized", log: Logger.healthKit)
    }
    
    private func setupAdvancedAnalyzers() {
        // NEW: Initialize advanced analysis components
        sleepPatternAnalyzer = SleepPatternAnalyzer()
        biometricAnalyzer = BiometricAnalyzer()
        healthPredictor = HealthPredictor()
        recoveryAnalyzer = RecoveryAnalyzer()
        stressAnalyzer = StressAnalyzer()
        trendAnalyzer = TrendAnalyzer()
        
        Logger.success("Advanced health analyzers initialized", log: Logger.healthKit)
    }
    
    // MARK: - Authorization
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.error("HealthKit is not available on this device", log: Logger.healthKit)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.getRequestStatusForAuthorization(toShare: typesToWrite, read: typesToRead) { status, error in
            DispatchQueue.main.async {
                self.isAuthorized = status == .unnecessary
            }
        }
    }
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.error("HealthKit is not available on this device", log: Logger.healthKit)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
            requestedPermissions = true
            Logger.success("HealthKit authorization successful", log: Logger.healthKit)
        } catch {
            Logger.error("HealthKit authorization failed: \(error.localizedDescription)", log: Logger.healthKit)
        }
    }
    
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
    
    private func calculateLinearTrend(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let n = Double(values.count)
        let indices = Array(0..<values.count).map { Double($0) }
        
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
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
    }()
} 