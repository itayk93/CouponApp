# CouponManager iOS App

אפליקציית iOS לניהול קופונים שמתחברת לשרת Flask הקיים.

## מבנה הפרויקט

```
CouponManager/
├── main.swift              # נקודת הכניסה לאפליקציה
├── ContentView.swift       # המסך הראשי
├── Models.swift           # מודלים של נתונים
├── APIClient.swift        # לקוח API לתקשורת עם השרת
├── AuthenticationManager.swift  # ניהול התחברות
├── LoginView.swift        # מסך התחברות ורישום
├── MainTabView.swift      # התפריט הראשי
├── CouponsListView.swift  # רשימת הקופונים
├── CouponsViewModel.swift # לוגיקה לניהול קופונים
├── AddCouponView.swift    # הוספת קופון חדש
├── UseCouponView.swift    # שימוש בקופון
├── StatisticsView.swift   # מסך סטטיסטיקות
└── ProfileView.swift      # מסך פרופיל
```

## תכונות

### 🔐 התחברות ואבטחה
- התחברות עם אימייל וסיסמה
- רישום משתמש חדש
- שמירת מצב התחברות במכשיר
- התנתקות מאובטחת

### 📱 ניהול קופונים
- צפייה ברשימת הקופונים שלי
- חיפוש וסינון קופונים
- הוספת קופון חדש
- עדכון שימוש בקופון (חלקי או מלא)
- מעקב אחר תאריכי תוקף

### 📊 סטטיסטיקות
- סך הערך של כל הקופונים
- סכום שנוצל ויתרה
- חיסכון כולל
- אחוז ניצול הקופונים

### 🔔 מערכת התראות חכמה
- **התראה חודשית**: הודעה אחת 30 ימים לפני תפוגת הקופון
- **התראות יומיות**: הודעה יומית ב-10:00 בבוקר בשבוע האחרון (7 ימים)
- **התראת יום התפוגה**: הודעה מיוחדת ביום פקיעת התוקף
- **באנר התראה**: באנר חזותי למעלה במסך הראשי עבור קופונים שעומדים לפוג בשבוע הקרוב
- **ניווט ישיר**: לחיצה על התראה מעבירה ישירות לפרטי הקופון

### 👤 פרופיל משתמש
- פרטי המשתמש
- הגדרות חשבון
- ניהול העדפות

## הגדרת הפרויקט

### דרישות מקדימות
- Xcode 14.0 ומעלה
- iOS 15.0 ומעלה
- חיבור לאינטרנט

### הגדרת השרת
הפרויקט מתחבר לשרת Flask הקיים ב: `https://www.couponmasteril.com`

API Endpoints הזמינים:
- `POST /api/auth/login` - התחברות
- `POST /api/auth/register` - רישום
- `POST /api/auth/logout` - התנתקות
- `GET /api/coupons/user/{id}` - קופונים של משתמש
- `POST /api/coupons` - הוספת קופון
- `POST /api/coupons/{id}/use` - שימוש בקופון
- `GET /api/companies` - רשימת חברות
- `GET /api/statistics/user/{id}` - סטטיסטיקות משתמש

### יצירת פרויקט Xcode

1. פתח Xcode
2. צור פרויקט iOS חדש:
   - Choose template: **iOS App**
   - Product Name: **CouponManager**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Use Core Data: **לא מסומן**
   - Include Tests: **מסומן**

3. העתק את כל הקבצי ה-Swift מתיקיית `CouponManager/` לפרויקט החדש

4. בפרויקט Xcode:
   - הגדר minimum deployment target ל-iOS 15.0
   - הוסף permissions לקובץ Info.plist אם נדרש

## התאמות נדרשות

### שינוי כתובת השרת
בקובץ `APIClient.swift`, שנה את המשתנה `baseURL`:

```swift
private let baseURL = "https://your-server-url.com"
```

### הוספת Support לעברית
1. בהגדרות הפרויקט, הוסף עברית ב-Localizations
2. הגדר Text Direction ל-Right to Left

## הרצת הפרויקט

1. פתח את הפרויקט ב-Xcode
2. בחר simulator או device
3. לחץ על Run (⌘+R)

## פתרון בעיות נפוצות

### בעיות חיבור לשרת
- וודא שכתובת השרת נכונה
- בדוק חיבור לאינטרנט
- וודא שהשרת פועל ומגיב

### בעיות authentication
- נקה cookies ב-simulator
- בדוק שפרטי ההתחברות נכונים
- וודא שה-API endpoints פועלים

### בעיות בנייה
- וודא שגירסת iOS minimum היא 15.0
- בדוק שכל הקבצים מוספים לפרויקט
- נקה build folder (⌘+Shift+K)

## 🔔 מערכת ההתראות - תיעוד טכני

### מבנה המערכת

מערכת ההתראות מורכבת משני מרכיבים עיקריים:

#### 1. NotificationManager.swift
מנהל ההתראות הראשי שמטפל ב:
- בקשת הרשאות התראות מהמשתמש
- תזמון התראות לקופונים שעומדים לפוג
- טיפול בלחיצות על התראות
- ניווט לפרטי קופון ספציפי

#### 2. ExpirationBanner.swift  
רכיב חזותי שמציג באנר התראה בחלק העליון של המסך הראשי עבור קופונים שעומדים לפוג בשבוע הקרוב.

### לוגיקת ההתראות

#### זמני התראה:
- **30 ימים לפני תפוגה**: התראה אחת בעברית עם שם החודש
- **7-1 ימים לפני תפוגה**: התראה יומית ב-10:00 בבוקר
- **יום התפוגה**: התראה מיוחדת ב-10:00 בבוקר

#### תוכן ההתראות:
```swift
// דוגמה לתוכן התראה חודשית
"הקופון של שופרסל יפוג תוקף באוקטובר. כדאי לנצל אותו עד 15/10/2024"

// דוגמה לתוכן התראה יומית  
"הקופון של שופרסל יפוג תוקף נשארו 3 ימים. לחץ כדי לצפות בפרטים"

// דוגמה לתוכן התראת יום התפוגה
"הקופון של שופרסל פג תוקף היום! לחץ כדי לצפות בפרטים"
```

### האנר התראה

האנר מופיע בחלק העליון של המסך הראשי ומציג:
- עד 3 קופונים שעומדים לפוג בשבוע הקרוב
- מספר הימים שנותרו לכל קופון
- אינדיקטור "+X עוד" אם יש יותר מ-3 קופונים
- אפשרות לחיצה לצפייה בפרטי הקופון

### אינטגרציה במערכת

#### הפעלת המערכת:
```swift
// ב-CouponsListView.swift
@StateObject private var notificationManager = NotificationManager.shared

// הפעלה אוטומטית בעת טעינת המסך
.onAppear {
    setupNotifications()
}
```

#### עדכון אוטומטי:
```swift
// עדכון התראות כאשר רשימת הקופונים משתנה
.onChange(of: coupons) { _ in
    updateExpiringCoupons()
    updateNotifications()
}
```

### הרשאות נדרשות

המערכת מבקשת הרשאות התראות מקומיות מהמשתמש:
- `.alert` - הצגת התראות חזותיות
- `.sound` - השמעת צלילי התראה
- `.badge` - תצוגת מספר התראות על האייקון

### מבנה קבצים

```
CouponManagerApp/
├── NotificationManager.swift      # מנהל ההתראות הראשי
├── ExpirationBanner.swift        # רכיב האנר התראה
├── CouponsListView.swift         # אינטגרציה במסך הראשי
├── CouponModels.swift           # הרחבות למודל Coupon
└── CouponDetailView.swift       # מסך פרטי קופון (יעד ניווט)
```

### פונקציות עיקריות

#### NotificationManager:
- `requestAuthorization()` - בקשת הרשאות
- `scheduleExpirationNotifications()` - תזמון התראות
- `updateNotifications()` - עדכון התראות
- `scheduleMonthlyNotification()` - התראה חודשית
- `scheduleDailyNotifications()` - התראות יומיות
- `scheduleExpirationDayNotification()` - התראת יום תפוגה

#### ExpirationBanner:
- `expirationText()` - חישוב טקסט זמן תפוגה
- `bannerRow()` - שורת קופון בודד
- `additionalCouponsRow()` - אינדיקטור קופונים נוספים

### הרחבות למודל Coupon

```swift
extension Coupon {
    var isExpiringInWeek: Bool {
        // בדיקה אם קופון עומד לפוג בשבוע הקרוב
    }
}
```

### דיבוג ובדיקה

המערכת כוללת מצב דיבוג עם:
- התראות בדיקה שנשלחות מיד לאחר ההפעלה
- הודעות לוג מפורטות בקונסול
- התראות דמו לבדיקת הפונקציונליות

## פיתוח נוסף

### הוספת תכונות
הפרויקט מבוסס על ארכיטקטורת MVVM ומוכן להוספת תכונות:
- Marketplace לקניית קופונים
- שיתוף קופונים
- סנכרון offline

### בדיקות
הפרויקט כולל מבנה לבדיקות unit tests ו-UI tests.

## 🎨 Latest Design & Functionality Updates

### Color Scheme Update (October 2025)

#### New Dark Blue-Gray Theme
- **Updated App Colors**: Replaced bright blue with elegant dark blue-gray theme
- **Main Color**: `#3C4A62` - Professional dark blue-gray
- **Light Accent**: `#4F5D75` - Subtle lighter blue-gray
- **Consistent Application**: All UI elements now use the new color scheme

```swift
// Updated AppColors.swift
static let appBlue = Color(red: 0.235, green: 0.290, blue: 0.384) // #3C4A62
static let appLightBlue = Color(red: 0.310, green: 0.365, blue: 0.459) // #4F5D75
```

### Coupon Design Redesign (October 2025)

#### Coupon Display Changes
- **Centered & Prominent Coupon Code Display**: Code now shown in 22pt, centered with colorful background
- **Removed Description Line**: Saves space and creates cleaner design
- **Full Dark Mode Support**: Colors automatically adapt to dark/light mode
- **Monospace Font**: Maximum readability for coupon codes
- **New Color Integration**: Uses the new dark blue-gray theme

```swift
// New code design with updated colors
Text(decryptedCode)
    .font(.system(size: 22, weight: .bold, design: .monospaced))
    .foregroundColor(colorScheme == .dark ? .white : .appBlue)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
        RoundedRectangle(cornerRadius: 8)
            .fill(colorScheme == .dark ? Color.appBlue.opacity(0.2) : Color.appBlue.opacity(0.1))
    )
```

### 🧠 Smart Coupon Sorting

Implemented a new smart sorting system based on 4 priority levels:

#### 1. **First Priority: Coupons Expiring This Week** ⏰
Coupons expiring within the next week are shown first to prevent value loss.

#### 2. **Second Priority: Companies by Personal Usage Pattern** 📈
The system collects personal usage data and sorts coupons by most-used companies:

```sql
SELECT 
    company,
    COUNT(*) as total_count,
    SUM(CASE WHEN cost > 0 THEN 1 ELSE 0 END) as paid_count,
    SUM(CASE WHEN cost = 0 THEN 1 ELSE 0 END) as free_count,
    SUM(cost) as total_spent
FROM coupon
WHERE user_id = ?
GROUP BY company
ORDER BY 
    paid_count DESC,  -- Paid coupons first
    total_count DESC  -- Total count second
```

#### 3. **Third Priority: Remaining Value** 💰
Coupons with higher remaining value are shown first.

#### 4. **Fourth Priority: Date Added** 📅
Newer coupons are preferred over older ones.

### Technical Changes Made

#### New Usage Statistics Model
```swift
struct CompanyUsageStats: Codable, Identifiable {
    let company: String
    let totalCount: Int      // Total coupons
    let paidCount: Int       // Paid coupons
    let freeCount: Int       // Free coupons
    let totalSpent: Double   // Total amount spent
}
```

#### New API for Data Collection
- `POST /rest/v1/rpc/get_company_usage_stats` - Returns grouped usage data by company

#### CouponsListView Updates
- Added `@State private var companyUsageStats: [CompanyUsageStats]`
- Enhanced `sortCoupons()` function with smart logic
- Automatic loading of usage data on every launch

### Benefits of the Changes

#### Color Scheme
- ✅ **Professional Appearance** - Dark blue-gray provides sophisticated look
- ✅ **Better Contrast** - Improved readability in both light and dark modes
- ✅ **Brand Consistency** - Unified color scheme across all app elements
- ✅ **User Experience** - Calmer, more professional visual identity

#### Design
- ✅ **Improved Readability** - Code is more prominent and easily readable
- ✅ **Space Saving** - Removal of unnecessary text
- ✅ **Professional Design** - Looks like leading mobile apps
- ✅ **Accessibility** - Full support for different display modes

#### Smart Sorting
- ✅ **Prevents Expiration Loss** - Urgent coupons shown first
- ✅ **Personal Customization** - Order based on your preferences and habits
- ✅ **Time Saving** - Most relevant coupons at the top of the list
- ✅ **Optimal Usage** - Encourages use of preferred companies

**Update Date**: October 10, 2025

## 📱 iOS Home Screen Widgets (New)

### Widget Overview
Added comprehensive iOS widget support with two widget sizes and deep linking functionality for quick access to coupon data directly from the home screen.

### Widget Types

#### 📊 Small Widget (Square)
- **Active Coupons Count**: Shows number of coupons with "פעיל" status
- **Total Value Display**: Shows sum of remaining value for non-one-time active coupons
- **⚠️ Priority Alert System**: When coupons expire this week, shows warning with company name and logo instead of regular stats
- **Smart Design**: Adapts text and colors based on system appearance (dark/light mode)

#### 🏢 Medium Widget (Wide Rectangle)
- **Top 4 Companies**: Shows companies with most coupons, ranked by count
- **Company Logos**: Displays actual company logos from the server
- **Coupon Count Badges**: Shows number of coupons per company
- **Interactive Tiles**: Each company tile is tappable for direct navigation

### Deep Linking System

#### URL Scheme Implementation
```swift
// URL Format
couponmanager://company/[CompanyName]

// Example
couponmanager://company/שופרסל
```

#### App Navigation Flow
1. User taps widget company tile
2. Widget generates deep link URL
3. Main app receives URL via `onOpenURL`
4. App automatically:
   - Sets search filter to company name
   - Changes filter to "All" to show all company coupons
   - Refreshes coupon list view
   - Takes user directly to filtered results

### Data Architecture

#### App Groups Integration
- **Shared Container**: `group.com.couponmanager.shared`
- **Efficient Sync**: Main app saves data to shared container when loading coupons
- **Widget Access**: Widget reads from shared container first, fallback to network
- **User Data Sharing**: Login tokens and user info shared securely

#### Smart Data Management
- **Primary Source**: Shared container data from main app
- **Fallback**: Direct API calls when shared data unavailable
- **Auto-Refresh**: Widget timeline updates every hour
- **Efficient Battery**: Minimal network usage through shared data

### Technical Implementation

#### Widget Extension Structure
```
CouponManagerWidget/
├── CouponManagerWidget.swift    # Main widget implementation
├── SharedModels.swift          # Widget-specific data models  
├── WidgetAPIClient.swift       # API client with shared data support
└── Info.plist                 # Widget configuration & permissions
```

#### Main App Integration
```
CouponManagerApp/
├── AppGroupManager.swift       # Shared data management
├── Info.plist                 # URL scheme & App Groups config
├── ContentView.swift          # Deep link handling
└── CouponsListView.swift      # Navigation response to deep links
```

### Setup Requirements

#### Manual Xcode Configuration Required
Due to Xcode project complexity, manual setup is required:

1. **Add Widget Extension Target** in Xcode:
   - File → New → Target → Widget Extension
   - Name: `CouponManagerWidget`

2. **Copy Widget Files** to the new target:
   - `CouponManagerWidget/CouponManagerWidget.swift`
   - `CouponManagerWidget/SharedModels.swift`
   - `CouponManagerWidget/WidgetAPIClient.swift`

3. **Configure App Groups**:
   - Enable App Groups capability for both targets
   - Add group: `group.com.couponmanager.shared`

4. **Add URL Scheme** to main app Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>couponmanager</string>
           </array>
       </dict>
   </array>
   ```

### Widget Features

#### Expiration Detection
```swift
// Week-based expiration detection
private var weeklyExpiredCoupons: [WidgetCoupon] {
    let calendar = Calendar.current
    let today = Date()
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
    
    return coupons.filter { coupon in
        guard let expirationDate = coupon.expirationDate else { return false }
        return expirationDate >= weekAgo && expirationDate <= today && coupon.isExpired
    }
}
```

#### Company Ranking Logic
```swift
// Top companies by coupon count with logo support
private var topCompanies: [(company: String, count: Int, logoPath: String)] {
    let companyCounts = Dictionary(grouping: coupons) { $0.company }
        .mapValues { $0.count }
        .sorted { $0.value > $1.value }
        .prefix(4)
}
```

### Widget Behavior

#### Update Schedule
- **Automatic**: Every 60 minutes
- **Triggered**: When main app loads new coupon data
- **Smart Refresh**: Only when data actually changes

#### Error Handling
- **Network Failures**: Falls back to cached shared data
- **Missing Data**: Shows placeholder content
- **API Errors**: Graceful degradation to sample data

### User Experience

#### Visual Design
- **App Consistency**: Uses the new dark blue-gray color scheme (#3C4A62)
- **Hebrew Support**: All text properly displayed in Hebrew
- **Accessibility**: Full VoiceOver and Dynamic Type support
- **Dark Mode**: Automatic adaptation to system appearance

#### Interaction Flow
```
Home Screen Widget Tap → Deep Link → App Launch → Auto-Filter → Company Coupons
```

### Performance Optimizations

#### Efficient Data Loading
- **Shared Container First**: Avoids unnecessary network calls
- **Compressed Models**: Minimal data structures for widgets
- **Async Loading**: Non-blocking image loading for company logos
- **Memory Management**: Proper cleanup and resource management

#### Battery Optimization
- **Minimal Network**: Primary reliance on shared data
- **Smart Updates**: Only refresh when actual changes occur
- **Background Efficiency**: Optimized for iOS background processing

### Files Added

#### New Widget Files
- `CouponManagerWidget/CouponManagerWidget.swift`
- `CouponManagerWidget/SharedModels.swift`
- `CouponManagerWidget/WidgetAPIClient.swift`
- `CouponManagerWidget/Info.plist`
- `CouponManagerApp/AppGroupManager.swift`
- `WIDGET_SETUP_INSTRUCTIONS.md` (Hebrew setup guide)

#### Modified Files
- `CouponManagerApp/CouponManagerAppApp.swift` - Deep link handling
- `CouponManagerApp/ContentView.swift` - User data sharing
- `CouponManagerApp/CouponsListView.swift` - Navigation and data sync

**Widget Update Date**: October 10, 2025

## תמיכה
לשאלות ובעיות, פנה לצוות הפיתוח או פתח issue בגיטהאב.