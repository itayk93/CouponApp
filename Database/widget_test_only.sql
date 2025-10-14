-- Widget Testing Only - Safe for existing website
-- Run these queries to test the widget without affecting anything else

-- ==================================================
-- 1. CHECK IF FUNCTIONS EXIST
-- ==================================================
SELECT 
    routine_name, 
    routine_type, 
    data_type
FROM information_schema.routines 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies')
ORDER BY routine_name;

-- ==================================================
-- 2. FIND A REAL USER ID TO TEST WITH
-- ==================================================
SELECT id, username, email FROM users LIMIT 5;

-- ==================================================
-- 3. TEST WIDGET COUPONS FUNCTION
-- ==================================================
-- Replace 1 with a real user ID from step 2
SELECT * FROM get_widget_coupons(1) LIMIT 5;

-- ==================================================
-- 4. TEST WIDGET COMPANIES FUNCTION
-- ==================================================
SELECT * FROM get_widget_companies() LIMIT 10;

-- ==================================================
-- 5. CHECK FUNCTION PERMISSIONS
-- ==================================================
SELECT 
    routine_name,
    grantee,
    privilege_type
FROM information_schema.routine_privileges 
WHERE routine_name IN ('get_widget_coupons', 'get_widget_companies');

-- ==================================================
-- 6. VERIFY SECURITY (should fail)
-- ==================================================
-- This should return an error for non-existent user
-- SELECT * FROM get_widget_coupons(99999);

-- ==================================================
-- 7. COMPARE WITH DIRECT QUERY (for debugging)
-- ==================================================
-- Replace 1 with real user ID - this should return same results
SELECT 
    c.id,
    c.code,
    c.company,
    c.value,
    c.status,
    c.user_id
FROM coupon c
WHERE c.user_id = 1  -- Replace with real user ID
ORDER BY c.date_added DESC
LIMIT 5;

-- ==================================================
-- 8. CHECK SHARED CONTAINER DATA (iOS debugging)
-- ==================================================
-- This helps debug if user data is saved correctly
-- Check your iOS app's UserDefaults for group.com.couponmanager.shared
-- Key: "lastLoggedInUser"

-- ==================================================
-- NOTES:
-- ==================================================
-- 1. These queries are read-only and safe
-- 2. They don't modify any existing data or policies
-- 3. They only test the new RPC functions
-- 4. Your website continues to work normally
-- 5. If functions don't exist, run widget_safe_solution.sql first
