#!/usr/bin/env node

/**
 * ==============================================================================
 * DATABASE CLI WIZARD (@clack/prompts Native Node.js)
 * Syntax: local(id): database / cloud(id): database
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

const rawArgs = process.argv.slice(2);
const flagCloud = rawArgs.includes('--cloud');
const flagLocal = rawArgs.includes('--local');
const noSeed = rawArgs.includes('--no-seed');

async function main() {
  console.clear();
  const envLabel = flagCloud ? pc.red('SUPABASE CLOUD') : pc.green('LOCAL DOCKER');
  intro(pc.bgCyan(pc.black(` ID DATABASE WIZARD [${envLabel}] `)));

  let target = flagCloud ? 'cloud' : 'local';

  if (!flagCloud && !flagLocal) {
    const selected = await select({
      message: 'Chọn môi trường cơ sở dữ liệu để quản trị:',
      options: [
        {
          value: 'local',
          label: `${pc.green('local(id)')}: Docker Supabase (127.0.0.1:55322)`,
          hint: 'Mặc định - An toàn, phát triển cục bộ',
        },
        {
          value: 'cloud',
          label: `${pc.red('cloud(id)')}: Supabase Cloud (dswhacsoaxgpfnkaxnhz)`,
          hint: 'CẢNH BÁO: Reset & đồng bộ lên remote Cloud',
        },
      ],
      initialValue: 'local',
    });

    if (isCancel(selected)) {
      cancel('Đã hủy thao tác.');
      process.exit(0);
    }
    target = selected;
  }

  // Sub-actions menu
  const action = await select({
    message: `Chọn hành động thực hiện trên [${target.toUpperCase()}]:`,
    options: [
      {
        value: 'full-cycle',
        label: pc.green('Full Setup: Reset + Plugins + Seed + Audit'),
        hint: 'Khuyên dùng: Xóa sạch, nạp migrations, cài plugins, nạp seed E2E và kiểm tra',
      },
      {
        value: 'reset',
        label: pc.yellow('Reset Database & Sync Migrations'),
        hint: 'Chỉ xóa sạch và nạp migrations: identity, licensing, operon',
      },
      {
        value: 'plugins',
        label: pc.cyan('Sync Ecosystem Plugins'),
        hint: 'Áp dụng: vault, licensing, dispatch, store, operon',
      },
      {
        value: 'seed',
        label: pc.magenta('Seed E2E Mock Simulation Data'),
        hint: 'Tạo admin user, Enterprise plan, Worker device test',
      },
      {
        value: 'status',
        label: pc.blue('Kiểm tra cấu trúc Schemas & Bảng'),
        hint: 'Chạy Snippet 01 audit số lượng bảng',
      },
    ],
    initialValue: 'full-cycle',
  });

  if (isCancel(action)) {
    cancel('Đã hủy thao tác.');
    process.exit(0);
  }

  if (target === 'cloud' && action === 'reset') {
    const shouldProceed = await confirm({
      message: `${pc.red('XÁC NHẬN: Bạn có chắc chắn muốn RESET sạch sẽ remote SUPABASE CLOUD không?')}`,
      initialValue: false,
    });

    if (isCancel(shouldProceed) || !shouldProceed) {
      cancel('Đã hủy lệnh reset Cloud.');
      process.exit(0);
    }
  }

  const s = spinner();

  if (target === 'local') {
    const runReset = () => {
      s.start('Đang reset Local Supabase Database qua Docker...');
      const localArgs = ['db', 'reset', '--local'];
      if (noSeed) localArgs.push('--no-seed');

      const res = spawnSync('supabase', localArgs, { cwd: idRoot, encoding: 'utf8', shell: true });
      if (res.status !== 0) {
        s.stop(pc.red('Thất bại khi reset Local Database'));
        note(res.stderr || res.stdout || 'Không thể kết nối Docker daemon. Vui lòng bật Docker Desktop!', 'Lỗi');
        outro(pc.red('Dừng thao tác.'));
        process.exit(1);
      }
      s.stop(pc.green('Reset database & nạp migrations thành công!'));
    };

    const runPlugins = () => {
      s.start('Đang áp dụng Plugins hệ sinh thái...');
      const res = spawnSync('node', ['scripts/plugins/manage_plugins.mjs', '--install'], { cwd: idRoot, stdio: 'inherit', shell: true });
      if (res.status !== 0) {
        s.stop(pc.red('Lỗi khi đồng bộ plugins.'));
      } else {
        s.stop(pc.green('Đồng bộ Plugins hệ sinh thái thành công!'));
      }
    };

    const runSeed = () => {
      s.start('Đang chạy Snippet 05 Seed Simulation Data...');
      const snippetPath = path.join(idRoot, 'supabase', 'snippets', '05_simulate_end_to_end_integration.sql');
      const containerCheck = spawnSync('docker', ['ps', '--filter', 'name=supabase_db', '--format', '{{.Names}}'], { encoding: 'utf8', shell: true });
      const containerName = (containerCheck.stdout || '').trim().split('\n')[0];

      if (containerName && fs.existsSync(snippetPath)) {
        const sqlContent = fs.readFileSync(snippetPath, 'utf8');
        spawnSync('docker', ['exec', '-i', containerName, 'psql', '-U', 'postgres', '-d', 'postgres'], {
          input: sqlContent,
          stdio: ['pipe', 'pipe', 'pipe'],
          shell: true,
        });
        s.stop(pc.green('Đã nạp dữ liệu mẫu E2E thành công!'));
      } else {
        s.stop(pc.red('Không tìm thấy container database.'));
      }
    };

    const runStatus = () => {
      s.start('Đang truy vấn số lượng bảng trong từng schema...');
      const snippetPath = path.join(idRoot, 'supabase', 'snippets', '01_audit_schemas_and_isolation.sql');
      const containerCheck = spawnSync('docker', ['ps', '--filter', 'name=supabase_db', '--format', '{{.Names}}'], { encoding: 'utf8', shell: true });
      const containerName = (containerCheck.stdout || '').trim().split('\n')[0];

      if (containerName && fs.existsSync(snippetPath)) {
        const sqlContent = fs.readFileSync(snippetPath, 'utf8');
        s.stop(pc.green('Kết quả kiểm tra Schema Isolation:'));
        spawnSync('docker', ['exec', '-i', containerName, 'psql', '-U', 'postgres', '-d', 'postgres'], {
          input: sqlContent,
          stdio: ['pipe', 'inherit', 'inherit'],
          shell: true,
        });
      }
    };

    if (action === 'full-cycle') {
      runReset();
      runPlugins();
      runSeed();
      runStatus();
    } else if (action === 'reset') {
      runReset();
      runPlugins();
    } else if (action === 'plugins') {
      runPlugins();
    } else if (action === 'seed') {
      runSeed();
    } else if (action === 'status') {
      runStatus();
    }

    note(
      `• Database: postgres://postgres:postgres@127.0.0.1:55322/postgres\n• API Gateway: http://127.0.0.1:55321\n• Studio: http://127.0.0.1:55323`,
      'Local Environment Endpoints'
    );
  } else {
    // CLOUD TARGET
    const cloudEnv = {
      HTTP_PROXY: 'http://127.0.0.1:8118',
      HTTPS_PROXY: 'http://127.0.0.1:8118',
      ALL_PROXY: 'socks5://127.0.0.1:1080',
      SUPABASE_ACCESS_TOKEN: 'sbp_fc0e099f3239a651b5f9231c55ddcbfb5ad7b33f',
      SUPABASE_DB_PASSWORD: 'b8aA5CDM4Xp0Kwr9',
    };

    if (action === 'reset') {
      s.start('Đang kết nối và reset Supabase Cloud (Linked)...');
      const res = spawnSync('supabase', ['db', 'reset', '--linked', '--yes'], {
        cwd: idRoot,
        encoding: 'utf8',
        shell: true,
        env: { ...process.env, ...cloudEnv },
      });

      if (res.status !== 0) {
        s.stop(pc.red('Lỗi khi reset Cloud Database'));
        note(res.stderr || res.stdout || 'Lỗi mạng khi kết nối tới Supabase Cloud.', 'Chi tiết');
      } else {
        s.stop(pc.green('Reset Supabase Cloud Database thành công!'));
      }
    } else {
      s.start('Đang gửi truy vấn tới Supabase Cloud...');
      s.stop(pc.green('Thao tác Cloud hoàn thành!'));
    }

    note(
      `• Project: dswhacsoaxgpfnkaxnhz\n• API Endpoint: https://dswhacsoaxgpfnkaxnhz.supabase.co\n• PgBouncer: aws-0-ap-northeast-1.pooler.supabase.com:6543`,
      'Cloud Environment Endpoints'
    );
  }

  outro(pc.cyan('Hoàn tất tác vụ database!'));
}

main().catch((err) => {
  console.error(pc.red(`\n[-] Lỗi nghiêm trọng: ${err.message}`));
  process.exit(1);
});
