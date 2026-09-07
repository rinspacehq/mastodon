import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repositoryRoot = path.resolve(
  path.dirname(new URL(import.meta.url).pathname),
  '..',
);
const packageJson = JSON.parse(
  fs.readFileSync(path.join(repositoryRoot, 'package.json'), 'utf8'),
);
const provenance = JSON.parse(
  fs.readFileSync(
    path.join(repositoryRoot, 'app/javascript/rinspace_shared/provenance.json'),
    'utf8',
  ),
);
const entryPath = path.join(
  repositoryRoot,
  'app/javascript/mastodon/features/compose/redesign/index.tsx',
);
const hostStylesPath = path.join(
  repositoryRoot,
  'app/javascript/mastodon/features/compose/redesign/rinspace_shared.module.scss',
);
const composerPath = path.join(
  repositoryRoot,
  'app/javascript/rinspace_shared/RinspaceTweetComposer.tsx',
);
const composerStylesPath = path.join(
  repositoryRoot,
  'app/javascript/rinspace_shared/rinspace-tweet-composer.css',
);
const entry = fs.readFileSync(entryPath, 'utf8');
const hostStyles = fs.readFileSync(hostStylesPath, 'utf8');

function sha256(file) {
  return crypto
    .createHash('sha256')
    .update(fs.readFileSync(file))
    .digest('hex');
}

for (const retiredDependency of [
  '@rinspace/tweet-composer',
  '@rinspace/world-shell',
]) {
  if (packageJson.dependencies[retiredDependency]) {
    throw new Error(
      `retired public dependency is forbidden: ${retiredDependency}`,
    );
  }
}
if (
  provenance.generated !== true ||
  provenance.sourceRepository !== 'rinspacehq/rinspace' ||
  !provenance.composer ||
  sha256(composerPath) !== provenance.composer.sha256 ||
  sha256(composerStylesPath) !== provenance.composer.styleSha256
) {
  throw new Error('shared composer does not match private-source provenance');
}
if (
  !entry.includes("from '@/rinspace_shared/RinspaceTweetComposer'") ||
  !entry.includes("import '@/rinspace_shared/rinspace-tweet-composer.css'")
) {
  throw new Error(
    'Mastodon composer entry does not render the generated private source',
  );
}
for (const forbiddenImport of [
  './attachments',
  './footer',
  './textarea',
  './visibility',
  './poll',
  './emoji',
]) {
  if (entry.includes(`from '${forbiddenImport}'`)) {
    throw new Error(
      `Mastodon composer entry imports duplicate UI module ${forbiddenImport}`,
    );
  }
}
if (/\b(button|textarea|select|input)\b\s*[{,]/u.test(hostStyles)) {
  throw new Error(
    'host composer stylesheet must only map layout and design tokens',
  );
}

process.stdout.write(
  `${JSON.stringify(
    {
      sourceRepository: provenance.sourceRepository,
      sourceCommit: provenance.sourceCommit,
      sourcePath: provenance.composer.sourcePath,
      sha256: provenance.composer.sha256,
      styleSha256: provenance.composer.styleSha256,
    },
    null,
    2,
  )}\n`,
);
