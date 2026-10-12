import assert from 'node:assert/strict';
import {deliveryDecision,deliveryStatus,retryDecision} from '../supabase/functions/browser-push/dispatch_policy.mjs';
for (const eligible of [false,true]) for (const subscriptionPresent of [false,true]) for (const publishedRelease of [false,true]) {
 const expected=eligible&&subscriptionPresent&&publishedRelease?'send':'failed';
 assert.equal(deliveryDecision({eligible,subscriptionPresent,releaseEvent:true,publishedRelease}),expected);
}
assert.equal(deliveryDecision({eligible:true,subscriptionPresent:true,releaseEvent:false,publishedRelease:false}),'send');
assert.equal(deliveryDecision({eligible:false,subscriptionPresent:true,releaseEvent:false,publishedRelease:false}),'failed');
for (const outcome of ['expired','missing','rejected','accepted']) assert.equal(deliveryStatus(outcome),outcome==='accepted'?'sent':'failed');
assert.equal(retryDecision(1),'pending');assert.equal(retryDecision(4),'pending');assert.equal(retryDecision(5),'failed');
console.log('PASS: 15 executable dispatcher policy assertions');
