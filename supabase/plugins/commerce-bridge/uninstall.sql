-- ============================================================================
-- PLUGIN: COMMERCE BRIDGE (MEDUSA SCHEMA ISOLATION) - UNINSTALLATION
-- Plugin ID: commerce-bridge
-- ============================================================================

-- Drop schema medusa and all contained tables (Warning: Destructive)
DROP SCHEMA IF EXISTS medusa CASCADE;

-- Unregister plugin status
DO $$ BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'plugins') THEN
        UPDATE public.plugins 
        SET status = 'uninstalled', updated_at = now()
        WHERE id = 'commerce-bridge';
    END IF;
END $$;
