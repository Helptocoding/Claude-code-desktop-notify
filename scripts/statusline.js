import fs from 'fs';
import path from 'path';
import os from 'os';
import { PKG } from './lib/constants.js';

const HOME = os.homedir();
const CLAUDE_DIR = path.join(HOME, '.claude');
const HOOKS_DIR = path.join(CLAUDE_DIR, 'hooks');
const SETTINGS_PATH = path.join(CLAUDE_DIR, 'settings.json');
const ACTIVE_FLAG = path.join(CLAUDE_DIR, `.${PKG}-active`);
const STATUSLINE_BACKUP = path.join(CLAUDE_DIR, '.desktop-notify-statusline-prev.cmd');

export function setActiveFlag(active = true) {
  fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  if (active) {
    fs.writeFileSync(ACTIVE_FLAG, 'on\n', 'utf8');
  } else {
    try { fs.unlinkSync(ACTIVE_FLAG); } catch {}
  }
}

function getStatusLineCommand(settings) {
  const sl = settings?.statusLine;
  if (!sl) return null;
  if (typeof sl === 'string') return sl;
  return sl.command ?? null;
}

function isOurStatusLine(cmd) {
  if (typeof cmd !== 'string') return false;
  return cmd.includes('claude-code-desktop-notify-statusline')
    || cmd.includes('desktop-notify-statusline-wrapper');
}

export function installStatusline(pkgRoot, env, log = {}) {
  const ok = log.ok ?? (() => {});
  const info = log.info ?? (() => {});
  const warn = log.warn ?? (() => {});

  const srcBadge = path.join(pkgRoot, 'hooks', env === 'windows' || env === 'wsl' ? 'statusline.ps1' : 'statusline.sh');
  const destBadge = path.join(HOOKS_DIR, `${PKG}-statusline${env === 'windows' || env === 'wsl' ? '.ps1' : '.sh'}`);
  const srcWrapper = path.join(pkgRoot, 'hooks', env === 'windows' || env === 'wsl' ? 'statusline-wrapper.ps1' : 'statusline-wrapper.sh');
  const destWrapper = path.join(HOOKS_DIR, `${PKG}-statusline-wrapper${env === 'windows' || env === 'wsl' ? '.ps1' : '.sh'}`);

  fs.mkdirSync(HOOKS_DIR, { recursive: true });
  fs.copyFileSync(srcBadge, destBadge);
  if (env !== 'windows' && env !== 'wsl') fs.chmodSync(destBadge, 0o755);
  fs.copyFileSync(srcWrapper, destWrapper);
  if (env !== 'windows' && env !== 'wsl') fs.chmodSync(destWrapper, 0o755);

  let settings = {};
  try {
    settings = JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8'));
  } catch {}

  const existing = getStatusLineCommand(settings);
  let hookCommand;

  if (env === 'windows' || env === 'wsl') {
    hookCommand = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${destWrapper}"`;
  } else {
    hookCommand = destWrapper;
  }

  if (existing && !isOurStatusLine(existing)) {
    fs.writeFileSync(STATUSLINE_BACKUP, existing, 'utf8');
    settings.statusLine = { type: 'command', command: hookCommand };
    fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
    ok('Status line: badge [NOTIFY] añadido junto a tu configuración actual');
    info('Reinicia Claude Code para ver el indicador [NOTIFY]');
    return;
  }

  if (existing && isOurStatusLine(existing)) {
    ok('Status line [NOTIFY] ya estaba configurada');
    return;
  }

  settings.statusLine = { type: 'command', command: hookCommand };
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
  ok('Status line: badge [NOTIFY] configurado');
  info('Reinicia Claude Code para ver el indicador en la barra inferior');
}

export function uninstallStatusline(log = {}) {
  const ok = log.ok ?? (() => {});
  const warn = log.warn ?? (() => {});

  try {
    const settings = JSON.parse(fs.readFileSync(SETTINGS_PATH, 'utf8'));
    const cmd = getStatusLineCommand(settings);

    if (cmd && isOurStatusLine(cmd)) {
      if (fs.existsSync(STATUSLINE_BACKUP)) {
        const prev = fs.readFileSync(STATUSLINE_BACKUP, 'utf8').trim();
        if (prev) {
          settings.statusLine = { type: 'command', command: prev };
        } else {
          delete settings.statusLine;
        }
        fs.unlinkSync(STATUSLINE_BACKUP);
        ok('Status line anterior restaurada');
      } else {
        delete settings.statusLine;
        ok('Status line [NOTIFY] eliminada');
      }
      fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
    }
  } catch (e) {
    warn(`No se pudo limpiar status line: ${e.message}`);
  }

  for (const name of [
    `${PKG}-statusline.ps1`,
    `${PKG}-statusline.sh`,
    `${PKG}-statusline-wrapper.ps1`,
    `${PKG}-statusline-wrapper.sh`,
  ]) {
    try { fs.unlinkSync(path.join(HOOKS_DIR, name)); } catch {}
  }

  try { fs.unlinkSync(ACTIVE_FLAG); } catch {}
  try { fs.unlinkSync(STATUSLINE_BACKUP); } catch {}
}
