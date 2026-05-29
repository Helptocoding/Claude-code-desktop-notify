#!/usr/bin/env node
/**
 * claude-code-desktop-notify uninstall
 * Corre automáticamente al hacer `npm remove -g claude-code-desktop-notify`
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { PKG } from './lib/constants.js';
import { uninstallStatusline } from './statusline.js';

const c = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
};
const ok   = (msg) => console.log(`${c.green}✔${c.reset} ${msg}`);
const warn = (msg) => console.log(`${c.yellow}⚠${c.reset} ${msg}`);
const info = (msg) => console.log(`${c.cyan}ℹ${c.reset} ${msg}`);

const HOME          = os.homedir();
const HOOKS_DIR     = path.join(HOME, '.claude', 'hooks');
const SETTINGS_PATH = path.join(HOME, '.claude', 'settings.json');

function isOurHook(command) {
  if (typeof command !== 'string') return false;
  return command.includes(PKG) || command.includes('claude-notify');
}

function uninstall() {
  console.log(`\n${c.bold}${PKG} — desinstalando${c.reset}\n`);

  try {
    const raw = fs.readFileSync(SETTINGS_PATH, 'utf8');
    const settings = JSON.parse(raw);

    if (settings.hooks?.Notification) {
      const before = settings.hooks.Notification.length;

      settings.hooks.Notification = settings.hooks.Notification
        .map(entry => {
          if (!entry.hooks) return entry;
          const filtered = entry.hooks.filter(h => !isOurHook(h.command));
          return filtered.length > 0 ? { ...entry, hooks: filtered } : null;
        })
        .filter(Boolean);

      const after = settings.hooks.Notification.length;

      if (before !== after || before > 0) {
        if (settings.hooks.Notification.length === 0) {
          delete settings.hooks.Notification;
        }
        if (Object.keys(settings.hooks).length === 0) {
          delete settings.hooks;
        }
        fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
        ok('Entrada removida de settings.json');
      } else {
        warn(`No se encontró entrada de ${PKG} en settings.json`);
      }
    }
  } catch (e) {
    warn(`No se pudo limpiar settings.json: ${e.message}`);
  }

  const scripts = [
    `${PKG}.ps1`,
    `${PKG}.sh`,
    `${PKG}-reset-title.ps1`,
    `${PKG}-reset-title.sh`,
    'claude-notify.ps1',
    'claude-notify.sh',
  ];
  for (const script of scripts) {
    const filePath = path.join(HOOKS_DIR, script);
    try {
      fs.unlinkSync(filePath);
      ok(`Eliminado: ${filePath}`);
    } catch {
      // No existía, ignorar
    }
  }

  // Limpiar hook Stop
  try {
    const raw = fs.readFileSync(SETTINGS_PATH, 'utf8');
    const settings = JSON.parse(raw);
    if (settings.hooks?.Stop) {
      settings.hooks.Stop = settings.hooks.Stop
        .map(entry => {
          if (!entry.hooks) return entry;
          const filtered = entry.hooks.filter(h => !isOurHook(h.command));
          return filtered.length > 0 ? { ...entry, hooks: filtered } : null;
        })
        .filter(Boolean);
      if (settings.hooks.Stop.length === 0) delete settings.hooks.Stop;
      if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
      fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
      ok('Hook Stop removido de settings.json');
    }
  } catch {}

  // Limpiar archivo de contador
  const countFile = path.join(os.homedir(), '.claude', '.notify-count');
  try { fs.unlinkSync(countFile); ok('Contador de título eliminado'); } catch {}

  uninstallStatusline({ ok, warn });

  console.log('');
  ok(`${PKG} desinstalado correctamente.`);
  info('Tu configuración de Claude Code no fue afectada.');
  console.log('');
}

try {
  uninstall();
} catch (e) {
  console.error('Error durante la desinstalación:', e.message);
}
