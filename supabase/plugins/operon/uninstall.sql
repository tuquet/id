-- ============================================================================
-- PLUGIN: OPERON AUTOMATION & BROWSER RUNTIME ENGINE (UNINSTALLATION)
-- Plugin ID: operon
-- ============================================================================

-- Drop schema operon and all unified tables (Destructive)
DROP SCHEMA IF EXISTS operon CASCADE;

-- Unregister plugin status
DO $$ BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'plugins') THEN
        UPDATE public.plugins 
        SET status = 'uninstalled', updated_at = now()
        WHERE id = 'operon';
    END IF;
END $$;
