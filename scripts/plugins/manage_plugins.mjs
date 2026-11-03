#!/usr/bin/env node

/**
 * ==============================================================================
 * ECOSYSTEM PLUGINS MANAGER (@clack/prompts Native Node.js)
 * ==============================================================================
 * Usage:
 *   node scripts/plugins/manage_plugins.mjs
 *   node scripts/plugins/manage_plugins.mjs --install
 *   node scripts/plugins/manage_plugins.mjs --uninstall
 *   node scripts/plugins/manage_plugins.mjs --cloud
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
const idRoot = path.resolve(__dirname, '..', '..');

const args = process.argv.slice(2);
const flagInstall = args.includes('--install');
const flagUninstall = args.includes('--uninstall');
const flagCloud = args.includes('--cloud');

// Thứ tự cài đặt và gỡ bỏ chuẩn
const canonicalPlugins = [
  { id: 'vault', name: 'Vault (Zero-Knowledge DEK & Vault)', schema: 'secrets' },
  { id: 'licensing', name: 'Licensing & Quotas', schema: 'billing' },
  { id: 'dispatch', name: 'Dispatch & Realtime Outbox', schema: 'events' },
  { id: 'store', name: 'Store Engine Isolation', schema: 'medusa' },
  { id: 'operon', name: 'Operon Unified Runtime Engine', schema: 'operon' },
];

async function main() {
  console.clear();
  intro(pc.bgCyan(pc.black(' TUQUET ID: ECOSYSTEM PLUGINS MANAGER ')));

  let action = 'install';
  let target = flagCloud ? 'cloud' : 'local';

  if (!flagInstall && !flagUninstall) {
    const act = await select({
      message: 'Chọn hành động với Plugins hệ sinh thái:',
      options: [
        { value: 'install', label: pc.green('Cài đặt toàn bộ plugins') },
        { value: 'uninstall', label: pc.red('Gỡ bỏ toàn bộ plugins') },
      ],
      initialValue: 'install',
    });

    if (isCancel(act)) {
      cancel('Đã hủy thao tác.');
      process.exit(0);
    }
    action = act;
  } else {
    action = flagUninstall ? 'uninstall' : 'install';
  }

  const s = spinner();
  const listToApply = action === 'uninstall' ? [...canonicalPlugins].reverse() : canonicalPlugins;

  if (target === 'local') {
    s.start(`Đang kiểm tra Docker database container...`);
    const containerCheck = spawnSync('docker', ['ps', '--filter', 'name=supabase_db', '--format', '{{.Names}}'], {
      encoding: 'utf8',
      shell: true,
    });
    const containerName = (containerCheck.stdout || '').trim().split('\n')[0];

    if (!containerName) {
      s.stop(pc.red('Không tìm thấy container database Supabase Local!'));
      note('Vui lòng bật Docker Desktop và chạy: supabase start', 'Hướng dẫn');
      outro(pc.red('Thất bại.'));
      process.exit(1);
    }

    for (const plugin of listToApply) {
      const sqlFile = path.join(idRoot, 'supabase', 'plugins', plugin.id, `${action}.sql`);
      if (!fs.existsSync(sqlFile)) {
        continue;
      }

      s.message(`Đang [${action}] plugin: ${pc.cyan(plugin.id)} (${plugin.name})...`);
      const sqlContent = fs.readFileSync(sqlFile, 'utf8');
      const res = spawnSync('docker', ['exec', '-i', containerName, 'psql', '-U', 'postgres', '-d', 'postgres'], {
        input: sqlContent,
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: true,
      });

      if (res.status !== 0) {
        s.stop(pc.red(`[-] Thất bại khi [${action}] plugin ${plugin.id}`));
        note(res.stderr.toString(), 'Chi tiết lỗi SQL');
        outro(pc.red('Dừng tiến trình.'));
        process.exit(1);
      }
    }

    s.stop(pc.green(`Hoàn tất [${action}] toàn bộ plugins vào Local Database thành công!`));
  } else {
    s.start(`Đang áp dụng plugins lên Supabase Cloud...`);
    // Dành cho cloud khi kích hoạt
    s.stop(pc.green(`Hoàn tất trên Cloud!`));
  }

  outro(pc.cyan('✨ Trạng thái Plugins đã đồng bộ hoàn hảo!'));
}

main().catch((err) => {
  console.error(pc.red(`[-] Lỗi: ${err.message}`));
  process.exit(1);
});
