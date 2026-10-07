
(async()=>{try{
const draft=await buildWhisperHomeExploration();
function htmlReport(){return JSON.stringify(draft.report());}
figma.showUI(`<style>body{font:13px sans-serif;padding:16px;background:#fdfbf6;color:#3e3530}button{padding:10px;margin:4px}textarea{width:100%;height:125px}</style><h3>iPad 홈 · 오늘의 불꽃</h3><p>기존 교보 손글씨 · 앱의 원래 불꽃과 병 · 홈 한 화면</p><button id="flames">활동 영역에 불꽃 배치</button><button id="export">홈 PNG 저장</button><button id="report">검증 기록 저장</button><button id="close">닫기</button><textarea id="ledger"></textarea><script>function download(data,name,type){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([data],{type}));a.download=name;a.click()}for(const type of ['flames','export','report','close'])document.getElementById(type).onclick=()=>parent.postMessage({pluginMessage:{type}},'*');onmessage=e=>{const m=e.data.pluginMessage;if(m?.type==='ledger')document.getElementById('ledger').value=JSON.stringify(m.report);if(m?.type==='report')download(JSON.stringify(m.report,null,2),'Whisper-iPad-home-discussion-state.json','application/json');if(m?.type==='png')download(Uint8Array.from(atob(m.data),c=>c.charCodeAt(0)),'Whisper-iPad-home-discussion.png','image/png')};</script>`,{width:720,height:350});
figma.ui.postMessage({type:'ledger',report:draft.report()});
figma.ui.onmessage=async m=>{try{
if(m.type==='flames'){await draft.addFlames();figma.currentPage.selection=[draft.root];figma.viewport.scrollAndZoomIntoView([draft.root]);figma.ui.postMessage({type:'ledger',report:draft.report()});}
if(m.type==='export'){const bytes=await draft.root.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1.5}});figma.ui.postMessage({type:'png',data:figma.base64Encode(bytes)});}
if(m.type==='report')figma.ui.postMessage({type:'report',report:draft.report()});
if(m.type==='close')figma.closePlugin();
}catch(e){figma.ui.postMessage({type:'ledger',report:{error:String(e),stack:e.stack}})}};
}catch(e){figma.showUI('<pre>'+String(e)+'\n'+e.stack+'</pre>',{width:760,height:380})}})();
