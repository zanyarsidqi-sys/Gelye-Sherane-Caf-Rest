import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {validateSubscription,validateExpiry,publicPayload,releaseNotesPreview} from '../../supabase/functions/browser-push/contracts.mjs';
const sub = {endpoint:'https://web.push.apple.com/QExample',keys:{p256dh:'A'.repeat(87),auth:'A'.repeat(22)}};
const config = JSON.stringify({url:'https://'+'a'.repeat(20)+'.supabase.co',token:'test-only-token',key:'public-key',vapid:'BA',expires:null});
function browser(overrides={}) {
 const calls=[];
 const subscription={toJSON:()=>sub,unsubscribe:async()=>{calls.push('unsubscribe');return true;}};
 const registration={active:true,pushManager:{getSubscription:async()=>null,subscribe:async()=>{calls.push('subscribe');return subscription;}}};
 const context={URL,Uint8Array,atob,setTimeout,clearTimeout,AbortSignal,isSecureContext:true,
 document:{baseURI:'https://cafe.example/'},location:{origin:'https://cafe.example',protocol:'https:'},matchMedia:()=>({matches:true}),
 navigator:{userAgent:'iPhone',platform:'iPhone',maxTouchPoints:1,serviceWorker:{register:async()=>{calls.push('register');return registration;}}},
 Notification:{permission:'default',requestPermission:async()=>{calls.push('permission');return 'granted';}},
 fetch:async()=>({ok:true,status:200,text:async()=>JSON.stringify({message:'Subscribed'})}),...overrides};
 context.window={PushManager:{},Notification:context.Notification};
 vm.createContext(context);
 vm.runInContext(readFileSync(new URL('../../web/push_client.js',import.meta.url),'utf8'),context);
 return {context,calls};
}
test('valid supported subscription accepted',()=>assert.equal(validateSubscription(sub).endpoint,sub.endpoint));
test('SSRF and malformed endpoint variants rejected',()=>{
 for(const endpoint of ['http://web.push.apple.com/a','https://127.0.0.1/a','https://web.push.apple.com.evil.example/a','https://user@web.push.apple.com/a','https://web.push.apple.com:8443/a','https://web.push.apple.com/a#fragment']) {
  assert.throws(()=>validateSubscription({...sub,endpoint}));
 }
});
test('invalid encryption key rejected',()=>assert.throws(()=>validateSubscription({...sub,keys:{p256dh:'short',auth:'short'}})));
test('expired and overlong device expiry rejected',()=>{
 const now=Date.parse('2026-10-12T00:00:00Z');
 assert.throws(()=>validateExpiry('2026-10-11T00:00:00Z',now));
 assert.throws(()=>validateExpiry('2028-10-12T00:00:00Z',now));
 assert.equal(validateExpiry('2026-10-13T00:00:00Z',now),'2026-10-13T00:00:00.000Z');
});
test('release payload carries validated version only',()=>{
 assert.deepEqual(JSON.parse(publicPayload('job-1','1.0.0.2')),{tag:'job-1',version:'1.0.0.2'});
 assert.deepEqual(JSON.parse(publicPayload('job-1','Private data or https://evil.example')),{tag:'job-1'});
});
test('release payload includes a bounded, sanitized release-note preview only for a valid version',()=>{
  assert.deepEqual(JSON.parse(publicPayload('job-1','1.0.0.2','  Fixes\n  and updates\tfor staff.  ')),{
    tag:'job-1',version:'1.0.0.2',notes:'Fixes and updates for staff.',
  });
  const longNotes='م'.repeat(500);
  const preview=releaseNotesPreview(longNotes);
  assert.ok(new TextEncoder().encode(preview).length<=603);
  assert.ok(preview.endsWith('…'));
  assert.deepEqual(Object.keys(JSON.parse(publicPayload('job-1','1.0.0.2','New release'))).sort(),['notes','tag','version']);
  assert.deepEqual(JSON.parse(publicPayload('job-1','invalid','Do not send')), {tag:'job-1'});
});
test('iPhone ordinary tab gets install guidance without asking permission',async()=>{
 const {context,calls}=browser({matchMedia:()=>({matches:false})});
 assert.equal(context.window.cafePushStatus(),'install_required');
 await assert.rejects(context.window.cafePushEnable(config),/Home Screen/);
 assert.equal(calls.length,0);
});
test('permission request precedes worker registration',async()=>{
 const {context,calls}=browser();
 await context.window.cafePushEnable(config);
 assert.deepEqual(calls,['permission','register','subscribe']);
});
test('failed registration at server unsubscribes browser',async()=>{
 const {context,calls}=browser({fetch:async()=>({ok:false,status:503})});
 await assert.rejects(context.window.cafePushEnable(config));
 assert.equal(calls.at(-1),'unsubscribe');
});
test('denied permission never subscribes',async()=>{
 const {context,calls}=browser({Notification:{permission:'denied',requestPermission:async()=>{throw Error('must not call');}}});
 await assert.rejects(context.window.cafePushEnable(config));assert.equal(calls.length,0);
});
test('release push shows version and release notes and ignores attacker-supplied click URL',async()=>{
 const handlers={},shown=[];let opened;
 const context={URL,self:{addEventListener:(name,fn)=>handlers[name]=fn,registration:{scope:'https://cafe.example/push/',showNotification:async(title,options)=>shown.push(options)}},
 clients:{matchAll:async()=>[],openWindow:async(url)=>opened=url}};
 vm.createContext(context);vm.runInContext(readFileSync(new URL('../../web/push/sw.js',import.meta.url),'utf8'),context);
  let pending;handlers.push({data:{json:()=>({tag:'job-2',version:'1.0.0.2',notes:'Improved dashboard and faster staff workflows.',url:'https://evil.example'})},waitUntil:p=>pending=p});await pending;
 assert.match(shown[0].body,/1\.0\.0\.2/);
  assert.match(shown[0].body,/Improved dashboard and faster staff workflows/);
  assert.match(shown[0].body,/full release notes/);
 handlers.notificationclick({notification:{close(){}},waitUntil:p=>pending=p});await pending;
 assert.equal(opened,'https://cafe.example/');
});

test('disable revokes server subscription before local unsubscribe',async()=>{
 const calls=[];
 const subObj={toJSON:()=>sub,unsubscribe:async()=>{calls.push('local-unsubscribe');return true;}};
 const registration={pushManager:{getSubscription:async()=>subObj}};
 const {context}=browser({navigator:{userAgent:'Chrome',platform:'Linux',maxTouchPoints:0,serviceWorker:{getRegistration:async()=>registration}},fetch:async()=>{calls.push('server-unsubscribe');return {ok:true,status:200,text:async()=>JSON.stringify({})};}});
 await context.window.cafePushDisable(config);
 assert.deepEqual(calls,['server-unsubscribe','local-unsubscribe']);
});
test('failed server revoke retains local subscription for retry',async()=>{
 let unsubscribed=false;
 const registration={pushManager:{getSubscription:async()=>({toJSON:()=>sub,unsubscribe:async()=>{unsubscribed=true;return true;}})}};
 const {context}=browser({navigator:{userAgent:'Chrome',platform:'Linux',maxTouchPoints:0,serviceWorker:{getRegistration:async()=>registration}},fetch:async()=>({ok:false,status:503})});
 await assert.rejects(context.window.cafePushDisable(config),/Push setup failed/);
 assert.equal(unsubscribed,false);
});

test('already granted permission does not request permission again',async()=>{
 const {context,calls}=browser({Notification:{permission:'granted',requestPermission:async()=>{throw Error('unexpected permission prompt');}}});
 await context.window.cafePushEnable(config);
 assert.deepEqual(calls,['register','subscribe']);
});
test('missing authentication blocks subscription registration',async()=>{
 const {context,calls}=browser({fetch:async()=>{throw Error('network must not be called');}});
 await assert.rejects(context.window.cafePushEnable(JSON.stringify({url:'https://'+'a'.repeat(20)+'.supabase.co',vapid:'BA'})),/authentication is missing/i);
 assert.deepEqual(calls,[]);
});

test('invalid push endpoint is rejected before browser permission prompt',async()=>{
 const {context,calls}=browser();
 await assert.rejects(context.window.cafePushEnable(JSON.stringify({url:'https://evil.example',token:'token',key:'key',vapid:'BA'})),/Invalid push service/);
 assert.deepEqual(calls,[]);
});
