-- ============================================================================
-- SNIPPET: 01_AUDIT_SCHEMAS_AND_ISOLATION.SQL
-- Mục đích: Kiểm tra cấu trúc phân vùng các schema trong cơ sở dữ liệu
-- Đảm bảo Medusa, Operon, Billing, Events được cách ly hoàn toàn, không xâm lấn public.
-- ============================================================================

SELECT 
    table_schema,
    COUNT(table_name) AS total_tables,
    CASE 
        WHEN table_schema = 'public' THEN 'Identity, Core Profiles & System Plugins'
        WHEN table_schema = 'billing' THEN 'Licensing, Wallets & Entitlements'
        WHEN table_schema = 'medusa' THEN 'Medusa v2 E-Commerce (Isolated)'
        WHEN table_schema = 'operon' THEN 'Unified Browser & Automation Engine'
        WHEN table_schema = 'events' THEN 'Realtime Dispatch & Outbox'
        WHEN table_schema = 'secrets' THEN 'Zero-Knowledge Vault'
        WHEN table_schema = 'auth' THEN 'Supabase Internal Auth Engine'
        ELSE 'System / Internal Schema'
    END AS description
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
GROUP BY table_schema
ORDER BY total_tables DESC;
