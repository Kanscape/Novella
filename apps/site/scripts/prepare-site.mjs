import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scripts = [
  'fetch-site-data.mjs',
  'generate-announcements.mjs',
  'generate-repository.mjs',
  'generate-sitemap.mjs',
];
const scriptsDirectory = fileURLToPath(new URL('.', import.meta.url));

for (const script of scripts) {
  await run(script);
}

function run(script) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [`${scriptsDirectory}${script}`], {
      env: process.env,
      stdio: 'inherit',
    });
    child.on('error', reject);
    child.on('exit', (code, signal) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${script} exited with ${code ?? signal}`));
    });
  });
}
