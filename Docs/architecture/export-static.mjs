// Convert the generated diagram SVG into README assets without executing HTML.
// Requires sharp; set WHISPER_SHARP_MODULE if it is outside Node's search path.
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const sharp = require(process.env.WHISPER_SHARP_MODULE || 'sharp');
const directory = path.dirname(fileURLToPath(import.meta.url));

for (const name of ['overview', 'moment-save']) {
  const sourceName = name === 'overview' ? 'overview.architecture.json' : 'moment-save.workflow.json';
  const source = JSON.parse(await fs.readFile(path.join(directory, sourceName), 'utf8'));
  const html = await fs.readFile(path.join(directory, `${name}.html`), 'utf8');
  const stylesheet = [...html.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(match => match[1]).join('\n');
  let svg = html.match(/<svg viewBox="[^"]+"[\s\S]*?<\/svg>/)?.[0];
  if (!svg) throw new Error(`Diagram SVG missing: ${name}`);
  const variables = {};
  for (const selector of [':root,\n    [data-theme="dark"]', '[data-theme="light"]']) {
    const offset = html.indexOf(selector);
    const body = html.slice(html.indexOf('{', offset) + 1, html.indexOf('}', offset));
    for (const [, key, value] of body.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) variables[key] = value.trim();
  }
  const classes = new Set([...svg.matchAll(/class="([^"]+)"/g)].flatMap(match => match[1].split(/\s+/)));
  const rules = [];
  for (const [, selector, body] of stylesheet.matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    const matches = [...selector.matchAll(/\.([a-zA-Z_][\w-]*)/g)].some(match => classes.has(match[1]));
    if ((matches || selector.trim() === 'svg') && !selector.includes('@') && !selector.includes('html[')) {
      rules.push(`${selector}{${body}}`);
    }
  }
  let css = rules.join('\n').replace(/var\((--[\w-]+)(?:,\s*([^)]*))?\)/g, (_, key, fallback) => {
    const value = variables[key] ?? fallback;
    if (!value) throw new Error(`Unresolved CSS variable: ${key}`);
    return value;
  });
  css += '\ntext { font-family: "Apple SD Gothic Neo", "Arial", sans-serif; }';
  svg = svg.replace(/var\((--[\w-]+)\)/g, (_, key) => {
    if (!variables[key]) throw new Error(`Unresolved SVG variable: ${key}`);
    return variables[key];
  });
  const [x, y, width, height] = svg.match(/viewBox="([^"]+)"/)[1].split(' ').map(Number);
  const escapeXml = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  const title = escapeXml(source.meta.title);
  const revision = source.meta.repository.revision.slice(0, 7);
  svg = svg.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ')
    .replace(/viewBox="[^"]+"/, `viewBox="${x} ${y - 58} ${width} ${height + 86}"`)
    .replace(/(<svg[^>]*>)/, `$1<style><![CDATA[${css}]]></style><rect x="${x}" y="${y - 58}" width="${width}" height="${height + 86}" fill="#ffffff"/><text x="40" y="-18" font-size="22" font-weight="700" fill="#111827">${title}</text>`)
    .replace('</svg>', `<text x="40" y="${height + 9}" font-size="11" fill="#5b6474">코드 기준 ${revision} · Archify 생성 · 정적 이미지</text></svg>`);
  await fs.writeFile(path.join(directory, `${name}.svg`), svg);
  await sharp(Buffer.from(svg), { density: 192 }).png().toFile(path.join(directory, `${name}.png`));
  console.log(`Exported ${name}.svg and ${name}.png`);
}
