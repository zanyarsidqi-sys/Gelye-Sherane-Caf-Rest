import webpush from 'npm:web-push@3.6.7';
import {validateSubscription,validateExpiry,publicPayload} from './contracts.mjs';
import {deliveryDecision,deliveryStatus,retryDecision} from './dispatch_policy.mjs';
const env=(key:string)=>Deno.env.get(key)??'';
const url=env('SUPABASE_URL'), adminKey=env('SUPABASE_SERVICE_ROLE_KEY');
const origins=env('WEB_PUSH_ALLOWED_ORIGINS').split(',').map(x=>x.trim()).filter(Boolean);
async function db(path:string, options:RequestInit={}) {
 const response=await fetch(url+'/rest/v1/'+path,{...options,headers:{apikey:adminKey,authorization:'Bearer '+adminKey,'content-type':'application/json',prefer:'return=representation',...options.headers},signal:AbortSignal.timeout(10000)});
 if(!response.ok) throw Error('Push database unavailable');
 const text=await response.text(); return text ? JSON.parse(text) : null;
}
async function send(subscription:any, tag:string, version:string|null=null) {
 const sub=validateSubscription({endpoint:subscription.endpoint,keys:{p256dh:subscription.p256dh,auth:subscription.auth_key}});
 const request=webpush.generateRequestDetails(sub,publicPayload(tag,version),{
   TTL:300,vapidDetails:{subject:env('WEB_PUSH_SUBJECT'),publicKey:env('WEB_PUSH_PUBLIC_KEY'),privateKey:env('WEB_PUSH_PRIVATE_KEY')}
 });
 const response=await fetch(request.endpoint,{method:'POST',headers:request.headers,body:request.body,redirect:'error',signal:AbortSignal.timeout(10000)});
 if(response.status===404||response.status===410) {
   await db('gs_browser_push_subscriptions?id=eq.'+subscription.id,{method:'DELETE'});
   return 'expired';
 }
 if(!response.ok) throw Error('Push delivery failed');
 return 'accepted';
}
async function matches(a:string,b:string) {
 if(!b || b.length<32) return false;
 const hash=async(s:string)=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)));
 const x=await hash(a),y=await hash(b);let different=0;
 for(let i=0;i<x.length;i++) different|=x[i]^y[i];return different===0;
}
Deno.serve(async(req:Request)=>{
 const origin=req.headers.get('origin')??'';
 const cors=origins.includes(origin)?{'access-control-allow-origin':origin,'vary':'Origin','access-control-allow-headers':'authorization,apikey,content-type,x-client-info','access-control-allow-methods':'POST,OPTIONS'}:{};
 const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{'content-type':'application/json','cache-control':'no-store',...cors}});
 if(origin&&!origins.includes(origin)) return reply(403,'Origin not allowed');
 if(req.method==='OPTIONS') return new Response(null,{status:204,headers:cors});
 if(req.method!=='POST') return reply(405,'Method not allowed');
 if(!url||!adminKey||!env('WEB_PUSH_PUBLIC_KEY')||!env('WEB_PUSH_PRIVATE_KEY')||!env('WEB_PUSH_SUBJECT')) return reply(503,'Push not configured');
 try {
  if(Number(req.headers.get('content-length')??0)>8192) return reply(413,'Request too large');
  const raw=await req.text();if(new TextEncoder().encode(raw).length>8192)return reply(413,'Request too large');
  let input:any;try{input=JSON.parse(raw);}catch{return reply(400,'Invalid request');}
  const bearer=req.headers.get('authorization')??'';
  if(input.action==='dispatch') {
   if(!await matches(bearer.replace(/^Bearer /,''),env('WEB_PUSH_DISPATCH_SECRET'))) return reply(401,'Unauthorized');
   const jobs=await db('rpc/gs_claim_browser_push_jobs',{method:'POST',body:'{}'});
   // Bounded parallel delivery stays inside the two-minute claim lease.
   await Promise.all(jobs.map(async(job:any)=>{
    const filter='id=eq.'+job.id+'&lease_id=eq.'+job.lease_id;
    try {
     const eligible=await db('rpc/gs_browser_push_eligible',{method:'POST',body:JSON.stringify({p_subscription:job.subscription_id,p_section:job.section_key})});
     const rows=eligible?await db('gs_browser_push_subscriptions?id=eq.'+job.subscription_id+'&limit=1'):[];
     let version:string|null=null;
     if(job.source_table==='gs_app_release_events') {
       const events=await db('gs_app_release_events?select=release_id&id=eq.'+job.source_id+'&action=eq.publish');
       const releases=events.length?await db('gs_app_releases?select=version&id=eq.'+events[0].release_id+'&status=eq.published&platform=eq.web&channel=eq.stable'):[];
       if(deliveryDecision({eligible,subscriptionPresent:rows.length>0,releaseEvent:true,publishedRelease:releases.length>0})==='failed') {
         await db('gs_browser_push_jobs?'+filter,{method:'PATCH',body:JSON.stringify({status:'failed'})});
         return;
       }
       version=releases[0].version;
     }
     // A 404/410 response means the push subscription was removed, not delivered.
     // Never mark such jobs as sent; preserve accurate release-delivery history.
     const outcome=rows.length ? await send(rows[0],'job-'+job.id,version) : 'missing';
     await db('gs_browser_push_jobs?'+filter,{method:'PATCH',body:JSON.stringify({status:deliveryStatus(outcome)})});
    }catch {
     await db('gs_browser_push_jobs?'+filter,{method:'PATCH',body:JSON.stringify({status:retryDecision(job.attempts),available_at:new Date(Date.now()+60000*job.attempts).toISOString()})});
    }
   }));
   return reply(200,'Dispatch batch processed');
  }
  if(!['subscribe','test','unsubscribe'].includes(input.action)) return reply(400,'Unsupported action');
  // Verify the JWT with Auth before reading any claims; metadata is never authorization.
  const authResponse=await fetch(url+'/auth/v1/user',{headers:{apikey:adminKey,authorization:bearer},signal:AbortSignal.timeout(10000)});
  if(!authResponse.ok)return reply(401,'Sign in required');
  const user=await authResponse.json();
  const part=bearer.replace(/^Bearer /,'').split('.')[1];
  const padded=part.replace(/-/g,'+').replace(/_/g,'/');
  const claims=JSON.parse(atob(padded+'='.repeat((4-padded.length%4)%4)));
  if(claims.aal!=='aal2'||claims.sub!==user.id||!/^\w{8}-\w{4}-\w{4}-\w{4}-\w{12}$/.test(claims.session_id))return reply(403,'MFA required');
  const profiles=await db('employee_profiles?select=user_id&user_id=eq.'+user.id+'&is_active=eq.true');
  if(profiles.length!==1)return reply(403,'Active employee required');
  const permissions=await db('employee_section_permissions?select=section_key&user_id=eq.'+user.id+'&section_key=eq.dashboard&can_view=eq.true');
  if(!permissions.length)return reply(403,'Employee access required');
  let subscription:any, expires:string|null;
  try{subscription=validateSubscription(input.subscription);expires=validateExpiry(input.expires_at);}catch{return reply(400,'Invalid subscription');}
  const own='user_id=eq.'+user.id+'&session_id=eq.'+claims.session_id+'&endpoint=eq.'+encodeURIComponent(subscription.endpoint);
  if(input.action==='unsubscribe') {await db('gs_browser_push_subscriptions?'+own,{method:'DELETE'});return reply(200,'Removed');}
  if(input.action==='subscribe') {
   // A browser may renew its push keys on the same device. Do not count
   // that renewal as an eleventh device or leave an obsolete key behind.
   const existing=await db('gs_browser_push_subscriptions?select=id,endpoint,session_id&user_id=eq.'+user.id);
   const sameDevice=existing.find((row:any)=>row.endpoint===subscription.endpoint && row.session_id===claims.session_id);
   if(!sameDevice && existing.length>=10)return reply(409,'Device limit reached; remove an old device subscription');
   if(sameDevice) {
     await db('gs_browser_push_subscriptions?id=eq.'+sameDevice.id+'&user_id=eq.'+user.id+'&session_id=eq.'+claims.session_id,{method:'PATCH',body:JSON.stringify({p256dh:subscription.keys.p256dh,auth_key:subscription.keys.auth,expires_at:expires})});
   } else {
     await db('gs_browser_push_subscriptions',{method:'POST',body:JSON.stringify({user_id:user.id,session_id:claims.session_id,endpoint:subscription.endpoint,p256dh:subscription.keys.p256dh,auth_key:subscription.keys.auth,expires_at:expires})});
   }
   return reply(200,'Subscribed');
  }
  // Atomic per-device cooldown, including concurrent test calls.
  const rows=await db('gs_browser_push_subscriptions?'+own+'&or=(last_test_at.is.null,last_test_at.lt.'+encodeURIComponent(new Date(Date.now()-60000).toISOString())+')',
    {method:'PATCH',body:JSON.stringify({last_test_at:new Date().toISOString()})});
  if(!rows.length)return reply(429,'Enable notifications first or wait one minute');
  const eligible=await db('rpc/gs_browser_push_eligible',{method:'POST',body:JSON.stringify({p_subscription:rows[0].id,p_section:'dashboard'})});
  if(!eligible)return reply(403,'Session no longer eligible');
  const result=await send(rows[0],'test-notification');
  return reply(result==='accepted'?200:410,result==='accepted'?'Accepted by push provider':'Subscription expired');
 } catch {return reply(503,'Push service unavailable');}
});
