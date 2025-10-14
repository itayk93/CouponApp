# הוראות הגדרת Widget עבור CouponManagerApp

## שלב 1: הוספת Widget Extension ב-Xcode

1. פתח את הפרויקט ב-Xcode
2. בחר את הפרויקט בעץ הקבצים השמאלי
3. לחץ על כפתור "+" בחלק התחתון של רשימת הטרגטים
4. בחר "Widget Extension" מרשימת התבניות
5. הגדר את השם כ: `CouponManagerWidget`
6. ודא שה-Bundle Identifier הוא: `[YOUR_APP_BUNDLE_ID].CouponManagerWidget`

## שלב 2: העתקת קבצי ה-Widget

1. מחק את הקבצים הדיפולטיים שנוצרו בתיקייה `CouponManagerWidget`
2. העתק את הקבצים הבאים לתיקיית ה-Widget Extension:
   - `CouponManagerWidget/CouponManagerWidget.swift`
   - `CouponManagerWidget/SharedModels.swift`
   - `CouponManagerWidget/WidgetAPIClient.swift`
   - `CouponManagerWidget/Info.plist`

## שלב 3: הגדרת App Groups (אופציונלי)

1. בחר את הטרגט הראשי של האפליקציה
2. לך ל-"Signing & Capabilities"
3. הוסף "App Groups" capability
4. צור קבוצה חדשה: `group.[YOUR_BUNDLE_ID].shared`
5. חזור על התהליך עבור ה-Widget Extension

## שלב 4: הגדרת URL Scheme

1. בחר את הטרגט הראשי של האפליקציה
2. לך ל-"Info" tab
3. הרחב את "URL Types"
4. הוסף URL Type חדש:
   - Identifier: `com.couponmanager.deeplink`
   - URL Schemes: `couponmanager`

## שלב 5: הגדרת Permissions

ודא שהאפליקציה הראשית מכילה את ההרשאות הבאות ב-Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>NSFaceIDUsageDescription</key>
<string>האפליקציה משתמשת ב-Face ID לאימות מהיר ובטוח</string>
<key>NSCameraUsageDescription</key>
<string>האפליקציה צריכה גישה למצלמה לצורך סריקת קופונים</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>האפליקציה צריכה גישה לגלריה לצורך בחירת תמונות של קופונים</string>
```

## שלב 6: בניית הפרויקט

1. בחר את סכמת האפליקציה הראשית
2. בנה את הפרויקט (Cmd+B)
3. בדוק שאין שגיאות compilation

## שלב 7: בדיקת ה-Widget

1. הרץ את האפליקציה על מכשיר או simulator
2. לך למסך הבית
3. גש להגדרות Widget:
   - iOS 14+: לחץ לחיצה ארוכה על המסך הריק ולחץ על "+"
   - או: Settings > Control Center > Customize Controls
4. חפש את "Coupon Manager" ברשימת ה-Widgets
5. הוסף את ה-Widget למסך הבית

## תכונות ה-Widget

### Widget קטן (Small):
- מציג מספר קופונים פעילים
- מציג סכום כולל של קופונים פעילים
- אזהרה על קופונים שפגו השבוע

### Widget בינוני (Medium):
- מציג 4 החברות המובילות לפי מספר קופונים
- לחיצה על חברה פותחת את האפליקציה עם פילטר לחברה זאת

## בעיות נפוצות

### השגיאה "Module not found"
- ודא שכל הקבצים נוספו לטרגט הנכון
- בדוק שה-Widget Extension כולל את כל הקבצים הנדרשים

### ה-Widget לא מופיע ברשימה
- ודא ש-Info.plist של ה-Widget תקין
- בדוק שהבנייה הושלמה בהצלחה

### נתונים לא מתעדכנים
- בדוק את חיבור האינטרנט
- ודא שמשתמש מחובר לאפליקציה

## הערות נוספות

- ה-Widget מתעדכן אוטומטית כל שעה
- בעת שגיאה, ה-Widget יציג נתונים לדוגמה
- Deep linking עובד רק כאשר האפליקציה מותקנת