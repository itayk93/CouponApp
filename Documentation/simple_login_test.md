# פתרון זמני - בדיקת התחברות

מכיוון שהפרויקט iOS התקלקל, בוא נבדוק קודם שהשרת עובד.

## שלב 1: בדיקת השרת (ממתין לעדכון)
```bash
curl https://www.couponmasteril.com/api/debug/user/1
```

כשזה יחזיר JSON במקום 404, השרת עודכן.

## שלב 2: בדיקת התחברות
```bash
curl -X POST https://www.couponmasteril.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"itayk93@gmail.com","password":"I637@A18!"}'
```

## שלב 3: יצירת פרויקט iOS חדש
אם הכל עובד בשרת, נוכל ליצור פרויקט iOS פשוט חדש.

בינתיים נמתין לעדכון השרת...