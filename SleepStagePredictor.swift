import Foundation
import CoreML
import os.log

/// SleepStagePredictor - Real Core ML model for sleep stage prediction with personalization
class SleepStagePredictor {
    private var model: SleepStagePredictorModel?
    private var personalizedThresholds: PersonalizedThresholds?
    private let fallbackAccuracy: Double = 0.65
    private let modelURL: URL
    
    init() {
        // Get the model URL from the app bundle
        self.modelURL = Bundle.main.url(forResource: "SleepStagePredictor", withExtension: "mlmodel") ?? URL(fileURLWithPath: "")
        loadModel()
        loadPersonalizedThresholds()
    }
    
    private func loadModel() {
        do {
            // Compile the model if needed
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            model = try SleepStagePredictorModel(contentsOf: compiledModelURL)
            Logger.success("Core ML model loaded successfully", log: Logger.aiEngine)
        } catch {
            Logger.error("Failed to load Core ML model: \(error.localizedDescription)", log: Logger.aiEngine)
            Logger.info("Using fallback prediction algorithm", log: Logger.aiEngine)
        }
    }
    
    private func loadPersonalizedThresholds() {
        if let data = UserDefaults.standard.data(forKey: "PersonalizedThresholds"),
           let thresholds = try? JSONDecoder().decode(PersonalizedThresholds.self, from: data) {
            self.personalizedThresholds = thresholds
            Logger.info("Loaded personalized thresholds for user", log: Logger.aiEngine)
        } else {
            Logger.info("Using default thresholds", log: Logger.aiEngine)
        }
    }
    
    func predictSleepStage(_ features: SleepFeatures) -> SleepStagePrediction {
        guard let model = model else {
            Logger.info("Core ML model not found, using fallback prediction", log: Logger.aiEngine)
            return fallbackPrediction(for: features)
        }
        
        do {
            // Create input for the real ML model
            let input = try createMLInput(from: features)
            let prediction = try model.prediction(input: input)
            
            // Extract prediction results
            let sleepStage = extractSleepStage(from: prediction)
            let confidence = extractConfidence(from: prediction)
            let sleepQuality = calculateSleepQuality(features)
            
            return SleepStagePrediction(
                sleepStage: sleepStage,
                confidence: confidence,
                sleepQuality: sleepQuality
            )
        } catch {
            Logger.error("ML prediction failed: \(error.localizedDescription)", log: Logger.aiEngine)
            return fallbackPrediction(for: features)
        }
    }
    
    private func createMLInput(from features: SleepFeatures) throws -> MLFeatureProvider {
        // Create input dictionary for the Core ML model
        let inputDictionary: [String: MLFeatureValue] = [
            "heartRate": MLFeatureValue(double: features.heartRateNormalized),
            "hrv": MLFeatureValue(double: features.hrvNormalized),
            "movement": MLFeatureValue(double: features.movementNormalized),
            "bloodOxygen": MLFeatureValue(double: features.bloodOxygenNormalized),
            "temperature": MLFeatureValue(double: features.temperatureNormalized),
            "breathingRate": MLFeatureValue(double: features.breathingRateNormalized),
            "timeOfNight": MLFeatureValue(double: features.timeOfNightNormalized),
            "previousStage": MLFeatureValue(double: features.previousStageNormalized)
        ]
        
        return try MLDictionaryFeatureProvider(dictionary: inputDictionary)
    }
    
    private func extractSleepStage(from prediction: MLFeatureProvider) -> SleepStage {
        // Extract the predicted sleep stage from the model output
        // The model returns probabilities for each class
        let awakeProb = prediction.featureValue(for: "awakeProbability")?.doubleValue ?? 0.0
        let lightProb = prediction.featureValue(for: "lightProbability")?.doubleValue ?? 0.0
        let deepProb = prediction.featureValue(for: "deepProbability")?.doubleValue ?? 0.0
        let remProb = prediction.featureValue(for: "remProbability")?.doubleValue ?? 0.0
        
        // Find the most likely stage
        let probabilities = [awakeProb, lightProb, deepProb, remProb]
        let maxIndex = probabilities.enumerated().max(by: { $0.element < $1.element })?.offset ?? 1
        
        switch maxIndex {
        case 0: return .awake
        case 1: return .light
        case 2: return .deep
        case 3: return .rem
        default: return .light
        }
    }
    
    private func extractConfidence(from prediction: MLFeatureProvider) -> Double {
        // Extract confidence from the model output
        // This could be based on the highest probability or a separate confidence output
        let awakeProb = prediction.featureValue(for: "awakeProbability")?.doubleValue ?? 0.0
        let lightProb = prediction.featureValue(for: "lightProbability")?.doubleValue ?? 0.0
        let deepProb = prediction.featureValue(for: "deepProbability")?.doubleValue ?? 0.0
        let remProb = prediction.featureValue(for: "remProbability")?.doubleValue ?? 0.0
        
        let maxProbability = max(awakeProb, lightProb, deepProb, remProb)
        return maxProbability
    }
    
    private func fallbackPrediction(for features: SleepFeatures) -> SleepStagePrediction {
        // Enhanced rule-based fallback prediction using personalized thresholds
        let heartRate = features.heartRate
        let hrv = features.hrv
        let movement = features.movement
        let bloodOxygen = features.bloodOxygen
        let breathingRate = features.breathingRate
        let timeOfNight = features.timeOfNight
        
        // Calculate probabilities for each stage based on multiple factors
        var stageScores: [SleepStage: Double] = [:]
        
        // Awake stage scoring with personalization
        let awakeScore = calculatePersonalizedAwakeScore(
            heartRate: heartRate, movement: movement, 
            breathingRate: breathingRate, timeOfNight: timeOfNight
        )
        stageScores[.awake] = awakeScore
        
        // Light sleep scoring with personalization
        let lightScore = calculatePersonalizedLightScore(
            heartRate: heartRate, hrv: hrv, movement: movement,
            bloodOxygen: bloodOxygen, timeOfNight: timeOfNight
        )
        stageScores[.light] = lightScore
        
        // Deep sleep scoring with personalization
        let deepScore = calculatePersonalizedDeepScore(
            heartRate: heartRate, hrv: hrv, movement: movement,
            bloodOxygen: bloodOxygen, breathingRate: breathingRate
        )
        stageScores[.deep] = deepScore
        
        // REM sleep scoring with personalization
        let remScore = calculatePersonalizedREMScore(
            heartRate: heartRate, hrv: hrv, movement: movement,
            breathingRate: breathingRate, timeOfNight: timeOfNight
        )
        stageScores[.rem] = remScore
        
        // Find the most likely stage
        let predictedStage = stageScores.max(by: { $0.value < $1.value })?.key ?? .light
        let confidence = stageScores[predictedStage] ?? 0.5
        
        return SleepStagePrediction(
            sleepStage: predictedStage,
            confidence: confidence,
            sleepQuality: calculateSleepQuality(features)
        )
    }
    
    // MARK: - Personalized Scoring Functions
    
    private func calculatePersonalizedAwakeScore(heartRate: Double, movement: Double, breathingRate: Double, timeOfNight: Double) -> Double {
        var score = 0.0
        
        // Use personalized thresholds if available
        if let thresholds = personalizedThresholds {
            if heartRate > thresholds.heartRate.awake { score += 0.3 }
            if movement > thresholds.movement.awake { score += 0.3 }
            if breathingRate > thresholds.breathingRate.awake { score += 0.2 }
        } else {
            // Default thresholds
            if heartRate > 70 { score += 0.3 }
            if heartRate > 80 { score += 0.2 }
            if movement > 0.5 { score += 0.3 }
            if movement > 0.8 { score += 0.2 }
            if breathingRate > 16 { score += 0.2 }
        }
        
        // Early or late in sleep cycle
        if timeOfNight < 1 || timeOfNight > 7 { score += 0.1 }
        
        return min(score, 1.0)
    }
    
    private func calculatePersonalizedLightScore(heartRate: Double, hrv: Double, movement: Double, bloodOxygen: Double, timeOfNight: Double) -> Double {
        var score = 0.0
        
        // Use personalized thresholds if available
        if let thresholds = personalizedThresholds {
            let hrThreshold = thresholds.heartRate.light
            let hrvThreshold = thresholds.hrv.light
            let movementThreshold = thresholds.movement.light
            
            if abs(heartRate - hrThreshold) < 10 { score += 0.3 }
            if abs(hrv - hrvThreshold) < 15 { score += 0.2 }
            if abs(movement - movementThreshold) < 0.2 { score += 0.2 }
        } else {
            // Default thresholds
            if 55 <= heartRate && heartRate <= 70 { score += 0.3 }
            if 20 <= hrv && hrv <= 45 { score += 0.2 }
            if 0.1 <= movement && movement <= 0.4 { score += 0.2 }
        }
        
        // Good blood oxygen
        if bloodOxygen > 95 { score += 0.1 }
        
        // Early in sleep cycle
        if 1 <= timeOfNight && timeOfNight <= 3 { score += 0.2 }
        
        return min(score, 1.0)
    }
    
    private func calculatePersonalizedDeepScore(heartRate: Double, hrv: Double, movement: Double, bloodOxygen: Double, breathingRate: Double) -> Double {
        var score = 0.0
        
        // Use personalized thresholds if available
        if let thresholds = personalizedThresholds {
            if heartRate < thresholds.heartRate.deep { score += 0.3 }
            if hrv > thresholds.hrv.deep { score += 0.3 }
            if movement < thresholds.movement.deep { score += 0.3 }
            if breathingRate < thresholds.breathingRate.deep { score += 0.1 }
        } else {
            // Default thresholds
            if heartRate < 60 { score += 0.3 }
            if heartRate < 50 { score += 0.2 }
            if hrv > 40 { score += 0.3 }
            if movement < 0.2 { score += 0.3 }
            if movement < 0.1 { score += 0.2 }
            if breathingRate < 14 { score += 0.1 }
        }
        
        // Good blood oxygen
        if bloodOxygen > 96 { score += 0.1 }
        
        return min(score, 1.0)
    }
    
    private func calculatePersonalizedREMScore(heartRate: Double, hrv: Double, movement: Double, breathingRate: Double, timeOfNight: Double) -> Double {
        var score = 0.0
        
        // Use personalized thresholds if available
        if let thresholds = personalizedThresholds {
            let hrThreshold = thresholds.heartRate.light // REM is similar to light for HR
            let hrvThreshold = thresholds.hrv.light
            let movementThreshold = thresholds.movement.light
            
            if abs(heartRate - hrThreshold) < 15 { score += 0.2 }
            if abs(hrv - hrvThreshold) < 20 { score += 0.2 }
            if abs(movement - movementThreshold) < 0.3 { score += 0.2 }
        } else {
            // Default thresholds
            if 60 <= heartRate && heartRate <= 80 { score += 0.2 }
            if 25 <= hrv && hrv <= 50 { score += 0.2 }
            if 0.2 <= movement && movement <= 0.6 { score += 0.2 }
        }
        
        // Variable breathing
        if 14 <= breathingRate && breathingRate <= 18 { score += 0.2 }
        
        // Later in sleep cycle (REM typically occurs later)
        if 3 <= timeOfNight && timeOfNight <= 6 { score += 0.2 }
        
        return min(score, 1.0)
    }
    
    private func calculateSleepQuality(_ features: SleepFeatures) -> Double {
        // Enhanced sleep quality calculation with personalization
        let heartRateScore = calculatePersonalizedHeartRateScore(features.heartRate)
        let movementScore = max(0, 1 - features.movement)
        let hrvScore = min(1, features.hrv / 100)
        let bloodOxygenScore = max(0, (features.bloodOxygen - 90) / 10)
        let breathingScore = calculatePersonalizedBreathingScore(features.breathingRate)
        
        // Weighted average
        let quality = (heartRateScore * 0.25 + 
                      movementScore * 0.25 + 
                      hrvScore * 0.2 + 
                      bloodOxygenScore * 0.15 + 
                      breathingScore * 0.15)
        
        return min(1.0, max(0.0, quality))
    }
    
    private func calculatePersonalizedHeartRateScore(_ heartRate: Double) -> Double {
        if let thresholds = personalizedThresholds {
            // Calculate optimal heart rate based on user's patterns
            let optimalHR = (thresholds.heartRate.deep + thresholds.heartRate.light) / 2
            return max(0, 1 - abs(heartRate - optimalHR) / optimalHR)
        } else {
            // Default calculation
            return max(0, 1 - abs(heartRate - 60) / 60)
        }
    }
    
    private func calculatePersonalizedBreathingScore(_ breathingRate: Double) -> Double {
        if let thresholds = personalizedThresholds {
            // Calculate optimal breathing rate based on user's patterns
            let optimalBR = (thresholds.breathingRate.deep + thresholds.breathingRate.light) / 2
            return max(0, 1 - abs(breathingRate - optimalBR) / optimalBR)
        } else {
            // Default calculation
            return max(0, 1 - abs(breathingRate - 14) / 10)
        }
    }
}

/// Enhanced sleep features for ML prediction with personalization
struct SleepFeatures {
    let heartRate: Double
    let hrv: Double
    let movement: Double
    let bloodOxygen: Double
    let temperature: Double
    let breathingRate: Double
    let timeOfNight: Double
    let previousStage: SleepStage
    
    // Normalized versions for ML with personalization
    var heartRateNormalized: Double { 
        if let thresholds = getPersonalizedThresholds() {
            return normalizeWithPersonalizedRange(heartRate, min: thresholds.heartRate.deep, max: thresholds.heartRate.awake)
        }
        return Self.normalizeHeartRate(heartRate)
    }
    
    var hrvNormalized: Double { 
        if let thresholds = getPersonalizedThresholds() {
            return normalizeWithPersonalizedRange(hrv, min: thresholds.hrv.awake, max: thresholds.hrv.deep)
        }
        return Self.normalizeHRV(hrv)
    }
    
    var movementNormalized: Double { Self.normalizeMovement(movement) }
    var bloodOxygenNormalized: Double { Self.normalizeBloodOxygen(bloodOxygen) }
    var temperatureNormalized: Double { Self.normalizeTemperature(temperature) }
    
    var breathingRateNormalized: Double { 
        if let thresholds = getPersonalizedThresholds() {
            return normalizeWithPersonalizedRange(breathingRate, min: thresholds.breathingRate.deep, max: thresholds.breathingRate.awake)
        }
        return Self.normalizeBreathingRate(breathingRate)
    }
    
    var timeOfNightNormalized: Double { Self.normalizeTimeOfNight(timeOfNight) }
    var previousStageNormalized: Double { Double(previousStage.rawValue) / 3.0 }
    
    init(
        heartRate: Double,
        hrv: Double,
        movement: Double,
        bloodOxygen: Double,
        temperature: Double,
        breathingRate: Double,
        timeOfNight: Double,
        previousStage: SleepStage
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.movement = movement
        self.bloodOxygen = bloodOxygen
        self.temperature = temperature
        self.breathingRate = breathingRate
        self.timeOfNight = timeOfNight
        self.previousStage = previousStage
    }
    
    private func getPersonalizedThresholds() -> PersonalizedThresholds? {
        if let data = UserDefaults.standard.data(forKey: "PersonalizedThresholds"),
           let thresholds = try? JSONDecoder().decode(PersonalizedThresholds.self, from: data) {
            return thresholds
        }
        return nil
    }
    
    private func normalizeWithPersonalizedRange(_ value: Double, min: Double, max: Double) -> Double {
        return max(0, min(1, (value - min) / (max - min)))
    }
    
    // Default normalization functions
    static func normalizeHeartRate(_ heartRate: Double) -> Double {
        return max(0, min(1, (heartRate - 40) / 60))
    }
    
    static func normalizeHRV(_ hrv: Double) -> Double {
        return max(0, min(1, (hrv - 10) / 70))
    }
    
    static func normalizeMovement(_ movement: Double) -> Double {
        return max(0, min(1, movement))
    }
    
    static func normalizeBloodOxygen(_ bloodOxygen: Double) -> Double {
        return max(0, min(1, (bloodOxygen - 90) / 10))
    }
    
    static func normalizeTemperature(_ temperature: Double) -> Double {
        return max(0, min(1, (temperature - 35) / 3))
    }
    
    static func normalizeBreathingRate(_ breathingRate: Double) -> Double {
        return max(0, min(1, (breathingRate - 8) / 17))
    }
    
    static func normalizeTimeOfNight(_ timeOfNight: Double) -> Double {
        return max(0, min(1, timeOfNight / 8.0))
    }
}

/// Enhanced sleep stage prediction with ML probabilities and personalization
struct SleepStagePrediction {
    let sleepStage: SleepStage
    let confidence: Double
    let sleepQuality: Double
    
    init(sleepStage: SleepStage, confidence: Double, sleepQuality: Double) {
        self.sleepStage = sleepStage
        self.confidence = confidence
        self.sleepQuality = sleepQuality
    }
}

// MARK: - Production-Grade Core ML Model Integration

/// Production-grade Core ML model wrapper for sleep stage prediction
class SleepStagePredictorModel {
    private var model: MLModel?
    private var isModelLoaded = false
    private let modelURL: URL
    
    init(contentsOf url: URL) throws {
        self.modelURL = url
        try loadModel()
    }
    
    private func loadModel() throws {
        do {
            // Load and compile the Core ML model
            let compiledModelURL = try MLModel.compileModel(at: modelURL)
            self.model = try MLModel(contentsOf: compiledModelURL)
            self.isModelLoaded = true
            
            Logger.success("Core ML model loaded successfully", log: Logger.ml)
        } catch {
            Logger.error("Failed to load Core ML model: \(error.localizedDescription)", log: Logger.ml)
            throw error
        }
    }
    
    func prediction(input: MLFeatureProvider) throws -> MLFeatureProvider {
        guard let model = model, isModelLoaded else {
            throw SleepStagePredictorError.modelNotLoaded
        }
        
        do {
            let prediction = try model.prediction(from: input)
            return prediction
        } catch {
            Logger.error("Model prediction failed: \(error.localizedDescription)", log: Logger.ml)
            throw error
        }
    }
    
    func isAvailable() -> Bool {
        return isModelLoaded && model != nil
    }
    
    func getModelInfo() -> ModelInfo {
        guard let model = model else {
            return ModelInfo(name: "Unknown", version: "Unknown", description: "Model not loaded")
        }
        
        return ModelInfo(
            name: model.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as? String ?? "SleepStagePredictor",
            version: model.modelDescription.metadata[MLModelMetadataKey.versionStringKey] as? String ?? "1.0",
            description: model.modelDescription.metadata[MLModelMetadataKey.descriptionKey] as? String ?? "Sleep stage prediction model"
        )
    }
}

// MARK: - Supporting Types

struct ModelInfo {
    let name: String
    let version: String
    let description: String
}

enum SleepStagePredictorError: Error {
    case modelNotLoaded
    case invalidInput
    case predictionFailed
    case modelCompilationFailed
}

// MARK: - Enhanced Prediction with Real ML Model

extension SleepStagePredictor {
    
    /// Enhanced prediction using real Core ML model with fallback
    func predictWithRealModel(features: SleepFeatures) -> SleepStagePrediction {
        guard let model = sleepStagePredictorModel, model.isAvailable() else {
            Logger.warning("Real ML model not available, using fallback prediction", log: Logger.ml)
            return createFallbackPrediction(for: features)
        }
        
        do {
            // Create ML feature provider from our features
            let inputFeatures = createMLFeatures(from: features)
            
            // Get prediction from Core ML model
            let prediction = try model.prediction(input: inputFeatures)
            
            // Extract probabilities from prediction
            let probabilities = extractProbabilities(from: prediction)
            
            // Determine sleep stage with highest probability
            let predictedStage = determineSleepStage(from: probabilities)
            
            // Calculate confidence and sleep quality
            let confidence = calculateConfidence(from: probabilities)
            let sleepQuality = calculateSleepQuality(features)
            
            Logger.success("Real ML prediction completed: \(predictedStage.displayName)", log: Logger.ml)
            
            return SleepStagePrediction(
                sleepStage: predictedStage,
                confidence: confidence,
                sleepQuality: sleepQuality
            )
            
        } catch {
            Logger.error("Real ML prediction failed: \(error.localizedDescription), using fallback", log: Logger.ml)
            return createFallbackPrediction(for: features)
        }
    }
    
    private func createMLFeatures(from features: SleepFeatures) -> MLFeatureProvider {
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
        
        do {
            return try MLDictionaryFeatureProvider(dictionary: featureDictionary)
        } catch {
            Logger.error("Failed to create ML features: \(error.localizedDescription)", log: Logger.ml)
            // Return empty feature provider as fallback
            return try! MLDictionaryFeatureProvider(dictionary: [:])
        }
    }
    
    private func extractProbabilities(from prediction: MLFeatureProvider) -> [SleepStage: Double] {
        var probabilities: [SleepStage: Double] = [:]
        
        // Extract probabilities for each sleep stage
        if let awakeProb = prediction.featureValue(for: "awakeProbability")?.doubleValue {
            probabilities[.awake] = awakeProb
        }
        
        if let lightProb = prediction.featureValue(for: "lightProbability")?.doubleValue {
            probabilities[.light] = lightProb
        }
        
        if let deepProb = prediction.featureValue(for: "deepProbability")?.doubleValue {
            probabilities[.deep] = deepProb
        }
        
        if let remProb = prediction.featureValue(for: "remProbability")?.doubleValue {
            probabilities[.rem] = remProb
        }
        
        // Normalize probabilities if they don't sum to 1
        let total = probabilities.values.reduce(0, +)
        if total > 0 {
            for stage in probabilities.keys {
                probabilities[stage] = probabilities[stage]! / total
            }
        }
        
        return probabilities
    }
    
    private func determineSleepStage(from probabilities: [SleepStage: Double]) -> SleepStage {
        let maxProbability = probabilities.max { $0.value < $1.value }
        return maxProbability?.key ?? .light
    }
    
    private func calculateConfidence(from probabilities: [SleepStage: Double]) -> Double {
        // Calculate confidence based on how clear the prediction is
        let maxProb = probabilities.values.max() ?? 0.0
        let secondMaxProb = probabilities.values.sorted(by: >).dropFirst().first ?? 0.0
        
        // Higher confidence if there's a clear winner
        let confidence = maxProb - secondMaxProb
        return min(1.0, max(0.0, confidence * 2.0)) // Scale to 0-1 range
    }
    
    private func createFallbackPrediction(for features: SleepFeatures) -> SleepStagePrediction {
        // Enhanced fallback prediction using rule-based logic
        let stage = determineFallbackStage(from: features)
        let confidence = 0.6 // Lower confidence for fallback
        let sleepQuality = calculateSleepQuality(features)
        
        return SleepStagePrediction(
            sleepStage: stage,
            confidence: confidence,
            sleepQuality: sleepQuality
        )
    }
    
    private func determineFallbackStage(from features: SleepFeatures) -> SleepStage {
        // Rule-based sleep stage determination
        let heartRate = features.heartRate
        let hrv = features.hrv
        let movement = features.movement
        let breathingRate = features.breathingRate
        let timeOfNight = features.timeOfNight
        
        // Awake: High movement, high heart rate
        if movement > 0.7 || heartRate > 80 {
            return .awake
        }
        
        // Deep sleep: Low heart rate, low HRV, low movement, early in night
        if heartRate < 55 && hrv < 20 && movement < 0.2 && timeOfNight < 3 {
            return .deep
        }
        
        // REM: Variable breathing, moderate heart rate, later in night
        if breathingRate > 16 && breathingRate < 20 && heartRate > 60 && heartRate < 75 && timeOfNight > 2 {
            return .rem
        }
        
        // Default to light sleep
        return .light
    }
} 