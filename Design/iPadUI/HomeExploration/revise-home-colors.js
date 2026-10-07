/* One-screen color proposal, after the user rejected the warm overall palette.
 * Reuses local neutral color variables without changing their definitions.
 * Icon + label and desk usage are confirmed. Neutral styling is for discussion.
 */
(async()=>{try{
const root=await figma.getNodeByIdAsync('10609:2000');
const collect=await figma.getNodeByIdAsync('10609:2024');
const record=await figma.getNodeByIdAsync('10609:2030');
const date=await figma.getNodeByIdAsync('10609:2010');
const underline=date?.children.find(n=>n.name==='Original date highlight');
const area=await figma.getNodeByIdAsync('10609:2021');
if(!root||!collect||!record||!area||underline?.name!=='Original date highlight')throw new Error('Expected existing home proposal missing.');
const vars=await figma.variables.getLocalVariablesAsync();const byId=new Map(vars.map(v=>[v.id,v]));
const tokenIds={background:'VariableID:1388:10249',ink:'VariableID:477:7245',secondary:'VariableID:477:7248',onPrimary:'VariableID:1388:10246'};
function paint(key,opacity=1){const v=byId.get(tokenIds[key]);if(!v)throw new Error('Existing neutral variable missing: '+key);return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0},opacity},'color',v);}
const mutated=[root.id,collect.id,record.id,underline.id],created=[];
for(const text of root.findAllWithCriteria({types:['TEXT']})){
  const fonts=text.fontName===figma.mixed?text.getRangeAllFontNames(0,text.characters.length):[text.fontName];
  for(const font of fonts)await figma.loadFontAsync(font);
  const key=text.parent?.id===record.id?'onPrimary':text.parent?.id==='10609:2001'?'secondary':'ink';
  text.fills=[paint(key)];mutated.push(text.id);
}
root.fills=[paint('background')];underline.visible=false;
collect.fills=[paint('background')];collect.strokes=[paint('ink',.16)];collect.strokeWeight=.7;collect.effects=[];
record.fills=[paint('ink')];record.strokes=[];record.effects=[];
const indicator=await figma.getNodeByIdAsync('10609:2032');indicator.fills=[paint('ink')];mutated.push(indicator.id);
for(const [id,key]of [['10609:2009','gearshapeNeutral'],['10609:2004','wifiNeutral'],['10609:2006','batteryNeutral']]){
  const n=await figma.getNodeByIdAsync(id);if(!n||n.type!=='RECTANGLE')throw new Error('Expected native symbol missing: '+id);
  const hash=figma.createImage(figma.base64Decode(HOME_ASSETS.symbols[key])).hash;n.fills=[{type:'IMAGE',imageHash:hash,scaleMode:'FIT'}];mutated.push(n.id);
}
for(const button of [collect,await figma.getNodeByIdAsync('10609:2013')]){
  for(const n of button.findAll())if('strokes'in n&&Array.isArray(n.strokes)&&n.strokes.some(p=>p.type==='SOLID')){n.strokes=[paint('ink')];mutated.push(n.id);}
}
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:[...new Set(mutated)],allFrameNodeIds:[root.id,...root.findAll().map(n=>n.id)],colorVariableIds:tokenIds,existingColorVariablesModified:[],agreed:{buttonLabels:'icon + text',usage:'desk or stand',flames:'independent movement within broad bounded area'},proposed:{palette:'white background, monochrome controls, original colorful flames',alignment:'bottom trailing',primary:'record in dark ink',decoration:'no date highlight or button shadows'},flameCount:area.children.length,activityArea:{id:area.id,width:area.width,height:area.height},controls:[collect,record].map(n=>({id:n.id,width:n.width,height:n.height,label:n.children.find(c=>c.type==='TEXT')?.characters})),appCodeChanged:false,cloudSyncVerified:false};
if(area.width!==940||area.height!==484||area.children.length!==5||collect.height!==48||record.height!==48)throw new Error('Layout changed unexpectedly.');
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 무채색 비교안</h3><p>흰 배경 · 무채색 글자와 버튼 · 기존 불꽃 색 유지<br>색감과 하단 오른쪽 배치는 논의안입니다. 앱 소스는 변경하지 않았습니다.</p><button id="preview">무채색 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-neutral-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-neutral.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
