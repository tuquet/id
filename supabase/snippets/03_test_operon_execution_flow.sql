-- ============================================================================
-- SNIPPET: 03_TEST_OPERON_EXECUTION_FLOW.SQL
-- Mục đích: Kiểm thử luồng tự động hóa Operon (Workflows -> Jobs -> Execution Logs)
-- Kiểm tra các trạng thái thực thi của Worker daemon và độ trễ ghi log.
-- ============================================================================

SELECT 
    w.id AS workflow_id,
    w.name AS workflow_name,
    j.id AS job_id,
    j.status AS job_status,
    j.priority,
    d.hostname AS executed_on_device,
    d.status AS device_status,
    COUNT(el.id) AS total_log_entries,
    MAX(el.created_at) AS last_log_timestamp
FROM operon.workflows w
JOIN operon.jobs j ON j.workflow_id = w.id
LEFT JOIN operon.devices d ON d.id = j.device_id
LEFT JOIN operon.execution_logs el ON el.job_id = j.id
GROUP BY w.id, w.name, j.id, j.status, j.priority, d.hostname, d.status
ORDER BY j.created_at DESC;
