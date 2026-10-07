/* Requested home mockup: collect beneath the date, record at bottom center.
 * Reuses the current neutral discussion frame and existing app artwork.
 * The Figma controls are static; native button rendering is implemented later.
 */
(async()=>{try{
const root=await figma.getNodeByIdAsync('10609:2000');
const header=await figma.getNodeByIdAsync('10609:2007');
const date=await figma.getNodeByIdAsync('10609:2010');
const field=await figma.getNodeByIdAsync('10609:2020');
const area=await figma.getNodeByIdAsync('10609:2021');
const footer=await figma.getNodeByIdAsync('10609:2022');
const row=await figma.getNodeByIdAsync('10609:2023');
const collect=await figma.getNodeByIdAsync('10609:2024');
const record=await figma.getNodeByIdAsync('10609:2030');
if(!root||header?.parent?.id!==root.id||field?.parent?.id!==root.id||area?.parent?.id!==field.id||footer?.parent?.id!==root.id||record?.parent?.id!==row?.id)throw new Error('Expected existing home proposal is missing.');
if(area.width!==940||area.height!==484||area.children.length!==5)throw new Error('Unexpected flame field state.');
for(const text of root.findAllWithCriteria({types:['TEXT']})){
 const fonts=text.fontName===figma.mixed?text.getRangeAllFontNames(0,text.characters.length):[text.fontName];
 for(const font of fonts)await figma.loadFontAsync(font);
}
const controlStyle=(await figma.getLocalTextStylesAsync()).find(s=>s.name==='Whisper iPad/control');
if(!controlStyle)throw new Error('Existing Whisper control text style is missing.');
const created=[],mutated=[root.id,header.id,date.id,field.id,footer.id,row.id,collect.id,record.id];
let dateStack=header.children.find(n=>n.name==='Today date and collection action');
if(!dateStack){dateStack=figma.createFrame();header.insertChild(1,dateStack);dateStack.name='Today date and collection action';created.push(dateStack.id);}
else mutated.push(dateStack.id);
dateStack.fills=[];dateStack.clipsContent=false;dateStack.layoutMode='VERTICAL';dateStack.resize(date.width,90);dateStack.primaryAxisSizingMode='AUTO';dateStack.counterAxisSizingMode='FIXED';dateStack.counterAxisAlignItems='CENTER';dateStack.itemSpacing=4;
if(date.parent?.id!==dateStack.id)dateStack.appendChild(date);
if(collect.parent?.id!==dateStack.id)dateStack.appendChild(collect);
collect.name='병에 담기 · quiet action below date';collect.fills=[];collect.strokes=[];collect.effects=[];collect.cornerRadius=22;collect.paddingLeft=collect.paddingRight=12;collect.itemSpacing=6;
const collectLabel=collect.children.find(n=>n.type==='TEXT');
const bottle=collect.children.find(n=>n.name==='App asset / BottleLineIcon · original colors');
if(!collectLabel||!bottle)throw new Error('Existing collection icon and label are missing.');
await collectLabel.setTextStyleIdAsync(controlStyle.id);
collectLabel.textAutoResize='WIDTH_AND_HEIGHT';
bottle.rescale(16/bottle.width);
collect.resize(Math.ceil(24+bottle.width+6+collectLabel.width),44);
mutated.push(collectLabel.id,bottle.id,...bottle.findAll().map(n=>n.id));
header.name='Home toolbar · date with day collection action';header.resize(1194,112);header.counterAxisAlignItems='MIN';header.paddingTop=8;header.paddingBottom=8;
field.resize(1194,556);field.primaryAxisAlignItems='MIN';field.paddingTop=28;field.paddingBottom=0;
row.name='Primary recording action · bottom center';row.resize(record.width,48);row.primaryAxisSizingMode='AUTO';row.counterAxisSizingMode='FIXED';row.itemSpacing=0;
footer.name='Home bottom action · centered recording';footer.counterAxisAlignItems='CENTER';footer.paddingLeft=footer.paddingRight=32;footer.paddingTop=16;
record.name='순간 남기기 · centered primary action';
const bounds=n=>{const b=n.absoluteBoundingBox;const r=root.absoluteBoundingBox;return{x:Math.round((b.x-r.x)*100)/100,y:Math.round((b.y-r.y)*100)/100,width:Math.round(b.width*100)/100,height:Math.round(b.height*100)/100};};
const activity=bounds(area),collection=bounds(collect),recording=bounds(record);
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:[...new Set(mutated)],allFrameNodeIds:[root.id,...root.findAll().map(n=>n.id)],requestedLayout:{settings:'top leading',date:'top center',archive:'top trailing',collect:'below date, quiet icon + label',record:'bottom center, prominent icon + label'},proposedPalette:'white background and monochrome controls; original colorful flames and handwriting',activityArea:{id:area.id,...activity,movement:'independent wandering; no clustering'},controls:[{id:collect.id,label:collectLabel.characters,...collection},{id:record.id,label:record.children.find(n=>n.type==='TEXT')?.characters,...recording}],flameCount:area.children.length,fonts:[...new Set(root.findAllWithCriteria({types:['TEXT']}).map(n=>n.fontName.family))],appCodeChanged:false,cloudSyncVerified:false,nativeRenderingVerified:false};
if(activity.x!==127||activity.y!==172||activity.width!==940||activity.height!==484)throw new Error('The existing activity bounds changed: '+JSON.stringify(activity));
if(collection.height<44||recording.height<44||Math.abs(recording.x+recording.width/2-root.width/2)>.1)throw new Error('Action placement verification failed.');
if(collection.y+collection.height>activity.y||recording.y<activity.y+activity.height)throw new Error('Controls overlap the flame activity area.');
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 기록과 오늘 정리</h3><p>병에 담기: 날짜 아래 · 순간 남기기: 하단 중앙<br>기존 불꽃 활동 범위 유지 · 앱 소스 변경 없음</p><button id="preview">홈 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-actions-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-actions.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
