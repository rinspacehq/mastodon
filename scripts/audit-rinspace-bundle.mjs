import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const packs = process.argv[2] || 'public/packs';
const manifestPath = path.resolve(root, packs, '.vite/manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const entryKey = 'entrypoints/application.ts';
const entry = manifest[entryKey];
if (!entry) throw new Error(`${entryKey} is absent from ${manifestPath}`);

const staticClosure = new Set();
const staticStyles = new Set();
function collect(key) {
  if (staticClosure.has(key) || !manifest[key]) return;
  staticClosure.add(key);
  for (const stylesheet of manifest[key].css || []) {
    staticStyles.add(stylesheet);
  }
  for (const imported of manifest[key].imports || []) collect(imported);
}
collect(entryKey);

const allJavaScript = Object.values(manifest).filter((value) =>
  value.file?.endsWith('.js'),
).length;
const staticJavaScript = [...staticClosure].filter((key) =>
  manifest[key]?.file?.endsWith('.js'),
).length;
// The pre-change production manifest loaded 215 JavaScript files from the
// application entry. The safe vendor-only grouping reduces that closure to
// 202 without merging Sass entrypoints or introducing import cycles. Keep a
// small allowance for upstream drift, while rejecting a return to baseline.
const budget = { staticJavaScript: 210, staticStyles: 25, allJavaScript: 500 };
if (
  staticJavaScript > budget.staticJavaScript ||
  staticStyles.size > budget.staticStyles ||
  allJavaScript > budget.allJavaScript
) {
  throw new Error(
    `Rinspace bundle exceeds request budgets: static-js=${staticJavaScript}/${budget.staticJavaScript}, static-css=${staticStyles.size}/${budget.staticStyles}, all-js=${allJavaScript}/${budget.allJavaScript}`,
  );
}

process.stdout.write(
  `Rinspace bundle audit passed: ${staticJavaScript} startup JavaScript, ${staticStyles.size} startup CSS, ${allJavaScript} total JavaScript files.\n`,
);
