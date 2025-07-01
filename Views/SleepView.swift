import SwiftUI
import HealthKit
import AVFoundation
import CoreHaptics
import Combine
import os.log

// MARK: - Custom Colors
extension Color {
    static let somnaPrimary = Color(red: 0.39, green: 0.4, blue: 0.96)
    static let somnaSecondary = Color(red: 0.55, green: 0.47, blue: 0.91)
    static let somnaAccent = Color(red: 0.2, green: 0.8, blue: 0.6)
    static let somnaBackground = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let somnaCardBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
}

// MARK: - Haptic Feedback
class HapticManager {
    static let shared = HapticManager()
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(type)
    }
    
    func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Main Sleep View

struct SleepView: View {
    @StateObject private var sleepManager = SleepManager()
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var appleWatchManager = AppleWatchManager()
    @StateObject private var audioEngine = AudioGenerationEngine()
    @StateObject private var smartAlarm = SmartAlarmSystem()
    
    @State private var showingSleepSession = false
    @State private var showingSettings = false
    @State private var showingAppleWatchSetup = false
    @State private var isAnalyzingHistoricalData = false
    @State private var analysisProgress: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with sleep score
                    SleepScoreHeader(sleepManager: sleepManager)
                    
                    // Sleep session controls
                    SleepSessionControls(
                        sleepManager: sleepManager,
                        showingSession: $showingSleepSession
                    )
                    
                    // Enhanced Audio Controls
                    AudioControlsSection(audioEngine: audioEngine)
                    
                    // Smart alarm section
                    SmartAlarmSection(smartAlarm: smartAlarm)
                    
                    // Apple Watch integration
                    AppleWatchSection(
                        appleWatchManager: appleWatchManager,
                        showingSetup: $showingAppleWatchSetup
                    )
                    
                    // Sleep insights
                    SleepInsightsSection(sleepManager: sleepManager)
                    
                    // Health data summary
                    HealthDataSection(healthKitManager: healthKitManager)
                }
                .padding()
            }
            .navigationTitle("SomnaSync Pro")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSleepSession) {
                SleepSessionView(sleepManager: sleepManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    sleepManager: sleepManager,
                    healthKitManager: healthKitManager,
                    appleWatchManager: appleWatchManager
                )
            }
            .sheet(isPresented: $showingAppleWatchSetup) {
                AppleWatchSetupView(appleWatchManager: appleWatchManager)
            }
            .onAppear {
                setupApp()
            }
            .overlay(
                // Historical data analysis overlay
                Group {
                    if isAnalyzingHistoricalData {
                        HistoricalDataAnalysisOverlay(
                            progress: analysisProgress,
                            onComplete: {
                                isAnalyzingHistoricalData = false
                                analysisProgress = 0.0
                            }
                        )
                    }
                }
            )
        }
    }
    
    private func setupApp() {
        Task {
            // Request HealthKit permissions
            await healthKitManager.requestPermissions()
            
            // Check if historical data analysis is needed
            if !UserDefaults.standard.bool(forKey: "historicalDataAnalyzed") {
                isAnalyzingHistoricalData = true
                await analyzeHistoricalData()
            }
            
            // Start Apple Watch monitoring
            await appleWatchManager.startMonitoring()
        }
    }
    
    private func analyzeHistoricalData() async {
        let dataManager = DataManager()
        
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                analysisProgress = Double(i) / 10.0
            }
        }
        
        await dataManager.analyzeHistoricalData()
        UserDefaults.standard.set(true, forKey: "historicalDataAnalyzed")
    }
}

// MARK: - Initial Analysis View
struct InitialAnalysisView: View {
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Setting Up Your Personal AI")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("SomnaSync Pro is analyzing your historical sleep data to create a personalized AI model just for you.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Progress Section
        VStack(spacing: 16) {
            HStack {
                    Text("Analysis Progress")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(dataManager.historicalAnalysisProgress * 100))%")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: dataManager.historicalAnalysisProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
                
                // Progress Details
                VStack(spacing: 8) {
                    ProgressStep(
                        title: "Requesting Permissions",
                        isCompleted: dataManager.historicalAnalysisProgress >= 0.1,
                        isActive: dataManager.historicalAnalysisProgress >= 0.0 && dataManager.historicalAnalysisProgress < 0.2
                    )
                    
                    ProgressStep(
                        title: "Analyzing Sleep Data",
                        isCompleted: dataManager.historicalAnalysisProgress >= 0.5,
                        isActive: dataManager.historicalAnalysisProgress >= 0.2 && dataManager.historicalAnalysisProgress < 0.5
                    )
                    
                    ProgressStep(
                        title: "Processing Biometrics",
                        isCompleted: dataManager.historicalAnalysisProgress >= 0.8,
                        isActive: dataManager.historicalAnalysisProgress >= 0.5 && dataManager.historicalAnalysisProgress < 0.8
                    )
                    
                    ProgressStep(
                        title: "Establishing Baseline",
                        isCompleted: dataManager.historicalAnalysisProgress >= 1.0,
                        isActive: dataManager.historicalAnalysisProgress >= 0.8 && dataManager.historicalAnalysisProgress < 1.0
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Data Points Counter
            if dataManager.historicalDataPoints > 0 {
                VStack(spacing: 8) {
                    Text("Data Points Analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(dataManager.historicalDataPoints)")
                    .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // Status Message
            VStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("This process only happens once and helps create your personalized sleep AI. The more data available, the better your personalized experience will be.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

// MARK: - Progress Step
struct ProgressStep: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 16, weight: .semibold))
            
            // Title
            Text(title)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
            
            Spacer()
            
            // Progress indicator for active step
            if isActive {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        if isCompleted {
            return "checkmark.circle.fill"
        } else if isActive {
            return "circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - AI Status Header
struct AIStatusHeader: View {
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: aiEngine.isInitialized ? "brain.head.profile" : "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundColor(aiEngine.isInitialized ? .somnaAccent : .orange)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                VStack(alignment: .leading) {
                    Text("AI Sleep Analysis")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(aiEngine.isInitialized ? "Active & Learning" : "Initializing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isAnimating ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(Int(aiEngine.modelAccuracy * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.somnaPrimary)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Personalization Progress
            HStack {
                Text("Personalization")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(aiEngine.personalizationLevel * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.somnaSecondary)
            }
            
            ProgressView(value: aiEngine.personalizationLevel)
                .progressViewStyle(LinearProgressViewStyle(tint: .somnaSecondary))
                .scaleEffect(y: 1.5)
                .animation(.easeInOut(duration: 0.5), value: aiEngine.personalizationLevel)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.somnaCardBackground)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.somnaPrimary.opacity(0.3), .somnaSecondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isAnimating = true
        }
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
    }
}

// MARK: - Current Sleep Status
struct CurrentSleepStatus: View {
    @StateObject private var sleepManager = SleepManager.shared
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                    Text("Current Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                
                Spacer()
                
                if aiEngine.anomalyDetected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .scaleEffect(isPulsing ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                        Text("Anomaly Detected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if let prediction = aiEngine.lastPrediction {
                VStack(spacing: 12) {
                    HStack {
                        SleepStageIcon(stage: prediction.sleepStage)
                            .scaleEffect(isPulsing ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
                        
                        VStack(alignment: .leading) {
                            Text(prediction.sleepStage.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Confidence: \(Int(prediction.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                }
                
                Spacer()
                
                        VStack(alignment: .trailing) {
                            Text("Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(prediction.sleepQuality * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(prediction.isHighQuality ? .somnaAccent : .orange)
                                .scaleEffect(isPulsing ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                        }
                    }
                    
                    // Stage Probabilities
                    StageProbabilitiesView(probabilities: prediction.probabilities)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bed.double")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                    
                    Text("No sleep data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start tracking to see your sleep analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
            }
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.somnaCardBackground)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.somnaPrimary.opacity(0.2), .somnaSecondary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isPulsing = true
        }
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
        }
    }
}

// MARK: - ML Prediction Card
struct MLPredictionCard: View {
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("ML Predictions")
                    .font(.headline)
                
                Spacer()
                
                Button("Details") {
                    // Show ML details
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let prediction = aiEngine.lastPrediction {
                VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                            Text("Predicted Stage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            Text(prediction.sleepStage.displayName)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Probability")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(prediction.stageProbability * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if prediction.isConfident {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("High confidence prediction")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Low confidence - collecting more data")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Smart Alarm Controls
struct SmartAlarmControls: View {
    @StateObject private var smartAlarm = SmartAlarmSystem.shared
    @State private var targetTime = Date()
    @State private var selectedFlexibility = WakeFlexibility.medium
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "alarm")
                            .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Smart Alarm")
                    .font(.headline)
                
                Spacer()
                
                if smartAlarm.isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            if smartAlarm.isActive {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Target Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(smartAlarm.targetWakeTime, style: .time)
                                .font(.title3)
                                .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                            Text("Optimal Time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            Text(smartAlarm.optimalWakeTime, style: .time)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(smartAlarm.confidence * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Button("Stop Tracking") {
                            Task {
                                await smartAlarm.stopSleepTracking()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    DatePicker("Target Wake Time", selection: $targetTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    Picker("Flexibility", selection: $selectedFlexibility) {
                        ForEach(WakeFlexibility.allCases, id: \.self) { flexibility in
                            Text(flexibility.rawValue).tag(flexibility)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Button("Start Smart Alarm") {
                        Task {
                            await smartAlarm.startSleepTracking()
                            await smartAlarm.setSmartAlarm(targetTime: targetTime, flexibility: selectedFlexibility)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Data Collection Status
struct DataCollectionStatus: View {
    @StateObject private var dataManager = DataManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundColor(.green)
                
                Text("Data Collection")
                    .font(.headline)
                
                Spacer()
                
                if dataManager.isCollectingData {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Data Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(dataManager.dataPointsCollected)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Last Update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dataManager.lastDataCollection, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if dataManager.isCollectingData {
                    Button("Stop Collection") {
                        dataManager.stopDataCollection()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button("Start Collection") {
                        Task {
                            await dataManager.startDataCollection()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Sleep Quality Metrics
struct SleepQualityMetrics: View {
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Sleep Quality")
                    .font(.headline)
                
                Spacer()
            }
            
            if let prediction = aiEngine.lastPrediction {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Overall Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(prediction.sleepQuality * 100))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(qualityColor(prediction.sleepQuality))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Stage Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(prediction.stageProbability * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    
                    ProgressView(value: prediction.sleepQuality)
                        .progressViewStyle(LinearProgressViewStyle(tint: qualityColor(prediction.sleepQuality)))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func qualityColor(_ quality: Double) -> Color {
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .orange }
        else { return .red }
    }
}

// MARK: - AI Recommendations
struct AIRecommendations: View {
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("AI Recommendations")
                    .font(.headline)
                
                Spacer()
            }
            
            if let prediction = aiEngine.lastPrediction, !prediction.recommendations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(prediction.recommendations.prefix(3), id: \.message) { recommendation in
                        HStack {
                            Image(systemName: recommendationIcon(recommendation.type))
                                .foregroundColor(recommendationColor(recommendation.priority))
                            
                            Text(recommendation.message)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(recommendationColor(recommendation.priority).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No recommendations at this time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func recommendationIcon(_ type: RecommendationType) -> String {
        switch type {
        case .stressReduction: return "heart.fill"
        case .relaxation: return "leaf.fill"
        case .comfort: return "bed.double.fill"
        case .environment: return "house.fill"
        case .schedule: return "clock.fill"
        case .healthAlert: return "exclamationmark.triangle.fill"
        }
    }
    
    private func recommendationColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - ML Model Status
struct MLModelStatus: View {
    @StateObject private var aiEngine = AISleepAnalysisEngine.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("ML Model Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Retrain") {
                    Task {
                        await aiEngine.retrainModel()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            let status = aiEngine.getStatus()
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Model Accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(status.modelAccuracy * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Data Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(status.dataPoints)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Predictions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(status.predictions)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Personalization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(status.personalizationLevel * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                
                ProgressView(value: status.modelAccuracy)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Supporting Views
struct SleepStageIcon: View {
    let stage: SleepStage
    
    var body: some View {
        Image(systemName: stageIconName)
            .font(.title)
            .foregroundColor(stageColor)
    }
    
    private var stageIconName: String {
        switch stage {
        case .awake: return "eye.fill"
        case .light: return "moon.fill"
        case .deep: return "bed.double.fill"
        case .rem: return "brain.head.profile"
        }
    }
    
    private var stageColor: Color {
        switch stage {
        case .awake: return .orange
        case .light: return .blue
        case .deep: return .purple
        case .rem: return .green
        }
    }
}

struct StageProbabilitiesView: View {
    let probabilities: [SleepStage: Double]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(SleepStage.allCases, id: \.self) { stage in
                if let probability = probabilities[stage] {
                    HStack {
                        SleepStageIcon(stage: stage)
                            .font(.caption)
                        
                        Text(stage.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(probability * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ProgressView(value: probability)
                            .progressViewStyle(LinearProgressViewStyle(tint: stageColor(stage)))
                            .frame(width: 60)
                    }
                }
            }
        }
    }
    
    private func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return .orange
        case .light: return .blue
        case .deep: return .purple
        case .rem: return .green
        }
    }
}

// MARK: - Placeholder Views
struct SettingsView: View {
    @ObservedObject var sleepManager: SleepManager
    @ObservedObject var healthKitManager: HealthKitManager
    @ObservedObject var appleWatchManager: AppleWatchManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sleep Settings") {
                    Text("Sleep preferences and configuration")
                }
                
                Section("HealthKit") {
                    Text("Health data permissions and settings")
                }
                
                Section("Apple Watch") {
                    Text("Watch connectivity and settings")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MLDetailsView: View {
    var body: some View {
        Text("ML Details")
            .navigationTitle("ML Details")
    }
}

struct DataCollectionView: View {
    var body: some View {
        Text("Data Collection")
            .navigationTitle("Data Collection")
    }
}

// MARK: - SleepStage Extension
extension SleepStage {
    var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .light: return "Light Sleep"
        case .deep: return "Deep Sleep"
        case .rem: return "REM Sleep"
        }
    }
}

// MARK: - SleepStagePrediction Extension
extension SleepStagePrediction {
    var recommendations: [SleepRecommendation] {
        // This would be populated by the AI engine
        return []
    }
}

// MARK: - Audio Controls Card
struct AudioControlsCard: View {
    @StateObject private var audioEngine = AudioGenerationEngine.shared
    @State private var isExpanded = false
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title2)
                    .foregroundColor(.somnaPrimary)
                    .rotationEffect(.degrees(isAnimating ? 5 : -5))
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("Audio Generation")
                .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.title3)
                        .foregroundColor(.somnaPrimary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Audio Status
                    HStack {
                        Circle()
                            .fill(audioEngine.isPlaying ? .somnaAccent : .gray)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAnimating ? 1.5 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                        
                        Text(audioEngine.isPlaying ? "Playing Audio" : "Audio Ready")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if audioEngine.isPlaying {
                            Text(audioEngine.currentAudioType?.displayName ?? "")
                                .font(.caption)
                                .foregroundColor(.somnaPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.somnaPrimary.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Volume Control
                    VStack(spacing: 8) {
                        HStack {
                            Text("Volume")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(audioEngine.volume * 100))%")
                                .font(.caption)
                                .foregroundColor(.somnaPrimary)
                        }
                        
                        Slider(value: $audioEngine.volume, in: 0...1)
                            .accentColor(.somnaPrimary)
                            .onChange(of: audioEngine.volume) { _ in
                                HapticManager.shared.impact(style: .light)
                            }
                    }
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            Task {
                                await audioEngine.generatePreSleepAudio(type: .binauralBeats(frequency: 432), duration: 1800)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.title3)
                                Text("Binaural")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.somnaPrimary)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            Task {
                                await audioEngine.generatePreSleepAudio(type: .whiteNoise(color: .white), duration: 1800)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.title3)
                                Text("White Noise")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.somnaSecondary)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Play/Stop Button
                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        if audioEngine.isPlaying {
                            audioEngine.stopAudio()
                        } else {
                            Task {
                                await audioEngine.generatePreSleepAudio(type: .binauralBeats(frequency: 432), duration: 1800)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                                .font(.title3)
                            Text(audioEngine.isPlaying ? "Stop Audio" : "Start Audio")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: audioEngine.isPlaying ? 
                                    [Color.red, Color.red.opacity(0.8)] : 
                                    [Color.somnaPrimary, Color.somnaSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .scaleEffect(isAnimating ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.somnaCardBackground)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.somnaPrimary.opacity(0.3), .somnaSecondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Audio Controls View
struct AudioControlsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioEngine = AudioGenerationEngine.shared
    
    @State private var selectedPreSleepType: PreSleepAudioType = .binauralBeats(frequency: 6.0)
    @State private var selectedSleepType: SleepAudioType = .deepSleep(frequency: 2.0)
    @State private var binauralFrequency: Double = 6.0
    @State private var noiseColor: NoiseColor = .pink
    @State private var waveIntensity: WaveIntensity = .gentle
    @State private var rainIntensity: RainIntensity = .gentle
    @State private var timeOfDay: TimeOfDay = .night
    @State private var meditationStyle: MeditationStyle = .mindfulness
    @State private var ambientGenre: AmbientGenre = .atmospheric
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Pre-Sleep Audio Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pre-Sleep Audio")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            // Binaural Beats
                            AudioOptionCard(
                                title: "Binaural Beats",
                                description: "Synchronize brainwaves for relaxation",
                                icon: "waveform.path.ecg",
                                color: .blue,
                                isSelected: isBinauralSelected
                            ) {
                                selectedPreSleepType = .binauralBeats(frequency: binauralFrequency)
                            }
                            
                            if isBinauralSelected {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Frequency: \(Int(binauralFrequency))Hz")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $binauralFrequency, in: 1...12, step: 0.5)
                                        .accentColor(.blue)
                                }
                                .padding(.leading, 20)
                            }
                            
                            // White Noise
                            AudioOptionCard(
                                title: "White Noise",
                                description: "Mask ambient sounds",
                                icon: "speaker.wave.2.fill",
                                color: .gray,
                                isSelected: isWhiteNoiseSelected
                            ) {
                                selectedPreSleepType = .whiteNoise(color: noiseColor)
                }
                            
                            if isWhiteNoiseSelected {
                                HStack {
                                    ForEach([NoiseColor.white, .pink, .brown], id: \.self) { color in
                                        Button(colorName) {
                                            noiseColor = color
                                            selectedPreSleepType = .whiteNoise(color: color)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(noiseColor == color ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(noiseColor == color ? .white : .primary)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                            
                            // Nature Sounds
                            AudioOptionCard(
                                title: "Nature Sounds",
                                description: "Relaxing natural environments",
                                icon: "leaf.fill",
                                color: .green,
                                isSelected: isNatureSelected
                            ) {
                                selectedPreSleepType = .natureSounds(environment: .ocean)
                            }
                            
                            // Guided Meditation
                            AudioOptionCard(
                                title: "Guided Meditation",
                                description: "Mindfulness and relaxation",
                                icon: "brain.head.profile",
                                color: .purple,
                                isSelected: isMeditationSelected
                            ) {
                                selectedPreSleepType = .guidedMeditation(style: meditationStyle)
                            }
                            
                            // Ambient Music
                            AudioOptionCard(
                                title: "Ambient Music",
                                description: "Atmospheric soundscapes",
                                icon: "music.note",
                                color: .orange,
                                isSelected: isAmbientSelected
                            ) {
                                selectedPreSleepType = .ambientMusic(genre: ambientGenre)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Sleep Audio Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sleep Audio")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            // Deep Sleep
                            AudioOptionCard(
                                title: "Deep Sleep",
                                description: "Delta wave synchronization",
                                icon: "bed.double.fill",
                                color: .purple,
                                isSelected: isDeepSleepSelected
                            ) {
                                selectedSleepType = .deepSleep(frequency: binauralFrequency)
                            }
                            
                            // Ocean Waves
                            AudioOptionCard(
                                title: "Ocean Waves",
                                description: "Gentle wave sounds",
                                icon: "wave.3.right",
                                color: .cyan,
                                isSelected: isOceanSelected
                            ) {
                                selectedSleepType = .oceanWaves(intensity: waveIntensity)
                            }
                            
                            if isOceanSelected {
                                HStack {
                                    ForEach([WaveIntensity.gentle, .moderate, .strong], id: \.self) { intensity in
                                        Button(intensityName) {
                                            waveIntensity = intensity
                                            selectedSleepType = .oceanWaves(intensity: intensity)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(waveIntensity == intensity ? Color.cyan : Color(.systemGray5))
                                        .foregroundColor(waveIntensity == intensity ? .white : .primary)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                            
                            // Rain Sounds
                            AudioOptionCard(
                                title: "Rain Sounds",
                                description: "Soothing rainfall",
                                icon: "cloud.rain.fill",
                                color: .blue,
                                isSelected: isRainSelected
                            ) {
                                selectedSleepType = .rainSounds(intensity: rainIntensity)
                            }
                            
                            if isRainSelected {
                                HStack {
                                    ForEach([RainIntensity.gentle, .moderate, .heavy], id: \.self) { intensity in
                                        Button(intensityName) {
                                            rainIntensity = intensity
                                            selectedSleepType = .rainSounds(intensity: intensity)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(rainIntensity == intensity ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(rainIntensity == intensity ? .white : .primary)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                            
                            // Forest Ambience
                            AudioOptionCard(
                                title: "Forest Ambience",
                                description: "Natural forest sounds",
                                icon: "tree.fill",
                                color: .green,
                                isSelected: isForestSelected
                            ) {
                                selectedSleepType = .forestAmbience(timeOfDay: timeOfDay)
                            }
                            
                            if isForestSelected {
                                HStack {
                                    ForEach([TimeOfDay.dawn, .day, .dusk, .night], id: \.self) { time in
                                        Button(timeName) {
                                            timeOfDay = time
                                            selectedSleepType = .forestAmbience(timeOfDay: time)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(timeOfDay == time ? Color.green : Color(.systemGray5))
                                        .foregroundColor(timeOfDay == time ? .white : .primary)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                    
                    // Play Button
                    Button(action: playSelectedAudio) {
                        HStack {
                            Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                            Text(audioEngine.isPlaying ? "Stop Audio" : "Play Audio")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(audioEngine.isPlaying ? Color.red : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(false)
                }
                .padding()
            }
            .navigationTitle("Audio Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func playSelectedAudio() {
        if audioEngine.isPlaying {
            audioEngine.stopAudio()
            } else {
            Task {
                await audioEngine.generatePreSleepAudio(type: selectedPreSleepType, duration: 1800)
            }
        }
    }
    
    // Selection helpers
    private var isBinauralSelected: Bool {
        if case .binauralBeats = selectedPreSleepType { return true }
        return false
    }
    
    private var isWhiteNoiseSelected: Bool {
        if case .whiteNoise = selectedPreSleepType { return true }
        return false
    }
    
    private var isNatureSelected: Bool {
        if case .natureSounds = selectedPreSleepType { return true }
        return false
    }
    
    private var isMeditationSelected: Bool {
        if case .guidedMeditation = selectedPreSleepType { return true }
        return false
    }
    
    private var isAmbientSelected: Bool {
        if case .ambientMusic = selectedPreSleepType { return true }
        return false
    }
    
    private var isDeepSleepSelected: Bool {
        if case .deepSleep = selectedSleepType { return true }
        return false
    }
    
    private var isOceanSelected: Bool {
        if case .oceanWaves = selectedSleepType { return true }
        return false
    }
    
    private var isRainSelected: Bool {
        if case .rainSounds = selectedSleepType { return true }
        return false
    }
    
    private var isForestSelected: Bool {
        if case .forestAmbience = selectedSleepType { return true }
        return false
    }
    
    // Helper functions for names
    private func colorName(_ color: NoiseColor) -> String {
        switch color {
        case .white: return "White"
        case .pink: return "Pink"
        case .brown: return "Brown"
        }
    }
    
    private func intensityName(_ intensity: WaveIntensity) -> String {
        switch intensity {
        case .gentle: return "Gentle"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        }
    }
    
    private func intensityName(_ intensity: RainIntensity) -> String {
        switch intensity {
        case .gentle: return "Gentle"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        }
    }
    
    private func timeName(_ time: TimeOfDay) -> String {
        switch time {
        case .dawn: return "Dawn"
        case .day: return "Day"
        case .dusk: return "Dusk"
        case .night: return "Night"
        }
    }
}

// MARK: - Audio Option Card
struct AudioOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
            }
        }
        .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Audio Controls Section

struct AudioControlsSection: View {
    @ObservedObject var audioEngine: AudioGenerationEngine
    @State private var selectedAudioType: AudioType = .binaural(frequency: 4.0)
    @State private var showingAudioSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.blue)
                Text("Sleep Audio")
                .font(.headline)
                Spacer()
                Button("Settings") {
                    showingAudioSettings = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Audio Type Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        AudioTypeButton(
                            title: "Binaural Beats",
                            subtitle: "4Hz Theta",
                            isSelected: isBinauralSelected,
                            action: { selectedAudioType = .binaural(frequency: 4.0) }
                        )
                        
                        AudioTypeButton(
                            title: "White Noise",
                            subtitle: "Pink",
                            isSelected: isWhiteNoiseSelected,
                            action: { selectedAudioType = .whiteNoise(color: .pink) }
                        )
                        
                        AudioTypeButton(
                            title: "Nature",
                            subtitle: "Ocean",
                            isSelected: isNatureSelected,
                            action: { selectedAudioType = .nature(environment: .ocean) }
                        )
                        
                        AudioTypeButton(
                            title: "Meditation",
                            subtitle: "Mindfulness",
                            isSelected: isMeditationSelected,
                            action: { selectedAudioType = .meditation(style: .mindfulness) }
                        )
                        
                        AudioTypeButton(
                            title: "Ambient",
                            subtitle: "Drone",
                            isSelected: isAmbientSelected,
                            action: { selectedAudioType = .ambient(genre: .drone) }
                        )
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Audio Controls
            HStack(spacing: 20) {
                // Play/Pause Button
                Button(action: toggleAudio) {
                    Image(systemName: audioEngine.isAudioPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                // Volume Control
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { audioEngine.volume },
                                set: { audioEngine.setVolume($0) }
                            ),
                            in: 0...1
                        )
                        .accentColor(.blue)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                    .foregroundColor(.secondary)
                    }
                }
            }
            
            // Audio Quality Indicators
            HStack(spacing: 16) {
                AudioQualityIndicator(
                    title: "Spatial Audio",
                    isEnabled: audioEngine.spatialAudioEnabled,
                    icon: "speaker.wave.3"
                )
                
                AudioQualityIndicator(
                    title: "EQ: \(audioEngine.eqPreset.rawValue)",
                    isEnabled: true,
                    icon: "slider.horizontal.3"
                )
                
                AudioQualityIndicator(
                    title: "Reverb: \(Int(audioEngine.reverbLevel * 100))%",
                    isEnabled: audioEngine.reverbLevel > 0,
                    icon: "waveform"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingAudioSettings) {
            AudioSettingsView(audioEngine: audioEngine)
    }
        .onChange(of: selectedAudioType) { newType in
            Task {
                await audioEngine.generateAudio(type: newType)
            }
        }
    }
    
    private var isBinauralSelected: Bool {
        if case .binaural = selectedAudioType { return true }
        return false
    }
    
    private var isWhiteNoiseSelected: Bool {
        if case .whiteNoise = selectedAudioType { return true }
        return false
    }
    
    private var isNatureSelected: Bool {
        if case .nature = selectedAudioType { return true }
        return false
    }
    
    private var isMeditationSelected: Bool {
        if case .meditation = selectedAudioType { return true }
        return false
    }
    
    private var isAmbientSelected: Bool {
        if case .ambient = selectedAudioType { return true }
        return false
    }
    
    private func toggleAudio() {
        Task {
            if audioEngine.isAudioPlaying {
                await audioEngine.stopAudio()
            } else {
                await audioEngine.playAudio()
            }
        }
    }
}

struct AudioTypeButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
    }
}

struct AudioQualityIndicator: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isEnabled ? .green : .secondary)
            Text(title)
                .font(.caption)
                .foregroundColor(isEnabled ? .primary : .secondary)
        }
    }
}

struct AudioSettingsView: View {
    @ObservedObject var audioEngine: AudioGenerationEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Audio Quality") {
                    Toggle("Spatial Audio", isOn: $audioEngine.spatialAudioEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reverb Level")
                        Slider(value: $audioEngine.reverbLevel, in: 0...1)
                        Text("\(Int(audioEngine.reverbLevel * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                }
                
                Section("Equalizer") {
                    Picker("EQ Preset", selection: $audioEngine.eqPreset) {
                        ForEach(EQPreset.allCases, id: \.self) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Advanced Audio") {
                    NavigationLink("Custom Audio Mix") {
                        CustomAudioMixView(audioEngine: audioEngine)
                    }
                    
                    NavigationLink("Progressive Audio") {
                        ProgressiveAudioView(audioEngine: audioEngine)
                    }
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CustomAudioMixView: View {
    @ObservedObject var audioEngine: AudioGenerationEngine
    @State private var selectedTypes: [AudioType] = []
    @State private var weights: [Float] = []
    
    var body: some View {
        Form {
            Section("Select Audio Types") {
                ForEach(AudioType.allCases, id: \.self) { audioType in
                    Toggle(audioType.displayName, isOn: Binding(
                        get: { selectedTypes.contains(audioType) },
                        set: { isSelected in
                            if isSelected {
                                selectedTypes.append(audioType)
                                weights.append(1.0)
                            } else {
                                if let index = selectedTypes.firstIndex(of: audioType) {
                                    selectedTypes.remove(at: index)
                                    weights.remove(at: index)
                                }
                            }
                        }
                    ))
                }
            }
            
            if !selectedTypes.isEmpty {
                Section("Mix Weights") {
                    ForEach(Array(selectedTypes.enumerated()), id: \.offset) { index, audioType in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(audioType.displayName)
                            Slider(value: Binding(
                                get: { weights[index] },
                                set: { weights[index] = $0 }
                            ), in: 0...2)
                            Text("\(String(format: "%.1f", weights[index]))x")
                .font(.caption)
                .foregroundColor(.secondary)
        }
                    }
                }
                
                Section {
                    Button("Generate Custom Mix") {
                        Task {
                            await audioEngine.generateCustomMix(
                                audioTypes: selectedTypes,
                                weights: weights,
                                duration: 300.0
                            )
                        }
                    }
                    .disabled(selectedTypes.isEmpty)
                }
            }
        }
        .navigationTitle("Custom Mix")
    }
}

struct ProgressiveAudioView: View {
    @ObservedObject var audioEngine: AudioGenerationEngine
    @State private var startType: AudioType = .binaural(frequency: 8.0)
    @State private var endType: AudioType = .binaural(frequency: 0.5)
    @State private var duration: TimeInterval = 1800 // 30 minutes
    
    var body: some View {
        Form {
            Section("Start Audio") {
                Picker("Start Type", selection: $startType) {
                    ForEach(AudioType.allCases, id: \.self) { audioType in
                        Text(audioType.displayName).tag(audioType)
                    }
                }
            }
            
            Section("End Audio") {
                Picker("End Type", selection: $endType) {
                    ForEach(AudioType.allCases, id: \.self) { audioType in
                        Text(audioType.displayName).tag(audioType)
                    }
                }
            }
            
            Section("Duration") {
                Picker("Duration", selection: $duration) {
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                    Text("45 minutes").tag(TimeInterval(2700))
                    Text("60 minutes").tag(TimeInterval(3600))
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section {
                Button("Generate Progressive Audio") {
                    Task {
                        await audioEngine.generateProgressiveAudio(
                            startType: startType,
                            endType: endType,
                            duration: duration
                        )
                    }
                }
            }
        }
        .navigationTitle("Progressive Audio")
    }
}

// MARK: - AudioType Extensions

extension AudioType: CaseIterable {
    static var allCases: [AudioType] {
        return [
            .binaural(frequency: 4.0),
            .whiteNoise(color: .pink),
            .nature(environment: .ocean),
            .meditation(style: .mindfulness),
            .ambient(genre: .drone),
            .customMix
        ]
    }
    
    var displayName: String {
        switch self {
        case .binaural(let frequency):
            return "Binaural Beats (\(Int(frequency))Hz)"
        case .whiteNoise(let color):
            return "\(color.rawValue) Noise"
        case .nature(let environment):
            return "\(environment.rawValue) Sounds"
        case .meditation(let style):
            return "\(style.rawValue) Meditation"
        case .ambient(let genre):
            return "\(genre.rawValue) Music"
        case .customMix:
            return "Custom Mix"
        }
    }
}

// MARK: - SleepScoreHeader
struct SleepScoreHeader: View {
    @ObservedObject var sleepManager: SleepManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep Score")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Last 7 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(sleepManager.sleepScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: Double(sleepManager.sleepScore) / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - SleepSessionControls
struct SleepSessionControls: View {
    @ObservedObject var sleepManager: SleepManager
    @Binding var showingSession: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.blue)
                Text("Sleep Session")
                .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                            await sleepManager.startSleepSession()
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Session")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Button(action: { showingSession = true }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("View Session")
                    }
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - SmartAlarmSection
struct SmartAlarmSection: View {
    @ObservedObject var smartAlarm: SmartAlarmSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "alarm.fill")
                    .foregroundColor(.orange)
                Text("Smart Alarm")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $smartAlarm.isEnabled)
                    }
                    
            if smartAlarm.isEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Target Wake Time:")
                        Spacer()
                        Text(smartAlarm.targetWakeTime, style: .time)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Optimal Wake Window:")
                        Spacer()
                        Text("\(smartAlarm.optimalWakeWindow) min")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Confidence:")
                        Spacer()
                        Text("\(Int(smartAlarm.wakeConfidence * 100))%")
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                    }
                }
                .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AppleWatchSection
struct AppleWatchSection: View {
    @ObservedObject var appleWatchManager: AppleWatchManager
    @Binding var showingSetup: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "applewatch")
                    .foregroundColor(.green)
                Text("Apple Watch")
                    .font(.headline)
                Spacer()
                if appleWatchManager.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Setup") {
                        showingSetup = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if appleWatchManager.isConnected {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Heart Rate:")
                        Spacer()
                        Text("\(appleWatchManager.currentHeartRate) BPM")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Sleep Tracking:")
                        Spacer()
                        Text(appleWatchManager.isSleepTracking ? "Active" : "Inactive")
                            .fontWeight(.medium)
                            .foregroundColor(appleWatchManager.isSleepTracking ? .green : .orange)
                    }
                }
            } else {
                Text("Connect your Apple Watch for enhanced sleep tracking and biometric monitoring.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - SleepInsightsSection
struct SleepInsightsSection: View {
    @ObservedObject var sleepManager: SleepManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("Sleep Insights")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                InsightRow(
                    title: "Deep Sleep",
                    value: "\(sleepManager.deepSleepPercentage)%",
                    color: .blue
                )
                
                InsightRow(
                    title: "REM Sleep",
                    value: "\(sleepManager.remSleepPercentage)%",
                    color: .purple
                )
                
                InsightRow(
                    title: "Sleep Efficiency",
                    value: "\(sleepManager.sleepEfficiency)%",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - InsightRow
struct InsightRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - HealthDataSection
struct HealthDataSection: View {
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Health Data")
                    .font(.headline)
                Spacer()
                if healthKitManager.isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Authorize") {
                        Task {
                            await healthKitManager.requestPermissions()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if healthKitManager.isAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Last Sleep Duration:")
                        Spacer()
                        Text(healthKitManager.lastSleepDuration)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Average Sleep:")
                        Spacer()
                        Text(healthKitManager.averageSleepDuration)
                            .fontWeight(.medium)
                    }
                }
            } else {
                Text("Authorize HealthKit access to view your sleep data and receive personalized insights.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - HistoricalDataAnalysisOverlay
struct HistoricalDataAnalysisOverlay: View {
    let progress: Double
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
                
                Text("Analyzing Historical Sleep Data")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This helps us provide personalized sleep insights and recommendations.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.systemGray6).opacity(0.9))
            .cornerRadius(20)
        }
        .onChange(of: progress) { newProgress in
            if newProgress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - SleepSessionView
struct SleepSessionView: View {
    @ObservedObject var sleepManager: SleepManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Sleep Session View")
                    .font(.title)
                Text("Detailed sleep session tracking and analysis")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Sleep Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - AppleWatchSetupView
struct AppleWatchSetupView: View {
    @ObservedObject var appleWatchManager: AppleWatchManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Apple Watch Setup")
                    .font(.title)
                Text("Configure Apple Watch connectivity")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Apple Watch Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 