# Tuquet Ecosystem Architecture & Network Matrix

Tài liệu này lưu trữ đặc tả chuẩn mực về kiến trúc mạng, phân định cổng kết nối và quy tắc chuyển đổi biến môi trường giữa **Local Dev** và **Production Cloud**.

---

## 1. MA TRẬN 1: MÔI TRƯỜNG PHÁT TRIỂN CỤC BỘ (LOCAL DEV MATRIX)

| Dự án | Thành phần nghiệp vụ | Nơi chạy thực tế | Cổng (Port) | Giao thức | Biến môi trường cốt lõi (.env) | URL / Endpoint cục bộ | Ghi chú kỹ thuật |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- | :--- |
| **`id`** | API Gateway (Auth & REST) | Docker (`supabase_kong_cloud`) | **`55321`** | HTTP | `API_EXTERNAL_URL`<br>`SUPABASE_URL` | `http://127.0.0.1:55321` | Auth GoTrue, ES256 JWKS, PostgREST |
| **`id`** | PostgreSQL DB Engine | Docker (`supabase_db_cloud`) | **`55322`** | Postgres TCP | `POSTGRES_PORT`<br>`DATABASE_URL` | `postgres://...:55322/postgres` | Chứa schemas: public, billing, operon, medusa |
| **`id`** | Supabase Studio Dashboard | Docker (`supabase_studio_cloud`) | **`55323`** | HTTP | `STUDIO_PORT` | `http://127.0.0.1:55323` | Giao diện quản trị Database & Storage |
| **`id`** | Inbucket Test Mailer | Docker (`supabase_inbucket_cloud`)| **`55324`** | HTTP | `INBUCKET_PORT` | `http://127.0.0.1:55324` | Hòm thư bẫy OTP & Magic Link thử nghiệm |
| **`store`** | Medusa Core Backend | Node.js Process | **`9000`** | HTTP | `PORT`<br>`DATABASE_URL`<br>`ID_JWKS_URL` | `http://localhost:9000` | Backend API (search_path=medusa,public) |
| **`store`** | Next.js Storefront | Node.js Process | **`8000`** | HTTP | `NEXT_PUBLIC_BASE_URL`<br>`NEXT_PUBLIC_MEDUSA_BACKEND_URL`<br>`NEXT_PUBLIC_SUPABASE_URL` | `http://localhost:8000` | Giao diện web bán lẻ DTC |
| **`console`** | Admin Workstation Web | Vite Dev Server | **`5666`** | HTTP | `VITE_PORT`<br>`VITE_SUPABASE_URL`<br>`VITE_DAEMON_PORT` | `http://localhost:5666` | Dashboard điều khiển trung tâm |
| **`operon`** | Automation Engine Daemon | Rust Executable | **`8765`** | WebSocket / HTTP | `DAEMON_PORT`<br>`SUPABASE_URL` | `ws://127.0.0.1:8765` | Daemon điều khiển Chromium automation |

---

## 2. MA TRẬN 2: MÔI TRƯỜNG PRODUCTION CLOUD (PRODUCTION MATRIX)

| Dự án | Thành phần nghiệp vụ | Nền tảng thực thi | Cổng nội bộ | Cổng công khai | Giao thức | Biến môi trường cốt lõi (.env) | Tên miền Production | Vai trò kỹ thuật & Port Scope |
| :--- | :--- | :--- | :---: | :---: | :---: | :--- | :--- | :--- |
| **`id`** | API Gateway (Auth & REST) | **Supabase Cloud** | `8000` | **`443`** | HTTPS / WSS | `API_EXTERNAL_URL`<br>`SUPABASE_URL`<br>`VITE_SUPABASE_URL`<br>`NEXT_PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co`<br>*(Custom: `id.tuquet.com`)* | Cấp phát token ES256, JWKS, PostgREST API |
| **`id`** | PgBouncer Pooler | **Supabase Cloud** | — | **`6543`** | Postgres + TLS | `DATABASE_URL` *(Medusa Backend)* | `pooler.<ref>.supabase.co:6543` | **Dành riêng cho Medusa Backend** trên VPS (Chống nghẽn pool) |
| **`id`** | Postgres Direct DB | **Supabase Cloud** | `5432` | **`5432`** | Postgres + TLS | `DIRECT_DATABASE_URL` | `db.<ref>.supabase.co:5432` | Dành cho chạy Migration / Schema Setup |
| **`id`** | Studio Dashboard | **Supabase Cloud** | — | **`443`** | HTTPS | — | `https://supabase.com/dashboard` | Quản trị DB, RLS, Storage |
| **`store`** | Medusa Core Backend | **VPS Linux** | **`9000`** | **`443`** | HTTPS | `PORT`<br>`DATABASE_URL`<br>`ID_JWKS_URL`<br>`STORE_CORS` | `https://api.store.tuquet.com` | Chạy Node.js Server qua Cloudflare Tunnel |
| **`store`** | Next.js Storefront | **Cloudflare / Vercel** | Serverless | **`443`** | HTTPS | `NEXT_PUBLIC_BASE_URL`<br>`NEXT_PUBLIC_MEDUSA_BACKEND_URL`<br>`NEXT_PUBLIC_COOKIE_DOMAIN` | `https://store.tuquet.com` | Next.js E-Commerce (Cookie SSO `.tuquet.com`) |
| **`console`** | Admin Workstation Web | **Cloudflare Pages** | Static Edge | **`443`** | HTTPS | `VITE_SUPABASE_URL`<br>`VITE_COOKIE_DOMAIN`<br>`VITE_DAEMON_URL` | `https://console.tuquet.com` | Vue 3 SPA Admin Dashboard ($0 chi phí) |
| **`operon`** | Automation Engine Daemon | **Desktop Cá Nhân** | **`8765`** | *Không mở* | WebSocket (WS) | `DAEMON_PORT`<br>`SUPABASE_URL` | `ws://127.0.0.1:8765` | Cầu nối điều khiển Bot từ Console trên máy local |

---

## 3. BẢNG MAPPING BIẾN MÔI TRƯỜNG KHI SWITCH (DEV <-> PROD)

| Biến môi trường cốt lõi | Dự án sử dụng | Môi trường Local Dev | Môi trường Production Cloud |
| :--- | :--- | :--- | :--- |
| **`SUPABASE_URL`** *(hoặc VITE_ / NEXT_PUBLIC_)* | Tất cả (`id`, `store`, `console`, `operon`) | `http://127.0.0.1:55321` | `https://<project-ref>.supabase.co` |
| **`DATABASE_URL`** | `store` (Medusa Backend) | `postgres://...:55322/postgres` | `postgres://...:6543/postgres` (Cổng 6543 PgBouncer) |
| **`ID_JWKS_URL`** | `store` (Medusa Backend) | `http://127.0.0.1:55321/auth/v1/.well-known/jwks.json` | `https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json` |
| **`MEDUSA_BACKEND_URL`** | `store` (Storefront) | `http://localhost:9000` | `https://api.store.tuquet.com` |
| **`COOKIE_DOMAIN`** | `store`, `console`, `id` | *(để trống / localhost)* | `.tuquet.com` (SSO Root Cookie) |
| **`DAEMON_URL`** | `console` (Admin UI) | `ws://127.0.0.1:8765` | `ws://127.0.0.1:8765` *(Luôn luôn là loopback local)* |
