/* Official Apple Liquid Glass text buttons, tinted with existing Whisper colors.
 * Import Button - Liquid Glass - Text from the iOS and iPadOS 27 Assets library.
 * Native component links, geometry, shadows and GLASS effects remain intact.
 */
(async()=>{try{
figma.showUI('<style>body{font:14px sans-serif;padding:18px}pre{white-space:pre-wrap}</style><h3>Liquid Glass 시안 준비</h3><pre id="status">공식 컴포넌트 확인 중</pre><button onclick="parent.postMessage({pluginMessage:{type:\'close\'}},\'*\')">닫기</button><script>onmessage=e=>{document.getElementById("status").textContent=e.data.pluginMessage.status}</script>',{width:740,height:360});
figma.ui.onmessage=m=>{if(m.type==='close')figma.closePlugin();};
const progress=status=>figma.ui.postMessage({status});
const root=await figma.getNodeByIdAsync('10609:2000'),row=await figma.getNodeByIdAsync('10609:2023'),footer=await figma.getNodeByIdAsync('10609:2022'),area=await figma.getNodeByIdAsync('10609:2021');
let record=row?.children.find(n=>n.name==='Apple Liquid Glass · 순간 남기기')||await figma.getNodeByIdAsync('10619:2457');
if(root?.type!=='FRAME'||row?.type!=='FRAME'||area?.type!=='FRAME'||record?.type!=='INSTANCE')throw new Error('Expected home proposal or imported glass button missing.');
progress('공식 유리 버튼 원본 확인 중');
const main=await record.getMainComponentAsync(),owner=main?.parent?.type==='COMPONENT_SET'?main.parent:main;
if(!main?.remote||owner?.name!=='Button - Liquid Glass - Text')throw new Error('Expected official Liquid Glass component link.');
const accent=await figma.variables.getVariableByIdAsync('VariableID:1388:10242'),ink=await figma.variables.getVariableByIdAsync('VariableID:1388:10244');
if(accent?.name!=='whisperAccent'||ink?.name!=='whisperTextPrimary')throw new Error('Existing app colors missing.');
const bounds=n=>{const b=n.absoluteBoundingBox,r=root.absoluteBoundingBox;return{x:Math.round((b.x-r.x)*100)/100,y:Math.round((b.y-r.y)*100)/100,width:Math.round(b.width*100)/100,height:Math.round(b.height*100)/100};};
const before={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
progress('폰트 확인 중');
const fonts=new Map();for(const source of [root,owner])for(const t of source.findAllWithCriteria({types:['TEXT']}))for(const f of t.fontName===figma.mixed?t.getRangeAllFontNames(0,t.characters.length):[t.fontName])fonts.set(f.family+'/'+f.style,f);
for(const f of fonts.values()){progress('폰트 준비: '+f.family+' / '+f.style);await figma.loadFontAsync({family:f.family,style:f.style});}
progress('유리 버튼에 앱 색상 적용 중');
const created=[],mutated=[row.id,footer.id,record.id];
let collect=row.children.find(n=>n.name==='Apple Liquid Glass · 병에 담기');
if(!collect){collect=record.clone();created.push(collect.id);}
record.setProperties({Size:'Large',Style:'Glass Prominent','Is Enabled':'True',Destructive:'False'});
collect.setProperties({Size:'Large',Style:'Glass','Is Enabled':'True',Destructive:'False'});
function label(n,value){const text=n.findAllWithCriteria({types:['INSTANCE']}).find(c=>c.name==='Text');if(!text||!text.componentProperties['Label#10462:47'])throw new Error('Expected native label property.');text.setProperties({'Label#10462:47':value});mutated.push(text.id,...text.findAll().map(c=>c.id));}
label(collect,'병에 담기');label(record,'+ 순간 남기기');
const effects=n=>JSON.stringify([n,...n.findAll()].filter(c=>c.effects?.length).map(c=>({id:c.id,effects:c.effects})));
const materialsBefore=[effects(collect),effects(record)];
const tint=record.findAll(n=>n.name==='Tint').find(n=>Array.isArray(n.fills)&&n.fills.some(p=>p.type==='SOLID'));
if(!tint)throw new Error('Native tint layer missing.');
tint.fills=tint.fills.map(p=>p.type==='SOLID'?{...figma.variables.setBoundVariableForPaint(p,'color',accent),opacity:p.opacity}:p);mutated.push(tint.id);
for(const t of collect.findAllWithCriteria({types:['TEXT']})){t.fills=t.fills.map(p=>p.type==='SOLID'?{...figma.variables.setBoundVariableForPaint(p,'color',ink),opacity:p.opacity}:p);mutated.push(t.id);}
if(materialsBefore[0]!==effects(collect)||materialsBefore[1]!==effects(record))throw new Error('Native material effects were modified.');
collect.name='Apple Liquid Glass · 병에 담기';record.name='Apple Liquid Glass · 순간 남기기';
const hidden=[];for(const n of row.children.filter(n=>n.id!==collect.id&&n.id!==record.id)){if(n.visible){n.visible=false;mutated.push(n.id);}hidden.push(n.id);}
row.appendChild(collect);row.appendChild(record);for(const n of [collect,record]){n.layoutSizingHorizontal='HUG';n.layoutSizingVertical='HUG';}
row.name='Home actions · Apple Liquid Glass with Whisper tint';row.primaryAxisSizingMode='AUTO';row.counterAxisSizingMode='AUTO';row.itemSpacing=12;footer.name='Home bottom actions · native Liquid Glass';
const after={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};if(JSON.stringify(before)!==JSON.stringify(after))throw new Error('Flame bounds changed.');
const group=bounds(row);if(Math.abs(group.x+group.width/2-root.width/2)>.1||[collect,record].some(n=>bounds(n).y<after.activity.y+after.activity.height))throw new Error('Glass button placement failed.');
const controls=[];for(const n of [collect,record]){const source=await n.getMainComponentAsync();const glassNodes=n.findAll(c=>c.effects?.some(e=>e.type==='GLASS'));if(!glassNodes.length)throw new Error('Official GLASS effect is missing.');controls.push({id:n.id,name:n.name,...bounds(n),componentProperties:n.componentProperties,source:{id:source.id,key:source.key,name:source.name,remote:source.remote},glassEffectNodeIds:glassNodes.map(c=>c.id),texts:n.findAllWithCriteria({types:['TEXT']}).map(t=>({id:t.id,text:t.characters,font:t.fontName}))});}
if(created.includes(collect.id))created.push(...collect.findAll().map(n=>n.id));else mutated.push(collect.id);
mutated.push(...record.findAll().map(n=>n.id),...collect.findAll().map(n=>n.id));
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:[...new Set(mutated)],sourceKit:{name:'Apple / iOS and iPadOS 27',communityUrl:'https://www.figma.com/community/file/1651309003795292092/ios-and-ipados-27',component:'Button - Liquid Glass - Text'},controls,actionGroup:{id:row.id,...group,gap:row.itemSpacing},palette:{accent:{variableId:accent.id,hex:'#F4523B',resolved:accent.resolveForConsumer(record)},secondaryText:{variableId:ink.id,hex:'#3E3530',resolved:ink.resolveForConsumer(collect)}},hiddenPreviousControlIds:hidden,activityArea:{id:area.id,...after.activity,movement:'independent wandering; no clustering'},flameCount:area.children.length,flameBoundsPreserved:true,nativeMaterialEffectsPreserved:true,appCodeChanged:false,cloudSyncVerified:false,nativeRenderingVerified:false};
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 앱 색상의 Liquid Glass</h3><p>병에 담기: Glass · 순간 남기기: Glass Prominent<br>기존 앱의 코랄 포인트색 · Apple 재질 유지</p><button id="preview">유리 버튼 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-liquid-glass-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-liquid-glass.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
