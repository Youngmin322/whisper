/* Review revision: give the existing secondary collection action a visible outline.
 * Uses the established neutral color variable; preserves layout and flame artwork.
 * Executed by the registered local Figma development plugin.
 */
(async()=>{try{
const root=await figma.getNodeByIdAsync('10609:2000');
const collect=await figma.getNodeByIdAsync('10609:2024');
const record=await figma.getNodeByIdAsync('10609:2030');
const area=await figma.getNodeByIdAsync('10609:2021');
if(root?.type!=='FRAME'||collect?.type!=='FRAME'||record?.type!=='FRAME'||area?.type!=='FRAME')throw new Error('Expected home proposal is missing.');
const bounds=n=>{const b=n.absoluteBoundingBox,r=root.absoluteBoundingBox;return{x:Math.round((b.x-r.x)*100)/100,y:Math.round((b.y-r.y)*100)/100,width:Math.round(b.width*100)/100,height:Math.round(b.height*100)/100};};
const before={collection:bounds(collect),recording:bounds(record),activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
const secondary=await figma.variables.getVariableByIdAsync('VariableID:477:7248');
if(!secondary||secondary.resolvedType!=='COLOR')throw new Error('Existing neutral secondary color is missing.');
const stroke=figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:.38,g:.38,b:.38},opacity:.6},'color',secondary);
collect.name='병에 담기 · outlined secondary button below date';
collect.fills=[];collect.effects=[];collect.strokes=[stroke];collect.strokeWeight=1;collect.strokeAlign='INSIDE';collect.cornerRadius=22;
const after={collection:bounds(collect),recording:bounds(record),activity:bounds(area),flames:area.children.map(n=>({id:n.id,...bounds(n)}))};
if(JSON.stringify(before)!==JSON.stringify(after)||area.children.length!==5)throw new Error('The outline changed existing content bounds.');
const report={frameId:root.id,pageId:figma.currentPage.id,createdNodeIds:[],mutatedNodeIds:[collect.id],allFrameNodeIds:[root.id,...root.findAll().map(n=>n.id)],requestedRevision:'Thin neutral outline on the existing round collection button',collectionButton:{id:collect.id,label:'병에 담기',...after.collection,cornerRadius:collect.cornerRadius,strokeWeight:collect.strokeWeight,strokeAlign:collect.strokeAlign,strokeVariableId:secondary.id,strokeOpacity:stroke.opacity},recordButton:{id:record.id,label:'순간 남기기',...after.recording},activityArea:{id:area.id,...after.activity,movement:'independent wandering; no clustering'},flames:after.flames,flameCount:area.children.length,layoutPreserved:true,appCodeChanged:false,cloudSyncVerified:false,nativeRenderingVerified:false};
figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:white;color:#111}button{padding:10px;margin:4px}textarea{width:100%;height:145px}</style><h3>iPad 홈 · 병에 담기 버튼 윤곽선</h3><p>얇은 무채색 테두리 · 기존 위치와 크기 유지<br>불꽃 활동 범위 유지 · 앱 소스 변경 없음</p><button id="preview">수정 시안 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>const r=${JSON.stringify(report).replace(/</g,'\\u003c')};document.getElementById('ledger').value=JSON.stringify(r);function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}document.getElementById('preview').onclick=()=>parent.postMessage({pluginMessage:{type:'preview'}},'*');document.getElementById('close').onclick=()=>parent.postMessage({pluginMessage:{type:'close'}},'*');document.getElementById('report').onclick=()=>download(JSON.stringify(r,null,2),'Whisper-iPad-home-outlined-state.json','application/json');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-outlined.png','image/png')};</script>`,{width:740,height:360});
figma.ui.onmessage=async m=>{if(m.type==='close'){figma.closePlugin();return}if(m.type==='preview'){const bytes=await root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:740,height:360});}})();
