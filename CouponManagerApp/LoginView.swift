//
//  LoginView.swift
//  CouponManagerApp
//
//  מסך התחברות מלא
//

import SwiftUI
import UIKit
import WidgetKit

struct LoginView: View {
    let onLoginSuccess: (User) -> Void
    let onLogout: () -> Void
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    @State private var isPasswordVisible = false
    @Environment(\.colorScheme) private var colorScheme
    
    private let primaryBlue = Color.appBlue
    private let orangeAccent = Color(red: 255/255, green: 136/255, blue: 0/255)
    private let lightGray = Color(red: 248/255, green: 250/255, blue: 252/255)
    
    // MARK: - Dark Mode Support
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(red: 247/255, green: 249/255, blue: 252/255)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white
    }
    
    private var inputBackgroundColor: Color {
        colorScheme == .dark ? Color(.tertiarySystemBackground) : lightGray
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .secondary
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 15) {
                        Text("ברוכים הבאים!")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(primaryBlue)
                            .padding(.top, 50)
                        
                        // Orange decorative line
                        Rectangle()
                            .fill(orangeAccent)
                            .frame(width: 80, height: 4)
                            .cornerRadius(2)
                    }
                    .padding(.bottom, 40)
                
                    // Login Card
                    VStack(spacing: 25) {
                        // Card Header
                        VStack(spacing: 15) {
                            Text("התחברות")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(primaryBlue)
                            
                            // Decorative dots
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(primaryBlue)
                                    .frame(width: 6, height: 6)
                                Circle()
                                    .fill(Color.red.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                Circle()
                                    .fill(primaryBlue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Email Field
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack {
                                Text("Email")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(primaryTextColor)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("itayk93@gmail.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textContentType(.emailAddress)
                                    .environment(\.layoutDirection, .leftToRight)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(inputBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        
                        // Password Field
                        VStack(alignment: .trailing, spacing: 8) {
                            HStack {
                                Text("סיסמה")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(primaryTextColor)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                if isPasswordVisible {
                                    TextField("••••••••", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("••••••••", text: $password)
                                        .textContentType(.password)
                                }
                                
                                Button(action: {
                                    isPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(inputBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Login Button
                        Button(action: login) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isLoading ? "מתחבר..." : "התחברות")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(primaryBlue)
                            .cornerRadius(10)
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        
                        // Secondary options
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Button("הירשם כאן") {
                                    // Register action
                                }
                                .foregroundColor(primaryBlue)
                                .font(.system(size: 15))
                                
                                Text("|")
                                    .foregroundColor(.gray)
                                
                                Button("שחזור סיסמה") {
                                    // Forgot password action
                                }
                                .foregroundColor(primaryBlue)
                                .font(.system(size: 15))
                            }
                            
                            // OR divider
                            HStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("או")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 10)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 10)
                            
                            // Google Login Button
                            Button(action: {
                                // Google login action
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .foregroundColor(.gray)
                                    Text("התחברות עם Google")
                                        .foregroundColor(primaryTextColor)
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, minHeight: 45)
                                .background(cardBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 40)
                    .background(cardBackgroundColor)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 30)
                
                    // Features Section
                    VStack(spacing: 30) {
                        // Section title
                        VStack(spacing: 10) {
                            Text("איך Coupon Master עוזר לכם לנהל קופונים?")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(primaryBlue)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            // Orange line under title
                            Rectangle()
                                .fill(orangeAccent)
                                .frame(width: 60, height: 3)
                                .cornerRadius(3)
                        }
                        .padding(.top, 40)
                        
                        // Features Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 15),
                            GridItem(.flexible(), spacing: 15)
                        ], spacing: 20) {
                            FeatureCard(
                                icon: "📊",
                                title: "סטטיסטיקות",
                                description: "ראו כמה כסף חסכתם, על מה הוצאתם הכי הרבה ועוד נתונים מעניינים.",
                                primaryColor: primaryBlue,
                                orangeAccent: orangeAccent,
                                backgroundColor: cardBackgroundColor
                            )
                            
                            FeatureCard(
                                icon: "⚠️",
                                title: "התראות חכמות",
                                description: "האפליקציה עוקבת אחר כמה כסף נשאר בכל קופון ומציגה לכם את הסכום הכולל \"בארנק\".",
                                primaryColor: primaryBlue,
                                orangeAccent: orangeAccent,
                                backgroundColor: cardBackgroundColor
                            )
                            
                            FeatureCard(
                                icon: "💰",
                                title: "מעקב יתרות",
                                description: "קבלו התראות חודש לפני, שבוע לפני ויום מראש. לא תשכחו עוד קופון!",
                                primaryColor: primaryBlue,
                                orangeAccent: orangeAccent,
                                backgroundColor: cardBackgroundColor
                            )
                            
                            FeatureCard(
                                icon: "📱",
                                title: "הכנסת קופונים",
                                description: "הכניסו את כל הקופונים הדיגיטליים שלכם במקום אחד. שוברים לסופרמרקט, כרטיסי מתנה ועוד",
                                primaryColor: primaryBlue,
                                orangeAccent: orangeAccent,
                                backgroundColor: cardBackgroundColor
                            )
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 50)
                }
            }
            .background(backgroundColor)
            .navigationBarHidden(true)
            .environment(\.layoutDirection, .rightToLeft)
            // Tap anywhere to dismiss the keyboard
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
        }
        .onAppear {
            // Pre-fill for testing
            email = "itayk93@gmail.com"
        }
    }
    
    private func login() {
        isLoading = true
        errorMessage = ""
        
        print("🔐 Attempting login for: \(email)")
        
        // Find user by email
        
        // Search for user by email instead of ID
        // let originalFetchUser = apiClient.fetchUser  // Not needed anymore
        
        // Create a custom search
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/users?email=eq.\(email)&select=*") else {
            errorMessage = "שגיאה בחיבור לשרת"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "שגיאה בחיבור: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "לא התקבלו נתונים מהשרת"
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    
                    guard let user = users.first else {
                        errorMessage = "אימייל לא נמצא במערכת"
                        return
                    }
                    
                    // Check password
                    let isPasswordValid = PasswordManager.checkPassword(password, againstHash: user.password)
                    
                    if isPasswordValid {
                        print("✅ Login successful!")
                        
                        // Save user data for Face ID auto-login (standard UserDefaults)
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "lastLoggedInUser")
                        }
                        
                        // Save user to shared App Group for the widget
                        AppGroupManager.shared.saveCurrentUserToSharedContainer(user)
                        // Trigger widget refresh
                        WidgetCenter.shared.reloadAllTimelines()
                        
                        onLoginSuccess(user)
                    } else {
                        errorMessage = "סיסמה שגויה"
                        print("❌ Password verification failed")
                    }
                    
                } catch {
                    errorMessage = "שגיאה בפענוח נתונים: \(error.localizedDescription)"
                    print("❌ JSON decode error: \(error)")
                }
            }
        }.resume()
    }
}

struct MainAppView: View {
    let user: User
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("ברוך הבא,")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("\(user.firstName ?? "משתמש") \(user.lastName ?? "")")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.appBlue)
                }
                .padding()
                
                Divider()
                
                // User Info Cards
                ScrollView {
                    LazyVStack(spacing: 15) {
                        InfoCard(title: "פרטי חשבון", icon: "person.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "ID", value: "\(user.id)")
                                InfoRow(label: "אימייל", value: user.email)
                                InfoRow(label: "גיל", value: user.age?.description ?? "לא מוגדר")
                                InfoRow(label: "מין", value: user.gender ?? "לא מוגדר")
                            }
                        }
                        
                        InfoCard(title: "סטטוס", icon: "checkmark.shield.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "חשבון מאומת", value: user.isConfirmed ? "✅ כן" : "❌ לא")
                                InfoRow(label: "מנהל", value: user.isAdmin ? "👑 כן" : "👤 לא")
                                InfoRow(label: "חשבון פעיל", value: !user.isDeleted ? "✅ כן" : "❌ לא")
                            }
                        }
                        
                        InfoCard(title: "קופונים", icon: "ticket.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "מספר קופונים", value: "\(user.slots)")
                                InfoRow(label: "קופונים אוטומטיים", value: "\(user.slotsAutomaticCoupons)")
                                InfoRow(label: "קופונים שנמכרו", value: "\(user.couponsSoldCount)")
                            }
                        }
                        
                        InfoCard(title: "הגדרות", icon: "gear.circle.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(label: "ניוזלטר", value: user.newsletterSubscription ? "✅ מנוי" : "❌ לא מנוי")
                                InfoRow(label: "סיכום טלגרם", value: user.telegramMonthlySummary ? "✅ פעיל" : "❌ לא פעיל")
                                InfoRow(label: "באנר וואטסאפ", value: user.showWhatsappBanner ? "✅ מוצג" : "❌ מוסתר")
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("מנהל קופונים")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.appBlue)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let primaryColor: Color
    let orangeAccent: Color
    let backgroundColor: Color
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 15) {
            // Icon
            VStack {
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(primaryColor.opacity(0.1))
                    )
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            
            // Title
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Description
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            // Orange bottom border that appears on hover
            Rectangle()
                .fill(orangeAccent)
                .frame(height: 4)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isHovered),
            alignment: .bottom
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered.toggle()
                }
            }
        }
    }
}

#Preview {
    LoginView(
        onLoginSuccess: { user in
            print("Login successful for user: \(user.firstName ?? "Unknown")")
        },
        onLogout: {
            print("Logout")
        }
    )
}
