const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const readJson = (name) => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));

// Sort object keys recursively so formatting/key order changes do not rebuild.
function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

try {
  const pkg = readJson('package.json');
  const lock = readJson('package-lock.json');
  // Conservatively include dev dependencies: they can supply config plugins.
  // Ignore scripts and other unrelated package metadata.
  const direct = { ...pkg.devDependencies, ...pkg.dependencies, ...pkg.optionalDependencies };
  const dependencies = Object.fromEntries(Object.entries(direct).map(([name, requested]) => {
    const entry = lock.packages?.[`node_modules/${name}`] ?? lock.dependencies?.[name];
    if (!entry?.version) throw new Error(`Missing locked version for ${name}; run npm install.`);
    return [name, { requested, resolved: entry.version }];
  }));
  // This intentionally does not inspect transitive dependencies, asset contents,
  // environment variables, or manual native edits. Use dev:native for those.
  const inputs = { version: 1, app: readJson('app.json'), dependencies };
  const fingerprint = crypto.createHash('sha256')
    .update(JSON.stringify(canonicalize(inputs))).digest('hex');
  process.stdout.write(`${fingerprint}\n`);
} catch (error) {
  console.error(`Cannot calculate native fingerprint: ${error.message}`);
  process.exitCode = 1;
}
