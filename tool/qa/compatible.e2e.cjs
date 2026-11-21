// Run from the repository root. Fake provider only; see tool/qa/README.md.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
(async () => {
  const browser = await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE,headless:true,args:['--no-sandbox','--disable-dev-shm-usage'],env:{...process.env,TMPDIR:process.cwd()+'/.tmp',TMP:process.cwd()+'/.tmp',TEMP:process.cwd()+'/.tmp'}});
  try {
    for (const theme of ['light','dark']) {
      const context = await browser.newContext({viewport:{width:390,height:844},colorScheme:theme});
      const fixture = JSON.parse(fs.readFileSync('.tmp/management-fixture.json','utf8'));
      fixture.messages=[]; fixture.settings.ageConfirmed=true; fixture.settings.onboardingComplete=true;
      fixture.settings.themeMode=theme;
      fixture.settings.provider={kind:'openaiCompatible',baseUrl:'https://compatible.example/v1',model:'provider-selected-model',models:['provider-selected-model'],rememberKey:true};
      fixture.threads=fixture.threads.map(t=>({...t,contextMemo:'',summarizedThroughMessageId:null}));
      await context.addInitScript(data=>{
        if (!localStorage.getItem('compat-seeded')) {
          localStorage.setItem('flutter.dreamtide.v2.state',JSON.stringify(JSON.stringify(data)));
          localStorage.setItem('flutter.dreamtide.provider.apiKey.web',JSON.stringify('fake-browser-test-key'));
          localStorage.setItem('compat-seeded','1');
        }
      },fixture);
      const page = await context.newPage(); page.setDefaultTimeout(20000);
      const errors=[];page.on('pageerror',e=>errors.push(e.stack||e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
      const bodies=[];let mode='empty';
      await page.route('https://compatible.example/**',async route=>{
        const request=route.request();if(request.method()==='OPTIONS')return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});
        assert.equal(new URL(request.url()).pathname,'/v1/chat/completions');
        assert.equal(request.headers()['authorization'],'Bearer fake-browser-test-key');
        const body=request.postDataJSON();bodies.push(body);
        assert.equal(body.model,'provider-selected-model');assert.equal(body.max_tokens,undefined);
        if(mode==='empty' && body.stream===true)return route.fulfill({status:200,contentType:'text/event-stream',body:'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n'});
        if(mode==='error')return route.fulfill({status:200,contentType:'text/event-stream',body:'event: error\ndata: {"error":{"message":"测试供应商上游暂时不可用"}}\n\n'});
        return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({choices:[{message:{content:mode==='retry'?'重试成功并保留原消息':'兼容回退回复成功'},finish_reason:'stop'}]})});
      });
      await page.goto((process.env.DREAMTIDE_QA_BASE_URL || 'http://127.0.0.1:8089/Dreamtide/') + '#/chat/thread_gu',{waitUntil:'networkidle'});
      await page.locator('flt-semantics-placeholder').waitFor({state:'attached'});
      await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
      await page.getByRole('textbox').last().waitFor({state:'attached'});
      assert.match(await page.title(),/Dreamtide|触梦/);
      const send=async text=>{await page.getByRole('textbox').last().focus();await page.keyboard.press('Control+A');await page.keyboard.insertText(text);await page.waitForTimeout(150);await page.getByRole('button',{name:'发送',exact:true}).evaluate(e=>e.click())};
      const read=()=>page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.dreamtide.v2.state'))));
      await send('请自然接话');
      await page.getByRole('button',{name:'长按消息操作 兼容回退回复成功',exact:true}).waitFor();
      assert.deepEqual(bodies.map(b=>b.stream),[true,false]);
      mode='error';await send('继续聊下一句');
      await page.getByText(/测试供应商上游暂时不可用/).waitFor();
      await page.screenshot({path:`.tmp/compat-error-${theme}.png`});
      assert.equal(bodies.length,3);
      mode='retry';await page.getByRole('button',{name:'重试',exact:true}).evaluate(e=>e.click());
      await page.getByRole('button',{name:'长按消息操作 重试成功并保留原消息',exact:true}).waitFor();
      await page.waitForTimeout(800);
      const saved=await read();assert.equal(saved.messages.filter(m=>!m.fromAi&&m.text==='继续聊下一句').length,1);
      assert.equal(saved.messages.filter(m=>m.fromAi).length,2);
      assert(!saved.messages.some(m=>m.text.trim()===''));
      await page.screenshot({path:`.tmp/compat-success-${theme}.png`});
      assert.equal(errors.length,0,errors.join('\n'));
      console.log(JSON.stringify({theme,thirdPartyHost:true,emptyStreamFallback:true,sseErrorVisible:true,retryNoDuplicate:true,persisted:true,consoleErrors:errors,requests:bodies.length}));
      await context.close();
    }
  }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
