-- ============================================================================
-- SNIPPET: 05_SIMULATE_END_TO_END_INTEGRATION.SQL
-- Mục đích: Kịch bản mô phỏng toàn diện E2E test data:
-- 1. Tìm User và Tenant mẫu (admin@tuquet.dev)
-- 2. Gán Subscription gói Enterprise (schema: billing)
-- 3. Tạo thiết bị worker & browser profile trong operon (schema: operon)
-- 4. Tạo workflow & job test để kiểm tra luồng kết nối thực tế
-- ============================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_tenant_id UUID;
    v_device_id UUID;
    v_profile_id UUID;
    v_workflow_id UUID;
    v_job_id UUID;
BEGIN
    -- 1. Tìm user admin và tenant tương ứng
    SELECT u.id, tm.tenant_id INTO v_user_id, v_tenant_id 
    FROM auth.users u
    JOIN public.tenant_members tm ON tm.user_id = u.id
    WHERE u.email = 'admin@tuquet.dev'
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Không tìm thấy admin@tuquet.dev! Vui lòng kiểm tra seed data.';
        RETURN;
    END IF;

    RAISE NOTICE 'Đang thực thi mô phỏng E2E cho User: % | Tenant: %', v_user_id, v_tenant_id;

    -- 2. Đảm bảo Gói cước Enterprise & Subscription (schema: billing)
    INSERT INTO billing.plans (id, name, description, max_members, max_storage_mb, max_monthly_runs, price_monthly_usd)
    VALUES ('enterprise', 'Enterprise Plan', 'Gói tự động hóa không giới hạn cho doanh nghiệp', 50, 10240, 100000, 199.00)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO billing.subscriptions (tenant_id, plan_id, status)
    VALUES (v_tenant_id, 'enterprise', 'active')
    ON CONFLICT (tenant_id) DO UPDATE 
    SET plan_id = 'enterprise', status = 'active', updated_at = now();

    -- 3. Tạo thiết bị Operon Worker giả lập (schema: operon)
    INSERT INTO operon.devices (tenant_id, name, ip_address, status, specs)
    VALUES (v_tenant_id, 'worker-edge-01.tuquet.dev', '127.0.0.1'::inet, 'online', '{"cpu": "16 cores", "ram": "64GB", "gpu": "RTX 4090"}'::jsonb)
    RETURNING id INTO v_device_id;

    -- 4. Tạo Browser Profile giả lập (schema: operon)
    INSERT INTO operon.browser_profiles (tenant_id, name, fingerprint, is_locked, created_by)
    VALUES (
        v_tenant_id, 
        'Production Chromium Profile #1', 
        '{"userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", "canvas_hash": "a91b2c"}'::jsonb, 
        false, 
        v_user_id
    )
    RETURNING id INTO v_profile_id;

    -- 5. Tạo Workflow & Job kiểm thử (schema: operon)
    INSERT INTO operon.workflows (tenant_id, name, description, nodes, edges)
    VALUES (
        v_tenant_id, 
        'Ecosystem Verification Flow', 
        'Workflow kiểm tra tính liên lạc giữa Operon Engine, Console và ID SSOT',
        '[{"id": "node-1", "type": "navigate", "data": {"url": "http://localhost:8000"}}]'::jsonb,
        '[{"id": "edge-1", "source": "node-1", "target": "node-2"}]'::jsonb
    )
    RETURNING id INTO v_workflow_id;

    INSERT INTO operon.jobs (workflow_id, profile_id, device_id, status)
    VALUES (v_workflow_id, v_profile_id, v_device_id, 'pending')
    RETURNING id INTO v_job_id;

    -- 6. Ghi telemetry log (schema: operon)
    INSERT INTO operon.execution_logs (job_id, level, message, metadata)
    VALUES (v_job_id, 'info', 'E2E Simulation Job successfully queued', jsonb_build_object('simulated_by', 'snippets/05_simulate_end_to_end_integration.sql'));

    RAISE NOTICE 'Hoàn tất mô phỏng thành công! Device ID: %, Job ID: %, Workflow ID: %', v_device_id, v_job_id, v_workflow_id;
END $$;
