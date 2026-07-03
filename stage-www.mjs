// Stages the web app into www/ for Capacitor. Runs automatically before
// `npx cap copy` / `npx cap sync` via the "capacitor:copy:before" hook in
// package.json. The project root can't be the webDir directly because
// Capacitor would copy node_modules, .git, and the native projects into
// the app bundle.
import { mkdirSync, copyFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const www = join(root, 'www');

const files = [
  'index.html',
  'favicon.svg',
  'affirmations.js',
  'capacitor-init.js',
  'revenuecat-handler.js',
];

rmSync(www, { recursive: true, force: true });
mkdirSync(www, { recursive: true });
for (const f of files) {
  copyFileSync(join(root, f), join(www, f));
  console.log(`staged ${f}`);
}
console.log(`\nwww/ ready for Capacitor (${files.length} files)`);
