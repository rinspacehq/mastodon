import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function inventory(root) {
  const files = {};
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const file = path.join(directory, entry.name);
      assert(!entry.isSymbolicLink(), 'Generated assets must not contain symlinks');
      if (entry.isDirectory()) visit(file);
      else {
        assert(entry.isFile());
        const name = path.relative(root, file).split(path.sep).join('/');
        if (name !== 'rinspace-release.json') {
          files[name] = createHash('sha256').update(fs.readFileSync(file)).digest('hex');
        }
      }
    }
  }
  visit(root);
  return Object.fromEntries(Object.entries(files).sort(([a], [b]) => a.localeCompare(b)));
}

export function verify(root, commit) {
  const record = JSON.parse(fs.readFileSync(path.join(root, 'rinspace-release.json')));
  assert.equal(record.schemaVersion, 'rinspace-mastodon-assets/v1');
  assert.equal(record.sourceCommit, commit);
  assert.match(commit, /^[0-9a-f]{40}$/);
  assert.deepEqual(record.files, inventory(root));
  assert(record.files['.vite/manifest.json'], 'Missing Vite manifest');
  assert(record.files['sw.js'], 'Missing service worker');
  assert(Object.keys(record.files).some(name => name.endsWith('.css')));
  assert(Object.keys(record.files).some(name => name.endsWith('.js')));
  return record;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = path.resolve('public/packs');
  const commit = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  if (process.argv[2] === 'build') {
    assert.equal(execFileSync('git', ['status', '--porcelain'], { encoding: 'utf8' }).trim(), '');
    assert(!fs.existsSync(path.join(root, 'rinspace-release.json')), 'Refuse old build output');
    execFileSync(process.execPath, ['node_modules/vite/bin/vite.js', 'build', '--mode', 'production'], {
      stdio: 'inherit',
      env: { PATH: process.env.PATH, HOME: process.env.HOME, TMPDIR: process.env.TMPDIR,
        NODE_ENV: 'production', RAILS_ENV: 'production', NODE_OPTIONS: '--max-old-space-size=1664',
        RAYON_NUM_THREADS: '1', UV_THREADPOOL_SIZE: '1' },
    });
    fs.writeFileSync(path.join(root, 'rinspace-release.json'), JSON.stringify({
      schemaVersion: 'rinspace-mastodon-assets/v1', sourceCommit: commit, files: inventory(root),
    }, null, 2) + '\n', { flag: 'wx' });
  } else assert.equal(process.argv[2], 'verify');
  const record = verify(root, commit);
  console.log(JSON.stringify({ verified: true, sourceCommit: commit, files: Object.keys(record.files).length }));
}
