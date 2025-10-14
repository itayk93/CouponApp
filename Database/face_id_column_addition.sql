-- Add face_id_enabled column to users table
-- This column will store whether the user has enabled Face ID authentication for the app

ALTER TABLE users 
ADD COLUMN face_id_enabled BOOLEAN DEFAULT FALSE;

-- Add a comment to the column
COMMENT ON COLUMN users.face_id_enabled IS 'Whether the user has enabled Face ID authentication for automatic app login';

-- Create an index for faster queries (optional but recommended)
CREATE INDEX idx_users_face_id_enabled ON users(face_id_enabled) WHERE face_id_enabled = TRUE;

-- Example query to verify the column was added
-- SELECT id, email, face_id_enabled FROM users LIMIT 5;