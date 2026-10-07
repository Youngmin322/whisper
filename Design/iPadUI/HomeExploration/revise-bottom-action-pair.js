/* Requested comparison: place both filled actions together at bottom center.
 * Reuses current home nodes, original bottle and existing neutral color tokens.
 * No application source or global variable values are changed.
 */
(async()=>{try{
const ids={root:'10609:2000',header:'10609:2007',dateStack:'10615:2051',area:'10609:2021',footer:'10609:2022',row:'10609:2023',collect:'10609:2024',record:'10609:2030'};
const nodes={};for(const [key,id]of Object.entries(ids)){nodes[key]=await figma.getNodeByIdAsync(id);if(nodes[key]?.type!=='FRAME')throw new Error('Expected home frame missing: '+key);}
const {root,header,dateStack,area,footer,row,collect,record}=nodes;
if(record.parent?.id!==row.id||row.parent?.id!==footer.id||dateStack.parent?.id!==header.id)throw new Error('Unexpected home action hierarchy.');
const bounds=n=>{const b=n.absoluteBoundingBox,r=root.absoluteBoundingBox;return{x:Math.round((b.x-r.x)*100)/100,y:Math.round((b.y-r.y)*100)/100,width:Math.round(b.width*100)/100,height:Math.round(b.height*100)/100};};
const before={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
for(const text of root.findAllWithCriteria({types:['TEXT']}))for(const font of text.fontName===figma.mixed?text.getRangeAllFontNames(0,text.characters.length):[text.fontName])await figma.loadFontAsync(font);
const ink=await figma.variables.getVariableByIdAsync('VariableID:477:7245');
if(!ink||ink.resolvedType!=='COLOR')throw new Error('Existing neutral ink color missing.');
const controlStyle=(await figma.getLocalTextStylesAsync()).find(s=>s.name==='Whisper iPad/control');
if(!controlStyle)throw new Error('Existing control text style missing.');
const collectLabel=collect.children.find(n=>n.type==='TEXT'),recordLabel=record.children.find(n=>n.type==='TEXT');
const bottle=collect.children.find(n=>n.name==='App asset / BottleLineIcon · original colors');
if(!collectLabel||!recordLabel||!bottle)throw new Error('Existing collection artwork or action label missing.');
for(const label of [collectLabel,recordLabel]){await label.setTextStyleIdAsync(controlStyle.id);label.fontSize=16;label.lineHeight={unit:'PIXELS',value:24};label.textAutoResize='WIDTH_AND_HEIGHT';}
bottle.rescale(20/bottle.width);
if(collect.parent?.id!==row.id)row.insertChild(0,collect);
row.name='Home actions · filled pair at bottom center';row.layoutMode='HORIZONTAL';row.resize(308,48);row.primaryAxisSizingMode='AUTO';row.counterAxisSizingMode='FIXED';row.counterAxisAlignItems='CENTER';row.itemSpacing=12;
for(const button of [collect,record]){button.layoutMode='HORIZONTAL';button.resize(148,48);button.primaryAxisSizingMode='FIXED';button.counterAxisSizingMode='FIXED';button.primaryAxisAlignItems='CENTER';button.counterAxisAlignItems='CENTER';button.paddingLeft=button.paddingRight=20;button.paddingTop=button.paddingBottom=0;button.itemSpacing=8;button.cornerRadius=12;button.strokes=[];button.effects=[];}
collect.name='병에 담기 · filled secondary action · bottom center';
const collectionPaint=figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:.06,g:.06,b:.06}},'color',ink);
const created=[];
let collectionBackground=collect.children.find(n=>n.name==='Collection button · neutral background');
if(!collectionBackground){collectionBackground=figma.createRectangle();collect.insertChild(0,collectionBackground);created.push(collectionBackground.id);}
collectionBackground.name='Collection button · neutral background';collectionBackground.layoutPositioning='ABSOLUTE';collectionBackground.resize(148,48);collectionBackground.x=collectionBackground.y=0;collectionBackground.cornerRadius=12;collectionBackground.fills=[collectionPaint];collectionBackground.strokes=[];collectionBackground.opacity=.1;
collect.fills=[];
record.name='순간 남기기 · filled primary action · bottom center';
dateStack.name='Today date · information only';dateStack.primaryAxisSizingMode='AUTO';
header.name='Home toolbar · date and archive';
footer.name='Home bottom actions · centered filled pair';footer.counterAxisAlignItems='CENTER';
const after={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
if(JSON.stringify(before)!==JSON.stringify(after)||area.children.length!==5)throw new Error('The action revision changed flame bounds.');
const controls=[collect,record].map(n=>({id:n.id,label:n.children.find(c=>c.type==='TEXT').characters,...bounds(n),cornerRadius:n.cornerRadius}));
const group=bounds(row);
if(Math.abs(group.x+group.width/2-root.width/2)>.1||controls.some(n=>n.height!==48||n.y<after.activity.y+after.activity.height)||row.children.length!==2)throw new Error('Bottom action pair validation failed.');
if(Math.abs(collectionBackground.opacity-.1)>.0001)throw new Error('Collection background opacity is unexpected: '+collectionBackground.opacity);
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:[header.id,dateStack.id,footer.id,row.id,collect.id,record.id,collectLabel.id,recordLabel.id,bottle.id,...bottle.findAll().map(n=>n.id),...(!created.includes(collectionBackground.id)?[collectionBackground.id]:[])],allFrameNodeIds:[root.id,...root.findAll().map(n=>n.id)],requestedRevision:'Both filled actions together at bottom center; collection light gray, recording dark',controls,actionGroup:{id:row.id,...group,gap:row.itemSpacing},collectionFill:{backgroundNodeId:collectionBackground.id,variableId:ink.id,opacity:collectionBackground.opacity},activityArea:{id:area.id,...after.activity,movement:'independent wandering; no clustering'},flames:after.flames,flameCount:area.children.length,flameBoundsPreserved:true,appCodeChanged:false,cloudSyncVerified:false,nativeRenderingVerified:false};
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 하단의 두 기록 버튼</h3><p>병에 담기: 옅은 회색 · 순간 남기기: 검정<br>높이 48pt · 모서리 12pt · 하단 중앙</p><button id="preview">수정 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-bottom-pair-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-bottom-pair.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
