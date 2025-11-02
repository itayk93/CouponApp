//
//  CouponManagerAppApp.swift
//  CouponManagerApp
//
//  Created by itay karkason on 20/09/2025.
//

import SwiftUI

@main
struct CouponManagerAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()  // מסך ראשי שמנהל את ההתחברות ומעבר לאפליקציה
                // Ensure SwiftUI views (including alerts) use RTL layout
                .environment(\.layoutDirection, .rightToLeft)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        // Handle widget deep links (company filters and coupon detail)
        if url.scheme == "couponmanager" || url.scheme == "couponmaster" {
            // Home screen deep link
            if url.host == "home" {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToHome"), object: nil)
                return
            }

            // Company filter links: couponmanager://company-filter/<company>
            if url.host == "company-filter", let companyEncoded = url.pathComponents.last,
               let company = companyEncoded.removingPercentEncoding {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToCompanyFilter"),
                    object: company
                )
                return
            }

            // Legacy/company link: couponmanager://company/<company>
            if url.host == "company", let company = url.pathComponents.last {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToCompany"),
                    object: company
                )
                return
            }

            // Coupon detail link: couponmaster://coupon/<id> or couponmanager://coupon/<id>
            if url.host == "coupon", let idString = url.pathComponents.last, let couponId = Int(idString) {
                // Save pending coupon id to shared container so that after login we can resume navigation
                if let sharedDefaults = AppGroupManager.shared.sharedUserDefaults {
                    sharedDefaults.set(couponId, forKey: "PendingCouponId")
                    print("🔖 Saved pending coupon id: \(couponId) to shared container")
                } else {
                    // Fallback to standard defaults
                    UserDefaults.standard.set(couponId, forKey: "PendingCouponId")
                }

                // Check if Face ID is enabled for the last logged in user and require authentication if so
                if let sharedData = AppGroupManager.shared.sharedUserDefaults?.data(forKey: "lastLoggedInUser"),
                   let user = try? JSONDecoder().decode(User.self, from: sharedData) {
                    let faceManager = FaceIDManager.shared
                    if faceManager.isFaceIDEnabled(for: user.id) && faceManager.isFaceIDAvailable {
                        Task {
                            let authenticated = await faceManager.authenticateWithFaceID(reason: "התחבר לאפליקציה כדי לפתוח את הקופון")
                            if authenticated {
                                // Remove pending and navigate
                                AppGroupManager.shared.sharedUserDefaults?.removeObject(forKey: "PendingCouponId")
                                NotificationCenter.default.post(name: NSNotification.Name("NavigateToCouponDetail"), object: nil, userInfo: ["couponId": couponId])
                            } else {
                                print("🔒 Face ID authentication failed - pending coupon remains saved until login")
                            }
                        }
                        return
                    }
                }

                // No Face ID required or no user found - try to navigate immediately (if logged in)
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToCouponDetail"), object: nil, userInfo: ["couponId": couponId])
                return
            }

            // Import image from share extension: couponmanager://import-image?file=<name>
            if url.host == "import-image" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let fileName = components.queryItems?.first(where: { $0.name == "file" })?.value {
                    // Post a notification with the incoming file name. The main list view
                    // will open the Add-from-Image flow, load the image from the shared
                    // container, and trigger analysis as usual.
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToAddFromImage"),
                        object: nil,
                        userInfo: ["fileName": fileName]
                    )
                    return
                }
            }
        }
    }
}
