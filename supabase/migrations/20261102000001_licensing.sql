-- ============================================================================
-- SUPABASE MIGRATION: GLOBAL USER ENTITLEMENTS & ACCESS PERMITS
-- Version: 20261102000001
-- Target: Supabase / PostgreSQL (Core IAM Extension)
-- Description: Central entitlements registry for all ecosystem apps (License,
--              Plans, Tiers, Feature Flags) tied to auth.users.
-- ============================================================================

-- 1. Create Entitlements Table in public schema
CREATE TABLE IF NOT EXISTS public.user_entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    app_code TEXT NOT NULL,
    tier TEXT NOT NULL DEFAULT 'standard',
    license_key TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for high-performance license and access lookup
CREATE INDEX IF NOT EXISTS idx_user_entitlements_lookup 
ON public.user_entitlements(user_id, app_code);

-- 2. Enable Row-Level Security (RLS)
ALTER TABLE public.user_entitlements ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can view their own entitlements"
    ON public.user_entitlements
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE POLICY "Service role full access on entitlements"
    ON public.user_entitlements
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
