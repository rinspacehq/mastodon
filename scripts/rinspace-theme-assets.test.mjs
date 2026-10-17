import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { inventory, verify } from './rinspace-theme-assets.mjs';

test('fixed assets inventory rejects drift, missing files and wrong source', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mastodon-theme-test-'));
  try {
    fs.mkdirSync(path.join(root, '.vite'));
    for (const name of ['.vite/manifest.json', 'sw.js', 'application.js', 'theme.css']) {
      fs.writeFileSync(path.join(root, name), '{}');
    }
    const commit = 'a'.repeat(40);
    fs.writeFileSync(path.join(root, 'rinspace-release.json'), JSON.stringify({
      schemaVersion: 'rinspace-mastodon-assets/v1', sourceCommit: commit, files: inventory(root),
    }));
    assert.equal(verify(root, commit).sourceCommit, commit);
    assert.throws(() => verify(root, 'b'.repeat(40)));
    fs.writeFileSync(path.join(root, 'theme.css'), 'tampered');
    assert.throws(() => verify(root, commit));
    fs.unlinkSync(path.join(root, 'sw.js'));
    assert.throws(() => verify(root, commit));
  } finally { fs.rmSync(root, { recursive: true }); }
});

test('generated symlinks are rejected', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mastodon-theme-test-'));
  try {
    fs.symlinkSync('/etc/passwd', path.join(root, 'bad'));
    assert.throws(() => inventory(root));
  } finally { fs.rmSync(root, { recursive: true }); }
});
