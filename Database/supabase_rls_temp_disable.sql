-- Temporary RLS Configuration for iOS App Testing
-- Run this in Supabase SQL Editor to enable the iOS app to work

-- ==================================================
-- OPTION 1: TEMPORARILY DISABLE RLS (FOR TESTING ONLY)
-- ==================================================

-- Disable RLS temporarily for testing
ALTER TABLE coupon DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE tag DISABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_tags DISABLE ROW LEVEL SECURITY;

-- ==================================================
-- OPTION 2: CREATE BYPASS POLICIES FOR ANON KEY (RECOMMENDED)
-- ==================================================

-- Re-enable RLS
ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_tags ENABLE ROW LEVEL SECURITY;

-- Create bypass policies for anon users with service role
-- Note: This allows the anon key to access all data (less secure but works)

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "coupon_select_anon" ON coupon;
DROP POLICY IF EXISTS "coupon_insert_anon" ON coupon;
DROP POLICY IF EXISTS "coupon_update_anon" ON coupon;
DROP POLICY IF EXISTS "coupon_delete_anon" ON coupon;
DROP POLICY IF EXISTS "coupon_usage_all_anon" ON coupon_usage;
DROP POLICY IF EXISTS "users_all_anon" ON users;
DROP POLICY IF EXISTS "notifications_all_anon" ON notifications;
DROP POLICY IF EXISTS "transactions_all_anon" ON transactions;
DROP POLICY IF EXISTS "companies_all_anon" ON companies;
DROP POLICY IF EXISTS "tag_all_anon" ON tag;
DROP POLICY IF EXISTS "coupon_tags_all_anon" ON coupon_tags;

-- Create permissive policies for anon role (for iOS app)
CREATE POLICY "coupon_select_anon" ON coupon
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "coupon_insert_anon" ON coupon
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "coupon_update_anon" ON coupon
    FOR UPDATE
    TO anon
    USING (true);

CREATE POLICY "coupon_delete_anon" ON coupon
    FOR DELETE
    TO anon
    USING (true);

CREATE POLICY "coupon_usage_all_anon" ON coupon_usage
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "users_all_anon" ON users
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "notifications_all_anon" ON notifications
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "transactions_all_anon" ON transactions
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

CREATE POLICY "companies_all_anon" ON companies
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "tag_all_anon" ON tag
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "coupon_tags_all_anon" ON coupon_tags
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);

-- ==================================================
-- IMPORTANT NOTES:
-- ==================================================
-- 1. Choose either OPTION 1 or OPTION 2, not both
-- 2. OPTION 1 completely disables RLS (less secure)
-- 3. OPTION 2 allows anon role to access all data (also less secure but keeps RLS structure)
-- 4. For production, you should implement proper JWT-based authentication
-- 5. The iOS app should eventually use Supabase Auth instead of custom login

-- ==================================================
-- TO RE-ENABLE PROPER RLS LATER:
-- ==================================================
-- Run the queries from supabase_rls_policies.sql
-- And remove these temporary policies:
-- 
-- DROP POLICY "coupon_select_anon" ON coupon;
-- DROP POLICY "coupon_insert_anon" ON coupon;
-- DROP POLICY "coupon_update_anon" ON coupon;
-- DROP POLICY "coupon_delete_anon" ON coupon;
-- DROP POLICY "coupon_usage_all_anon" ON coupon_usage;
-- DROP POLICY "users_all_anon" ON users;
-- DROP POLICY "notifications_all_anon" ON notifications;
-- DROP POLICY "transactions_all_anon" ON transactions;
-- DROP POLICY "companies_all_anon" ON companies;
-- DROP POLICY "tag_all_anon" ON tag;
-- DROP POLICY "coupon_tags_all_anon" ON coupon_tags;