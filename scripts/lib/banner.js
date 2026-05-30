import { CREDITS, PKG } from './constants.js';
import fs from 'fs';

// npm suprime stdout y stderr en postinstall — escribir directo al terminal
let ttyFd = -1;
try {
  const ttyDev = process.platform === 'win32' ? 'CON' : '/dev/tty';
  ttyFd = fs.openSync(ttyDev, 'w');
} catch {}

function ttyWrite(msg = '') {
  const line = msg + '\n';
  if (ttyFd >= 0) {
    try { fs.writeSync(ttyFd, line); return; } catch {}
  }
  process.stderr.write(line);
}

export function printInstallBanner(c) {
  const line = '─'.repeat(52);
  ttyWrite('');
  ttyWrite(`${c.cyan}${line}${c.reset}`);
  ttyWrite(`  ${c.green}✔${c.reset} ${c.bold}${PKG}${c.reset} listo`);
  ttyWrite(`${c.cyan}${line}${c.reset}`);
  ttyWrite('');
  ttyWrite(`  Ahora Claude Code te avisará cuando necesite`);
  ttyWrite(`  tu atención — sin que tengas que estar mirando`);
  ttyWrite(`  la terminal todo el tiempo.`);
  ttyWrite('');
  ttyWrite(`  ${c.bold}Pruébalo:${c.reset}  ${c.cyan}${PKG} test${c.reset}`);
  ttyWrite(`  ${c.bold}Silenciar:${c.reset} ${c.cyan}${PKG} off${c.reset}  /  ${c.cyan}${PKG} on${c.reset} para reactivar`);
  ttyWrite('');
  ttyWrite(`  ${c.yellow}⭐ Si te es útil:${c.reset} ${c.dim}${CREDITS.projectUrl}${c.reset}`);
  ttyWrite(`  ${c.dim}by ${CREDITS.author}${c.reset}`);
  ttyWrite(`${c.cyan}${line}${c.reset}`);
  ttyWrite('');
}
