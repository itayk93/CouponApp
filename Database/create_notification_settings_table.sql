-- Create global notification settings table
CREATE TABLE IF NOT EXISTS notification_settings (
    id SERIAL PRIMARY KEY,
    daily_notification_hour INTEGER DEFAULT 20,
    daily_notification_minute INTEGER DEFAULT 14,
    monthly_notification_hour INTEGER DEFAULT 10,
    monthly_notification_minute INTEGER DEFAULT 0,
    expiration_day_hour INTEGER DEFAULT 10,
    expiration_day_minute INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert default settings
INSERT INTO notification_settings (
    daily_notification_hour,
    daily_notification_minute,
    monthly_notification_hour,
    monthly_notification_minute,
    expiration_day_hour,
    expiration_day_minute
) VALUES (20, 14, 10, 0, 10, 0)
ON CONFLICT DO NOTHING;

-- Add push_token column to users table if it doesn't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token TEXT;

-- Create RLS policy for notification_settings (admin only)
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;

-- First, let's check what type of ID your users table uses
-- If your users table uses UUID for id, use this:
CREATE POLICY "Admin can manage notification settings UUID" ON notification_settings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.is_admin = true
        )
    );

-- If your users table uses integer for id, use this instead:
-- CREATE POLICY "Admin can manage notification settings INT" ON notification_settings
--     FOR ALL USING (
--         EXISTS (
--             SELECT 1 FROM users 
--             WHERE users.email = auth.email()
--             AND users.is_admin = true
--         )
--     );

-- Allow service role to access everything
CREATE POLICY "Service role can access notification settings" ON notification_settings
    FOR ALL USING (current_setting('role') = 'service_role');

-- Create function to update timestamp
CREATE OR REPLACE FUNCTION update_notification_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger
CREATE TRIGGER update_notification_settings_updated_at
    BEFORE UPDATE ON notification_settings
    FOR EACH ROW EXECUTE FUNCTION update_notification_settings_updated_at();