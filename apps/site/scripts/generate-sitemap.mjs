import { mkdir, writeFile } from 'node:fs/promises';

const siteUrl = (process.env.SITE_URL || 'https://novella.celia.sh').replace(/\/$/, '');
const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${['/', '/download'].map((path) => `  <url><loc>${siteUrl}${path}</loc></url>`).join('\n')}\n</urlset>\n`;
await mkdir('public', { recursive: true });
await writeFile('public/sitemap.xml', xml, 'utf8');
