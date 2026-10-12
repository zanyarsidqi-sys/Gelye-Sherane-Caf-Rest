import test from 'node:test';
import assert from 'node:assert/strict';
import {classifyExistingReceipt} from '../supabase/functions/verify-prepaid-receipt/receipt_contract.mjs';
const base={provider:'verified_provider',provider_transaction_id:'transaction_123',finance_invoice_id:'f47ac10b-58cc-4372-a567-0e02b2c3d479',confirmed_amount_iqd:5000,currency:'IQD',verified_at:'2026-10-12T09:00:00Z',provider_proof_sha256:'a'.repeat(64)};
test('exact immutable evidence replay is idempotent',()=>assert.equal(classifyExistingReceipt(base,{...base}),'identical'));
for(const [field,value] of [['provider','other'],['provider_transaction_id','different'],['finance_invoice_id','b47ac10b-58cc-4372-a567-0e02b2c3d479'],['confirmed_amount_iqd',6000],['currency','USD'],['verified_at','2026-10-12T09:00:01Z'],['provider_proof_sha256','b'.repeat(64)]]){
 test('rejects replay mismatch '+field,()=>assert.equal(classifyExistingReceipt(base,{...base,[field]:value}),'conflict'));
}
test('rejects missing receipt',()=>assert.equal(classifyExistingReceipt(null,base),'conflict'));
