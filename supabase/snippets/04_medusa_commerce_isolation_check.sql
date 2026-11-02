-- ============================================================================
-- SNIPPET: 04_MEDUSA_COMMERCE_ISOLATION_CHECK.SQL
-- Mục đích: Kiểm tra và đo lường số lượng bảng và dữ liệu trong schema medusa
-- Đảm bảo Medusa v2 lưu trữ 100% độc lập, không conflict với bảng của Operon hay Auth.
-- ============================================================================

SELECT 
    table_name,
    (xpath('/row/cnt/text()', xml_count))[1]::text::int AS approximate_row_count
FROM (
    SELECT 
        table_name,
        query_to_xml(format('SELECT count(*) AS cnt FROM %I.%I', table_schema, table_name), false, true, '') AS xml_count
    FROM information_schema.tables
    WHERE table_schema = 'medusa'
) sub
ORDER BY table_name;
