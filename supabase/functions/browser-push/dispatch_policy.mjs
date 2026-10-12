// Pure, executable decision policy shared by the live dispatcher and Node tests.
export function deliveryDecision({eligible, subscriptionPresent, releaseEvent, publishedRelease}) {
  if (!eligible || !subscriptionPresent) return 'failed';
  if (releaseEvent && !publishedRelease) return 'failed';
  return 'send';
}
export function deliveryStatus(outcome) {
  return outcome === 'accepted' ? 'sent' : 'failed';
}
export function retryDecision(attempts) {
  return Number.isInteger(attempts) && attempts >= 5 ? 'failed' : 'pending';
}
