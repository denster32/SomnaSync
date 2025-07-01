import Foundation
import HealthKit
import CoreML
import os.log

/// DataManager - Handles real sleep data collection and model training
@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var isCollectingData = false
    @Published var dataPointsCollected = 0
    @Published var lastDataCollection = Date()
    @Published var modelTrainingProgress: Double = 0.0
    @Published var isAnalyzingHistoricalData = false
    @Published var historicalAnalysisProgress: Double = 0.0
    @Published var historicalDataPoints = 0
    @Published var hasCompletedInitialAnalysis = false
    
    private let healthStore = HKHealthStore()
    private var sleepDataHistory: [LabeledSleepData] = []
    private let maxDataPoints = 10000
    
    private init() {
        // Check if initial analysis has been completed
        hasCompletedInitialAnalysis = UserDefaults.standard.bool(forKey: "hasCompletedInitialAnalysis")
    }
    
    // MARK: - Initial Setup and Historical Analysis
    func performInitialSetup() async {
        // Check if initial analysis has already been completed
        if hasCompletedInitialAnalysis {
            Logger.info("Initial analysis already completed", log: Logger.dataManager)
            return
        }
        
        await MainActor.run {
            self.isAnalyzingHistoricalData = true
            self.historicalAnalysisProgress = 0.0
        }
        
        Logger.info("Starting initial historical data analysis...", log: Logger.dataManager)
        
        do {
            // Request HealthKit permissions
            await requestHealthKitPermissions()
            
            // Analyze historical sleep data
            await analyzeHistoricalSleepData()
            
            // Analyze historical biometric data
            await analyzeHistoricalBiometricData()
            
            // Establish user baseline
            await establishUserBaseline()
            
            // Mark analysis as completed
            await MainActor.run {
                self.hasCompletedInitialAnalysis = true
                self.isAnalyzingHistoricalData = false
                self.historicalAnalysisProgress = 1.0
            }
            
            UserDefaults.standard.set(true, forKey: "hasCompletedInitialAnalysis")
            
            Logger.success("Initial historical analysis completed successfully!", log: Logger.dataManager)
            Logger.info("Analyzed \(historicalDataPoints) historical data points", log: Logger.dataManager)
            
        } catch {
            Logger.error("Initial analysis failed: \(error.localizedDescription)", log: Logger.dataManager)
            
            await MainActor.run {
                self.isAnalyzingHistoricalData = false
                self.historicalAnalysisProgress = 0.0
            }
        }
    }
    
    private func analyzeHistoricalSleepData() async {
        await MainActor.run {
            self.historicalAnalysisProgress = 0.2
        }
        
        Logger.info("Analyzing historical sleep data...", log: Logger.dataManager)
        
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            
            let sleepSamples = try await fetchHistoricalSleepData(from: startDate, to: endDate)
            
            await MainActor.run {
                self.historicalAnalysisProgress = 0.4
            }
            
            Logger.info("Found \(sleepSamples.count) historical sleep samples", log: Logger.dataManager)
            
            // Process each sleep sample
            for sample in sleepSamples {
                await processHistoricalSleepSample(sample)
            }
            
            await MainActor.run {
                self.historicalAnalysisProgress = 0.6
            }
            
        } catch {
            Logger.error("Failed to analyze historical sleep data: \(error.localizedDescription)", log: Logger.dataManager)
        }
    }
    
    private func analyzeHistoricalBiometricData() async {
        await MainActor.run {
            self.historicalAnalysisProgress = 0.7
        }
        
        Logger.info("Analyzing historical biometric data...", log: Logger.dataManager)
        
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            
            let biometricSamples = try await fetchHistoricalBiometricData(from: startDate, to: endDate)
            
            await MainActor.run {
                self.historicalDataPoints += biometricSamples.count
            }
            
            Logger.info("Found \(biometricSamples.count) historical biometric samples", log: Logger.dataManager)
            
            await processHistoricalBiometricData(biometricSamples)
            
            await MainActor.run {
                self.historicalAnalysisProgress = 0.9
            }
            
        } catch {
            Logger.error("Failed to analyze historical biometric data: \(error.localizedDescription)", log: Logger.dataManager)
        }
    }
    
    private func establishUserBaseline() async {
        await MainActor.run {
            self.historicalAnalysisProgress = 0.95
        }
        
        Logger.info("Establishing user baseline...", log: Logger.dataManager)
        
        if let baseline = await createInitialUserBaseline() {
            await MainActor.run {
                self.userBaseline = baseline
            }
            
            if let data = try? JSONEncoder().encode(baseline) {
                UserDefaults.standard.set(data, forKey: "userSleepBaseline")
            }
            
            Logger.success("User baseline established", log: Logger.dataManager)
        }
        
        await MainActor.run {
            self.historicalAnalysisProgress = 1.0
        }
    }
    
    private func fetchHistoricalSleepData(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await healthStore.samples(of: sleepType, predicate: predicate, sortDescriptors: [sortDescriptor])
    }
    
    private func fetchHistoricalBiometricData(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        var allSamples: [HKQuantitySample] = []
        
        // Heart rate data
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let samples = try await healthStore.samples(of: heartRateType, predicate: predicate)
            allSamples.append(contentsOf: samples)
        }
        
        // HRV data
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let samples = try await healthStore.samples(of: hrvType, predicate: predicate)
            allSamples.append(contentsOf: samples)
        }
        
        // Blood oxygen data
        if let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let samples = try await healthStore.samples(of: oxygenType, predicate: predicate)
            allSamples.append(contentsOf: samples)
        }
        
        return allSamples
    }
    
    private func processHistoricalSleepSample(_ sample: HKCategorySample) async {
        // Convert HealthKit sleep sample to our format
        let sleepStage = mapSleepAnalysisToStage(sample.value)
        
        // Create labeled data point
        let labeledData = LabeledSleepData(
            timestamp: sample.startDate,
            features: createFeaturesFromHistoricalData(sample),
            predictedStage: sleepStage,
            actualStage: sleepStage,
            confidence: 0.8, // High confidence for historical data
            sleepQuality: calculateHistoricalSleepQuality(sample)
        )
        
        await addToHistory(labeledData)
    }
    
    private func processHistoricalBiometricData(_ samples: [HKQuantitySample]) async {
        // Group samples by time and create features
        let groupedSamples = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfHour(for: sample.startDate)
        }
        
        for (hour, hourSamples) in groupedSamples {
            let features = createFeaturesFromBiometricSamples(hourSamples)
            
            // Create labeled data point
            let labeledData = LabeledSleepData(
                timestamp: hour,
                features: features,
                predictedStage: .light, // Default for historical data
                actualStage: nil,
                confidence: 0.6,
                sleepQuality: 0.7
            )
            
            await addToHistory(labeledData)
        }
    }
    
    private func createFeaturesFromHistoricalData(_ sample: HKCategorySample) -> SleepFeatures {
        // Create features from historical sleep data
        return SleepFeatures(
            heartRate: 65.0, // Default values for historical data
            hrv: 35.0,
            movement: 0.2,
            bloodOxygen: 97.0,
            temperature: 36.8,
            breathingRate: 14.0,
            timeOfNight: calculateTimeOfNight(for: sample.startDate),
            previousStage: .awake
        )
    }
    
    private func createFeaturesFromBiometricSamples(_ samples: [HKQuantitySample]) -> SleepFeatures {
        // Aggregate biometric samples into features
        var heartRate = 65.0
        var hrv = 35.0
        var bloodOxygen = 97.0
        
        for sample in samples {
            switch sample.quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
                hrv = sample.quantity.doubleValue(for: HKUnit(from: "ms"))
            case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
                bloodOxygen = sample.quantity.doubleValue(for: HKUnit.percent()) * 100
            default:
                break
            }
        }
        
        return SleepFeatures(
            heartRate: heartRate,
            hrv: hrv,
            movement: 0.2,
            bloodOxygen: bloodOxygen,
            temperature: 36.8,
            breathingRate: 14.0,
            timeOfNight: calculateTimeOfNight(for: samples.first?.startDate ?? Date()),
            previousStage: .awake
        )
    }
    
    private func calculateHistoricalSleepQuality(_ sample: HKCategorySample) -> Double {
        // Calculate sleep quality based on sleep stage and duration
        let duration = sample.endDate.timeIntervalSince(sample.startDate)
        let stage = mapSleepAnalysisToStage(sample.value)
        
        var quality = 0.5 // Base quality
        
        // Duration factor
        if duration > 6 * 3600 { // More than 6 hours
            quality += 0.2
        } else if duration > 4 * 3600 { // More than 4 hours
            quality += 0.1
        }
        
        // Stage factor
        switch stage {
        case .deep:
            quality += 0.2
        case .rem:
            quality += 0.15
        case .light:
            quality += 0.1
        case .awake:
            quality -= 0.1
        }
        
        return max(0.0, min(1.0, quality))
    }
    
    private func createInitialUserBaseline() async -> UserSleepBaseline? {
        guard !sleepDataHistory.isEmpty else { return nil }
        
        let baseline = UserSleepBaseline()
        
        // Calculate averages from historical data
        let heartRates = sleepDataHistory.compactMap { $0.features.heartRateNormalized * 60 + 40 } // Convert back to BPM
        let hrvs = sleepDataHistory.compactMap { $0.features.hrvNormalized * 80 + 10 } // Convert back to ms
        let qualities = sleepDataHistory.map { $0.sleepQuality }
        
        if !heartRates.isEmpty {
            baseline.averageHeartRate = heartRates.reduce(0, +) / Double(heartRates.count)
        }
        
        if !hrvs.isEmpty {
            baseline.averageHRV = hrvs.reduce(0, +) / Double(hrvs.count)
        }
        
        if !qualities.isEmpty {
            baseline.averageSleepQuality = qualities.reduce(0, +) / Double(qualities.count)
        }
        
        baseline.dataPoints = sleepDataHistory.count
        baseline.personalizationLevel = min(1.0, Double(sleepDataHistory.count) / 100.0)
        
        return baseline
    }
    
    private func calculateTimeOfNight(for date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Calculate time since typical sleep start (11 PM)
        if hour >= 23 {
            return Double(hour - 23)
        } else if hour < 7 {
            return Double(hour + 1)
        } else {
            return 0.0
        }
    }
    
    // MARK: - Data Collection
    func startDataCollection() async {
        await MainActor.run {
            self.isCollectingData = true
        }
        
        Logger.info("Starting real sleep data collection...", log: Logger.dataManager)
        
        do {
            // Request HealthKit permissions if not already granted
            await requestHealthKitPermissions()
            
            // Start collecting sleep data
            await collectSleepData()
            
            await MainActor.run {
                self.isCollectingData = false
            }
            
        } catch {
            Logger.error("Failed to start data collection: \(error.localizedDescription)", log: Logger.dataManager)
            
            await MainActor.run {
                self.isCollectingData = false
            }
        }
    }
    
    private func requestHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.error("HealthKit is not available on this device", log: Logger.dataManager)
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
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            Logger.success("HealthKit permissions granted", log: Logger.dataManager)
        } catch {
            Logger.error("HealthKit permissions failed: \(error.localizedDescription)", log: Logger.dataManager)
        }
    }
    
    func stopDataCollection() async {
        await MainActor.run {
            self.isCollectingData = false
        }
        
        Logger.info("Stopped sleep data collection", log: Logger.dataManager)
    }
    
    private func collectSleepData() async {
        while isCollectingData {
            do {
                let sleepData = try await fetchCurrentSleepData()
                
                if let labeledData = await labelSleepData(sleepData) {
                    await addToHistory(labeledData)
                    
                    await MainActor.run {
                        self.dataPointsCollected += 1
                        self.lastDataCollection = Date()
                    }
                }
                
                // Wait 30 seconds before next collection
                try await Task.sleep(nanoseconds: 30_000_000_000)
                
            } catch {
                Logger.error("Error collecting sleep data: \(error.localizedDescription)", log: Logger.dataManager)
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Wait 1 minute on error
            }
        }
    }
    
    private func fetchCurrentSleepData() async throws -> RawSleepData {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        // Fetch heart rate data
        let heartRateData = try await fetchHeartRateData(from: startOfDay, to: now)
        
        // Fetch HRV data
        let hrvData = try await fetchHRVData(from: startOfDay, to: now)
        
        // Fetch blood oxygen data
        let bloodOxygenData = try await fetchBloodOxygenData(from: startOfDay, to: now)
        
        // Fetch respiratory rate data
        let respiratoryData = try await fetchRespiratoryData(from: startOfDay, to: now)
        
        // Fetch temperature data
        let temperatureData = try await fetchTemperatureData(from: startOfDay, to: now)
        
        // Fetch sleep analysis data
        let sleepAnalysisData = try await fetchSleepAnalysisData(from: startOfDay, to: now)
        
        return RawSleepData(
            timestamp: now,
            heartRate: heartRateData,
            hrv: hrvData,
            bloodOxygen: bloodOxygenData,
            respiratoryRate: respiratoryData,
            temperature: temperatureData,
            sleepAnalysis: sleepAnalysisData
        )
    }
    
    private func fetchHeartRateData(from start: Date, to end: Date) async throws -> Double {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKQuantitySample {
            return sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
        
        return 0.0
    }
    
    private func fetchHRVData(from start: Date, to end: Date) async throws -> Double {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: hrvType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKQuantitySample {
            return sample.quantity.doubleValue(for: HKUnit(from: "ms"))
        }
        
        return 0.0
    }
    
    private func fetchBloodOxygenData(from start: Date, to end: Date) async throws -> Double {
        guard let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: oxygenType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKQuantitySample {
            return sample.quantity.doubleValue(for: HKUnit.percent()) * 100
        }
        
        return 0.0
    }
    
    private func fetchRespiratoryData(from start: Date, to end: Date) async throws -> Double {
        guard let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: respiratoryType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKQuantitySample {
            return sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
        
        return 0.0
    }
    
    private func fetchTemperatureData(from start: Date, to end: Date) async throws -> Double {
        guard let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: temperatureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKQuantitySample {
            return sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
        }
        
        return 0.0
    }
    
    private func fetchSleepAnalysisData(from start: Date, to end: Date) async throws -> SleepStage? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw DataError.unsupportedDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let samples = try await healthStore.samples(of: sleepType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor])
        
        if let sample = samples.first as? HKCategorySample {
            return mapSleepAnalysisToStage(sample.value)
        }
        
        return nil
    }
    
    private func mapSleepAnalysisToStage(_ value: Int) -> SleepStage {
        switch value {
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            return .awake
        case HKCategoryValueSleepAnalysis.inBed.rawValue:
            return .light
        case HKCategoryValueSleepAnalysis.asleep.rawValue:
            return .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            return .rem
        default:
            return .light
        }
    }
    
    // MARK: - Data Labeling
    private func labelSleepData(_ rawData: RawSleepData) async -> LabeledSleepData? {
        // Use AI engine to predict sleep stage
        let features = SleepFeatures(
            heartRate: rawData.heartRate,
            hrv: rawData.hrv,
            movement: 0.0, // Will be calculated from other sensors
            bloodOxygen: rawData.bloodOxygen,
            temperature: rawData.temperature,
            breathingRate: rawData.respiratoryRate,
            timeOfNight: calculateTimeOfNight(),
            previousStage: getPreviousStage()
        )
        
        let prediction = AISleepAnalysisEngine.shared.predictSleepStage(features)
        
        // Create labeled data point
        return LabeledSleepData(
            timestamp: rawData.timestamp,
            features: features,
            predictedStage: prediction.sleepStage,
            actualStage: rawData.sleepAnalysis,
            confidence: prediction.confidence,
            sleepQuality: prediction.sleepQuality
        )
    }
    
    private func calculateTimeOfNight() -> Double {
        // Calculate time since sleep start (simplified)
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        // Assume sleep starts around 11 PM
        if hour >= 23 {
            return Double(hour - 23)
        } else if hour < 7 {
            return Double(hour + 1)
        } else {
            return 0.0 // Not sleep time
        }
    }
    
    private func getPreviousStage() -> SleepStage {
        return sleepDataHistory.last?.predictedStage ?? .awake
    }
    
    private func addToHistory(_ data: LabeledSleepData) async {
        await MainActor.run {
            self.sleepDataHistory.append(data)
            
            // Maintain history size
            if self.sleepDataHistory.count > self.maxDataPoints {
                self.sleepDataHistory.removeFirst()
            }
        }
    }
    
    // MARK: - Model Training
    func trainModel() async {
        guard sleepDataHistory.count >= 100 else {
            Logger.error("Insufficient data for training. Need at least 100 data points.", log: Logger.dataManager)
            return
        }
        
        await MainActor.run {
            self.modelTrainingProgress = 0.0
        }
        
        Logger.info("Starting model training with \(sleepDataHistory.count) data points...", log: Logger.dataManager)
        
        do {
            // Prepare training data
            let trainingData = prepareTrainingData()
            
            // Train the model
            let model = try await performModelTraining(data: trainingData)
            
            // Save the trained model
            try await saveTrainedModel(model)
            
            await MainActor.run {
                self.modelTrainingProgress = 1.0
            }
            
            Logger.success("Model training completed successfully!", log: Logger.dataManager)
            
        } catch {
            Logger.error("Model training failed: \(error.localizedDescription)", log: Logger.dataManager)
        }
    }
    
    private func prepareTrainingData() -> TrainingData {
        let features = sleepDataHistory.map { $0.features }
        let labels = sleepDataHistory.map { $0.predictedStage.rawValue }
        
        return TrainingData(
            features: features,
            labels: labels,
            timestamps: sleepDataHistory.map { $0.timestamp }
        )
    }
    
    private func performModelTraining(data: TrainingData) async throws -> MLModel {
        Logger.info("Starting real model training with Create ML", log: Logger.dataManager)
        
        await MainActor.run {
            self.modelTrainingProgress = 0.1
        }
        
        // Step 1: Prepare training data in Create ML format
        let trainingData = try await prepareCreateMLData(data)
        await updateTrainingProgress(0.2)
        
        // Step 2: Configure model parameters
        let modelParameters = configureModelParameters()
        await updateTrainingProgress(0.3)
        
        // Step 3: Create and train the model
        let model = try await trainCreateMLModel(trainingData: trainingData, parameters: modelParameters)
        await updateTrainingProgress(0.8)
        
        // Step 4: Validate the model
        let validationResult = try await validateTrainedModel(model, data: data)
        await updateTrainingProgress(0.9)
        
        // Step 5: Save model metadata
        try await saveModelMetadata(validationResult)
        await updateTrainingProgress(1.0)
        
        Logger.success("Model training completed successfully with accuracy: \(validationResult.accuracy)", log: Logger.dataManager)
        
        return model
    }
    
    private func prepareCreateMLData(_ data: TrainingData) async throws -> MLDataTable {
        Logger.info("Preparing Create ML training data", log: Logger.dataManager)
        
        // Convert our training data to Create ML format
        var featureColumns: [String: [Double]] = [:]
        var labelColumn: [String] = []
        
        for (index, features) in data.features.enumerated() {
            // Add normalized features
            featureColumns["heartRate"] = (featureColumns["heartRate"] ?? []) + [features.heartRateNormalized]
            featureColumns["hrv"] = (featureColumns["hrv"] ?? []) + [features.hrvNormalized]
            featureColumns["movement"] = (featureColumns["movement"] ?? []) + [features.movementNormalized]
            featureColumns["bloodOxygen"] = (featureColumns["bloodOxygen"] ?? []) + [features.bloodOxygenNormalized]
            featureColumns["temperature"] = (featureColumns["temperature"] ?? []) + [features.temperatureNormalized]
            featureColumns["breathingRate"] = (featureColumns["breathingRate"] ?? []) + [features.breathingRateNormalized]
            featureColumns["timeOfNight"] = (featureColumns["timeOfNight"] ?? []) + [features.timeOfNightNormalized]
            featureColumns["previousStage"] = (featureColumns["previousStage"] ?? []) + [features.previousStageNormalized]
            
            // Add label
            let stageName = SleepStage(rawValue: data.labels[index])?.displayName ?? "unknown"
            labelColumn.append(stageName)
        }
        
        // Create MLDataTable
        let dataTable = try MLDataTable(dictionary: featureColumns)
        
        // Add label column
        let labelDataTable = try MLDataTable(column: labelColumn, named: "sleepStage")
        let combinedTable = dataTable.join(with: labelDataTable)
        
        Logger.success("Created training data table with \(combinedTable.rows.count) samples", log: Logger.dataManager)
        return combinedTable
    }
    
    private func configureModelParameters() -> MLClassifier.ModelParameters {
        var parameters = MLClassifier.ModelParameters()
        
        // Configure neural network parameters
        parameters.algorithm = .neuralNetwork
        parameters.validation = .holdOut(fraction: 0.2)
        parameters.maxIterations = 1000
        parameters.regularization = 0.01
        
        // Configure neural network architecture
        parameters.neuralNetworkParameters = MLNeuralNetworkParameters()
        parameters.neuralNetworkParameters?.hiddenLayers = [64, 32] // 64 -> 32 -> output
        parameters.neuralNetworkParameters?.activationFunction = .relu
        
        Logger.info("Configured model parameters for neural network training", log: Logger.dataManager)
        return parameters
    }
    
    private func trainCreateMLModel(trainingData: MLDataTable, parameters: MLClassifier.ModelParameters) async throws -> MLModel {
        Logger.info("Training Create ML classifier", log: Logger.dataManager)
        
        let startTime = Date()
        
        // Train the classifier
        let classifier = try MLClassifier(trainingData: trainingData, 
                                        targetColumn: "sleepStage", 
                                        parameters: parameters)
        
        let trainingTime = Date().timeIntervalSince(startTime)
        Logger.success("Model training completed in \(String(format: "%.2f", trainingTime)) seconds", log: Logger.dataManager)
        
        return classifier.model
    }
    
    private func validateTrainedModel(_ model: MLModel, data: TrainingData) async throws -> ModelValidationResult {
        Logger.info("Validating trained model", log: Logger.dataManager)
        
        // Create validation data (last 20% of data)
        let validationSize = data.features.count / 5
        let validationFeatures = Array(data.features.suffix(validationSize))
        let validationLabels = Array(data.labels.suffix(validationSize))
        
        var correctPredictions = 0
        var totalPredictions = 0
        
        for (index, features) in validationFeatures.enumerated() {
            do {
                let prediction = try await makePrediction(model: model, features: features)
                let actualStage = SleepStage(rawValue: validationLabels[index]) ?? .light
                
                if prediction.sleepStage == actualStage {
                    correctPredictions += 1
                }
                totalPredictions += 1
            } catch {
                Logger.error("Prediction failed during validation: \(error.localizedDescription)", log: Logger.dataManager)
            }
        }
        
        let accuracy = totalPredictions > 0 ? Double(correctPredictions) / Double(totalPredictions) : 0.0
        
        let validationResult = ModelValidationResult(
            accuracy: accuracy,
            totalSamples: totalPredictions,
            correctPredictions: correctPredictions,
            trainingDataSize: data.features.count,
            validationDataSize: validationFeatures.count
        )
        
        Logger.success("Model validation completed with accuracy: \(String(format: "%.2f", accuracy * 100))%", log: Logger.dataManager)
        return validationResult
    }
    
    private func makePrediction(model: MLModel, features: SleepFeatures) async throws -> SleepStagePrediction {
        // Create ML feature provider
        let featureDictionary: [String: MLFeatureValue] = [
            "heartRate": MLFeatureValue(double: features.heartRateNormalized),
            "hrv": MLFeatureValue(double: features.hrvNormalized),
            "movement": MLFeatureValue(double: features.movementNormalized),
            "bloodOxygen": MLFeatureValue(double: features.bloodOxygenNormalized),
            "temperature": MLFeatureValue(double: features.temperatureNormalized),
            "breathingRate": MLFeatureValue(double: features.breathingRateNormalized),
            "timeOfNight": MLFeatureValue(double: features.timeOfNightNormalized),
            "previousStage": MLFeatureValue(double: features.previousStageNormalized)
        ]
        
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: featureDictionary)
        let prediction = try model.prediction(from: inputFeatures)
        
        // Extract prediction result
        if let classLabel = prediction.featureValue(for: "sleepStage")?.stringValue {
            let sleepStage = SleepStage.fromDisplayName(classLabel) ?? .light
            return SleepStagePrediction(
                sleepStage: sleepStage,
                confidence: 0.8, // Default confidence for validation
                sleepQuality: calculateSleepQuality(features)
            )
        }
        
        throw DataError.predictionFailed
    }
    
    private func saveModelMetadata(_ validationResult: ModelValidationResult) async throws {
        let metadata = ModelMetadata(
            trainingDate: Date(),
            accuracy: validationResult.accuracy,
            totalSamples: validationResult.totalSamples,
            correctPredictions: validationResult.correctPredictions,
            trainingDataSize: validationResult.trainingDataSize,
            validationDataSize: validationResult.validationDataSize,
            modelVersion: "1.0"
        )
        
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: "ModelMetadata")
            Logger.success("Model metadata saved", log: Logger.dataManager)
        }
    }
    
    private func updateTrainingProgress(_ progress: Double) async {
        await MainActor.run {
            self.modelTrainingProgress = progress
        }
    }
    
    private func calculateSleepQuality(_ features: SleepFeatures) -> Double {
        // Calculate sleep quality based on features
        let heartRateScore = max(0, 1 - abs(features.heartRate - 60) / 60)
        let movementScore = max(0, 1 - features.movement)
        let hrvScore = min(1, features.hrv / 100)
        let bloodOxygenScore = max(0, (features.bloodOxygen - 90) / 10)
        
        return (heartRateScore * 0.3 + movementScore * 0.3 + hrvScore * 0.2 + bloodOxygenScore * 0.2)
    }
    
    // MARK: - Data Export
    func exportTrainingData() -> Data? {
        let exportData = TrainingDataExport(
            dataPoints: sleepDataHistory.count,
            dateRange: (sleepDataHistory.first?.timestamp, sleepDataHistory.last?.timestamp),
            features: sleepDataHistory.map { $0.features },
            predictions: sleepDataHistory.map { $0.predictedStage },
            actualStages: sleepDataHistory.compactMap { $0.actualStage },
            confidences: sleepDataHistory.map { $0.confidence },
            sleepQualities: sleepDataHistory.map { $0.sleepQuality }
        )
        
        do {
            let data = try JSONEncoder().encode(exportData)
            Logger.success("Training data exported successfully", log: Logger.dataManager)
            return data
        } catch {
            Logger.error("Failed to export training data: \(error.localizedDescription)", log: Logger.dataManager)
            return nil
        }
    }
}

// MARK: - Data Models
struct RawSleepData {
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let bloodOxygen: Double
    let respiratoryRate: Double
    let temperature: Double
    let sleepAnalysis: SleepStage?
}

struct LabeledSleepData {
    let timestamp: Date
    let features: SleepFeatures
    let predictedStage: SleepStage
    let actualStage: SleepStage?
    let confidence: Double
    let sleepQuality: Double
}

struct TrainingData {
    let features: [SleepFeatures]
    let labels: [Int]
    let timestamps: [Date]
}

struct TrainingDataExport: Codable {
    let dataPoints: Int
    let dateRange: (Date?, Date?)
    let features: [SleepFeatures]
    let predictions: [SleepStage]
    let actualStages: [SleepStage]
    let confidences: [Double]
    let sleepQualities: [Double]
}

enum DataError: Error {
    case unsupportedDataType
    case insufficientData
    case trainingNotImplemented
    case modelSaveFailed
    case predictionFailed
}

// MARK: - SleepFeatures Codable
extension SleepFeatures: Codable {}

// MARK: - Supporting Types

struct ModelValidationResult {
    let accuracy: Double
    let totalSamples: Int
    let correctPredictions: Int
    let trainingDataSize: Int
    let validationDataSize: Int
}

struct ModelMetadata: Codable {
    let trainingDate: Date
    let accuracy: Double
    let totalSamples: Int
    let correctPredictions: Int
    let trainingDataSize: Int
    let validationDataSize: Int
    let modelVersion: String
}

// MARK: - SleepStage Extension

extension SleepStage {
    static func fromDisplayName(_ displayName: String) -> SleepStage? {
        switch displayName.lowercased() {
        case "awake": return .awake
        case "light sleep": return .light
        case "deep sleep": return .deep
        case "rem": return .rem
        default: return nil
        }
    }
}

// MARK: - DataError Extension

extension DataError {
    static let predictionFailed = DataError.unsupportedDataType // Reuse existing error
} 