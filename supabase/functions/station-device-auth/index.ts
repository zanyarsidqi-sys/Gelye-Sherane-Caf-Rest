import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// Source-only endpoint. Deploy behind HTTPS with platform edge rate limiting.
// SQL enforces durable per-username failed-attempt limits; edge rate limits
// per source IP are additionally required before exposing public login.
const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db = createClient(url, serviceKey, { auth: { persistSession: false } });
const enc = new TextEncoder();
async function digest(s: string) {
 const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s)));
 return Array.from(bytes, b => b.toString(16).padStart(2,"0")).join("");
}
function response(data: unknown, status = 200) {
 return new Response(JSON.stringify(data), { status, headers: {
  "content-type":"application/json", "cache-control":"no-store", "pragma":"no-cache" }});
}
Deno.serve(async req => {
 if (req.method !== "POST") return response({error:"Method not allowed"},405);
 // Never accept caller-supplied station identity as authority. RPCs bind session token to station.
 // Enforce IP rate limits at the gateway before enabling this public endpoint.
 let body: Record<string,unknown>;
 try {
  const raw = await req.text();
  if (enc.encode(raw).byteLength > 4096) return response({error:"Request too large"},413);
  const parsed: unknown = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw Error();
  body = parsed as Record<string,unknown>;
 } catch { return response({error:"Invalid request"},400); }
 if (body.action === "login") {
  if (typeof body.username !== "string" || typeof body.password !== "string" ||
   body.username.length > 64 || body.password.length > 128 || body.username.length < 4)
   return response({error:"Invalid request"},400);
  const token = crypto.randomUUID()+"."+crypto.randomUUID();
  const {data,error} = await db.rpc("gs_1223_device_login", {
   p_username:body.username, p_password:body.password, p_token_hash:await digest(token) });
  if (error) return response({error:"Login unavailable"},503);
  if (!data?.length) return response({error:"Invalid credentials or temporarily blocked"},401);
  return response({token,station:data[0].station_key,session_id:data[0].session_id,
   expires_at:data[0].expires_at,order_print:data[0].order_print,bill_print:data[0].bill_print});
 }
 if (body.action === "heartbeat" || body.action === "logout") {
  if (typeof body.token !== "string" || body.token.length > 256 || body.token.length < 20)
   return response({error:"Invalid session"},401);
  if (body.action === "logout") {
   const {data,error} = await db.rpc("gs_1226_device_logout", {p_token_hash:await digest(body.token)});
   if (error) return response({error:"Logout unavailable"},503);
   return response({revoked:data===true});
  }
  const {data,error} = await db.rpc("gs_1223_device_heartbeat", {
   p_token_hash:await digest(body.token),p_printer_ready:body.printer_ready===true });
  if (error || !data?.length) return response({error:"Expired or revoked session"},401);
  return response({station:data[0].station_key,order_print:data[0].order_print,
   bill_print:data[0].bill_print,expires_at:data[0].expires_at});
 }
 if (body.action === "claim_print" || body.action === "ack_print") {
  if (typeof body.token !== "string" || body.token.length < 20 || body.token.length > 256)
   return response({error:"Invalid session"},401);
  const tokenHash = await digest(body.token);
  if (body.action === "claim_print") {
   const {data,error} = await db.rpc("gs_1227_device_claim_print",{p_token_hash:tokenHash});
   if (error) return response({error:"Unable to claim station ticket"},403);
   return response({ticket:Array.isArray(data) && data.length ? data[0] : null});
  }
  if (typeof body.ticket_id !== "number" || !Number.isSafeInteger(body.ticket_id)
    || body.ticket_id <= 0 || typeof body.attempt !== "number"
    || !Number.isSafeInteger(body.attempt) || body.attempt <= 0
    || !["received","printed","failed"].includes(String(body.result))
    || (body.error != null && (typeof body.error !== "string" || body.error.length > 500)))
   return response({error:"Invalid print acknowledgment"},400);
  const {data,error} = await db.rpc("gs_1227_device_ack_print",{
   p_token_hash:tokenHash,p_ticket_id:body.ticket_id,p_attempt:body.attempt,
   p_result:body.result,p_error:body.error ?? null
  });
  if (error || data !== true) return response({error:"Print acknowledgment rejected"},409);
  return response({acknowledged:true});
 }

 if (body.action === "resolve_print") {
  if (typeof body.token !== "string" || body.token.length < 20 || body.token.length > 256
      || !Number.isSafeInteger(body.ticket_id) || Number(body.ticket_id) <= 0
      || !Number.isSafeInteger(body.attempt) || Number(body.attempt) <= 0)
   return response({error:"Invalid print request"},400);
  const {data,error} = await db.rpc("gs_1230_resolve_station_ticket",{
   p_token_hash:await digest(body.token),
   p_ticket_id:body.ticket_id,p_attempt:body.attempt
  });
  if (error || !data) return response({error:"Print ticket unavailable"},403);
  return response({ticket:data});
 }
 if (["claim_revision_print","resolve_revision_print","ack_revision_print"].includes(String(body.action))) {
  if (typeof body.token !== "string" || body.token.length < 20 || body.token.length > 256)
   return response({error:"Invalid station session"},401);
  const p_token_hash = await digest(body.token);
  if (body.action === "claim_revision_print") {
   const {data,error} = await db.rpc("gs_1233_claim_revision_print",{p_token_hash});
   if (error) return response({error:"Revision claim unavailable"},403);
   return response({ticket:Array.isArray(data) && data.length ? data[0] : null});
  }
  if (!Number.isSafeInteger(body.ticket_id) || Number(body.ticket_id)<=0
   || !Number.isSafeInteger(body.attempt) || Number(body.attempt)<=0)
   return response({error:"Invalid revision ticket"},400);
  if (body.action === "resolve_revision_print") {
   const {data,error} = await db.rpc("gs_1233_resolve_revision_print",{
    p_token_hash,p_ticket_id:body.ticket_id,p_attempt:body.attempt});
   if (error || !data) return response({error:"Revision payload unavailable"},403);
   return response({ticket:data});
  }
  if (!["received","printed","failed"].includes(String(body.result)) ||
   (body.error != null && (typeof body.error !== "string" || body.error.length>500)))
   return response({error:"Invalid revision acknowledgment"},400);
  const {data,error} = await db.rpc("gs_1233_ack_revision_print",{
   p_token_hash,p_ticket_id:body.ticket_id,p_attempt:body.attempt,
   p_result:body.result,p_error:body.error ?? null});
  if (error || data!==true) return response({error:"Revision acknowledgment rejected"},409);
  return response({acknowledged:true});
 }
 return response({error:"Unknown action"},400);
});
