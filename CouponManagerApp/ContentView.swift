//
//  ContentView.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var currentUser: User?
    @StateObject private var faceIDManager = FaceIDManager.shared
    @State private var shouldAttemptFaceID = false
    
    var body: some View {
        Group {
            if isLoggedIn, let user = currentUser {
                CouponsListView(user: user, onLogout: handleLogout)
                    .onAppear {
                        // Load Face ID preference when user logs in
                        Task {
                            await faceIDManager.loadFaceIDPreference(for: user.id)
                        }
                    }
            } else {
                LoginView(
                    onLoginSuccess: { user in
                        currentUser = user
                        isLoggedIn = true
                        
                        // Save user data for widget
                        AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
                        
                        // Register for push notifications
                        registerForPushNotifications()
                        
                        // After a successful login, check if there is a pending coupon from a widget tap
                        handlePendingCouponIfAny(user: user)
                    },
                    onLogout: {
                        handleLogout()
                    }
                )
                .onAppear {
                    checkForAutoLogin()
                }
            }
        }
    }
    
    private func registerForPushNotifications() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func handleLogout() {
        currentUser = nil
        isLoggedIn = false
        shouldAttemptFaceID = false
    }
    
    private func checkForAutoLogin() {
        // Check both standard UserDefaults and shared container for stored user
        var userData: Data?
        
        // First try standard UserDefaults (for backward compatibility)
        if let standardData = UserDefaults.standard.data(forKey: "lastLoggedInUser") {
            userData = standardData
        }
        // Then try shared container (for widget compatibility)
        else if let sharedData = AppGroupManager.shared.sharedUserDefaults?.data(forKey: "lastLoggedInUser") {
            userData = sharedData
        }
        
        if let userData = userData,
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            
            // Also save to shared container if not already there
            AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
            
            if faceIDManager.isFaceIDEnabled(for: user.id) && faceIDManager.isFaceIDAvailable {
                // Attempt Face ID authentication
                Task {
                    let success = await faceIDManager.authenticateWithFaceID(reason: "התחבר לאפליקציה")
                    if success {
                        DispatchQueue.main.async {
                            currentUser = user
                            isLoggedIn = true
                            // Also save to shared container to ensure AppDelegate sees user when APNs returns token
                            AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
                            // Ensure APNs registration also happens on auto-login
                            registerForPushNotifications()
                            // After Face ID auto-login, check for pending coupon
                            handlePendingCouponIfAny(user: user)
                        }
                    }
                }
            }
        }
    }
}

    // Check the shared container for a pending coupon id saved by the widget deep link.
    private func handlePendingCouponIfAny(user: User) {
        var pendingId: Int? = nil
                if let sharedDefaults = AppGroupManager.shared.sharedUserDefaults {
            if let val = sharedDefaults.object(forKey: "PendingCouponId") as? Int {
                pendingId = val
                sharedDefaults.removeObject(forKey: "PendingCouponId")
            }
        }

        if pendingId == nil {
            if let val = UserDefaults.standard.object(forKey: "PendingCouponId") as? Int {
                pendingId = val
                UserDefaults.standard.removeObject(forKey: "PendingCouponId")
            }
        }

        if let couponId = pendingId {
            // Post notification but DO NOT remove the pending id here - let the CouponsListView
            // consume and remove it after it loads its coupons to ensure navigation succeeds.
            print("🔔 Resuming pending coupon navigation to id: \(couponId)")
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToCouponDetail"), object: nil, userInfo: ["couponId": couponId])
        }
    }

#Preview {
    ContentView()
}
