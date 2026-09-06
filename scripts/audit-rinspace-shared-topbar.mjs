import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const sourcePath = new URL(
  '../app/javascript/rinspace_shared/RinspaceTopbarFrame.tsx',
  import.meta.url,
);
const manifestPath = new URL(
  '../app/javascript/rinspace_shared/provenance.json',
  import.meta.url,
);
const brandAssetPath = new URL(
  '../app/javascript/images/rinspace-mark-128.png',
  import.meta.url,
);
const source = await readFile(sourcePath);
const brandAsset = await readFile(brandAssetPath);
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
const actual = createHash('sha256').update(source).digest('hex');
const actualBrandAsset = createHash('sha256').update(brandAsset).digest('hex');
const sourceMarker =
  '// RINSPACE_SHARED_SOURCE: edit only in rinspace/ui, then run the one-way sync.';

if (
  manifest.generated !== true ||
  !source.toString('utf8').startsWith(sourceMarker) ||
  manifest.sha256 !== actual ||
  manifest.brandAssetSha256 !== actualBrandAsset
) {
  throw new Error(
    `Rinspace shared topbar provenance mismatch: expected ${manifest.sha256}, received ${actual}`,
  );
}

process.stdout.write(`Rinspace shared topbar verified: ${actual}\n`);
