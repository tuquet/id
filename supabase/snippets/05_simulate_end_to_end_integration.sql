-- ============================================================================
-- SNIPPET: 05_SIMULATE_END_TO_END_INTEGRATION.SQL
-- Mục đích: Kịch bản mô phỏng toàn diện E2E test data:
-- 1. Đảm bảo user test tồn tại
-- 2. Gán gói Entitlements (Licensing)
-- 3. Tạo thiết bị worker & browser profile trong operon
-- 4. Tạo workflow & job test để kiểm tra luồng kết nối thực tế
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_device_id UUID;
    v_profile_id UUID;
    v_workflow_id UUID;
    v_job_id UUID;
BEGIN
    -- 1. Tìm hoặc lấy ID của user đầu tiên trong hệ thống
    SELECT id INTO v_user_id FROM auth.users ORDER BY created_at ASC LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Chưa có user nào trong auth.users! Hãy đăng ký hoặc tạo 1 tài khoản trước.';
        RETURN;
    END IF;

    RAISE NOTICE 'Đang thực thi mô phỏng E2E cho User ID: %', v_user_id;

    -- 2. Đảm bảo Profile và Entitlements
    INSERT INTO billing.user_entitlements (user_id, plan_id, status, limits)
    VALUES (
        v_user_id,
        'pro',
        'active',
        '{"max_devices": 10, "max_profiles": 50, "concurrency": 5}'::jsonb
    )
    ON CONFLICT (user_id) DO UPDATE 
    SET plan_id = 'pro', status = 'active', updated_at = now();

    -- 3. Tạo thiết bị Operon Worker giả lập
    INSERT INTO operon.devices (user_id, hostname, platform, status, ip_address)
    VALUES (v_user_id, 'worker-node-01.local', 'windows', 'online', '127.0.0.1')
    RETURNING id INTO v_device_id;

    -- 4. Tạo Browser Profile giả lập
    INSERT INTO operon.browser_profiles (user_id, name, browser_type, stealth_enabled)
    VALUES (v_user_id, 'Automation Profile #1', 'chromium', true)
    RETURNING id INTO v_profile_id;

    -- 5. Tạo Workflow & Job kiểm thử
    INSERT INTO operon.workflows (user_id, name, description, steps)
    VALUES (
        v_user_id, 
        'Ecosystem Verification Flow', 
        'Workflow kiểm tra tính liên lạc giữa Operon Engine, Console và ID SSOT',
        '[{"action": "navigate", "url": "http://localhost:8000"}, {"action": "check_status"}]'::jsonb
    )
    RETURNING id INTO v_workflow_id;

    INSERT INTO operon.jobs (workflow_id, profile_id, device_id, status, priority)
    VALUES (v_workflow_id, v_profile_id, v_device_id, 'pending', 10)
    RETURNING id INTO v_job_id;

    -- 6. Ghi log khởi tạo
    INSERT INTO operon.execution_logs (job_id, level, message, details)
    VALUES (v_job_id, 'info', 'E2E Simulation Job successfully queued', jsonb_build_object('simulated_by', 'snippets/05_simulate_end_to_end_integration.sql'));

    RAISE NOTICE 'Hoàn tất mô phỏng! Job ID: %, Workflow ID: %', v_job_id, v_workflow_id;
END $$;
