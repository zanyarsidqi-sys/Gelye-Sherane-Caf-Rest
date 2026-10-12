// Deployment-gated provider API verification. Never trust a client-supplied paid flag.
// Required secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FINANCE_INGEST_TOKEN,
// PROVIDER_LOOKUP_BASE_URL (fixed HTTPS endpoint), PROVIDER_API_TOKEN, PROVIDER_NAME.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { validateProviderReceipt, validateRequest, classifyExistingReceipt } from './receipt_contract.mjs';
const enc = new TextEncoder();
const reply=(status:number,message:string)=>new Response(JSON.stringify({message,invoice_settled:false,unified_ledger_posted:false,dashboard_certified:false}),{status,headers:{'content-type':'application/json','cache-control':'no-store'}});
async function tokenMatches(received:string,secret:string):Promise<boolean> {
  const hash=async (v:string)=>new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(v)));
  const a=await hash(received),b=await hash(secret);let difference=0;
  for(let i=0;i<a.length;i++) difference|=a[i]^b[i];return difference===0;
}
Deno.serve(async(req:Request)=>{
  if(req.method!=='POST') return reply(405,'Method not allowed');
  const dbUrl=Deno.env.get('SUPABASE_URL'),key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const secret=Deno.env.get('FINANCE_INGEST_TOKEN'),base=Deno.env.get('PROVIDER_LOOKUP_BASE_URL');
  const apiKey=Deno.env.get('PROVIDER_API_TOKEN'),provider=Deno.env.get('PROVIDER_NAME');
  if(!dbUrl||!key||!secret||secret.length<32||!base||!apiKey||!provider||!/^[A-Za-z0-9_-]{2,80}$/.test(provider)) return reply(503,'Provider verification not configured');
  let lookup:URL;
  try {lookup=new URL(base);if(lookup.protocol!=='https:'||lookup.username||lookup.password||lookup.search||lookup.hash||lookup.port) throw Error();}
  catch {return reply(503,'Provider verification endpoint invalid');}
  const authorization=req.headers.get('authorization')??'';
  if(!authorization.startsWith('Bearer ')||!(await tokenMatches(authorization.slice(7),secret))) return reply(401,'Unauthorized');
  const length=Number(req.headers.get('content-length')??0);
  if(length>2048) return reply(413,'Request too large');
  let input:{invoice_id:string,transaction_id:string};
  try {const raw=await req.text();if(enc.encode(raw).length>2048) return reply(413,'Request too large');input=validateRequest(JSON.parse(raw));}
  catch {return reply(400,'Invalid request');}
  const db=createClient(dbUrl,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:invoice,error:invoiceError}=await db.from('gs_motel_food_finance_invoices').select('id,total_iqd,payment_status').eq('id',input.invoice_id).maybeSingle();
  if(invoiceError||!invoice||invoice.payment_status!=='unpaid'||!Number.isSafeInteger(Number(invoice.total_iqd))||Number(invoice.total_iqd)<=0) return reply(409,'Invoice not eligible');
  // Only the configured provider host is contacted; no URL comes from caller input.
  const endpoint=new URL(lookup.toString().replace(/\/$/,'')+'/'+encodeURIComponent(input.transaction_id));
  let providerData:unknown;
  try {
    const response=await fetch(endpoint,{headers:{authorization:'Bearer '+apiKey,accept:'application/json'},redirect:'error',signal:AbortSignal.timeout(8000)});
    if(!response.ok) return reply(502,'Provider did not confirm transaction');
    if(Number(response.headers.get('content-length')??0)>8192) return reply(502,'Provider response too large');
    const body=await response.text();if(enc.encode(body).length>8192) return reply(502,'Provider response too large');
    providerData=JSON.parse(body);
  }catch{return reply(502,'Provider verification unavailable');}
  let attested:{amount_iqd:number,verified_at:string};
  try {attested=validateProviderReceipt(providerData,input.transaction_id,input.invoice_id);}
  catch{return reply(409,'Provider evidence mismatch');}
  if(attested.amount_iqd!==Number(invoice.total_iqd)) return reply(409,'Provider amount differs from invoice');
  const evidence=enc.encode(JSON.stringify({provider,transaction_id:input.transaction_id,invoice_id:input.invoice_id,...attested}));
  const proof=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',evidence)),v=>v.toString(16).padStart(2,'0')).join('');
  const {error:writeError}=await db.from('gs_motel_prepaid_verified_receipts').insert({provider,provider_transaction_id:input.transaction_id,finance_invoice_id:input.invoice_id,confirmed_amount_iqd:attested.amount_iqd,currency:'IQD',verified_at:attested.verified_at,verified_by_service:'provider-api-lookup-v1',provider_proof_sha256:proof});
  if(writeError) {
    // Unique collisions must be reconciled against immutable evidence; never
    // accept a replay merely because the transaction reference already exists.
    const {data:existing,error:readError}=await db.from('gs_motel_prepaid_verified_receipts')
      .select('provider,provider_transaction_id,finance_invoice_id,confirmed_amount_iqd,currency,verified_at,provider_proof_sha256')
      .eq('provider',provider).eq('provider_transaction_id',input.transaction_id).maybeSingle();
    if(readError||!existing) return reply(409,'Receipt write failed or invoice has a conflicting receipt');
    const classification=classifyExistingReceipt(existing,{
      provider,provider_transaction_id:input.transaction_id,finance_invoice_id:input.invoice_id,
      confirmed_amount_iqd:attested.amount_iqd,currency:'IQD',verified_at:attested.verified_at,
      provider_proof_sha256:proof
    });
    if(classification==='identical') return reply(200,'Identical provider receipt already recorded; allocation remains separate');
    return reply(409,'Provider receipt conflicts with immutable existing evidence');
  }
  return reply(201,'Verified receipt recorded; separate authorized allocation required');
});
