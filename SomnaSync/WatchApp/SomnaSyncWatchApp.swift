import SwiftUI
import WatchKit
import HealthKit
import WatchConnectivity
import os.log

// MARK: - Custom Colors for Watch
extension Color {
    static let somnaPrimary = Color(red: 0.39, green: 0.4, blue: 0.96)
    static let somnaSecondary = Color(red: 0.55, green: 0.47, blue: 0.91)
    static let somnaAccent = Color(red: 0.2, green: 0.8, blue: 0.6)
    static let somnaBackground = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let somnaCardBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
}

// MARK: - Haptic Feedback for Watch
class WatchHapticManager {
    static let shared = WatchHapticManager()
    
    func impact(style: WKHapticType) {
        WKInterfaceDevice.current().play(style)
    }
    
    func notification(type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

/// Enhanced SomnaSyncWatchApp - Complete Apple Watch integration with advanced sleep tracking
@main
struct SomnaSyncWatchApp: App {
    @StateObject private var watchManager = AppleWatchManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var sleepManager = SleepManager.shared
    @StateObject private var smartAlarm = SmartAlarmSystem.shared
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(watchManager)
                .environmentObject(healthKitManager)
                .environmentObject(sleepManager)
                .environmentObject(smartAlarm)
        }
    }
}

/// Enhanced WatchContentView - Main Apple Watch interface
struct WatchContentView: View {
    @EnvironmentObject var watchManager: AppleWatchManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var sleepManager: SleepManager
    @EnvironmentObject var smartAlarm: SmartAlarmSystem
    
    @State private var selectedTab = 0
    @State private var showingSleepSession = false
    @State private var showingBiometrics = false
    @State private var showingAlarm = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Sleep Dashboard Tab
            WatchSleepDashboard()
                .tag(0)
            
            // Biometrics Tab
            WatchBiometricsView()
                .tag(1)
            
            // Smart Alarm Tab
            WatchSmartAlarmView()
                .tag(2)
            
            // Quick Actions Tab
            WatchQuickActionsView()
                .tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .onAppear {
            watchManager.startMonitoring()
        }
    }
}

/// Enhanced Watch Sleep Dashboard
struct WatchSleepDashboard: View {
    @EnvironmentObject var sleepManager: SleepManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sleep Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: sleepManager.sleepScore / 100)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: sleepManager.sleepScore)
                    
                    VStack {
                        Text("\(Int(sleepManager.sleepScore))")
                            .font(.system(size: 16, weight: .bold))
                        Text("Score")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // Sleep Status
                VStack(spacing: 4) {
                    Text(sleepManager.currentSleepStage.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(sleepManager.currentSleepDuration.formattedDuration)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Quick Stats
                HStack(spacing: 16) {
                    WatchStatCard(
                        title: "Quality",
                        value: "\(Int(sleepManager.sleepQuality * 100))%",
                        color: .green
                    )
                    
                    WatchStatCard(
                        title: "Cycles",
                        value: "\(sleepManager.completedSleepCycles)",
                        color: .orange
                    )
                }
                
                // Health Score
                if healthKitManager.healthScore > 0 {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Health Score: \(Int(healthKitManager.healthScore * 100))")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Enhanced Watch Biometrics View
struct WatchBiometricsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Heart Rate
                WatchBiometricCard(
                    title: "Heart Rate",
                    value: "\(Int(healthKitManager.currentHeartRate))",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red,
                    trend: healthKitManager.biometricTrends?.heartRateTrend
                )
                
                // HRV
                WatchBiometricCard(
                    title: "HRV",
                    value: String(format: "%.1f", healthKitManager.currentHRV),
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .blue,
                    trend: healthKitManager.biometricTrends?.hrvTrend
                )
                
                // Respiratory Rate
                WatchBiometricCard(
                    title: "Respiratory",
                    value: String(format: "%.1f", healthKitManager.currentRespiratoryRate),
                    unit: "bpm",
                    icon: "lungs.fill",
                    color: .green,
                    trend: healthKitManager.biometricTrends?.respiratoryRateTrend
                )
                
                // Recovery Status
                WatchRecoveryStatusCard(recoveryStatus: healthKitManager.recoveryStatus)
                
                // Stress Level
                WatchStressLevelCard(stressLevel: healthKitManager.stressLevel)
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Enhanced Watch Smart Alarm View
struct WatchSmartAlarmView: View {
    @EnvironmentObject var smartAlarm: SmartAlarmSystem
    @State private var showingAlarmSetup = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Alarm Status
                VStack(spacing: 8) {
                    Image(systemName: smartAlarm.isEnabled ? "alarm.fill" : "alarm")
                        .font(.system(size: 24))
                        .foregroundColor(smartAlarm.isEnabled ? .orange : .gray)
                    
                    Text(smartAlarm.isEnabled ? "Alarm Set" : "No Alarm")
                        .font(.system(size: 14, weight: .semibold))
                    
                    if smartAlarm.isEnabled {
                        Text(smartAlarm.targetWakeTime.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sleep Cycle Info
                if let prediction = smartAlarm.sleepCyclePrediction {
                    VStack(spacing: 6) {
                        Text("Sleep Cycles")
                            .font(.system(size: 12, weight: .medium))
                        
                        Text("\(prediction.cycles.count) cycles predicted")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("Confidence: \(Int(prediction.confidence * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Wakeup Readiness
                if smartAlarm.wakeupReadiness > 0 {
                    VStack(spacing: 4) {
                        Text("Wakeup Readiness")
                            .font(.system(size: 12, weight: .medium))
                        
                        ProgressView(value: smartAlarm.wakeupReadiness)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        
                        Text("\(Int(smartAlarm.wakeupReadiness * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Quick Actions
                HStack(spacing: 12) {
                    Button("Set Alarm") {
                        showingAlarmSetup = true
                    }
                    .buttonStyle(WatchButtonStyle(color: .blue))
                    
                    Button("Cancel") {
                        smartAlarm.cancelAlarm()
                    }
                    .buttonStyle(WatchButtonStyle(color: .red))
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingAlarmSetup) {
            WatchAlarmSetupView()
        }
    }
}

/// Enhanced Watch Quick Actions View
struct WatchQuickActionsView: View {
    @EnvironmentObject var sleepManager: SleepManager
    @EnvironmentObject var smartAlarm: SmartAlarmSystem
    @State private var showingSleepSession = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Start Sleep Session
            Button(action: {
                showingSleepSession = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 20))
                    Text("Start Sleep")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(WatchButtonStyle(color: .purple))
            
            // Quick Alarm
            Button(action: {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                let wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
                Task {
                    await smartAlarm.setSmartAlarm(targetTime: wakeTime)
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "alarm")
                        .font(.system(size: 20))
                    Text("Quick Alarm")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(WatchButtonStyle(color: .orange))
            
            // Health Check
            Button(action: {
                Task {
                    await healthKitManager.performComprehensiveHealthAnalysis()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                    Text("Health Check")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(WatchButtonStyle(color: .red))
        }
        .padding()
        .sheet(isPresented: $showingSleepSession) {
            WatchSleepSessionView()
        }
    }
}

// MARK: - Supporting Views

struct WatchStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct WatchBiometricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: TrendDirection?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .bottom, spacing: 2) {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(unit)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let trend = trend {
                Image(systemName: trendIcon(for: trend))
                    .foregroundColor(trendColor(for: trend))
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func trendIcon(for trend: TrendDirection) -> String {
        switch trend {
        case .increasing:
            return "arrow.up"
        case .decreasing:
            return "arrow.down"
        case .stable:
            return "minus"
        }
    }
    
    private func trendColor(for trend: TrendDirection) -> Color {
        switch trend {
        case .increasing:
            return .red
        case .decreasing:
            return .green
        case .stable:
            return .gray
        }
    }
}

struct WatchRecoveryStatusCard: View {
    let recoveryStatus: RecoveryStatus
    
    var body: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(recoveryColor)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(recoveryStatus.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(recoveryColor)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(recoveryColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var recoveryColor: Color {
        switch recoveryStatus {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        case .unknown:
            return .gray
        }
    }
}

struct WatchStressLevelCard: View {
    let stressLevel: StressLevel
    
    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(stressColor)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Stress")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(stressLevel.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(stressColor)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(stressColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var stressColor: Color {
        switch stressLevel {
        case .low:
            return .green
        case .moderate:
            return .orange
        case .high:
            return .red
        }
    }
}

struct WatchButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct WatchAlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var smartAlarm: SmartAlarmSystem
    @State private var selectedTime = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Set Alarm")
                .font(.system(size: 16, weight: .semibold))
            
            DatePicker("Wake Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WatchButtonStyle(color: .gray))
                
                Button("Set") {
                    Task {
                        await smartAlarm.setSmartAlarm(targetTime: selectedTime)
                        dismiss()
                    }
                }
                .buttonStyle(WatchButtonStyle(color: .blue))
            }
        }
        .padding()
    }
}

struct WatchSleepSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sleepManager: SleepManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Sleep Session")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 8) {
                Text("Duration: \(sleepManager.currentSleepDuration.formattedDuration)")
                    .font(.system(size: 14))
                
                Text("Stage: \(sleepManager.currentSleepStage.displayName)")
                    .font(.system(size: 14))
                
                Text("Quality: \(Int(sleepManager.sleepQuality * 100))%")
                    .font(.system(size: 14))
            }
            
            Button("End Session") {
                sleepManager.endSleepSession()
                dismiss()
            }
            .buttonStyle(WatchButtonStyle(color: .red))
        }
        .padding()
    }
}

// MARK: - Extensions

extension RecoveryStatus {
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .unknown:
            return "Unknown"
        }
    }
}

extension StressLevel {
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        }
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

// MARK: - Supporting Types

struct BiometricDataPoint {
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let bloodOxygen: Double
    let movement: Double
    let temperature: Double
}

struct SleepStageData {
    let stage: SleepStage
    let confidence: Double
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let movement: Double
    let bloodOxygen: Double
}

enum WatchMessageType: String {
    case startSleepTracking = "startSleepTracking"
    case stopSleepTracking = "stopSleepTracking"
    case biometricDataUpdate = "biometricDataUpdate"
    case sleepStageUpdate = "sleepStageUpdate"
    case batteryLevelUpdate = "batteryLevelUpdate"
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

// MARK: - Logger Extension

extension Logger {
    static let watchManager = Logger(subsystem: "com.somnasync.pro.watch", category: "WatchSleepManager")
} 
