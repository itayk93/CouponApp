//
//  AppColors.swift
//  CouponManagerApp
//
//  Created for custom app colors
//

import SwiftUI

extension Color {
    // Main app colors based on the dark blue-gray shade from the provided image
    static let appBlue = Color(red: 0.235, green: 0.290, blue: 0.384) // #3C4A62 - Dark Blue Gray
    static let appLightBlue = Color(red: 0.310, green: 0.365, blue: 0.459) // #4F5D75 - Lighter Blue Gray
    
    // Create a gradient version of the app blue
    static var appBlueGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [appBlue, appLightBlue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Alternative gradient directions
    static var appBlueGradientVertical: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [appBlue, appLightBlue]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var appBlueGradientHorizontal: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [appBlue, appLightBlue]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Helper for creating a background with the app gradient
    static func appBlueBackground() -> some View {
        Rectangle()
            .fill(appBlueGradient)
    }
}

// MARK: - View Extensions for easy gradient usage
extension View {
    func appBlueGradientBackground() -> some View {
        self.background(Color.appBlueGradient)
    }
    
    func appBlueGradientForeground() -> some View {
        self.foregroundStyle(Color.appBlueGradient)
    }
}