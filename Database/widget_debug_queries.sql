-- Widget Debug Queries
-- Run these in Supabase SQL Editor to debug widget issues

-- ==================================================
-- 1. CHECK IF RPC FUNCTION EXISTS
-- ==================================================
SELECT 
    routine_name, 
    routine_type, 
    data_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'get_widget_coupons';

-- ==================================================
-- 2. CHECK CURRENT RLS POLICIES
-- ==================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('coupon', 'companies', 'users')
ORDER BY tablename, policyname;

-- ==================================================
-- 3. CHECK IF RLS IS ENABLED
-- ==================================================
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('coupon', 'companies', 'users')
ORDER BY tablename;

-- ==================================================
-- 4. TEST DIRECT QUERY (WITHOUT RLS)
-- ==================================================
-- This should work if RLS is disabled or has permissive policies
SELECT COUNT(*) as total_coupons FROM coupon;
SELECT COUNT(*) as total_companies FROM companies;

-- ==================================================
-- 5. TEST RPC FUNCTION (replace user_id with actual ID)
-- ==================================================
-- First, find a user ID that exists:
SELECT id, username, email FROM users LIMIT 5;

-- Then test the RPC function (replace 1 with actual user ID):
SELECT * FROM get_widget_coupons(1) LIMIT 5;

-- ==================================================
-- 6. CHECK COUPONS FOR SPECIFIC USER
-- ==================================================
-- Replace 1 with actual user ID
SELECT 
    c.id,
    c.code,
    c.company,
    c.value,
    c.status,
    c.user_id,
    COALESCE(cu.used_value, 0) as used_value
FROM coupon c
LEFT JOIN (
    SELECT 
        coupon_id,
        SUM(value_used) as used_value
    FROM coupon_usage 
    GROUP BY coupon_id
) cu ON c.id = cu.coupon_id
WHERE c.user_id = 1  -- Replace with actual user ID
ORDER BY c.date_added DESC
LIMIT 10;

-- ==================================================
-- 7. CHECK COMPANIES
-- ==================================================
SELECT * FROM companies LIMIT 10;

-- ==================================================
-- 8. TEST ANON ROLE PERMISSIONS
-- ==================================================
-- These queries simulate what the widget would do with anon key
-- They might fail if RLS is restrictive

-- Test coupon access
SELECT COUNT(*) FROM coupon;

-- Test companies access  
SELECT COUNT(*) FROM companies;

-- Test specific user's coupons (this will likely fail with RLS)
SELECT COUNT(*) FROM coupon WHERE user_id = 1;

-- ==================================================
-- 9. CHECK AUTH STATUS
-- ==================================================
-- Check current auth context
SELECT 
    auth.uid() as current_user_id,
    auth.role() as current_role,
    auth.email() as current_email;

-- ==================================================
-- 10. DEBUG WIDGET DATA STRUCTURE
-- ==================================================
-- Check if the coupon table has the expected columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'coupon' 
ORDER BY ordinal_position;

-- Check if the companies table has the expected columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'companies' 
ORDER BY ordinal_position;

-- ==================================================
-- 11. SAMPLE DATA FOR TESTING
-- ==================================================
-- If you need to create test data:
/*
INSERT INTO users (username, email, password_hash) 
VALUES ('testuser', 'test@example.com', 'hashedpassword')
RETURNING id;

INSERT INTO coupon (code, company, value, cost, user_id, status) 
VALUES ('TEST123', 'Test Company', 100, 80, 1, 'פעיל')
RETURNING id;
*/

-- ==================================================
-- 12. FIX RLS FOR WIDGET (TEMPORARY)
-- ==================================================
-- If the above queries fail, run this to temporarily fix RLS:

-- Option A: Disable RLS temporarily
-- ALTER TABLE coupon DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE companies DISABLE ROW LEVEL SECURITY;

-- Option B: Add permissive policies for anon role
/*
DROP POLICY IF EXISTS "coupon_select_anon" ON coupon;
DROP POLICY IF EXISTS "companies_select_anon" ON companies;

CREATE POLICY "coupon_select_anon" ON coupon
    FOR SELECT TO anon USING (true);

CREATE POLICY "companies_select_anon" ON companies  
    FOR SELECT TO anon USING (true);
*/
