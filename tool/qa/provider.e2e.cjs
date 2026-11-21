// Fake supplier only. Verifies settings -> authenticated catalog -> chat.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE,headless:true,args:['--no-sandbox','--disable-dev-shm-usage'],env:{...process.env,TMPDIR:process.cwd()+'/.tmp',TMP:process.cwd()+'/.tmp',TEMP:process.cwd()+'/.tmp'}});
 const report=[];
 try {
  for (const width of [390,1440]) for (const theme of ['light','dark']) {
   const context=await browser.newContext({viewport:{width,height:width===390?844:900},colorScheme:theme});
   const fixture=JSON.parse(fs.readFileSync('.tmp/management-fixture.json'));
   fixture.messages=[];fixture.settings.ageConfirmed=true;fixture.settings.themeMode=theme;
   fixture.settings.provider={kind:'openaiCompatible',baseUrl:'https://api.deepseek.com',model:'previous-model',models:['previous-model'],rememberKey:true};
   await context.addInitScript(data=>{
    if(localStorage.getItem('provider-seeded')) return;
    localStorage.setItem('provider-seeded','1');
    localStorage.setItem('flutter.dreamtide.v2.state',JSON.stringify(JSON.stringify(data)));
    localStorage.setItem('flutter.dreamtide.provider.apiKey.web',JSON.stringify('fake-old-key'));
   },fixture);
   const page=await context.newPage();page.setDefaultTimeout(30000);
   const errors=[],calls=[];page.on('pageerror',e=>errors.push(e.stack||e.message));
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.route('https://catalog.example/**',async route=>{
    try {
     const request=route.request();if(request.method()==='OPTIONS')return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
     assert.equal(request.headers().authorization,'Bearer fake-new-key');
     const path=new URL(request.url()).pathname;calls.push(path);
     if(path==='/v1/models')return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({data:Array.from({length:1500},(_,i)=>({id:`model-${i}`,name:i===1499?'目标视觉模型':`候选模型 ${i}`}))})});
     assert.equal(path,'/v1/chat/completions');assert.equal(request.postDataJSON().model,'model-1499');
     return route.fulfill({status:200,contentType:'text/event-stream',body:'data: {"choices":[{"delta":{"content":"配置与聊天联动通过。"}}]}\n\ndata: [DONE]\n\n'});
    } catch(e){errors.push(e.message);return route.fulfill({status:500,body:'mock contract failed'})}
   });
   const click=async(name)=>{await page.getByRole('button',{name,exact:true}).last().evaluate(e=>e.click());await page.waitForTimeout(300)};
   const type=async(box,text)=>{await box.focus();await page.keyboard.press('Control+A');await page.keyboard.insertText(text);await page.waitForTimeout(120)};
   const read=()=>page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.dreamtide.v2.state'))));
   await page.goto((process.env.DREAMTIDE_QA_BASE_URL || 'http://127.0.0.1:8089/Dreamtide/')+'#/provider',{waitUntil:'networkidle'});
   await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
   await page.getByRole('textbox').first().waitFor();assert.match(await page.title(),/Dreamtide|触梦/);
   await type(page.getByRole('textbox').first(),'https://catalog.example');await click('拉取模型');
   await page.getByText('更换供应商地址后，请填写该供应商的 API Key。',{exact:true}).waitFor();assert.equal(calls.length,0);
   await type(page.getByRole('textbox').nth(1),'fake-new-key');await click('拉取模型');
   await page.getByRole('button',{name:/^默认模型/}).evaluate(e=>e.click());
   await page.getByText('显示 1500 / 1500 个模型',{exact:true}).waitFor();
   await type(page.getByRole('textbox').last(),'目标视觉');await page.getByText('显示 1 / 1500 个模型',{exact:true}).waitFor();
   await page.screenshot({path:`.tmp/provider-picker-${width===390?'phone':'desktop'}-${theme}.png`});await page.getByRole('button',{name:/^目标视觉模型/}).evaluate(e=>e.click());
   await click('保存');await page.waitForTimeout(700);
   let saved=await read();assert.equal(saved.settings.provider.model,'model-1499');assert.equal(saved.settings.provider.baseUrl,'https://catalog.example');
   await page.evaluate(()=>location.hash='/chat/thread_gu');await page.getByRole('textbox').last().waitFor();
   await type(page.getByRole('textbox').last(),'测试配置联动');await click('发送');
   await page.getByRole('button',{name:'长按消息操作 配置与聊天联动通过。',exact:true}).waitFor();
   await page.waitForTimeout(500);saved=await read();assert.equal(saved.messages.filter(m=>m.fromAi).length,1);
   assert.deepEqual(calls,['/v1/models','/v1/chat/completions']);assert.deepEqual(errors,[]);
   const result={width,theme,supplierKeyIsolation:true,catalogSearch1500:true,selectedModelSaved:true,chatUsesSelectedModelAndKey:true,consoleErrors:errors};report.push(result);
   console.log(JSON.stringify(result));await context.close();
  }
 } finally {fs.writeFileSync('.tmp/provider-report.json',JSON.stringify(report,null,2));await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
