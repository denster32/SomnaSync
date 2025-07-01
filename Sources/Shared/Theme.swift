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
