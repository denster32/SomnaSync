import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create the SwiftUI view that provides the window contents
        let contentView = ContentView()
        
        // Use a UIHostingController as window root view controller
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle any deep links that launched the app
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(url: urlContext.url)
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background
        // Schedule background tasks
        if #available(iOS 13.0, *) {
            BackgroundTaskManager.shared.scheduleSleepAnalysisTask()
            BackgroundTaskManager.shared.scheduleBiometricProcessingTask()
            BackgroundTaskManager.shared.scheduleAIOptimizationTask()
        }
    }
    
    // MARK: - URL Handling
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url: url)
    }
    
    // MARK: - Private Methods
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
                default:
                    break
                }
            }
        default:
            break
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        NavigationView {
            SleepView()
                .navigationTitle(AppConfiguration.appName)
                .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Request permissions when the app appears
            Task {
                await permissionManager.requestAllPermissions()
            }
        }
    }
}

// MARK: - Content View Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 