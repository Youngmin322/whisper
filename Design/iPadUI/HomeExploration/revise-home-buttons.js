/* Figma discussion revision. User chose icon + label, usually uses iPad on a desk.
 * Right alignment and primary styling remain a proposal for visual review.
 * Requires HOME_ASSETS from home-assets.js. No application code is changed.
 */
(async () => { try {
  const root = await figma.getNodeByIdAsync('10609:2000');
  const footer = await figma.getNodeByIdAsync('10609:2022');
  const row = await figma.getNodeByIdAsync('10609:2023');
  const collect = await figma.getNodeByIdAsync('10609:2024');
  const record = await figma.getNodeByIdAsync('10609:2030');
  const plus = await figma.getNodeByIdAsync('10609:2031');
  const indicator = await figma.getNodeByIdAsync('10609:2032');
  const area = await figma.getNodeByIdAsync('10609:2021');
  if (!root || row?.parent?.id !== footer?.id || collect?.parent?.id !== row?.id || record?.parent?.id !== row?.id || plus?.parent?.id !== record?.id) throw new Error('Expected existing home controls are missing.');
  for (const text of root.findAllWithCriteria({types:['TEXT']})) {
    const fonts = text.fontName === figma.mixed ? text.getRangeAllFontNames(0,text.characters.length) : [text.fontName];
    for (const font of fonts) await figma.loadFontAsync(font);
  }
  const font = {family:'Noto Sans KR',style:'Medium'};
  await figma.loadFontAsync(font);
  const variables = await figma.variables.getLocalVariablesAsync();
  const byId = new Map(variables.map(v=>[v.id,v]));
  const colorIds = {text:'VariableID:1388:10244', secondary:'VariableID:1388:10245',accent:'VariableID:1388:10242',border:'VariableID:1388:10253',paper:'VariableID:1388:10248'};
  function paint(key, opacity=1) {
    const variable = byId.get(colorIds[key]);
    if (!variable) throw new Error('Existing app color missing: '+key);
    return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:1,g:1,b:1},opacity},'color',variable);
  }
  const style = (await figma.getLocalTextStylesAsync()).find(s=>s.name==='Whisper iPad/control');
  if (!style) throw new Error('Existing control text style missing.');
  const created = [], mutated = [footer.id,row.id,collect.id,record.id,plus.id,indicator.id], removed = [];
  async function addLabel(button, value, key) {
    let text = button.children.find(n=>n.name==='Action label' && n.type==='TEXT');
    if (!text) {text=figma.createText();button.appendChild(text);created.push(text.id);} else mutated.push(text.id);
    text.name='Action label';text.fontName=font;text.characters=value;
    await text.setTextStyleIdAsync(style.id);
    text.fontSize=16;text.lineHeight={unit:'PIXELS',value:24};text.textAutoResize='WIDTH_AND_HEIGHT';text.fills=[paint(key)];
    return text;
  }
  const collectLabel=await addLabel(collect,'병에 담기','secondary');
  const recordLabel=await addLabel(record,'순간 남기기','paper');
  let bottle=collect.children.find(n=>n.name==='App asset / BottleLineIcon · original colors');
  if (!bottle) {
    for (const old of collect.children.filter(n=>n.type!=='TEXT')) {removed.push(old.id,...old.findAll().map(n=>n.id));old.remove();}
    bottle=figma.createNodeFromSvg(HOME_ASSETS.bottle);collect.insertChild(0,bottle);bottle.name='App asset / BottleLineIcon · original colors';bottle.resize(20,24);created.push(bottle.id,...bottle.findAll().map(n=>n.id));
  }
  const whitePlus=figma.createImage(figma.base64Decode(HOME_ASSETS.symbols.plusWhite));
  plus.fills=[{type:'IMAGE',imageHash:whitePlus.hash,scaleMode:'FIT'}];plus.resize(18,18);
  for (const [button,label,icon] of [[collect,collectLabel,bottle],[record,recordLabel,plus]]) {
    button.layoutMode='HORIZONTAL';button.primaryAxisSizingMode='FIXED';button.counterAxisSizingMode='FIXED';button.paddingLeft=button.paddingRight=16;button.paddingTop=button.paddingBottom=0;button.itemSpacing=8;button.primaryAxisAlignItems='CENTER';button.counterAxisAlignItems='CENTER';button.cornerRadius=24;button.resize(Math.ceil(32+icon.width+8+label.width),48);
  }
  collect.name='병에 담기 · icon + label · 48 pt';record.name='순간 남기기 · primary · icon + label · 48 pt';
  collect.fills=[paint('paper',.9)];collect.strokes=[paint('border',.7)];collect.strokeWeight=.5;
  record.fills=[paint('accent')];record.strokes=[];
  row.name='Home actions · trailing alignment proposal';row.itemSpacing=12;row.resize(collect.width+12+record.width,48);row.primaryAxisSizingMode='AUTO';row.counterAxisSizingMode='FIXED';row.counterAxisAlignItems='CENTER';
  footer.name='Home bottom actions · desk / stand proposal';footer.counterAxisAlignItems='MAX';footer.paddingRight=32;footer.paddingLeft=32;footer.paddingTop=16;
  indicator.layoutPositioning='ABSOLUTE';indicator.x=(footer.width-indicator.width)/2;indicator.y=99;
  const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:mutated,removedNodeIds:removed,allFrameNodeIds:[root.id,...root.findAll().map(n=>n.id)],agreed:{usage:'desk or stand',buttonLabels:'icon + text',homeFlow:'home to archive; no global tabs',flames:'independent movement within broad bounded area'},proposed:{alignment:'bottom trailing, 32 pt inset',priority:'record primary; collect secondary',buttonHeight:48,labelFont:'Noto Sans KR / Medium / 16',buttonGap:12},controls:[collect,record].map(n=>({id:n.id,name:n.name,width:n.width,height:n.height,label:n.children.find(c=>c.type==='TEXT').characters})),activityArea:{id:area.id,width:area.width,height:area.height},appCodeChanged:false,cloudSyncVerified:false};
  if(area.width!==940 || area.height!==484 || collect.height<44 || record.height<44)throw new Error('Layout verification failed.');
  figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
  figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:#fdfbf6;color:#3e3530}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 기록 버튼 논의안</h3><p>아이콘 + 이름 · 순간 남기기 강조 · 하단 오른쪽 배치 제안<br>앱 소스는 변경하지 않았습니다.</p><button id="preview">버튼 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-buttons-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-buttons.png','image/png')};</script>`,{width:740,height:360});
  figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return;}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
} catch(error) {figma.showUI('<pre>'+String(error)+'\n'+error.stack+'</pre>',{width:740,height:360});}})();
