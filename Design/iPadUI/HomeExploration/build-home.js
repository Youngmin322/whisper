/* Whisper iPad home discussion draft. Existing brand assets; no app-code changes.
 * Run through the registered local Figma workshop when connector is unavailable.
 * Original SF Symbols are supplied by AppKit, because the local plugin runtime
 * predates the connector's getSfSymbolCharacter helper.
 */
async function buildWhisperHomeExploration() {
  const page = figma.currentPage;
  const name = '41 논의안 · iPad 홈 · 오늘의 불꽃';
  const prior = page.children.find(n => n.name === name);
  if (prior) throw new Error('The discussion draft already exists. Review it instead of creating a duplicate.');
  const available = await figma.listAvailableFontsAsync();
  const required = [{family:'Kyobo Handwriting 2019',style:'Regular'}, {family:'Noto Sans KR',style:'Medium'}, {family:'SF Pro',style:'Regular'}];
  for (const font of required) {
    if (!available.some(f => f.fontName.family === font.family && f.fontName.style === font.style)) throw new Error('Required font missing: '+JSON.stringify(font));
    await figma.loadFontAsync(font);
  }
  const vars = await figma.variables.getLocalVariablesAsync();
  const byId = new Map(vars.map(v => [v.id,v]));
  const colors = {
    bg: ['VariableID:1388:10247','#FDFBF6'], text: ['VariableID:1388:10244','#3E3530'],
    secondary: ['VariableID:1388:10245','#6E6156'], accent: ['VariableID:1388:10242','#F4523B'],
    highlight: ['VariableID:1388:10251','#F4DCC9'], border: ['VariableID:1388:10253','#E5D8CB']
  };
  const rgb = hex => ({r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255});
  function paint(key,opacity=1) {
    const [id,hex] = colors[key]; const v = byId.get(id);
    if(!v) throw new Error('Existing brand variable missing: '+id);
    return figma.variables.setBoundVariableForPaint({type:'SOLID',color:rgb(hex),opacity},'color',v);
  }
  const created=[];
  const track = n => {created.push(n.id);return n};
  function frame(parent,name,w,h,mode='NONE') {
    const n=track(figma.createFrame()); parent.appendChild(n); n.name=name; n.resize(w,h); n.fills=[]; n.layoutMode=mode; n.clipsContent=false;
    if(mode!=='NONE'){n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='FIXED';}
    return n;
  }
  function rectangle(parent,name,w,h,fill) {const n=track(figma.createRectangle());parent.appendChild(n);n.name=name;n.resize(w,h);n.fills=fill;return n;}
  const localStyles=await figma.getLocalTextStylesAsync();
  const handStyle=localStyles.find(s=>s.name==='Whisper iPad/hand28');
  const controlStyle=localStyles.find(s=>s.name==='Whisper iPad/control');
  if(!handStyle || !controlStyle) throw new Error('Existing Whisper text styles missing');
  async function label(parent,value,kind='control',key='secondary') {
    const n=track(figma.createText());parent.appendChild(n);n.name=value;n.fontName=kind==='system'?required[2]:kind==='hand'?required[0]:required[1];
    n.characters=value;
    if(kind==='system'){n.fontSize=14;n.lineHeight={unit:'PIXELS',value:20};}
    else await n.setTextStyleIdAsync(kind==='hand'?handStyle.id:controlStyle.id);
    n.textAutoResize='WIDTH_AND_HEIGHT';n.fills=[paint(key)];return n;
  }
  const images={}; for(const [key,data] of Object.entries(HOME_ASSETS.symbols)) images[key]=figma.createImage(figma.base64Decode(data)).hash;
  function symbol(parent,key,w,h) {return rectangle(parent,'SF Symbol / '+key,w,h,[{type:'IMAGE',imageHash:images[key],scaleMode:'FIT'}]);}
  function bottle(parent,w=19,h=23,tint=false) {
    const n=figma.createNodeFromSvg(HOME_ASSETS.bottle);parent.appendChild(n);n.name='App asset / BottleLineIcon';n.resize(w,h);
    const descendants=n.findAll(); created.push(n.id,...descendants.map(d=>d.id));
    if(tint) for(const child of descendants) {
      if('strokes' in child && child.strokes.length) child.strokes=[paint('accent')];
      if('fills' in child && child.fills.length) child.fills=[paint('accent')];
    }
    return n;
  }
  const root=frame(page,name,1194,834,'VERTICAL');root.x=96784;root.y=0;root.fills=[paint('bg')];root.clipsContent=true;
  const status=frame(root,'iPad system status',1194,32,'HORIZONTAL');status.paddingLeft=status.paddingRight=24;status.counterAxisAlignItems='CENTER';status.itemSpacing=7;
  await label(status,'9:41  10월 7일 수요일','system');
  const statusSpace=frame(status,'Flexible status space',800,20);statusSpace.layoutSizingHorizontal='FILL';
  symbol(status,'wifi',17,13);await label(status,'100%','system');symbol(status,'battery.100',26,13);
  const header=frame(root,'Home toolbar · existing iPhone hierarchy',1194,96,'HORIZONTAL');header.paddingLeft=header.paddingRight=32;header.primaryAxisAlignItems='SPACE_BETWEEN';header.counterAxisAlignItems='CENTER';
  const leading=frame(header,'Settings · 48 pt hit area',88,48,'HORIZONTAL');leading.counterAxisAlignItems='CENTER';symbol(leading,'gearshape',22,22);
  const date=frame(header,'Handwriting date with original underline',200,42);
  const dateText=await label(date,'10월 7일 수요일','hand','text');
  date.resize(dateText.width+12,42);
  const underline=rectangle(date,'Original date highlight',date.width,7,[paint('highlight')]);underline.cornerRadius=3.5;underline.y=33;
  date.insertChild(0,underline);dateText.x=6;dateText.y=0;
  const archive=frame(header,'Archive · existing bottle and label',88,48,'HORIZONTAL');archive.itemSpacing=4;archive.primaryAxisAlignItems='MAX';archive.counterAxisAlignItems='CENTER';bottle(archive);await label(archive,'보관함');
  const field=frame(root,'Today flame field · adapts around the center',1194,572,'VERTICAL');field.primaryAxisAlignItems='CENTER';field.counterAxisAlignItems='CENTER';
  const cluster=frame(field,'Independent flame movement area · bounded, no clustering',940,484);
  const footer=frame(root,'Native bottom actions',1194,134,'VERTICAL');footer.paddingTop=16;footer.paddingBottom=30;footer.itemSpacing=27;footer.counterAxisAlignItems='CENTER';
  const actions=frame(footer,'Collect and add',128,56,'HORIZONTAL');actions.itemSpacing=16;
  for(const [key,title] of [['bottle','병에 담기'],['plus','순간 남기기']]) {
    const button=frame(actions,title+' · 56 pt hit area',56,56,'HORIZONTAL');button.primaryAxisAlignItems='CENTER';button.counterAxisAlignItems='CENTER';button.cornerRadius=28;
    button.fills=[{type:'SOLID',color:rgb('#FFFFFF'),opacity:.78}];button.strokes=[paint('border',.55)];button.strokeWeight=.5;
    button.effects=[{type:'DROP_SHADOW',color:{...rgb('#3E3530'),a:.06},offset:{x:0,y:2},radius:10,spread:0,visible:true,blendMode:'NORMAL'}];
    if(key==='bottle') bottle(button,20,24,true);
    else {const plus=symbol(button,'plus',22,22);plus.name='SF Symbol / plus · native';}
  }
  const homeIndicator=rectangle(footer,'System home indicator',120,5,[paint('text',.35)]);homeIndicator.cornerRadius=2.5;
  const flameIds={joy:'10598:1163',calm:'10598:1165',anxiety:'10598:1167',sadness:'10598:1173'};
  const placements=[['joy',85,95,108],['calm',580,36,100],['anxiety',772,265,100],['sadness',292,300,104],['joy',524,329,116]];
  async function addFlames() {
    if(cluster.children.length) return;
    for(const [key,x,y,size] of placements) {
      const master=await figma.getNodeByIdAsync(flameIds[key]);if(!master || master.type!=='COMPONENT')throw new Error('Existing flame component missing: '+key);
      const n=master.createInstance();cluster.appendChild(n);n.rescale(size/76);n.x=x;n.y=y;n.name='Independent today moment / '+key;
      created.push(n.id,...n.findAll().map(c=>c.id));
    }
  }
  function report() {
    const descendants=root.findAll();const textNodes=descendants.filter(n=>n.type==='TEXT');
    const expected=new Set(required.map(f=>f.family));const mismatched=textNodes.filter(n=>n.fontName===figma.mixed || !expected.has(n.fontName.family));
    if(mismatched.length)throw new Error('Font verification failed');
    return {frameId:root.id,pageId:page.id,name:root.name,width:root.width,height:root.height,createdNodeIds:[...new Set(created)],fontFamilies:[...new Set(textNodes.map(n=>n.fontName.family))],fontMismatchCount:mismatched.length,flameCount:cluster.children.length,flamePlacements:placements,componentsReused:flameIds,colorVariables:Object.values(colors).map(([id])=>id),autoLayoutCount:descendants.filter(n=>'layoutMode'in n && n.layoutMode!=='NONE').length,source:'Whisper existing art and fonts; AppKit SF Symbols; editable Figma layers',codeChanged:false};
  }
  figma.currentPage.selection=[root];figma.viewport.scrollAndZoomIntoView([root]);
  return {root,cluster,created,addFlames,report};
}
