// Shared by the Deno Edge Function and offline Node regression tests.
export function validateProviderReceipt(payload, expectedTransaction, expectedInvoice) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) throw Error('Invalid provider response');
  if (payload.status !== 'confirmed' || payload.currency !== 'IQD') throw Error('Payment not confirmed in IQD');
  if (payload.transaction_id !== expectedTransaction || payload.invoice_id !== expectedInvoice) throw Error('Provider identity mismatch');
  if (!Number.isSafeInteger(payload.amount_iqd) || payload.amount_iqd <= 0) throw Error('Invalid amount');
  if (typeof payload.confirmed_at !== 'string' || !/^\d{4}-\d\d-\d\dT/.test(payload.confirmed_at) || !Number.isFinite(Date.parse(payload.confirmed_at))) throw Error('Missing confirmation time');
  if (Date.parse(payload.confirmed_at) > Date.now()+300000) throw Error('Future confirmation time');
  return { amount_iqd: payload.amount_iqd, verified_at: payload.confirmed_at };
}
export function validateRequest(payload) {
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || !uuid.test(payload.invoice_id ?? '') || typeof payload.transaction_id !== 'string' || !/^[A-Za-z0-9_.:-]{8,160}$/.test(payload.transaction_id)) throw Error('Invalid invoice or transaction');
  return { invoice_id: payload.invoice_id, transaction_id: payload.transaction_id };
}

// Compare immutable provider evidence before treating an ingestion retry as idempotent.
// A duplicate transaction with different invoice, amount, timestamp or hash is a conflict.
export function classifyExistingReceipt(existing, incoming) {
  if (!existing || !incoming || typeof existing !== 'object' || typeof incoming !== 'object') return 'conflict';
  const fields=['provider','provider_transaction_id','finance_invoice_id','confirmed_amount_iqd','currency','verified_at','provider_proof_sha256'];
  return fields.every(key=>existing[key]===incoming[key]) ? 'identical' : 'conflict';
}
