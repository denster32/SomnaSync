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
    
