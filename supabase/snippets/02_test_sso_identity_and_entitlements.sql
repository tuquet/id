-- ============================================================================
-- SNIPPET: 02_TEST_SSO_IDENTITY_AND_ENTITLEMENTS.SQL
-- Mục đích: Kiểm tra tính liên kết toàn vẹn dữ liệu từ auth.users sang:
-- 1. public.profiles (User identity & display)
-- 2. public.tenant_members & public.tenants (Multi-tenant mapping)
-- 3. billing.subscriptions & billing.plans (SaaS Quotas & Tier limits)
-- 4. operon.browser_profiles & operon.devices (Automation workloads)
-- ============================================================================

SELECT 
    u.id AS user_id,
    u.email,
    p.full_name,
    t.id AS tenant_id,
    t.name AS tenant_name,
    bp.name AS plan_name,
    s.status AS subscription_status,
    bp.max_monthly_runs,
    COUNT(DISTINCT obp.id) AS total_browser_profiles,
    COUNT(DISTINCT od.id) AS total_worker_devices
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN public.tenant_members tm ON tm.user_id = u.id
LEFT JOIN public.tenants t ON t.id = tm.tenant_id
LEFT JOIN billing.subscriptions s ON s.tenant_id = t.id
LEFT JOIN billing.plans bp ON bp.id = s.plan_id
LEFT JOIN operon.browser_profiles obp ON obp.tenant_id = t.id
LEFT JOIN operon.devices od ON od.tenant_id = t.id
GROUP BY u.id, u.email, p.full_name, t.id, t.name, bp.name, s.status, bp.max_monthly_runs;
