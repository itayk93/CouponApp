# סקירה תפעולית של נוטיפיקציות

## קבצים רלוונטיים
- `CouponManagerApp/NotificationManager.swift` – לוגיקת תזמון ומענה להתראות.
- `CouponManagerApp/GlobalNotificationSettings.swift` – זמני ברירת המחדל והסנכרון ל-UserDefaults/Supabase.
- `CouponManagerApp/CouponsListView.swift` – נקודת הכניסה שמבקשת הרשאה ומפעילה עדכון התראות לאחר טעינת הקופונים.
- `CouponManagerApp/AdminSettingsView.swift` – שליחת התראת בדיקה וניהול זמני ההתראות הגלובליים.

## עקרונות
- כותרת ההתראה היא תמיד שם האפליקציה (מתוך `CFBundleDisplayName`/`CFBundleName`); רק הגוף משתנה לפי סוג ההתראה.
- כל סבב `scheduleExpirationNotifications` מוחק קודם את כל הבקשות הממתינות (`removeAllPendingNotificationRequests`).
- מתזמנים רק אם `authorizationStatus == .authorized` ורק לקופונים שיש להם `expirationDate` עתידי, לא `isExpired` ולא `isFullyUsed`.
- `userInfo` בכל בקשה כולל מזהה קופון (כשיש) ושדה `type` לזיהוי/ניווט.
- זמני ברירת המחדל (ניתנים לשינוי דרך ההגדרות הגלובליות): יומית 20:14, חודשית 10:00, יום התפוגה 10:00.

## סוגי התראות קיימות
| סוג | טריגר | שעה | מזהה/`type` | גוף |
| --- | --- | --- | --- | --- |
| חודשית | `daysUntilExpiration == 30` | `monthlyNotificationHour:monthlyNotificationMinute` (ברירת מחדל 10:00) | מזהה `monthly-<couponId>`, `type: monthly` | "הקופון של <חברה> יפוג תוקף ב<חודש>... עד <תאריך>" |
| יומית (7–1 ימים אחרונים) | לכל יום שבו `daysUntilExpiration` בין 1 ל-7 | `dailyNotificationHour:dailyNotificationMinute` (ברירת מחדל 20:14) | מזהה `specific-day-<couponId>-<daysLeft>`, `type: specific_day` | "הקופון של <חברה> יפוג תוקף מחר/נשארו X ימים..." |
| יום תפוגה | `daysUntilExpiration == 0` | `expirationDayHour:expirationDayMinute` (ברירת מחדל 10:00) | מזהה `expiration-<couponId>`, `type: expiration` | "הקופון של <חברה> פג תוקף היום..." |
| בדיקת מערכת | לחיצה על "שלח התראת בדיקה עכשיו" ב-`AdminSettingsView` | נשלחת לאחר 5 שניות (Trigger מסוג `UNTimeIntervalNotificationTrigger`) | מזהה `test-notification-<timestamp>`, `type: test` | "מערכת ההתראות פועלת כראוי! זה בדיקה לוודא שהכל עובד" |

## הזרימה
- בעת `onAppear` של `CouponsListView` נקראת `setupNotifications()`: מבקשת הרשאה וכשהיא מתקבלת מפעילה `updateNotifications()`.
- `updateNotifications()` נקראת גם לאחר טעינת הנתונים הראשית (`loadData`) ובכל שינוי של המערך `coupons` (`onChange`), כדי לסנכרן תזמונים עם הנתונים העדכניים.
- `scheduleExpirationNotifications(for:)` היא הפונקציה המרכזית: מוחקת בקשות קיימות ומזמינה את `scheduleMonthlyNotification`, `scheduleSpecificDayNotification`, `scheduleExpirationDayNotification` בהתאם למספר הימים שנותרו.
- `userNotificationCenter(_:didReceive:...)` משתמש ב-`couponId` מתוך `userInfo` כדי לשגר `Notification.Name("NavigateToCouponDetail")` למסך הראשי.

## דיבוג ותפעול
- `NotificationManager.debugPendingNotifications()` מדפיסה לקונסול את כל הבקשות הממתינות עם מזהים וזמן טריגר.
- ב-`AdminSettingsView` יש כפתור למחיקת כל ההתראות הממתינות (`removeAllPendingNotificationRequests`) וכפתור שמירה שמעדכן את זמני ההתראות (שומר ב-UserDefaults ומנסה לעדכן ב-Supabase).
