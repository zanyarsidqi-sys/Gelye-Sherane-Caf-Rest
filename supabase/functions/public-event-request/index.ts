// Public event request endpoint: deny-by-default until secure intake RPC exists.
// Verify Turnstile before any database operation; do not expose service-role key.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async (req) => {
  const headers = { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
  if (req.method !== 'POST') return new Response(JSON.stringify({error:'Method not allowed'}),{status:405,headers});
  if (Number(req.headers.get('content-length') || '0') > 16384)
    return new Response(JSON.stringify({error:'Request too large'}),{status:413,headers});
  const secret=Deno.env.get('TURNSTILE_SECRET_KEY');
  const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const url=Deno.env.get('SUPABASE_URL');
  const salt=Deno.env.get('EVENT_RATE_LIMIT_SALT');
  if (!secret || !serviceKey || !url || !salt)
    return new Response(JSON.stringify({error:'Service not configured'}),{status:503,headers});
  let body: Record<string, unknown>;
  try { body=await req.json(); } catch {
    return new Response(JSON.stringify({error:'Invalid JSON'}),{status:400,headers});
  }
  const token=body.turnstile_token;
  if (typeof token!=='string' || token.length>4096)
    return new Response(JSON.stringify({error:'Verification required'}),{status:400,headers});
  const verification=await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify',{
    method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({secret,response:token}),
  });
  if (!verification.ok || !(await verification.json()).success)
    return new Response(JSON.stringify({error:'Verification failed'}),{status:403,headers});
  const ip=req.headers.get('cf-connecting-ip') || '';
  if (!ip) return new Response(JSON.stringify({error:'Request origin unavailable'}),{status:403,headers});
  const bytes=new TextEncoder().encode(salt+':'+ip);
  const digest=await crypto.subtle.digest('SHA-256',bytes);
  const hash=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
  const db=createClient(url,serviceKey,{auth:{persistSession:false}});
  const {data, error}=await db.rpc('gs_public_event_rate_limit',{p_key_hash:hash});
  if (error || data!==true)
    return new Response(JSON.stringify({error:'Rate limit reached or service unavailable'}),{status:429,headers});
  const required = ['customer_name','customer_phone','event_type','event_start',
    'event_end','guest_count','business_model','venue_scope','products'];
  if (required.some(k => !(k in body)) || !Array.isArray(body.products) ||
      body.products.length > 100 || !Array.isArray(body.table_ids) && body.venue_scope === 'selected_tables') {
    return new Response(JSON.stringify({error:'Invalid event details'}),{status:400,headers});
  }
  const { data: eventId, error: createError } = await db.rpc('gs_public_event_create', {
    p_customer_name:body.customer_name,p_customer_phone:body.customer_phone,
    p_event_type:body.event_type,p_start:body.event_start,p_end:body.event_end,
    p_guest_count:body.guest_count,p_business_model:body.business_model,
    p_services:body.requested_services ?? null,p_products:body.products,
    p_venue_scope:body.venue_scope,p_table_ids:body.table_ids ?? [],
  });
  if (createError) return new Response(JSON.stringify({
    error:'Unable to accept the event request. Check the details and availability.'
  }),{status:400,headers});
  return new Response(JSON.stringify({request_id:eventId,status:'pending_admin'}),
    {status:202,headers});
});
