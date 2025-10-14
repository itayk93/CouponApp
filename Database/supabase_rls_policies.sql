-- RLS Policies for CouponManagerApp iOS Integration
-- These policies ensure users can only access their own data
-- IMPORTANT: Run these carefully in Supabase SQL Editor

-- ==================================================
-- 1. USERS TABLE POLICIES
-- ==================================================

-- Enable RLS on users table (if not already enabled)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own profile
CREATE POLICY "users_select_own" ON users
    FOR SELECT
    USING (auth.uid()::text = id::text);

-- Policy: Users can update their own profile
CREATE POLICY "users_update_own" ON users
    FOR UPDATE
    USING (auth.uid()::text = id::text);

-- ==================================================
-- 2. COUPON TABLE POLICIES
-- ==================================================

-- Enable RLS on coupon table (if not already enabled)
ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;

-- Policy: Users can select their own coupons
CREATE POLICY "coupon_select_own" ON coupon
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

-- Policy: Users can insert their own coupons
CREATE POLICY "coupon_insert_own" ON coupon
    FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text);

-- Policy: Users can update their own coupons
CREATE POLICY "coupon_update_own" ON coupon
    FOR UPDATE
    USING (auth.uid()::text = user_id::text);

-- Policy: Users can delete their own coupons
CREATE POLICY "coupon_delete_own" ON coupon
    FOR DELETE
    USING (auth.uid()::text = user_id::text);

-- Policy: Allow reading coupons that are for sale (marketplace)
CREATE POLICY "coupon_select_marketplace" ON coupon
    FOR SELECT
    USING (is_for_sale = true AND status = 'פעיל');

-- ==================================================
-- 3. COUPON_USAGE TABLE POLICIES
-- ==================================================

-- Enable RLS on coupon_usage table (if not already enabled)
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;

-- Policy: Users can select usage for their own coupons
CREATE POLICY "coupon_usage_select_own" ON coupon_usage
    FOR SELECT
    USING (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_usage.coupon_id
        )
    );

-- Policy: Users can insert usage for their own coupons
CREATE POLICY "coupon_usage_insert_own" ON coupon_usage
    FOR INSERT
    WITH CHECK (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_usage.coupon_id
        )
    );

-- Policy: Users can update usage for their own coupons
CREATE POLICY "coupon_usage_update_own" ON coupon_usage
    FOR UPDATE
    USING (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_usage.coupon_id
        )
    );

-- Policy: Users can delete usage for their own coupons
CREATE POLICY "coupon_usage_delete_own" ON coupon_usage
    FOR DELETE
    USING (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_usage.coupon_id
        )
    );

-- ==================================================
-- 4. NOTIFICATIONS TABLE POLICIES
-- ==================================================

-- Enable RLS on notifications table (if not already enabled)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can select their own notifications
CREATE POLICY "notifications_select_own" ON notifications
    FOR SELECT
    USING (auth.uid()::text = user_id::text);

-- Policy: Users can update their own notifications (mark as viewed)
CREATE POLICY "notifications_update_own" ON notifications
    FOR UPDATE
    USING (auth.uid()::text = user_id::text);

-- ==================================================
-- 5. TRANSACTIONS TABLE POLICIES
-- ==================================================

-- Enable RLS on transactions table (if not already enabled)
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can select transactions where they are buyer or seller
CREATE POLICY "transactions_select_participant" ON transactions
    FOR SELECT
    USING (
        auth.uid()::text = seller_id::text OR 
        auth.uid()::text = buyer_id::text
    );

-- Policy: Users can insert transactions as buyer
CREATE POLICY "transactions_insert_as_buyer" ON transactions
    FOR INSERT
    WITH CHECK (auth.uid()::text = buyer_id::text);

-- Policy: Users can update transactions where they are buyer or seller
CREATE POLICY "transactions_update_participant" ON transactions
    FOR UPDATE
    USING (
        auth.uid()::text = seller_id::text OR 
        auth.uid()::text = buyer_id::text
    );

-- ==================================================
-- 6. COMPANIES TABLE POLICIES (Read-only for all users)
-- ==================================================

-- Enable RLS on companies table (if not already enabled)
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read companies
CREATE POLICY "companies_select_all" ON companies
    FOR SELECT
    TO authenticated
    USING (true);

-- ==================================================
-- 7. TAG TABLE POLICIES (Read-only for all users)
-- ==================================================

-- Enable RLS on tag table (if not already enabled)
ALTER TABLE tag ENABLE ROW LEVEL SECURITY;

-- Policy: All authenticated users can read tags
CREATE POLICY "tag_select_all" ON tag
    FOR SELECT
    TO authenticated
    USING (true);

-- ==================================================
-- 8. COUPON_TAGS TABLE POLICIES
-- ==================================================

-- Enable RLS on coupon_tags table (if not already enabled)
ALTER TABLE coupon_tags ENABLE ROW LEVEL SECURITY;

-- Policy: Users can select tags for their own coupons
CREATE POLICY "coupon_tags_select_own" ON coupon_tags
    FOR SELECT
    USING (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_tags.coupon_id
        )
    );

-- Policy: Users can insert tags for their own coupons
CREATE POLICY "coupon_tags_insert_own" ON coupon_tags
    FOR INSERT
    WITH CHECK (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_tags.coupon_id
        )
    );

-- Policy: Users can delete tags for their own coupons
CREATE POLICY "coupon_tags_delete_own" ON coupon_tags
    FOR DELETE
    USING (
        auth.uid()::text IN (
            SELECT user_id::text FROM coupon WHERE coupon.id = coupon_tags.coupon_id
        )
    );

-- ==================================================
-- NOTES:
-- ==================================================
-- 1. These policies assume you're using Supabase Auth where auth.uid() returns the authenticated user's ID
-- 2. The policies compare auth.uid() as text with the integer user_id fields
-- 3. For marketplace functionality, coupons marked as "for sale" are readable by all users
-- 4. Companies and tags are read-only for all authenticated users
-- 5. Users can only manipulate their own data (coupons, usage, notifications, etc.)
-- 6. Make sure to test these policies thoroughly before deploying to production
-- 7. If you have existing RLS policies, review them to avoid conflicts

-- ==================================================
-- TESTING QUERIES (Run after implementing policies):
-- ==================================================
-- Test user can only see their own coupons:
-- SELECT * FROM coupon; (should only return coupons for the authenticated user)

-- Test user can create a coupon:
-- INSERT INTO coupon (code, company, value, cost, user_id) VALUES ('TEST123', 'Test Company', 100, 80, auth.uid()::int);

-- Test user cannot see other users' coupons:
-- This should return empty if you try to access another user's coupon by ID