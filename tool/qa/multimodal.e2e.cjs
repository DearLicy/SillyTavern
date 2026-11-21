// Run from the repository root. See tool/qa/README.md.
const assert=require('node:assert/strict');const fs=require('fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const pixel=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=','base64');
const wav=Buffer.alloc(32044);wav.write('RIFF');wav.writeUInt32LE(32036,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(16000,24);wav.writeUInt32LE(32000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(32000,40);
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE,headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream'],env:{...process.env,TMPDIR:process.cwd()+'/.tmp',TMP:process.cwd()+'/.tmp',TEMP:process.cwd()+'/.tmp'}});
const report={mode:'release build + fake authenticated provider + real browser microphone/image storage/playback',cases:[]};try{for(const theme of ['light','dark']){
 const context=await browser.newContext({viewport:{width:390,height:844},permissions:['microphone','clipboard-read','clipboard-write'],colorScheme:theme});
 const fixture=JSON.parse(fs.readFileSync('.tmp/management-fixture.json'));fixture.settings.themeMode=theme;fixture.settings.provider={kind:'openaiCompatible',baseUrl:'https://api.deepseek.com',model:'fake-multimodal',models:['fake-multimodal'],rememberKey:true};fixture.messages=fixture.messages.filter(m=>m.threadId==='thread_gu');fixture.threads=fixture.threads.map(t=>({...t,contextMemo:'',summarizedThroughMessageId:null}));
 await context.addInitScript(data=>{if(!localStorage.getItem('media-seeded')){localStorage.setItem('flutter.dreamtide.v2.state',JSON.stringify(JSON.stringify(data)));localStorage.setItem('flutter.dreamtide.provider.apiKey.web',JSON.stringify('fake-browser-key'));localStorage.setItem('media-seeded','1');}},fixture);
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[],calls=[];page.on('pageerror',e=>errors.push(e.stack || e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const step=name=>console.log(JSON.stringify({theme,step:name}));
 let visionCount=0;let searchCount=0,asrCount=0,ttsCount=0,ocrCount=0;
 await page.route('https://api.deepseek.com/**',async route=>{ try {
  const req=route.request();const path=new URL(req.url()).pathname;calls.push(path);
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
  assert.equal(req.headers()['authorization'],'Bearer fake-browser-key');
  if(path.endsWith('/chat/completions')){const body=req.postDataJSON();if(!body.stream)return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({choices:[{message:{content:'{"summary":"本轮多模态交互","facts":[]}'}}]})});
   const image=(body.messages||[]).some(m=>Array.isArray(m.content)&&m.content.some(b=>b.type==='image_url'&&b.image_url.url.startsWith('data:image/png;base64,')));if(image)visionCount++;
   return route.fulfill({status:200,contentType:'text/event-stream',body:`data: ${JSON.stringify({choices:[{delta:{content:`看见你发来的图片了，第 ${visionCount} 次。[1]`}}]})}\n\ndata: [DONE]\n\n`});}
  if(path.endsWith('/tools/search')){searchCount++;return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({results:[{title:'官方测试来源',url:'https://example.org/source',summary:'有依据的信息'}]})});}
  if(path.endsWith('/tools/ocr')){ocrCount++;assert(req.postDataBuffer().includes(Buffer.from('name="purpose"')));assert(req.postDataBuffer().includes(Buffer.from([137,80,78,71])) || req.postDataBuffer().includes(Buffer.from([255,216,255])));return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({pages:[{index:0,text:'图片识别出的文字',finish_reason:'stop'}]})});}
  if(path.endsWith('/tools/asr')){asrCount++;const body=req.postDataBuffer();assert(body.includes(Buffer.from('RIFF')));assert(body.includes(Buffer.from('WAVE')));return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({text:'这是语音转成的草稿',duration_ms:1500})});}
  if(path.endsWith('/tools/tts')){ttsCount++;assert.equal(req.postDataJSON().format,'wav');return route.fulfill({status:200,contentType:'audio/wav',body:wav});}
  throw new Error('unexpected endpoint '+path);
 } catch(error) { errors.push('Mock contract: '+error.message);await route.fulfill({status:500,body:'test contract mismatch'}); }
 });
 const snap=async()=>page.locator('body').ariaSnapshot();
 const read=async()=>page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.dreamtide.v2.state'))));
 const click=async(name)=>{const escaped=name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');const exact=page.getByRole('button',{name,exact:true});await (await exact.count() ? exact.last() : page.getByRole('button',{name:new RegExp('^'+escaped)}).last()).evaluate(e=>e.click());await page.waitForTimeout(450)};
 const goto=async(path)=>{await page.evaluate(p=>location.hash=p,path);await page.waitForTimeout(550)};
 const file=async(action)=>{
  const chooser=page.waitForEvent('filechooser');
  await click(action);
  await (await chooser).setFiles({name:'photo.png',mimeType:'image/png',buffer:pixel});
  await page.waitForTimeout(1500);
 };
 const type=async(text)=>{const box=page.getByRole('textbox').last();await box.focus();await page.keyboard.press('Control+A');await page.keyboard.insertText(text);await page.waitForTimeout(150)};
 await page.goto((process.env.DREAMTIDE_QA_BASE_URL || 'http://127.0.0.1:8089/Dreamtide/'),{waitUntil:'networkidle'});await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(500);
 step('avatar');await goto('/profile');await page.waitForTimeout(800);await click('更换头像');await file('从相册选择');
 assert.equal((await read()).owner.avatarReference ?? null,null);
 await page.screenshot({path:`.tmp/avatar-preview-${theme}.png`});
 // Activate the accessible Save action; widget tests separately cover scrolling.
 await page.getByRole('button',{name:'保存资料',exact:true}).evaluate(e=>e.click());await page.waitForTimeout(850);
 let data=await read();assert(data.owner.avatarReference);
 step('image chat');await goto('/chat/thread_gu');await click('更多功能');await file('从相册发送图片');await click('发送');await page.waitForTimeout(800);
 assert(visionCount>=1,'model request must contain actual bytes');data=await read();const image=data.messages.find(m=>m.kind==='image');assert(image.localPath&&!JSON.stringify(data).includes('base64'));
 await page.screenshot({path:`.tmp/vision-chat-${theme}.png`});
 await click('更多');await click('重新生成上一条');assert(visionCount>=2);
 step('OCR');await click('更多功能');await file('识别图片文字');await page.getByRole('textbox').last().waitFor({state:'attached'});assert.match(await snap(),/图片识别出的文字/);await click('填入输入框');
 assert.equal(await page.getByRole('textbox').last().inputValue(),'图片识别出的文字');assert.equal(ocrCount,1);
 step('search');await type('搜索今天的消息');await click('更多功能');await click('开启联网搜索');await click('发送');await page.waitForTimeout(500);assert.equal(searchCount,1);data=await read();assert(data.messages.at(-1).sources.length===1);
 await page.getByRole('button',{name:/^联网来源/}).last().evaluate(e=>e.click());await page.waitForTimeout(500);assert.match(await snap(),/官方测试来源/);await page.screenshot({path:`.tmp/search-sources-${theme}.png`});await page.keyboard.press('Escape');await page.waitForTimeout(500);
 step('recording + ASR');await click('语音输入');await click('开始录音');await page.waitForTimeout(1800);assert.match(await snap(),/正在录音/);await page.screenshot({path:`.tmp/voice-recording-${theme}.png`});await click('结束并转文字');await page.waitForTimeout(800);assert.equal(asrCount,1);assert.match(await page.getByRole('textbox').last().inputValue(),/这是语音转成的草稿/);
 assert(!(await read()).messages.some(m=>m.text==='这是语音转成的草稿'));
 // Open a real message action via long press, request and play actual WAV.

 await page.screenshot({path:`.tmp/voice-draft-${theme}.png`});
 const el=page.getByText(/看见你发来的图片了/).last();const rect=await el.boundingBox();assert(rect);await page.mouse.move(rect.x+rect.width/2,rect.y+rect.height/2);await page.mouse.down();await page.waitForTimeout(800);await page.mouse.up();await page.waitForTimeout(400);
 step('TTS');await click('朗读消息');await click('生成语音');await page.waitForTimeout(700);assert.equal(ttsCount,1);await click('播放语音');await page.waitForTimeout(1300);await click('关闭');
 step('backup restore');await goto('/backup');await click('复制完整备份');await page.waitForTimeout(550);
 const backup=await page.evaluate(()=>navigator.clipboard.readText());const envelope=JSON.parse(backup);
 assert.equal(envelope.format,'dreamtide.media.v1');assert(Object.keys(envelope.attachments).length>=2);assert(!backup.includes('fake-browser-key'));
 await click('从 JSON 恢复');await type(backup);await click('覆盖恢复');await page.waitForTimeout(600);
 const restored=await read();assert(restored.owner.avatarReference!==data.owner.avatarReference);assert(restored.messages.some(m=>m.kind==='image'));assert(!JSON.stringify(restored).includes('base64'));
 await page.reload({waitUntil:'networkidle'});await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());await page.waitForTimeout(500);
 assert.match(await snap(),/数据与备份/);await goto('/chat/thread_gu');
 assert.equal(errors.length,0,errors.join('\n'));report.cases.push({theme,avatar:true,portableBackupRestoreAndRefresh:true,actualImageRequest:true,retryImage:true,ocrDraft:true,searchSources:true,pcmRecordingAndAsr:true,ttsPlayback:true,defaultHasNoBase64:true,consoleErrors:errors,requests:calls.length});await context.close();
 }fs.writeFileSync('.tmp/media-e2e-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1});
