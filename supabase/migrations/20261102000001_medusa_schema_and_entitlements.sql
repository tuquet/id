-- ============================================================================
-- SUPABASE MIGRATION: MEDUSA SCHEMA DEDICATED ISOLATION & GRANTS
-- Version: 20261102000001
-- Description: Creates isolated 'medusa' schema for Medusa v2 E-Commerce Engine
-- ============================================================================

-- 1. Create dedicated schema
CREATE SCHEMA IF NOT EXISTS medusa;

-- 2. Grants for standard Supabase roles
GRANT USAGE ON SCHEMA medusa TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON TABLES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON FUNCTIONS TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON SEQUENCES TO postgres, service_role;

-- 3. Entitlements Hub Table in public schema (Bản quyền xuyên suốt)
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

-- Enable RLS for entitlements
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
