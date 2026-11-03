#!/usr/bin/env node

/**
 * ==============================================================================
 * DATABASE RESET & SCHEMA SYNCHRONIZATION CLI (@clack/prompts Interactive)
 * ==============================================================================
 * Usage:
 *   node scripts/reset_database.mjs            (Interactive or Default --local)
 *   node scripts/reset_database.mjs --local    (Direct Local)
 *   node scripts/reset_database.mjs --cloud    (Direct Cloud)
 *   node scripts/reset_database.mjs --no-seed  (Skip Seed)
 * ==============================================================================
 */

import { intro, outro, select, confirm, spinner, note, isCancel, cancel } from '@clack/prompts';
import pc from 'picocolors';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const idRoot = path.resolve(__dirname, '..');

// 1. Phân tích cờ dòng lệnh
const rawArgs = process.argv.slice(2);
const flagCloud = rawArgs.includes('--cloud');
const flagLocal = rawArgs.includes('--local');
const noSeed = rawArgs.includes('--no-seed');

async function main() {
  console.clear();
  intro(pc.bgCyan(pc.black(' TUQUET ID PLATFORM: DATABASE RESET & SYNC ')));

  let target = 'local';

  // Nếu người dùng không chỉ định cờ, hiển thị giao diện Clack tương tác đẹp mắt
  if (!flagCloud && !flagLocal) {
    const selected = await select({
      message: 'Chọn môi trường cơ sở dữ liệu cần Reset & Đồng bộ:',
      options: [
        {
          value: 'local',
          label: `${pc.green('● Local Database')} (Docker 127.0.0.1:55322)`,
          hint: 'Mặc định - An toàn, chạy cục bộ',
        },
        {
          value: 'cloud',
          label: `${pc.red('▲ Supabase Cloud')} (Project: dswhacsoaxgpfnkaxnhz)`,
          hint: 'CẢNH BÁO: Xóa sạch & nạp lại schema trên Cloud',
        },
      ],
      initialValue: 'local',
    });

    if (isCancel(selected)) {
      cancel('Đã hủy thao tác.');
      process.exit(0);
    }
    target = selected;
  } else {
    target = flagCloud ? 'cloud' : 'local';
  }

  // Xác nhận nếu chọn môi trường Cloud
  if (target === 'cloud') {
    const shouldProceed = await confirm({
      message: `${pc.red('Bạn có chắc chắn muốn RESET cơ sở dữ liệu trên SUPABASE CLOUD không?')}`,
      initialValue: false,
    });

    if (isCancel(shouldProceed) || !shouldProceed) {
      cancel('Đã hủy reset Cloud DB.');
      process.exit(0);
    }
  }

  const s = spinner();

  if (target === 'local') {
    s.start('Đang kiểm tra Docker daemon và Supabase Local...');

    const localArgs = ['db', 'reset', '--local'];
    if (noSeed) localArgs.push('--no-seed');

    const result = spawnSync('supabase', localArgs, {
      cwd: idRoot,
      encoding: 'utf8',
      shell: true,
    });

    if (result.status !== 0) {
      s.stop(pc.red('Thất bại khi reset Local Database'));
      note(
        result.stderr || result.stdout || 'Không thể kết nối Docker daemon. Vui lòng đảm bảo Docker Desktop đang chạy!',
        'Chi tiết lỗi'
      );
      outro(pc.red('Quá trình thất bại. Vui lòng thử lại sau khi mở Docker.'));
      process.exit(1);
    }

    s.message('Đang áp dụng E2E Test Simulation Snippet vào Local DB...');
    const snippetPath = path.join(idRoot, 'supabase', 'snippets', '05_simulate_end_to_end_integration.sql');
    if (fs.existsSync(snippetPath)) {
      const containerCheck = spawnSync('docker', ['ps', '--filter', 'name=supabase_db', '--format', '{{.Names}}'], {
        encoding: 'utf8',
        shell: true,
      });

      const containerName = (containerCheck.stdout || '').trim().split('\n')[0];
      if (containerName) {
        const sqlContent = fs.readFileSync(snippetPath, 'utf8');
        spawnSync('docker', ['exec', '-i', containerName, 'psql', '-U', 'postgres', '-d', 'postgres'], {
          input: sqlContent,
          stdio: ['pipe', 'pipe', 'pipe'],
          shell: true,
        });
      }
    }

    s.stop(pc.green('Hoàn tất Reset & Khởi tạo Local Database thành công!'));
    note(
      `• Database: postgres://postgres:postgres@127.0.0.1:55322/postgres\n• API Gateway: http://127.0.0.1:55321\n• Studio: http://127.0.0.1:55323`,
      'Thông tin kết nối cục bộ'
    );
  } else {
    s.start('Đang thiết lập Gateway Proxy & kết nối Supabase Cloud...');

    const cloudEnv = {
      HTTP_PROXY: 'http://127.0.0.1:8118',
      HTTPS_PROXY: 'http://127.0.0.1:8118',
      ALL_PROXY: 'socks5://127.0.0.1:1080',
      SUPABASE_ACCESS_TOKEN: 'sbp_fc0e099f3239a651b5f9231c55ddcbfb5ad7b33f',
      SUPABASE_DB_PASSWORD: 'b8aA5CDM4Xp0Kwr9',
    };

    const cloudArgs = ['db', 'reset', '--linked', '--yes'];
    if (noSeed) cloudArgs.push('--no-seed');

    const result = spawnSync('supabase', cloudArgs, {
      cwd: idRoot,
      encoding: 'utf8',
      shell: true,
      env: { ...process.env, ...cloudEnv },
    });

    if (result.status !== 0) {
      s.stop(pc.red('Thất bại khi reset Cloud Database'));
      note(result.stderr || result.stdout || 'Lỗi kết nối tới Supabase Cloud.', 'Chi tiết lỗi');
      outro(pc.red('Quá trình reset Cloud thất bại.'));
      process.exit(1);
    }

    s.stop(pc.green('Hoàn tất Reset & Khởi tạo Supabase Cloud Database thành công!'));
    note(
      `• Project: dswhacsoaxgpfnkaxnhz\n• API Base: https://dswhacsoaxgpfnkaxnhz.supabase.co\n• PgBouncer Pooler: aws-0-ap-northeast-1.pooler.supabase.com:6543`,
      'Thông tin kết nối Cloud'
    );
  }

  outro(pc.cyan('✨ Hệ thống đã sẵn sàng cho bước tiếp theo!'));
}

main().catch((err) => {
  console.error(pc.red(`\n[-] Lỗi nghiêm trọng: ${err.message}`));
  process.exit(1);
});
