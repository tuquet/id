# Identity & Access Management Hub (id)

Dự án trung tâm quản lý **Danh tính (Auth / SSO)**, **Hồ sơ cá nhân (Profiles)**, và **Bản quyền dịch vụ (Entitlements / Subscriptions)** dùng chung cho toàn bộ hệ sinh thái:
- **Medusa E-Commerce Store** (`medusa`)
- **Operon Automation & Workers** (`operon`)
- Các Web/Desktop Apps vệ tinh khác

---

## 1. Cấu trúc thư mục

```text
id/
├── scripts/
│   └── plugins/
│       └── apply_plugins.ps1      # Cài đặt các schema plugins (billing, events, secrets)
├── supabase/
│   ├── config.toml                # Cấu hình cụm Supabase Local
│   ├── seed.sql                   # Dữ liệu mẫu khởi tạo
│   ├── migrations/                # Migrations nền tảng (Core IAM, Medusa Schema, Entitlements)
│   └── plugins/                   # Các module plugin tinh gọn:
│       ├── core-iam/              # Auth, Profiles, Tenants, RBAC
│       ├── secrets/               # Quản lý khóa bí mật / API Keys
│       ├── subscriptions/         # Quota, Ví Xu credits, Giấy phép
│       └── webhooks/              # Outbox Events đồng bộ dữ liệu
└── README.md
```

---

## 2. Các Schema trong PostgreSQL (1 Instance duy nhất)

| Schema | Mục đích | Ứng dụng phụ trách |
| :--- | :--- | :--- |
| **`auth`** | Tài khoản đăng nhập, JWT, OAuth, Passkeys | Supabase Auth (SSOT) |
| **`public`** | Profiles, Tenants, và `user_entitlements` | Chung toàn hệ sinh thái |
| **`medusa`** | Products, Orders, Carts, Payments | Medusa v2 Backend |
| **`billing`** | Plans, Quota, Ví Xu credits | Platform Hub |
| **`events`** | Webhooks, Outbox event deliveries | Event Bus |

---

## 3. Khởi động Local

```bash
# Di chuyển vào thư mục dự án
cd id

# 1. Bật Supabase Local
supabase start

# 2. Reset và chạy toàn bộ Migrations cốt lõi
supabase db reset

# 3. Cài đặt các plugin cần thiết (PowerShell)
powershell -ExecutionPolicy Bypass -File scripts/plugins/apply_plugins.ps1
```
