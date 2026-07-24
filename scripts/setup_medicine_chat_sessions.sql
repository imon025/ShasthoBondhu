-- Execute this script in your Supabase SQL Editor to create the necessary backend table for Chat History.

-- 1. Create the table
CREATE TABLE IF NOT EXISTS medicine_chat_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security (RLS) to keep data secure
ALTER TABLE medicine_chat_sessions ENABLE ROW LEVEL SECURITY;

-- 3. Create policies so users can only access their own data
-- Allow users to SELECT their own sessions
CREATE POLICY "Users can view their own chat sessions"
    ON medicine_chat_sessions
    FOR SELECT
    USING (
        user_id = auth.uid()::text OR user_id = 'guest'
    );

-- Allow users to INSERT/UPSERT their own sessions
CREATE POLICY "Users can insert their own chat sessions"
    ON medicine_chat_sessions
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()::text OR user_id = 'guest'
    );

-- Allow users to UPDATE their own sessions
CREATE POLICY "Users can update their own chat sessions"
    ON medicine_chat_sessions
    FOR UPDATE
    USING (
        user_id = auth.uid()::text OR user_id = 'guest'
    )
    WITH CHECK (
        user_id = auth.uid()::text OR user_id = 'guest'
    );

-- Allow users to DELETE their own sessions
CREATE POLICY "Users can delete their own chat sessions"
    ON medicine_chat_sessions
    FOR DELETE
    USING (
        user_id = auth.uid()::text OR user_id = 'guest'
    );
