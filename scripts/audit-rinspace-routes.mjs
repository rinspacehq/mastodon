import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const failures = [];

const innerProductPath = /^\/(?:$|home(?:\/|$)|timelines(?:\/|$)|conversations(?:\/|$)|public(?:\/|$)|tags(?:\/|$)|lists(?:\/|$)|notifications(?:\/|$)|favourites(?:\/|$)|bookmarks(?:\/|$)|pinned(?:\/|$)|directory(?:\/|$)|explore(?:\/|$)|publish(?:\/|$)|profile(?:\/|$)|@[A-Za-z0-9_@.-]+(?:\/|$)|accounts(?:\/|$)|collections(?:\/|$)|statuses(?:\/|$)|follow_requests(?:\/|$)|blocks(?:\/|$)|domain_blocks(?:\/|$)|followed_tags(?:\/|$)|mutes(?:\/|$)|deck(?:\/|$)|settings(?:\/|$)|search(?:\/|$)|web(?:\/|$)|media(?:\/|$)|polls(?:\/|$)|links(?:\/|$)|keyboard-shortcuts(?:\/|$)|overview(?:\/|$)|relationships(?:\/|$)|severed_relationships(?:\/|$)|statuses_cleanup(?:\/|$)|filters(?:\/|$)|invites(?:\/|$)|admin(?:\/|$)|about(?:\/|$)|privacy-policy(?:\/|$)|terms(?:\/|$)|terms-of-service(?:\/|$)|start(?:\/|$))/;

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
  '/search?q=reverse+engineering',
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
  '/relationships',
  '/severed_relationships/42',
  '/statuses_cleanup',
  '/filters/42',
  '/invites',
  '/admin/reports',
  '/privacy-policy',
  '/terms-of-service',
  '/keyboard-shortcuts',
  '/overview',
];

for (const href of representativeClientRoutes) {
  const pathname = new URL(href, 'https://rinspace.invalid').pathname;
  if (!innerProductPath.test(pathname) && !/^\/p\/\d+/.test(pathname)) {
    failures.push(`${href} is missing from the private Mastodon route fixture`);
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
