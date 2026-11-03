-- ============================================================================
-- PLUGIN: STORE (MEDUSA COMMERCE SCHEMA ISOLATION) - UNINSTALLATION
-- Plugin ID: store
-- ============================================================================

-- Drop schema medusa and all contained tables (Warning: Destructive)
DROP SCHEMA IF EXISTS medusa CASCADE;

-- Unregister plugin status
SELECT public.unregister_plugin('store');

DELETE FROM public.role_permissions WHERE permission_id LIKE 'store:%';
DELETE FROM public.permissions WHERE module = 'store';
