-- ============================================================================
-- OPN-CLOUD PLUGIN: SUBSCRIPTIONS, QUOTA & PAYMENT GATEWAY (UNINSTALLATION)
-- Plugin ID: licensing
-- Architecture: Atomic Zero-Orphan Cleanup via DROP SCHEMA CASCADE
-- ============================================================================

-- 1. Atomic Schema Drop (Instantly drops all billing tables, views, enums, and functions)
DROP SCHEMA IF EXISTS billing CASCADE;

-- 2. Unregister Plugin from Master Registry (Validates reverse dependencies)
SELECT public.unregister_plugin('licensing');

-- 3. Cleanup Permissions from Base Core
DELETE FROM public.role_permissions
WHERE permission_id LIKE 'licensing:%'
   OR permission_id LIKE 'quota:%'
   OR permission_id LIKE 'wallets:%'
   OR permission_id LIKE 'payments:%';
DELETE FROM public.permissions WHERE module = 'billing';
