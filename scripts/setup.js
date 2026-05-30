#!/usr/bin/env node
/**
 * claude-code-desktop-notify setup
 * Runs automatically after `npm install -g claude-code-desktop-notify`
 * Detects OS, copies the right hook script, and patches ~/.claude/settings.json
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';
import { PKG } from './lib/constants.js';
import { printInstallBanner } from './lib/banner.js';
import { installStatusline, setActiveFlag } from './statusline.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PKG_ROOT  = path.resolve(__dirname, '..');

// ─── Colores para la consola ────────────────────────────────────────────────
const c = {
  reset:  '\x1b[0m',
  green:  '\x1b[32m',
  yellow: '\x1b[33m',
  cyan:   '\x1b[36m',
  red:    '\x1b[31m',
  bold:   '\x1b[1m',
  dim:    '\x1b[2m',
};
const ok    = (msg) => console.log(`${c.green}✔${c.reset} ${msg}`);
const info  = (msg) => console.log(`${c.cyan}ℹ${c.reset} ${msg}`);
const warn  = (msg) => console.log(`${c.yellow}⚠${c.reset} ${msg}`);
const err   = (msg) => console.error(`${c.red}✖${c.reset} ${msg}`);
const title = (msg) => console.log(`\n${c.bold}${msg}${c.reset}\n`);

// ─── Detectar entorno ────────────────────────────────────────────────────────
function detectEnv() {
  if (process.platform === 'win32') return 'windows';

  // Detectar WSL
  try {
    const version = fs.readFileSync('/proc/version', 'utf8').toLowerCase();
    if (version.includes('microsoft') || version.includes('wsl')) return 'wsl';
  } catch {}

  if (process.platform === 'darwin') return 'macos';
  return 'linux';
}

// Convertir ruta Unix a Windows (para WSL)
function toWindowsPath(unixPath) {
  try {
    return execSync(`wslpath -w "${unixPath}"`, { encoding: 'utf8' }).trim();
  } catch {
    // Fallback manual
    return unixPath.replace(/^\/mnt\/([a-z])\//, '$1:/').replace(/\//g, '\\');
  }
}

// ─── Paths principales ───────────────────────────────────────────────────────
const HOME         = os.homedir();
const CLAUDE_DIR   = path.join(HOME, '.claude');
const HOOKS_DIR    = path.join(CLAUDE_DIR, 'hooks');
const SETTINGS_PATH = path.join(CLAUDE_DIR, 'settings.json');

// ─── Setup principal ─────────────────────────────────────────────────────────
function setup() {
  title(`${PKG} — instalando hooks de notificación`);

  const env = detectEnv();
  info(`Entorno detectado: ${c.bold}${env}${c.reset}`);

  // Crear directorios
  fs.mkdirSync(HOOKS_DIR, { recursive: true });
  ok(`Directorio de hooks: ${HOOKS_DIR}`);

  // ── Copiar el script correcto y construir el comando ──
  let hookCommand;

  if (env === 'windows') {
    const src  = path.join(PKG_ROOT, 'hooks', 'notify.ps1');
    const dest = path.join(HOOKS_DIR, `${PKG}.ps1`);
    fs.copyFileSync(src, dest);
    ok(`Script copiado → ${dest}`);

    const registerScript = path.join(PKG_ROOT, 'hooks', 'register-windows-toast.ps1');
    try {
      execSync(
        `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${registerScript}"`,
        { stdio: 'ignore' }
      );
      ok('App de notificaciones registrada en Windows');
    } catch {
      warn('No se pudo registrar la app de toast (las notificaciones pueden no mostrarse)');
    }

    hookCommand = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${dest}"`;

  } else if (env === 'wsl') {
    const src  = path.join(PKG_ROOT, 'hooks', 'notify-wsl.sh');
    const dest = path.join(HOOKS_DIR, `${PKG}.sh`);
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, '755');
    ok(`Script copiado → ${dest}`);

    // Para WSL, Claude Code corre en Windows, por lo que el comando
    // debe ser una ruta Windows que llame al script bash via wsl.exe
    const winDest = toWindowsPath(dest);
    hookCommand = `wsl.exe bash "${winDest}"`;

    // Alternativa si Claude Code está corriendo dentro de WSL
    info('Nota: si usas Claude Code desde dentro de WSL (no desde Windows), ejecuta:');
    info(`  ${PKG} setup --wsl-native`);

  } else {
    // macOS / Linux
    const src  = path.join(PKG_ROOT, 'hooks', 'notify.sh');
    const dest = path.join(HOOKS_DIR, `${PKG}.sh`);
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, '755');
    ok(`Script copiado → ${dest}`);
    hookCommand = dest;
  }

  // ── Patchear settings.json ──
  patchSettings(hookCommand, env, PKG_ROOT);

  installStatusline(PKG_ROOT, env, { ok, info, warn });
  setActiveFlag(true);

  printInstallBanner(c);
}

function patchSettings(hookCommand, env, pkgRoot) {
  // Leer settings existentes
  let settings = {};
  try {
    const raw = fs.readFileSync(SETTINGS_PATH, 'utf8');
    settings = JSON.parse(raw);
    ok(`settings.json encontrado: ${SETTINGS_PATH}`);
  } catch {
    info(`settings.json no existe, creando uno nuevo`);
  }

  // Asegurar estructura base
  settings.hooks ??= {};
  settings.hooks.Notification ??= [];

  // ── Comando de reset de título (hook Stop) ──
  let resetCommand;
  if (env === 'windows') {
    const src  = path.join(pkgRoot, 'hooks', 'reset-title.ps1');
    const dest = path.join(HOOKS_DIR, `${PKG}-reset-title.ps1`);
    fs.copyFileSync(src, dest);
    resetCommand = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${dest}"`;
  } else if (env === 'wsl') {
    const src  = path.join(pkgRoot, 'hooks', 'reset-title.sh');
    const dest = path.join(HOOKS_DIR, `${PKG}-reset-title.sh`);
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, '755');
    const winDest = (() => {
      try { return execSync(`wslpath -w "${dest}"`, { encoding: 'utf8' }).trim(); } catch { return dest; }
    })();
    resetCommand = `wsl.exe bash "${winDest}"`;
  } else {
    const src  = path.join(pkgRoot, 'hooks', 'reset-title.sh');
    const dest = path.join(HOOKS_DIR, `${PKG}-reset-title.sh`);
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, '755');
    resetCommand = dest;
  }

  // Actualizar comando de notificación si ya estaba instalado
  let updated = false;
  for (const entry of settings.hooks.Notification) {
    for (const hook of entry.hooks ?? []) {
      if (typeof hook.command === 'string' && (hook.command.includes(PKG) || hook.command.includes('claude-notify'))) {
        if (hook.command !== hookCommand) {
          hook.command = hookCommand;
          updated = true;
        }
      }
    }
  }
  if (updated) {
    ok(`Comando del hook actualizado en settings.json`);
    // Aún así continuar para registrar el hook Stop si no existe
  }

  const alreadyInstalled = settings.hooks.Notification
    .flatMap(entry => entry.hooks ?? [])
    .some(h => typeof h.command === 'string' && (h.command.includes(PKG) || h.command.includes('claude-notify')));

  if (!alreadyInstalled) {
    settings.hooks.Notification.push({
      matcher: "permission_prompt|idle_prompt",
      hooks: [
        {
          type: "command",
          command: hookCommand,
          timeout: 5
        }
      ]
    });
    ok(`Hook de notificación agregado a settings.json`);
  } else if (!updated) {
    ok(`${PKG} ya estaba en settings.json — sin cambios.`);
  }

  // ── Registrar hook Stop para resetear el título ──
  settings.hooks.Stop ??= [];
  const stopAlreadyInstalled = settings.hooks.Stop
    .flatMap(entry => entry.hooks ?? [])
    .some(h => typeof h.command === 'string' && h.command.includes(`${PKG}-reset-title`));

  if (!stopAlreadyInstalled) {
    settings.hooks.Stop.push({
      hooks: [
        {
          type: "command",
          command: resetCommand,
          timeout: 3
        }
      ]
    });
    ok(`Hook Stop (reset de título) agregado a settings.json`);
  }

  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
  ok(`settings.json actualizado`);
}

// ─── Ejecutar ────────────────────────────────────────────────────────────────
try {
  setup();
} catch (e) {
  err(`Error durante la instalación: ${e.message}`);
  console.error(e);
  // No hacer exit(1) — no queremos que falle el pnpm install completo
}
