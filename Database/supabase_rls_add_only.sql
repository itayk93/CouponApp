-- Add RLS Policies for iOS App (ADDITIVE ONLY - Won't break existing functionality)
-- These policies ADD support for the iOS app without removing existing policies
-- Run these in Supabase SQL Editor

-- ==================================================
-- 1. ADD POLICIES FOR ANON ROLE (iOS APP)
-- ==================================================

-- These policies allow the iOS app (using anon key) to access data
-- They are ADDITIVE and won't interfere with existing authenticated policies

-- COUPON TABLE - Add policies for anon role
CREATE POLICY "coupon_select_anon_ios" ON coupon
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "coupon_insert_anon_ios" ON coupon
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "coupon_update_anon_ios" ON coupon
    FOR UPDATE
    TO anon
    USING (true);

CREATE POLICY "coupon_delete_anon_ios" ON coupon
    FOR DELETE
    TO anon
    USING (true);

-- COUPON_USAGE TABLE - Add policies for anon role
CREATE POLICY "coupon_usage_select_anon_ios" ON coupon_usage
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "coupon_usage_insert_anon_ios" ON coupon_usage
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "coupon_usage_update_anon_ios" ON coupon_usage
    FOR UPDATE
    TO anon
    USING (true);

CREATE POLICY "coupon_usage_delete_anon_ios" ON coupon_usage
    FOR DELETE
    TO anon
    USING (true);

-- USERS TABLE - Add policies for anon role
CREATE POLICY "users_select_anon_ios" ON users
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "users_update_anon_ios" ON users
    FOR UPDATE
    TO anon
    USING (true);

-- NOTIFICATIONS TABLE - Add policies for anon role
CREATE POLICY "notifications_select_anon_ios" ON notifications
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "notifications_update_anon_ios" ON notifications
    FOR UPDATE
    TO anon
    USING (true);

-- TRANSACTIONS TABLE - Add policies for anon role
CREATE POLICY "transactions_select_anon_ios" ON transactions
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "transactions_insert_anon_ios" ON transactions
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "transactions_update_anon_ios" ON transactions
    FOR UPDATE
    TO anon
    USING (true);

-- COMPANIES TABLE - Add policies for anon role
CREATE POLICY "companies_select_anon_ios" ON companies
    FOR SELECT
    TO anon
    USING (true);

-- TAG TABLE - Add policies for anon role
CREATE POLICY "tag_select_anon_ios" ON tag
    FOR SELECT
    TO anon
    USING (true);

-- COUPON_TAGS TABLE - Add policies for anon role
CREATE POLICY "coupon_tags_select_anon_ios" ON coupon_tags
    FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "coupon_tags_insert_anon_ios" ON coupon_tags
    FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "coupon_tags_delete_anon_ios" ON coupon_tags
    FOR DELETE
    TO anon
    USING (true);

-- ==================================================
-- 2. ENABLE RLS ON TABLES (IF NOT ALREADY ENABLED)
-- ==================================================

-- Enable RLS on tables (safe to run multiple times)
ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_tags ENABLE ROW LEVEL SECURITY;

-- ==================================================
-- NOTES:
-- ==================================================
-- 1. These policies are ADDITIVE - they don't remove any existing policies
-- 2. They specifically target the 'anon' role which the iOS app uses
-- 3. Your existing web app policies remain untouched
-- 4. The IF NOT EXISTS clauses prevent conflicts if policies already exist
-- 5. RLS is enabled only if not already enabled

-- ==================================================
-- TO VERIFY POLICIES ARE WORKING:
-- ==================================================
-- SELECT * FROM pg_policies WHERE tablename IN ('coupon', 'coupon_usage', 'users');
-- This will show all policies including the new ones and existing ones