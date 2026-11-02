-- ============================================================================
-- PLUGIN: COMMERCE BRIDGE (MEDUSA SCHEMA ISOLATION) - INSTALLATION
-- Plugin ID: commerce-bridge
-- Version: 1.0.0
-- Architecture: PostgreSQL Dedicated Schema Isolation (schema: medusa)
-- ============================================================================

-- 1. Create Dedicated Schema
CREATE SCHEMA IF NOT EXISTS medusa;

-- 2. Grants for standard Supabase roles & Medusa connection
GRANT USAGE ON SCHEMA medusa TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON TABLES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON FUNCTIONS TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA medusa GRANT ALL ON SEQUENCES TO postgres, service_role;

-- 3. Register Plugin Metadata in Platform Core (if plugin registry exists)
DO $$ BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'plugins') THEN
        INSERT INTO public.plugins (id, name, version, status, description)
        VALUES (
            'commerce-bridge',
            'Commerce Bridge (Medusa Isolation)',
            '1.0.0',
            'installed',
            'Dedicated PostgreSQL schema isolation for Medusa v2'
        )
        ON CONFLICT (id) DO UPDATE SET
            status = 'installed',
            version = '1.0.0',
            updated_at = now();
    END IF;
END $$;
