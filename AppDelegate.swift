import UIKit
import HealthKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize background task manager
        BackgroundTaskManager.shared.registerBackgroundTasks()
        
        // Configure app appearance
        configureAppAppearance()
        
        // Request permissions and perform initial setup
        Task {
            await PermissionManager.shared.requestAllPermissions()
            
            // Perform initial historical data analysis
            await DataManager.shared.performInitialSetup()
            
            // NEW: Start comprehensive background health analysis
            await startComprehensiveHealthAnalysis()
        }
        
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session
    }
    
    // MARK: - Background Task Handling
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle background fetch
        completionHandler(.newData)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background tasks when app enters background
        if #available(iOS 13.0, *) {
            BackgroundTaskManager.shared.scheduleSleepAnalysisTask()
            BackgroundTaskManager.shared.scheduleBiometricProcessingTask()
            BackgroundTaskManager.shared.scheduleAIOptimizationTask()
            
            // NEW: Schedule comprehensive health analysis
            scheduleComprehensiveHealthAnalysis()
        }
    }
    
    // MARK: - URL Scheme Handling
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle deep links
        handleDeepLink(url: url)
        return true
    }
    
    // MARK: - Health Analysis Methods
    
    private func startComprehensiveHealthAnalysis() async {
        // Start comprehensive health data analysis
        let healthAnalyzer = BackgroundHealthAnalyzer.shared
        
        // Check if we should perform initial analysis
        if shouldPerformInitialAnalysis() {
            Logger.info("Starting initial comprehensive health analysis", log: Logger.health)
            
            // Perform initial analysis in background
            Task.detached(priority: .background) {
                await healthAnalyzer.performBackgroundHealthAnalysis()
            }
        } else {
            Logger.info("Skipping initial analysis - already performed recently", log: Logger.health)
        }
        
        // Schedule regular background analysis
        healthAnalyzer.startBackgroundAnalysis()
    }
    
    private func scheduleComprehensiveHealthAnalysis() {
        // Schedule comprehensive health analysis for background execution
        let healthAnalyzer = BackgroundHealthAnalyzer.shared
        healthAnalyzer.startBackgroundAnalysis()
        
        Logger.info("Scheduled comprehensive health analysis for background execution", log: Logger.health)
    }
    
    private func shouldPerformInitialAnalysis() -> Bool {
        // Check if we should perform initial analysis
        // This could be based on:
        // - First app launch
        // - Last analysis date
        // - Available health data
        // - User preferences
        
        let lastAnalysisDate = BackgroundHealthAnalyzer.shared.lastAnalysisDate
        
        if lastAnalysisDate == nil {
            // First time analysis
            return true
        }
        
        // Check if enough time has passed since last analysis (e.g., 24 hours)
        let timeSinceLastAnalysis = Date().timeIntervalSince(lastAnalysisDate!)
        let minimumInterval: TimeInterval = 24 * 60 * 60 // 24 hours
        
        return timeSinceLastAnalysis >= minimumInterval
    }
    
    // MARK: - Private Methods
    private func configureAppAppearance() {
        // Configure global app appearance
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        
        // Set status bar style
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    private func handleDeepLink(url: URL) {
        // Handle deep links for the app
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        switch components.scheme {
        case AppConfiguration.URLSchemes.primary, AppConfiguration.URLSchemes.secondary:
            // Handle app-specific deep links
            if let host = components.host {
                switch host {
                case "sleep":
                    // Navigate to sleep view
                    break
                case "settings":
                    // Navigate to settings
                    break
                case "health-analysis":
                    // NEW: Navigate to health analysis results
                    break
                default:
                    break
                }
            }
        default:
            break
        }
    }
} 