-- Simple RLS Policies for iOS App
-- Copy and paste these commands one by one in Supabase SQL Editor

-- Enable RLS on all tables
ALTER TABLE coupon ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE tag ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_tags ENABLE ROW LEVEL SECURITY;

-- Add policies for anon role (iOS app)
CREATE POLICY "coupon_select_anon_ios" ON coupon FOR SELECT TO anon USING (true);
CREATE POLICY "coupon_insert_anon_ios" ON coupon FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "coupon_update_anon_ios" ON coupon FOR UPDATE TO anon USING (true);
CREATE POLICY "coupon_delete_anon_ios" ON coupon FOR DELETE TO anon USING (true);

CREATE POLICY "coupon_usage_select_anon_ios" ON coupon_usage FOR SELECT TO anon USING (true);
CREATE POLICY "coupon_usage_insert_anon_ios" ON coupon_usage FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "coupon_usage_update_anon_ios" ON coupon_usage FOR UPDATE TO anon USING (true);
CREATE POLICY "coupon_usage_delete_anon_ios" ON coupon_usage FOR DELETE TO anon USING (true);

CREATE POLICY "users_select_anon_ios" ON users FOR SELECT TO anon USING (true);
CREATE POLICY "users_update_anon_ios" ON users FOR UPDATE TO anon USING (true);

CREATE POLICY "notifications_select_anon_ios" ON notifications FOR SELECT TO anon USING (true);
CREATE POLICY "notifications_update_anon_ios" ON notifications FOR UPDATE TO anon USING (true);

CREATE POLICY "transactions_select_anon_ios" ON transactions FOR SELECT TO anon USING (true);
CREATE POLICY "transactions_insert_anon_ios" ON transactions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "transactions_update_anon_ios" ON transactions FOR UPDATE TO anon USING (true);

CREATE POLICY "companies_select_anon_ios" ON companies FOR SELECT TO anon USING (true);
CREATE POLICY "tag_select_anon_ios" ON tag FOR SELECT TO anon USING (true);

CREATE POLICY "coupon_tags_select_anon_ios" ON coupon_tags FOR SELECT TO anon USING (true);
CREATE POLICY "coupon_tags_insert_anon_ios" ON coupon_tags FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "coupon_tags_delete_anon_ios" ON coupon_tags FOR DELETE TO anon USING (true);