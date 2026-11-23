import {readFile, writeFile} from 'node:fs/promises';
// Vite library CSS rebases public fonts as if CSS lived in assets/. The native app keeps app.css at the root.
const cssPath = 'apps/web/dist/app.css';
const css = await readFile(cssPath, 'utf8');
await writeFile(cssPath, css.replaceAll('url(../fonts/', 'url(./fonts/'));

await writeFile('apps/web/dist/index.html',`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src https://api.open-meteo.com https://archive-api.open-meteo.com https://geocoding-api.open-meteo.com; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'"><title>Memory Catcher 3</title><link rel="stylesheet" href="./app.css"></head><body><div id="root"></div><script src="./app.js"></script></body></html>`);
