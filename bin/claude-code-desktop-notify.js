#!/usr/bin/env node
/**
 * claude-code-desktop-notify CLI
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import { execSync, spawnSync } from 'child_process';
import { fileURLToPath } from 'url';

const PKG = 'claude-code-desktop-notify';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ACTIVE_FLAG = path.join(HOME, '.claude', `.${PKG}-active`);

function setActiveFlag(active) {
  fs.mkdirSync(path.dirname(ACTIVE_FLAG), { recursive: true });
  if (active) fs.writeFileSync(ACTIVE_FLAG, 'on\n', 'utf8');
  else { try { fs.unlinkSync(ACTIVE_FLAG); } catch {} }
}

const c = {
  reset:  '\x1b[0m',
  green:  '\x1b[32m',
  yellow: '\x1b[33m',
  cyan:   '\x1b[36m',
  red:    '\x1b[31m',
  bold:   '\x1b[1m',
  dim:    '\x1b[2m',
};

const ok   = (msg) => console.log(`${c.green}✔${c.reset} ${msg}`);
const warn = (msg) => console.log(`${c.yellow}⚠${c.reset} ${msg}`);
const fail = (msg) => console.log(`${c.red}✖${c.reset} ${msg}`);
const info = (msg) => console.log(`${c.cyan}ℹ${c.reset} ${msg}`);

const HOME          = os.homedir();
const HOOKS_DIR     = path.join(HOME, '.claude', 'hooks');
const SETTINGS_PATH = path.join(HOME, '.claude', 'settings.json');

function isOurHook(command) {
  if (typeof command !== 'string') return false;
  return command.includes(PKG) || command.includes('claude-notify');
}

/** Evita cmd /c al probar en Windows (rompe stdin y puede dar "Acceso denegado"). */
function resolveWindowsTestCommand(command) {
  const ps1Match = command.match(/claude-code-desktop-notify\.ps1/i);
  if (!ps1Match) return command;
  const ps1Path = command.match(/"([^"]*claude-code-desktop-notify\.ps1)"/i)?.[1]
    ?? path.join(HOOKS_DIR, `${PKG}.ps1`);
  return `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${ps1Path}"`;
}

function readSettings() {
  try {
    return JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function writeSettings(settings) {
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
}

function findEntry(settings) {
  return (settings.hooks?.Notification ?? []).find(entry =>
    (entry.hooks ?? []).some(h => isOurHook(h.command))
  );
}

const [,, command] = process.argv;

switch (command) {
  case 'setup':
  case undefined: {
    const result = spawnSync(process.execPath, [path.join(__dirname, '..', 'scripts', 'setup.js')], { stdio: 'inherit' });
    process.exit(result.status ?? 0);
    break;
  }

  case 'on':
    toggleNotifications(true);
    break;

  case 'off':
    toggleNotifications(false);
    break;

  case 'test':
    sendTestNotification();
    break;

  case 'status':
    showStatus();
    break;

  case 'uninstall': {
    const r = spawnSync(process.execPath, [path.join(__dirname, '..', 'scripts', 'uninstall.js')], { stdio: 'inherit' });
    process.exit(r.status ?? 0);
    break;
  }

  default:
    printHelp();
}

function toggleNotifications(enable) {
  console.log('');
  const settings = readSettings();
  const entry = findEntry(settings);

  if (!entry) {
    warn(`${PKG} no está instalado en settings.json.`);
    info(`Ejecuta: ${c.cyan}${PKG} setup${c.reset}`);
    console.log('');
    return;
  }

  if (enable) {
    if (!entry.disabled) {
      ok('Las notificaciones ya estaban activas.');
    } else {
      delete entry.disabled;
      writeSettings(settings);
      setActiveFlag(true);
      ok(`${c.bold}Notificaciones activadas.${c.reset}`);
      info(`Badge ${c.cyan}[NOTIFY]${c.reset} visible de nuevo en Claude Code`);
      info(`Prueba con: ${c.cyan}${PKG} test${c.reset}`);
    }
  } else {
    if (entry.disabled) {
      ok('Las notificaciones ya estaban desactivadas.');
    } else {
      entry.disabled = true;
      writeSettings(settings);
      setActiveFlag(false);
      ok(`${c.bold}Notificaciones desactivadas.${c.reset}`);
      info(`Badge ${c.cyan}[NOTIFY]${c.reset} oculto hasta que ejecutes ${c.cyan}${PKG} on${c.reset}`);
    }
  }
  console.log('');
}

function sendTestNotification() {
  console.log(`\n${c.bold}Enviando notificación de prueba...${c.reset}\n`);

  try {
    const settings = readSettings();
    const entry = findEntry(settings);

    if (!entry) {
      warn(`${PKG} no está en settings.json. Ejecuta: ${c.cyan}${PKG} setup${c.reset}`);
      return;
    }

    if (entry.disabled) {
      warn(`Las notificaciones están desactivadas. Actívalas con: ${c.cyan}${PKG} on${c.reset}`);
      return;
    }

    const notifyHook = entry.hooks.find(h => isOurHook(h.command));
    const testPayload = JSON.stringify({
      session_id: 'test-session',
      hook_event_name: 'Notification',
      notification_type: 'permission_prompt',
      message: `¡Prueba de ${PKG}! Las notificaciones funcionan correctamente.`,
      cwd: process.cwd(),
    });

    const testCommand = process.platform === 'win32'
      ? resolveWindowsTestCommand(notifyHook.command)
      : notifyHook.command;
    execSync(testCommand, { input: testPayload, stdio: ['pipe', 'inherit', 'inherit'] });

    ok('Notificación enviada. ¿La viste en el escritorio?');
    console.log(`  ${c.dim}Si no apareció, revisa los permisos de notificaciones de tu OS.${c.reset}\n`);

  } catch (e) {
    fail(`Error al enviar la notificación: ${e.message}`);
  }
}

function showStatus() {
  console.log(`\n${c.bold}${PKG} — estado${c.reset}\n`);

  try {
    const settings = readSettings();
    const entry = findEntry(settings);

    if (entry) {
      if (entry.disabled) {
        warn(`Instalado pero ${c.bold}desactivado${c.reset}  →  ${c.cyan}${PKG} on${c.reset} para reactivar`);
      } else {
        ok(`Activo`);
      }
      const hook = entry.hooks.find(h => isOurHook(h.command));
      if (hook) console.log(`  ${c.dim}Comando: ${hook.command}${c.reset}`);
    } else {
      fail('No encontrado en settings.json');
      console.log(`  Ejecuta: ${c.cyan}${PKG} setup${c.reset}`);
    }
  } catch {
    fail(`settings.json no encontrado en ${SETTINGS_PATH}`);
  }

  const scripts = [
    `${PKG}.ps1`,
    `${PKG}.sh`,
    'claude-notify.ps1',
    'claude-notify.sh',
  ];
  let found = false;
  for (const script of scripts) {
    const p = path.join(HOOKS_DIR, script);
    if (fs.existsSync(p)) {
      ok(`Script de hook: ${p}`);
      found = true;
    }
  }
  if (!found) warn(`No se encontró script de hook en ${HOOKS_DIR}`);

  console.log('');
}

function printHelp() {
  console.log(`
${c.bold}${PKG}${c.reset} — Notificaciones de escritorio para Claude Code

${c.bold}Uso:${c.reset}
  ${PKG} on          Activa las notificaciones
  ${PKG} off         Desactiva (sin desinstalar)
  ${PKG} status      Muestra el estado actual
  ${PKG} test        Envía una notificación de prueba
  ${PKG} setup       Instala/repara la configuración
  ${PKG} uninstall   Desinstala y limpia la configuración

${c.bold}Instalación:${c.reset}
  npm install -g ${PKG}

${c.bold}Eventos cubiertos:${c.reset}
  permission_prompt   Claude necesita que autorices una acción
  idle_prompt         Claude lleva 60+ segundos esperando tu respuesta
`);
}
