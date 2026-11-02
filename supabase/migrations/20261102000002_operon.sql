-- ============================================================================
-- PLUGIN: OPERON AUTOMATION & BROWSER RUNTIME ENGINE (INSTALLATION)
-- Plugin ID: operon
-- Version: 1.0.0
-- Architecture: Unified Single Dedicated Schema (schema: operon)
-- Dependencies: ["identity"]
-- ============================================================================

-- 1. Create Dedicated Schema
CREATE SCHEMA IF NOT EXISTS operon;

-- 2. Grants for standard Supabase roles
GRANT USAGE ON SCHEMA operon TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA operon GRANT ALL ON TABLES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA operon GRANT ALL ON FUNCTIONS TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA operon GRANT ALL ON SEQUENCES TO postgres, service_role;

-- 3. Enums in schema operon
DO $$ BEGIN
    CREATE TYPE operon.device_status AS ENUM ('online', 'offline', 'busy', 'error');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE operon.proxy_protocol AS ENUM ('http', 'https', 'socks5');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE operon.job_status AS ENUM ('pending', 'running', 'completed', 'failed', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- 4. BẢNG DỮ LIỆU CỐT LÕI (UNIFIED SCHEMA: OPERON)
-- ============================================================================

-- 4.1. Danh mục các bản build Chromium / Stealth Engine
CREATE TABLE IF NOT EXISTS operon.releases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version VARCHAR(32) NOT NULL UNIQUE,
    channel VARCHAR(32) NOT NULL DEFAULT 'stable',
    download_url TEXT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.2. Mẫu phần cứng giả lập (Hardware Fingerprint Templates)
CREATE TABLE IF NOT EXISTS operon.fingerprint_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL,
    os VARCHAR(32) NOT NULL DEFAULT 'windows',
    browser_type VARCHAR(32) NOT NULL DEFAULT 'chrome',
    fingerprint JSONB NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.3. Quản lý Proxies (Gắn theo Tenant)
CREATE TABLE IF NOT EXISTS operon.proxies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128),
    protocol operon.proxy_protocol NOT NULL DEFAULT 'socks5',
    host TEXT NOT NULL,
    port INTEGER NOT NULL,
    username TEXT,
    password TEXT,
    country_code VARCHAR(8),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.4. Hồ sơ trình duyệt độc lập (Browser Profiles)
CREATE TABLE IF NOT EXISTS operon.browser_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    release_id UUID REFERENCES operon.releases(id) ON DELETE SET NULL,
    template_id UUID REFERENCES operon.fingerprint_templates(id) ON DELETE SET NULL,
    proxy_id UUID REFERENCES operon.proxies(id) ON DELETE SET NULL,
    fingerprint JSONB NOT NULL DEFAULT '{}'::jsonb,
    cookies JSONB DEFAULT '[]'::jsonb,
    storage_state JSONB DEFAULT '{}'::jsonb,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.5. Danh sách Worker Nodes / Máy chủ Daemon (Devices)
CREATE TABLE IF NOT EXISTS operon.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    ip_address INET,
    status operon.device_status NOT NULL DEFAULT 'offline',
    specs JSONB DEFAULT '{}'::jsonb,
    last_heartbeat_at TIMESTAMPTZ,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.6. Phiên làm việc trình duyệt đang mở trên Node (Active Sessions)
CREATE TABLE IF NOT EXISTS operon.active_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES operon.devices(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES operon.browser_profiles(id) ON DELETE CASCADE,
    cdp_port INTEGER NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(device_id, profile_id)
);

-- 4.7. Kịch bản tự động hóa (Workflows)
CREATE TABLE IF NOT EXISTS operon.workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    nodes JSONB NOT NULL DEFAULT '[]'::jsonb,
    edges JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.8. Phiên chạy thực thi tác vụ (Jobs)
CREATE TABLE IF NOT EXISTS operon.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID REFERENCES operon.workflows(id) ON DELETE SET NULL,
    device_id UUID REFERENCES operon.devices(id) ON DELETE SET NULL,
    profile_id UUID REFERENCES operon.browser_profiles(id) ON DELETE SET NULL,
    status operon.job_status NOT NULL DEFAULT 'pending',
    result JSONB DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.9. Log thực thi chi tiết (Execution Logs)
CREATE TABLE IF NOT EXISTS operon.execution_logs (
    id BIGSERIAL PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES operon.jobs(id) ON DELETE CASCADE,
    level VARCHAR(16) NOT NULL DEFAULT 'info',
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4.10. Quản lý Ảnh chụp màn hình và Video lỗi (Assets)
CREATE TABLE IF NOT EXISTS operon.assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES operon.jobs(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES operon.browser_profiles(id) ON DELETE SET NULL,
    file_type VARCHAR(32) NOT NULL DEFAULT 'screenshot',
    storage_path TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ============================================================================
-- 5. CHỈ MỤC TỐC ĐỘ CAO (INDEXES)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_operon_profiles_tenant ON operon.browser_profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_operon_devices_tenant ON operon.devices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_operon_jobs_status ON operon.jobs(status);
CREATE INDEX IF NOT EXISTS idx_operon_logs_job ON operon.execution_logs(job_id);

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE operon.browser_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE operon.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE operon.workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE operon.proxies ENABLE ROW LEVEL SECURITY;
ALTER TABLE operon.jobs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Tenant members can manage their browser profiles"
    ON operon.browser_profiles
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tenant_members
            WHERE tenant_members.tenant_id = operon.browser_profiles.tenant_id
              AND tenant_members.user_id = auth.uid()
        )
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE POLICY "Service role full access on operon schema"
    ON operon.browser_profiles
    FOR ALL
    TO service_role
    USING (true);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 7. Register Plugin Metadata in Platform Core
DO $$ BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'plugins') THEN
        INSERT INTO public.plugins (id, name, version, status, description)
        VALUES (
            'operon',
            'Operon Automation Engine',
            '1.0.0',
            'installed',
            'Unified Antidetect Browser Profiles, Compute Fleet Nodes & Automation Scheduler'
        )
        ON CONFLICT (id) DO UPDATE SET
            status = 'installed',
            version = '1.0.0',
            updated_at = now();
    END IF;
END $$;
