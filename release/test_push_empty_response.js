const fs=require('fs'),vm=require('vm'),assert=require('assert');
const code=fs.readFileSync(require('path').join(__dirname,'../web/push_client.js'),'utf8');
const config={url:'https://gumudllyhzxoswmmweve.supabase.co',token:'test',key:'test'};
let requests=0; let responseStatus=204;
const registration={pushManager:{getSubscription:async()=>({toJSON:()=>({endpoint:'test'}),unsubscribe:async()=>true})}};
const context={URL,Uint8Array,Error,JSON,Promise,window:{PushManager:function(){},Notification:{permission:'granted'}},document:{baseURI:'https://cafe.example.com/'},location:{origin:'https://cafe.example.com'},navigator:{userAgent:'Chrome',platform:'Linux',maxTouchPoints:0,serviceWorker:{getRegistration:async()=>registration}},isSecureContext:true,PushManager:function(){},Notification:{permission:'granted'},matchMedia:()=>({matches:false}),fetch:async()=>{requests++;return {ok:responseStatus < 400,status:responseStatus,text:async()=>''}},AbortSignal:{timeout:()=>undefined}};
vm.createContext(context);vm.runInContext(code,context);
(async()=>{const result=await context.window.cafePushTest(JSON.stringify(config));assert.match(result,/Test accepted/);assert.strictEqual(requests,1); responseStatus=200; await context.window.cafePushTest(JSON.stringify(config)); assert.strictEqual(requests,2); responseStatus=500; await assert.rejects(context.window.cafePushTest(JSON.stringify(config)),/Push setup failed/); assert.strictEqual(requests,3); console.log('PASS: 204 and 200 empty responses accepted; 500 rejected');})().catch(e=>{console.error(e);process.exitCode=1});
