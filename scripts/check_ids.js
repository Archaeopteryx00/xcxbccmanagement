import fs from 'node:fs';
const html = fs.readFileSync('index.html', 'utf8');

const regex = /document\.getElementById\(['"]([^'"]+)['"]\)/g;
let match;
const usedIds = new Set();
while ((match = regex.exec(html)) !== null) {
  usedIds.add(match[1]);
}

console.log('Total getElementById IDs found in script:', usedIds.size);
const missing = [];
for (const id of usedIds) {
  const pattern = new RegExp(`id=["']${id}["']`);
  if (!pattern.test(html)) {
    missing.push(id);
  }
}

console.log('Missing IDs (' + missing.length + '):');
missing.forEach(id => console.log(' - ' + id));
