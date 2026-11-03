-- ============================================================================
-- PLUGIN: STORE (MEDUSA COMMERCE SCHEMA ISOLATION) - INSTALLATION
-- Plugin ID: store
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

-- 3. Permissions & Registration
INSERT INTO public.permissions (id, module, description)
VALUES 
    ('store:read',    'store', 'View store products, catalog, and inventory'),
    ('store:manage',  'store', 'Manage store orders, products, and fulfillment')
ON CONFLICT (id) DO UPDATE SET description = EXCLUDED.description, module = EXCLUDED.module;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r
CROSS JOIN (VALUES ('store:read'), ('store:manage')) AS p(id)
WHERE r.tenant_id IS NULL AND r.name IN ('owner', 'admin')
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM public.roles r
CROSS JOIN (VALUES ('store:read')) AS p(id)
WHERE r.tenant_id IS NULL AND r.name = 'member'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 4. Register Plugin in Master Registry
SELECT public.register_plugin(
    'store',
    'Store Engine (Medusa Commerce)',
    '1.0.0',
    'medusa',
    ARRAY[]::TEXT[],
    'Dedicated PostgreSQL schema isolation for Medusa v2',
    FALSE,
    '{"engine": "medusa_v2"}'::jsonb
);

