import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { resolveWorld } from '@rinspace/world-shell';

const root = path.resolve(import.meta.dirname, '..');
const failures = [];

const representativeClientRoutes = [
  '/?world=inner',
  '/home',
  '/timelines/home',
  '/conversations',
  '/public',
  '/public/local',
  '/tags/books?world=inner',
  '/lists/42',
  '/notifications',
  '/notifications/requests/42',
  '/favourites',
  '/bookmarks',
  '/pinned',
  '/directory',
  '/explore',
  '/publish',
  '/profile/edit',
  '/@alice?world=inner',
  '/@alice/with_replies',
  '/@alice/media',
  '/@alice/featured',
  '/@alice/collections',
  '/@alice/tagged/books',
  '/accounts/42/followers',
  '/collections/42',
  '/p/42',
  '/p/42/readable-post',
  '/statuses/42/favourites',
  '/follow_requests',
  '/blocks',
  '/domain_blocks',
  '/followed_tags',
  '/mutes',
  '/deck/getting-started',
];

for (const href of representativeClientRoutes) {
  const resolution = resolveWorld(href);
  if (resolution.runtime !== 'mastodon') {
    failures.push(
      `${href} resolves to ${resolution.runtime ?? 'no runtime'} via ${resolution.route?.id ?? 'no route'}`,
    );
  }
}

const sourceRoot = path.join(root, 'app/javascript/mastodon');
const sourceExtensions = new Set(['.js', '.jsx', '.ts', '.tsx']);

function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
  });
}

for (const file of walk(sourceRoot)) {
  if (!sourceExtensions.has(path.extname(file)) || file.endsWith('.test.ts')) continue;
  const source = fs.readFileSync(file, 'utf8');
  if (/\/@\$\{[^}]+\}\/\$\{[^}]+(?:id|status)[^}]*\}/i.test(source)) {
    failures.push(
      `${path.relative(root, file)} still generates an upstream /@handle/:statusId URL`,
    );
  }
}

const cachingSource = fs.readFileSync(
  path.join(sourceRoot, 'service_worker/caching.ts'),
  'utf8',
);
if (!cachingSource.includes("INNER_WORLD_ROOT = '/?world=inner'")) {
  failures.push('Service Worker does not declare the explicit inner-world root');
}
if (!cachingSource.includes('url.origin !== self.location.origin')) {
  failures.push('Service Worker cache is not restricted to same-origin assets');
}

const railsRoutes = fs.readFileSync(path.join(root, 'config/routes.rb'), 'utf8');
for (const marker of [
  "get '/p/:id'",
  "get '/p/:id/:slug'",
  "to: 'application#raise_not_found'",
]) {
  if (!railsRoutes.includes(marker)) failures.push(`Rails routes are missing: ${marker}`);
}

if (failures.length > 0) {
  process.stderr.write(`${failures.map((item) => `- ${item}`).join('\n')}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(
    `Rinspace route audit passed: ${representativeClientRoutes.length} client routes, no legacy status generators.\n`,
  );
}
