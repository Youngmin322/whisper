/* Replace hand-built controls with instances imported from Apple's official kit.
 * Source: Apple / iOS and iPadOS 27 / Buttons / Button - Content Area.
 * First import one instance from Figma's Assets panel. Preserve its remote link.
 * Only native variant and label properties are changed; kit styling is retained.
 */
(async()=>{try{
const root=await figma.getNodeByIdAsync('10609:2000');
const row=await figma.getNodeByIdAsync('10609:2023');
const footer=await figma.getNodeByIdAsync('10609:2022');
const area=await figma.getNodeByIdAsync('10609:2021');
const oldCollect=await figma.getNodeByIdAsync('10609:2024');
const oldRecord=await figma.getNodeByIdAsync('10609:2030');
let record=row?.children.find(n=>n.name==='Apple UI Kit · 순간 남기기')||await figma.getNodeByIdAsync('10619:2326');
if(root?.type!=='FRAME'||row?.type!=='FRAME'||area?.type!=='FRAME'||record?.type!=='INSTANCE'||!oldCollect||!oldRecord)throw new Error('Expected home proposal or imported Apple button missing.');
const main=await record.getMainComponentAsync();
const owner=main?.parent?.type==='COMPONENT_SET'?main.parent:main;
if(!main?.remote||owner?.name!=='Button - Content Area')throw new Error('Button must retain its official remote component link.');
const definitions=owner.componentPropertyDefinitions;
if(!definitions.Size.variantOptions.includes('Large')||!definitions.Style.variantOptions.includes('Bordered')||!definitions.Style.variantOptions.includes('Bordered - Prominent'))throw new Error('Native button variants are unavailable.');
const bounds=n=>{const b=n.absoluteBoundingBox,r=root.absoluteBoundingBox;return{x:Math.round((b.x-r.x)*100)/100,y:Math.round((b.y-r.y)*100)/100,width:Math.round(b.width*100)/100,height:Math.round(b.height*100)/100};};
const before={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
const fonts=new Map();
for(const source of [root,owner])for(const text of source.findAllWithCriteria({types:['TEXT']}))for(const font of text.fontName===figma.mixed?text.getRangeAllFontNames(0,text.characters.length):[text.fontName])fonts.set(font.family+'/'+font.style,font);
for(const font of fonts.values())await figma.loadFontAsync(font);
const created=[];
let collect=row.children.find(n=>n.name==='Apple UI Kit · 병에 담기');
if(!collect){collect=record.clone();created.push(collect.id);}
record.setProperties({'Size':'Large','Style':'Bordered - Prominent','Label Style':'Title and Icon','Is Enabled':'True','Destructive':'False','Label#488:0':'순간 남기기','Symbol#5473:145':'+'});
collect.setProperties({'Size':'Large','Style':'Bordered','Label Style':'Title only','Is Enabled':'True','Destructive':'False','Label#488:0':'병에 담기'});
if(created.includes(collect.id))created.push(...collect.findAll().map(n=>n.id));
record.name='Apple UI Kit · 순간 남기기';collect.name='Apple UI Kit · 병에 담기';
oldCollect.visible=false;oldRecord.visible=false;
row.appendChild(collect);row.appendChild(record);
for(const n of [collect,record]){n.layoutSizingHorizontal='HUG';n.layoutSizingVertical='HUG';}
row.name='Home actions · Apple iPadOS UI kit';row.primaryAxisSizingMode='AUTO';row.counterAxisSizingMode='AUTO';row.itemSpacing=12;
footer.name='Home bottom actions · official Apple buttons';
const after={activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
if(JSON.stringify(before)!==JSON.stringify(after))throw new Error('Flame bounds changed.');
const group=bounds(row);
if(Math.abs(group.x+group.width/2-root.width/2)>.1||[collect,record].some(n=>bounds(n).y<after.activity.y+after.activity.height))throw new Error('Native action placement verification failed.');
const controls=[];for(const n of [collect,record]){const component=await n.getMainComponentAsync();controls.push({id:n.id,name:n.name,...bounds(n),componentProperties:n.componentProperties,source:{id:component.id,key:component.key,name:component.name,remote:component.remote},fonts:n.findAllWithCriteria({types:['TEXT']}).map(t=>({name:t.name,font:t.fontName,size:t.fontSize}))});}
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:created,mutatedNodeIds:[row.id,footer.id,oldCollect.id,oldRecord.id,collect.id,record.id,...collect.findAll().map(n=>n.id),...record.findAll().map(n=>n.id)],sourceKit:{name:'Apple / iOS and iPadOS 27',communityUrl:'https://www.figma.com/community/file/1651309003795292092/ios-and-ipados-27',component:'Button - Content Area'},controls,actionGroup:{id:row.id,...group,gap:row.itemSpacing},hiddenPreviousControlIds:[oldCollect.id,oldRecord.id],activityArea:{id:area.id,...after.activity,movement:'independent wandering; no clustering'},flameCount:area.children.length,flameBoundsPreserved:true,kitStylingPreserved:true,appCodeChanged:false,cloudSyncVerified:false,nativeRenderingVerified:false};
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · Apple 기본 버튼</h3><p>iOS and iPadOS 27 공식 UI 키트 · Large<br>병에 담기: Bordered · 순간 남기기: Bordered - Prominent</p><button id="preview">Apple 버튼 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-apple-buttons-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-apple-buttons.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
