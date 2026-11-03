#!/usr/bin/env node

/**
 * ==============================================================================
 * DATABASE RESET & SCHEMA SYNCHRONIZATION CLI (Node.js Cross-Platform)
 * ==============================================================================
 * Usage:
 *   node scripts/reset_database.mjs            (Default: --local)
 *   node scripts/reset_database.mjs --local
 *   node scripts/reset_database.mjs --cloud
 *   node scripts/reset_database.mjs --no-seed
 * ==============================================================================
 */

import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const idRoot = path.resolve(__dirname, '..');

// 1. Phân tích tham số dòng lệnh
const args = process.argv.slice(2);
const isCloud = args.includes('--cloud');
const isLocal = args.includes('--local') || !isCloud; // Mặc định là local
const noSeed = args.includes('--no-seed');
const target = isCloud ? 'cloud' : 'local';

console.log('\x1b[36m%s\x1b[0m', '=================================================================');
console.log('\x1b[36m%s\x1b[0m', ' [ID PLATFORM] DATABASE RESET & SCHEMA SYNCHRONIZATION');
console.log('\x1b[33m%s\x1b[0m', ` Target Environment : ${target.toUpperCase()}`);
console.log('\x1b[33m%s\x1b[0m', ` Working Directory  : ${idRoot}`);
console.log('\x1b[36m%s\x1b[0m', '=================================================================');

function run(command, cmdArgs, options = {}) {
  const isWindows = process.platform === 'win32';
  const executable = isWindows && !command.endsWith('.exe') && !command.endsWith('.cmd')
    ? `${command}.cmd`
    : command;

  console.log('\x1b[90m%s\x1b[0m', `> ${command} ${cmdArgs.join(' ')}`);

  const result = spawnSync(command, cmdArgs, {
    cwd: idRoot,
    stdio: 'inherit',
    shell: true,
    env: { ...process.env, ...options.env },
  });

  if (result.error) {
    console.error('\x1b[31m%s\x1b[0m', `[-] Command execution failed: ${result.error.message}`);
    process.exit(1);
  }

  if (result.status !== 0 && !options.ignoreError) {
    console.error('\x1b[31m%s\x1b[0m', `[-] Command exited with code ${result.status}`);
    process.exit(result.status || 1);
  }

  return result;
}

try {
  if (target === 'local') {
    console.log('\n\x1b[32m%s\x1b[0m', '[1/2] Resetting Local Supabase Database...');
    const localArgs = ['db', 'reset', '--local'];
    if (noSeed) localArgs.push('--no-seed');
    run('supabase', localArgs);

    console.log('\n\x1b[32m%s\x1b[0m', '[2/2] Running Local E2E Simulation Snippet...');
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
          stdio: ['pipe', 'inherit', 'inherit'],
          shell: true,
        });
      }
    }

    console.log('\n\x1b[32m%s\x1b[0m', '✔ SUCCESS: Local database reset and initialized successfully!');
  } else {
    console.log('\n\x1b[33m%s\x1b[0m', '[1/2] Configuring Gateway Proxy & Supabase Credentials...');
    const cloudEnv = {
      HTTP_PROXY: 'http://127.0.0.1:8118',
      HTTPS_PROXY: 'http://127.0.0.1:8118',
      ALL_PROXY: 'socks5://127.0.0.1:1080',
      SUPABASE_ACCESS_TOKEN: 'sbp_fc0e099f3239a651b5f9231c55ddcbfb5ad7b33f',
      SUPABASE_DB_PASSWORD: 'b8aA5CDM4Xp0Kwr9',
    };

    console.log('\x1b[33m%s\x1b[0m', '[2/2] Resetting Remote Supabase Cloud Database (Linked)...');
    const cloudArgs = ['db', 'reset', '--linked', '--yes'];
    if (noSeed) cloudArgs.push('--no-seed');

    run('supabase', cloudArgs, { env: cloudEnv });

    console.log('\n\x1b[32m%s\x1b[0m', '✔ SUCCESS: Cloud Supabase database reset completed!');
  }
} catch (err) {
  console.error('\x1b[31m%s\x1b[0m', `\n[-] Fatal Error: ${err.message}`);
  process.exit(1);
}
