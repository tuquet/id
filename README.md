# Identity & Access Management Platform (id)

**`id`** là sản phẩm trung tâm cung cấp dịch vụ **Định danh (Identity & SSO)**, **Cấp phép & Bản quyền (Licensing & Entitlements)**, **Kho bảo mật (Vault)**, và **Điều phối sự kiện (Dispatch)** xuyên suốt cho toàn bộ hệ sinh thái:
- **Store Platform:** Medusa v2 E-Commerce (`medusa`)
- **Automation Runtime:** Operon Workers & Browser Sandbox (`operon`)
- **Client Apps:** Web console, Desktop & Mobile apps

---

## 1. Cấu trúc Module Sản phẩm (Product Modules)

```text
id/
├── scripts/
│   └── plugins/
│       ├── apply_plugins.ps1      # Runner tự động cài đặt module sản phẩm (PowerShell)
│       └── apply_plugins.sh       # Runner tự động cài đặt module sản phẩm (Bash)
├── supabase/
│   ├── config.toml                # Cấu hình cụm Supabase Control Plane
│   ├── seed.sql                   # Khởi tạo dữ liệu mẫu cho Local Development
│   ├── migrations/                # Cốt lõi nền tảng (Core Foundation)
│   │   ├── 20261011000001_identity.sql     # Core IAM, Profiles, Tenants, RBAC
│   │   └── 20261102000001_licensing.sql    # Global User Entitlements (Bản quyền xuyên suốt)
│   └── plugins/                   # Các phân hệ sản phẩm độc lập (Product Capabilities):
│       ├── identity/              # [Identity] Metadata & profile inspection
│       ├── licensing/             # [Licensing] Quota, ví xu credits, tier entitlements
│       ├── store/                 # [Store Engine] Dedicated schema isolation cho Medusa v2
│       ├── vault/                 # [Vault] Mã hóa zero-knowledge DEK, API credentials
│       └── dispatch/              # [Dispatch] Outbox events, realtime message broker
└── README.md
```

---

## 2. Bản đồ Schema PostgreSQL (Unified Instance)

| Schema | Sản phẩm phụ trách | Mô tả chức năng |
| :--- | :--- | :--- |
| **`auth`** | Supabase Auth (SSOT) | Quản lý đăng ký, đăng nhập, JWT, OAuth, Passkeys |
| **`public`** | **`identity`** & **`licensing`** | Profiles, Organizations, và bảng `user_entitlements` |
| **`billing`** | **`licensing`** | Bảng giá (plans), hạn mức (quotas), ví tín dụng (wallets) |
| **`medusa`** | **`store`** | Cô lập toàn bộ bảng của Medusa Store (Products, Orders, Carts) |
| **`secrets`** | **`vault`** | Lưu trữ mã bí mật, Private Keys được mã hóa |
| **`events`** | **`dispatch`** | Bảng Outbox lưu sự kiện đồng bộ giữa các app |

---

## 3. Khởi động & Vận hành

### Khởi động Local Control Plane
```bash
# Bật Supabase container
supabase start

# Reset và nạp toàn bộ migrations nền tảng
supabase db reset
```

### Kích hoạt toàn bộ hoặc từng Module Sản phẩm
```powershell
# Kích hoạt toàn bộ modules
powershell -ExecutionPolicy Bypass -File scripts/plugins/apply_plugins.ps1

# Hoặc kích hoạt riêng module Store cho Medusa
powershell -ExecutionPolicy Bypass -File scripts/plugins/apply_plugins.ps1 -Plugin store
```
