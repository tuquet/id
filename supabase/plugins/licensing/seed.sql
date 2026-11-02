-- ============================================================================
-- SUBSCRIPTIONS PLUGIN SAMPLE SEED DATA
-- Description: Default Plans, Pluggable Payment Gateways, Secrets & Bank Accounts
-- ============================================================================

-- 1. Default Plans
INSERT INTO billing.plans (id, name, description, max_members, max_storage_mb, max_monthly_runs, price_monthly_usd)
VALUES 
    ('free', 'Free Starter', 'Entry plan for individual developers and small tests', 2, 500, 1000, 0.00),
    ('pro', 'Team Pro', 'Advanced automation capabilities with team collaboration', 10, 10240, 50000, 29.00),
    ('enterprise', 'Enterprise Fleet', 'Dedicated workers, custom quotas, and SLAs', 100, 102400, 1000000, 199.00)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    max_members = EXCLUDED.max_members,
    max_storage_mb = EXCLUDED.max_storage_mb,
    max_monthly_runs = EXCLUDED.max_monthly_runs;

-- 2. Pluggable Payment Gateways
INSERT INTO billing.payment_gateways (id, name, channel, driver, currency, rate_per_credit, public_config, is_active, sort_order)
VALUES
    (
        'internal_wallet',
        'Vi Xu Noi Bo (Thanh toan tuc thi)',
        'internal_wallet',
        'ledger',
        'CREDITS',
        1.000000,
        '{"unit": "Xu", "instant": true}'::jsonb,
        TRUE,
        1
    ),
    (
        'bank_vietqr',
        'Chuyen khoan Ngan hang 24/7 (VietQR / Napas247)',
        'bank_transfer',
        'sepay',
        'VND',
        1000.000000,
        '{"bank_bin": "970422", "bank_name": "MBBank", "account_no": "0000123456789", "account_name": "TUQUET PLATFORM", "qr_template": "compact2"}'::jsonb,
        TRUE,
        2
    ),
    (
        'momo_ewallet',
        'Vi Dien Tu MoMo (QR / Chuyen khoan SĐT)',
        'e_wallet',
        'momo_ipn',
        'VND',
        1000.000000,
        '{"wallet_provider": "MoMo", "wallet_phone": "0900000000", "account_name": "TUQUET PLATFORM"}'::jsonb,
        TRUE,
        3
    ),
    (
        'stripe_card',
        'The Quoc Te Visa / Mastercard / Apple Pay (Stripe)',
        'card_intl',
        'stripe',
        'USD',
        0.040000,
        '{"provider": "Stripe", "supported_cards": ["visa", "mastercard", "amex", "apple_pay"]}'::jsonb,
        TRUE,
        4
    ),
    (
        'crypto_usdt',
        'Tien Ma Hoa USDT (TRC20 / BEP20 / Binance Pay)',
        'crypto',
        'trc20',
        'USDT',
        0.040000,
        '{"network": "TRC20", "token": "USDT", "wallet_address": "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb"}'::jsonb,
        TRUE,
        5
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    channel = EXCLUDED.channel,
    driver = EXCLUDED.driver,
    currency = EXCLUDED.currency,
    rate_per_credit = EXCLUDED.rate_per_credit,
    public_config = EXCLUDED.public_config,
    sort_order = EXCLUDED.sort_order;

-- 3. Payment Gateway Webhook Secrets
INSERT INTO billing.payment_gateway_secrets (gateway_id, secret_config)
VALUES
    ('bank_vietqr', '{"webhook_secret": "test-sepay-hmac-secret-placeholder"}'::jsonb),
    ('momo_ewallet', '{"webhook_secret": "test-momo-hmac-secret-placeholder"}'::jsonb),
    ('stripe_card', '{"webhook_secret": "whsec_test_stripe_placeholder"}'::jsonb),
    ('crypto_usdt', '{"webhook_secret": "test-crypto-hmac-secret-placeholder"}'::jsonb)
ON CONFLICT (gateway_id) DO NOTHING;

-- 4. Dynamic Bank Receiving Accounts Pool
INSERT INTO billing.bank_receiving_accounts (id, bank_bin, bank_name, account_no, account_name, qr_template, daily_limit_vnd, priority, is_active, status)
VALUES
    ('mbbank_primary', '970422', 'MBBank', '0000123456789', 'TUQUET PLATFORM', 'compact2', 300000000.00, 1, TRUE, 'active'),
    ('vpbank_secondary', '970432', 'VPBank', '9888777666', 'TUQUET MEDIA CORP', 'compact2', 500000000.00, 2, TRUE, 'active'),
    ('techcombank_backup', '970407', 'Techcombank', '19033445566778', 'TUQUET BACKUP', 'compact2', 150000000.00, 3, TRUE, 'active')
ON CONFLICT (id) DO UPDATE SET
    bank_name = EXCLUDED.bank_name,
    account_no = EXCLUDED.account_no,
    account_name = EXCLUDED.account_name,
    daily_limit_vnd = EXCLUDED.daily_limit_vnd;
