-- ============================================================================
-- PLUGIN: OPERON AUTOMATION & BROWSER RUNTIME ENGINE (UNINSTALLATION)
-- Plugin ID: operon
-- ============================================================================

-- Drop schema operon and all unified tables (Destructive)
DROP SCHEMA IF EXISTS operon CASCADE;

-- Unregister plugin status
SELECT public.unregister_plugin('operon');

DELETE FROM public.role_permissions WHERE permission_id LIKE 'operon:%';
DELETE FROM public.permissions WHERE module = 'operon';
