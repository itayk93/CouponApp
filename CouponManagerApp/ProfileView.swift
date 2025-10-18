//
//  ProfileView.swift
//  CouponManagerApp
//
//  פרופיל משתמש עם זיהוי פנים
//

import SwiftUI
import LocalAuthentication
import Combine

struct ProfileView: View {
    let user: User
    let onLogout: () -> Void
    
    @State private var showingFaceIDAlert = false
    @State private var faceIDAlertMessage = ""
    @State private var isLoading = false
    @State private var showingAdminSettings = false
    @State private var showingWidgetManagement = false
    private let apiClient = APIClient()
    @StateObject private var faceIDManager = FaceIDManager.shared
    
    private let primaryBlue = Color.appBlue
    private let orangeAccent = Color(red: 255/255, green: 136/255, blue: 0/255)
    private let lightGray = Color(red: 248/255, green: 250/255, blue: 252/255)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Profile Information Cards
                    profileCardsSection
                    
                    // Settings Section
                    settingsSection
                    
                    // Logout Button
                    logoutSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("פרופיל")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                Task {
                    await faceIDManager.loadFaceIDPreference(for: user.id)
                }
            }
            .rtlAlert("זיהוי פנים",
                      isPresented: $showingFaceIDAlert,
                      message: faceIDAlertMessage,
                      buttons: [RTLAlertButton("אישור", role: .cancel, action: nil)])
            .sheet(isPresented: $showingAdminSettings) {
                AdminSettingsView(user: user) {
                    showingAdminSettings = false
                }
            }
            .sheet(isPresented: $showingWidgetManagement) {
                WidgetCouponsOrderingView(user: user) {
                    // Handle any updates if needed
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [primaryBlue.opacity(0.8), primaryBlue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                if let profileImage = user.profileImage, !profileImage.isEmpty {
                    AsyncImage(url: URL(string: profileImage)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
            }
            
            // User Name
            VStack(spacing: 4) {
                Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Orange decorative line
            Rectangle()
                .fill(orangeAccent)
                .frame(width: 60, height: 3)
                .cornerRadius(3)
        }
        .padding(.top, 30)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Profile Cards Section
    private var profileCardsSection: some View {
        VStack(spacing: 15) {
            ProfileInfoCard(title: "פרטי חשבון", icon: "person.fill") {
                VStack(spacing: 8) {
                    InfoRow(label: "מזהה משתמש", value: "\(user.id)")
                    InfoRow(label: "גיל", value: user.age?.description ?? "לא מוגדר")
                    InfoRow(label: "מין", value: user.gender ?? "לא מוגדר")
                    InfoRow(label: "אזור", value: user.region ?? "לא מוגדר")
                }
            }
            
            ProfileInfoCard(title: "סטטוס חשבון", icon: "checkmark.shield.fill") {
                VStack(spacing: 8) {
                    InfoRow(label: "חשבון מאומת", value: user.isConfirmed ? "✅ כן" : "❌ לא")
                    InfoRow(label: "מנהל", value: user.isAdmin ? "👑 כן" : "👤 לא")
                    InfoRow(label: "חשבון פעיל", value: !user.isDeleted ? "✅ כן" : "❌ לא")
                }
            }
            
            // Admin Settings Section - only show for admin users
            if user.isAdmin {
                ProfileInfoCard(title: "הגדרות מנהל", icon: "gear.badge") {
                    VStack(spacing: 12) {
                        Button(action: {
                            showingAdminSettings = true
                        }) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .font(.title3)
                                Text("הגדרות התראות")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(primaryBlue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(primaryBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Text("ניהול זמני ההתראות של המערכת")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ProfileInfoCard(title: "נתוני קופונים", icon: "ticket.fill") {
                VStack(spacing: 8) {
                    InfoRow(label: "מספר קופונים", value: "\(user.slots)")
                    InfoRow(label: "קופונים אוטומטיים", value: "\(user.slotsAutomaticCoupons)")
                    InfoRow(label: "קופונים שנמכרו", value: "\(user.couponsSoldCount)")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 15) {
            // Face ID Setting Card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundColor(primaryBlue)
                        .font(.title2)
                    
                    Text("אבטחה")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("זיהוי פנים")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("פתח את האפליקציה עם זיהוי פנים")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $faceIDManager.isFaceIDEnabled)
                            .labelsHidden()
                            .onChange(of: faceIDManager.isFaceIDEnabled) { _, newValue in
                                handleFaceIDToggle(newValue)
                            }
                    }
                    
                    if faceIDManager.isFaceIDEnabled {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("זיהוי פנים מופעל - האפליקציה תיפתח אוטומטית עם זיהוי פנים")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Other Settings Card
            // Widget Management Card
            ProfileInfoCard(title: "ניהול ווידג'ט", icon: "square.grid.2x2.fill") {
                VStack(spacing: 12) {
                    Button(action: {
                        showingWidgetManagement = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title3)
                            Text("סידור קופונים בווידג'ט")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "arrow.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(primaryBlue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(primaryBlue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Text("בחר עד 4 קופונים וקבע את סדר הופעתם בווידג'ט")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            ProfileInfoCard(title: "הגדרות כלליות", icon: "gear.circle.fill") {
                VStack(spacing: 8) {
                    InfoRow(label: "ניוזלטר", value: user.newsletterSubscription ? "✅ מנוי" : "❌ לא מנוי")
                    InfoRow(label: "סיכום טלגרם", value: user.telegramMonthlySummary ? "✅ פעיל" : "❌ לא פעיל")
                    InfoRow(label: "באנר וואטסאפ", value: user.showWhatsappBanner ? "✅ מוצג" : "❌ מוסתר")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    
    // MARK: - Logout Section
    private var logoutSection: some View {
        VStack(spacing: 20) {
            Button(action: {
                onLogout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("התנתקות")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
    }
    
    // MARK: - Face ID Functions
    private func handleFaceIDToggle(_ enabled: Bool) {
        if enabled {
            // Enable Face ID
            Task {
                let success = await faceIDManager.enableFaceID(for: user.id)
                if success {
                    faceIDAlertMessage = "זיהוי פנים הופעל בהצלחה!"
                } else {
                    faceIDAlertMessage = "אימות זיהוי פנים נכשל. נסה שוב."
                }
                showingFaceIDAlert = true
            }
        } else {
            // Disable Face ID
            Task {
                await faceIDManager.disableFaceID(for: user.id)
                faceIDAlertMessage = "זיהוי פנים בוטל"
                showingFaceIDAlert = true
            }
        }
    }
}

// MARK: - Profile Info Card Component
struct ProfileInfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.appBlue)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Info Row Component (Reused from existing code)
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ProfileView(
        user: User(
            id: 1,
            email: "test@test.com",
            password: nil,
            firstName: "דוגמה",
            lastName: "משתמש",
            age: 30,
            gender: "male",
            region: "מרכז",
            isConfirmed: true,
            isAdmin: false,
            slots: 5,
            slotsAutomaticCoupons: 50,
            createdAt: "2024-01-01T00:00:00Z",
            profileDescription: nil,
            profileImage: nil,
            couponsSoldCount: 0,
            isDeleted: false,
            dismissedExpiringAlertAt: nil,
            dismissedMessageId: nil,
            googleId: nil,
            newsletterSubscription: true,
            telegramMonthlySummary: true,
            newsletterImage: nil,
            showWhatsappBanner: false,
            faceIdEnabled: false,
            pushToken: nil
        ),
        onLogout: {}
    )
}
