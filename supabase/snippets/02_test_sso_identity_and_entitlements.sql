-- ============================================================================
-- SNIPPET: 02_TEST_SSO_IDENTITY_AND_ENTITLEMENTS.SQL
-- Mục đích: Kiểm tra tính liên kết toàn vẹn dữ liệu từ auth.users sang:
-- 1. public.profiles (Identity)
-- 2. billing.user_entitlements (Quyền hạn / Gói cước)
-- 3. operon.browser_profiles (Hồ sơ automation)
-- ============================================================================

SELECT 
    u.id AS user_id,
    u.email,
    u.created_at AS registered_at,
    p.full_name,
    p.avatar_url,
    ue.plan_id AS tier_plan,
    ue.status AS subscription_status,
    ue.limits->>'max_devices' AS allowed_devices,
    ue.limits->>'max_profiles' AS allowed_profiles,
    COUNT(DISTINCT bp.id) AS active_browser_profiles,
    COUNT(DISTINCT d.id) AS active_devices
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
LEFT JOIN billing.user_entitlements ue ON ue.user_id = u.id
LEFT JOIN operon.browser_profiles bp ON bp.user_id = u.id
LEFT JOIN operon.devices d ON d.user_id = u.id
GROUP BY u.id, u.email, u.created_at, p.full_name, p.avatar_url, ue.plan_id, ue.status, ue.limits;
