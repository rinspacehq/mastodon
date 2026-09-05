import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function option(name) {
  const index = process.argv.indexOf(name);
  if (index < 0 || !process.argv[index + 1]) throw new Error(`${name} is required`);
  return process.argv[index + 1];
}

const releaseDirectory = path.resolve(option('--release'));
const manifestPath = path.join(releaseDirectory, 'world-release-manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const archive = `rinspace-world-shell-${manifest.shellVersion}.tgz`;

if (!manifest.artifacts?.[archive]) throw new Error('world-shell archive is absent from the release manifest');
if (!/^0\.1\.\d+$/.test(manifest.shellVersion)) throw new Error(`unsupported world-shell ${manifest.shellVersion}`);
if (manifest.contractVersion !== '1.0.0') throw new Error(`unsupported world contract ${manifest.contractVersion}`);
if (manifest.source.dirty && !process.argv.includes('--allow-dirty')) {
  throw new Error('formal Mastodon consumption refuses a dirty world release');
}

const source = path.join(releaseDirectory, archive);
const actualSha256 = sha256(source);
if (actualSha256 !== manifest.artifacts[archive]?.sha256) {
  throw new Error('world-shell archive checksum does not match the release manifest');
}

const repositoryRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const vendorDirectory = path.join(repositoryRoot, 'vendor/rinspace');
const destination = path.join(vendorDirectory, archive);
fs.mkdirSync(vendorDirectory, { recursive: true });
fs.copyFileSync(source, destination);

const packagePath = path.join(repositoryRoot, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
packageJson.dependencies['@rinspace/world-shell'] = `file:vendor/rinspace/${archive}`;
fs.writeFileSync(packagePath, `${JSON.stringify(packageJson, null, 2)}\n`);

fs.writeFileSync(
  path.join(repositoryRoot, 'config/rinspace-world-release.lock.json'),
  `${JSON.stringify({
    schemaVersion: 1,
    shell: { name: '@rinspace/world-shell', version: manifest.shellVersion, file: `vendor/rinspace/${archive}`, sha256: actualSha256 },
    contractVersion: manifest.contractVersion,
    source: manifest.source,
  }, null, 2)}\n`,
);

process.stdout.write(`${JSON.stringify({
  archive: destination,
  dependency: packageJson.dependencies['@rinspace/world-shell'],
  sha256: actualSha256,
  source: manifest.source,
}, null, 2)}\n`);
