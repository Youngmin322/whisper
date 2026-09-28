const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = __dirname;

const items = [
  ['joy', '기쁨', '따뜻하게 웃는 대표 캐릭터'],
  ['anxiety', '불안', '휘어진 끝 · 걱정스러운 표정'],
  ['depression', '우울', '처진 끝 · 무거워진 눈꺼풀'],
  ['anger', '분노', '솟은 불꽃 · 단호한 눈썹'],
  ['sadness', '슬픔', '처진 불꽃 · 눈물 한 방울'],
  ['calm', '평온', '편안히 감은 눈 · 작은 미소'],
];

async function main() {
  for (const [slug] of items) {
    fs.copyFileSync(path.join(root, 'Approved', `${slug}.png`), path.join(root, `${slug}.png`));
  }

  const cards = items.map(([slug, label, caption], i) => {
    const x = 60 + (i % 3) * 368;
    const y = 144 + Math.floor(i / 3) * 412;
    const b64 = fs.readFileSync(path.join(root, `${slug}.png`)).toString('base64');
    return `<g transform="translate(${x} ${y})">
      <rect width="344" height="388" rx="24" fill="#FFFDFA" stroke="#EDE7DF"/>
      <image x="35.5" y="21" width="273" height="273" href="data:image/png;base64,${b64}"/>
      <text x="172" y="325" text-anchor="middle" font-size="25" font-weight="600" fill="#29252A">${label}</text>
      <text x="172" y="355" text-anchor="middle" font-size="15" fill="#77716D">${caption}</text>
    </g>`;
  }).join('\n');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1000" viewBox="0 0 1200 1000">
    <rect width="1200" height="1000" fill="#FAF7F1"/>
    <g font-family="Apple SD Gothic Neo, Noto Sans KR, sans-serif">
      <text x="60" y="66" font-size="34" font-weight="700" fill="#29252A">마음의 불꽃들</text>
      <text x="60" y="105" font-size="17" fill="#77716D">한 캐릭터씩 확인하고 확정한 감정 불꽃 세트</text>
      ${cards}
    </g>
  </svg>`;
  fs.writeFileSync(path.join(root, 'character-sheet.svg'), svg);
  await sharp(Buffer.from(svg)).png().toFile(path.join(root, 'character-sheet.png'));
  console.log('Preserved 6 original PNGs and rendered the approved character sheet.');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
