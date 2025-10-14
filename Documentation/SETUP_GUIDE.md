# מדריך הגדרה - אפליקציית מנהל קופונים

## הקבצים שנוצרו:
- ✅ `User.swift` - מודל משתמש עם כל השדות
- ✅ `APIClient.swift` - חיבור ל-Supabase
- ✅ `SupabaseConfig.swift` - קריאת הגדרות מ-environment
- ✅ `ContentView.swift` - UI מלא להצגת נתוני משתמש
- ✅ `Config.xcconfig` - משתני סביבה (עם הפרטים האמיתיים שלך)
- ✅ `Info.plist` - קונפיגורציה של האפליקציה
- ✅ `.gitignore` - מגן על הפרטים הסודיים

## שלבי הגדרה ב-Xcode:

### 1. פתח את הפרויקט
```bash
open CouponManagerApp.xcodeproj
```

### 2. הוסף את כל הקבצים לפרויקט
- ב-Xcode Navigator, לחץ ימין על "CouponManagerApp" (התיקייה כחולה)
- בחר "Add Files to CouponManagerApp"
- בחר את כל הקבצי ה-Swift החדשים:
  - User.swift
  - APIClient.swift  
  - SupabaseConfig.swift
- ודא שהם מוספים לטרגט

### 3. וודא שכל הקבצים בפרויקט
ודא שכל הקבצים האלה מופיעים ב-Navigator:
- ✅ CouponManagerAppApp.swift
- ✅ ContentView.swift  
- ✅ User.swift
- ✅ APIClient.swift
- ✅ SupabaseConfig.swift
- ✅ Info.plist
- ✅ Config.xcconfig

### 5. הרץ את האפליקציה
- בחר simulator (iPhone 15 או כל iPhone)
- לחץ Command+R או כפתור ה-Run
- האפליקציה צריכה להציג את נתוני המשתמש עם ID=1 מ-Supabase

## מה האפליקציה עושה:
1. מתחברת ל-Supabase עם ה-URL וה-Key שלך
2. שולפת משתמש עם ID=1 מטבלת users
3. מציגה את כל הפרטים בממשק נקי ומסודר בעברית
4. כוללת טיפול בשגיאות ו-loading state

## פתרון בעיות:

### אם האפליקציה לא מצליחה להתחבר:
1. בדוק שה-URLs נכונים בקובץ Config.xcconfig
2. ודא שטבלת users קיימת ב-Supabase
3. בדוק שיש משתמש עם ID=1
4. ודא שהגישה לטבלה מותרת (RLS policies)

### אם יש שגיאות build:
1. ודא שכל הקבצים מוספים לפרויקט
2. בדוק שה-Config.xcconfig מקושר נכון
3. נקה build folder (Command+Shift+K)

## מה הלאה:
האפליקציה מוכנה ופונקציונלית! אתה יכול להוסיף:
- עוד מסכים
- הוספת/עריכת קופונים
- התחברות משתמשים
- ועוד...

הפרטים הסודיים מוגנים ולא יועלו לגיט! 🔒