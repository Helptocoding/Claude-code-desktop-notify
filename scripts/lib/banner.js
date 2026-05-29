import { CREDITS, PKG } from './constants.js';

export function printInstallBanner(c) {
  const line = '─'.repeat(52);
  console.log('');
  console.log(`${c.cyan}${line}${c.reset}`);
  console.log(`${c.bold}  ${PKG}${c.reset} instalado correctamente`);
  console.log(`${c.cyan}${line}${c.reset}`);
  console.log('');
  console.log(`  ${c.bold}Creado por:${c.reset} ${CREDITS.author}`);
  console.log(`  ${c.dim}GitHub:${c.reset}  ${CREDITS.projectUrl}`);
  console.log('');
  console.log(`  ${c.bold}Indicador en Claude Code:${c.reset} ${c.cyan}[NOTIFY]${c.reset} (barra inferior)`);
  console.log('');
  console.log(`  ${c.bold}Comandos:${c.reset}`);
  console.log(`    ${c.cyan}${PKG} test${c.reset}   — probar notificación + sonido`);
  console.log(`    ${c.cyan}${PKG} off${c.reset}    — silenciar (quita badge y alertas)`);
  console.log(`    ${c.cyan}${PKG} on${c.reset}     — reactivar`);
  console.log('');
  console.log(`  ${c.yellow}Reinicia Claude Code${c.reset} para ver el badge [NOTIFY].`);
  console.log(`${c.cyan}${line}${c.reset}`);
  console.log('');
}
