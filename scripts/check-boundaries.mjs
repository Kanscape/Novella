import { readdir, readFile } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const packagesRoot = join(root, 'packages');
const platformImports = new Set([
  'electron',
  'expo',
  'react',
  'react-dom',
  'react-native',
]);

const allowedWorkspaceDependencies = {
  'api-client': new Set(['platform-contracts']),
  'client-core': new Set([
    'api-client',
    'platform-contracts',
    'reader-engine',
  ]),
  'platform-contracts': new Set(),
  'reader-engine': new Set(),
};

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await sourceFiles(path)));
    } else if (['.ts', '.tsx'].includes(extname(entry.name))) {
      files.push(path);
    }
  }

  return files;
}

function importedModules(source) {
  const modules = [];
  const pattern = /\b(?:from\s+|import\s*\()(['"])([^'"]+)\1/g;

  for (const match of source.matchAll(pattern)) {
    modules.push(match[2]);
  }

  return modules;
}

const violations = [];

for (const [packageName, allowedDependencies] of Object.entries(
  allowedWorkspaceDependencies,
)) {
  const directory = join(packagesRoot, packageName, 'src');

  for (const file of await sourceFiles(directory)) {
    const source = await readFile(file, 'utf8');

    for (const importedModule of importedModules(source)) {
      const topLevelModule = importedModule.startsWith('@')
        ? importedModule.split('/').slice(0, 2).join('/')
        : importedModule.split('/')[0];

      if (
        platformImports.has(topLevelModule) ||
        topLevelModule.startsWith('expo-') ||
        topLevelModule.startsWith('node:')
      ) {
        violations.push(
          `${relative(root, file)} imports platform module "${importedModule}"`,
        );
      }

      if (importedModule.startsWith('@novella/')) {
        const dependencyName = importedModule.slice('@novella/'.length).split('/')[0];
        if (!allowedDependencies.has(dependencyName)) {
          violations.push(
            `${relative(root, file)} imports disallowed workspace package "${importedModule}"`,
          );
        }
      }
    }
  }
}

if (violations.length > 0) {
  console.error(violations.join('\n'));
  process.exitCode = 1;
} else {
  console.log('Shared package boundaries are valid.');
}
