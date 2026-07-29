// revenuecat-webhook — keeps profiles.is_paid_member in sync with the
// subscriber's real entitlement state in RevenueCat.
//
// This is the ONLY code path (besides direct DB access with the service
// role key) allowed to write is_paid_member — see MEMBERSHIP_PROTECTION.sql,
// which installs a trigger rejecting that column change from any other role.
//
// Design: rather than branching on RevenueCat's event.type (INITIAL_PURCHASE,
// RENEWAL, CANCELLATION, EXPIRATION, TRANSFER, PRODUCT_CHANGE, BILLING_ISSUE,
// ...), which is easy to get subtly wrong — e.g. CANCELLATION only means
// auto-renew was turned off, not that access ended — this function treats
// every webhook delivery as nothing more than "something changed for this
// subscriber, go check the truth." It then asks RevenueCat's REST API for
// the subscriber's current entitlement state and writes exactly that. This
// is correct for every event type without enumerating any of them.
//
// Required secrets (set via `supabase secrets set`, see deployment notes):
//   REVENUECAT_WEBHOOK_AUTH   — shared secret; must match the "Authorization"
//                               header value configured in the RevenueCat
//                               dashboard's webhook settings.
//   REVENUECAT_SECRET_API_KEY — RevenueCat *secret* v1 API key (Project
//                               Settings -> API Keys -> Secret keys), used to
//                               call GET /v1/subscribers/{id}. NOT the same
//                               as the public SDK keys in revenuecat-handler.js.
//
// Auto-provided by the Supabase Edge Functions runtime (no setup needed):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Must match RC_ENTITLEMENT_ID in revenuecat-handler.js.
const ENTITLEMENT_ID = 'member';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const REVENUECAT_WEBHOOK_AUTH = Deno.env.get('REVENUECAT_WEBHOOK_AUTH');
const REVENUECAT_SECRET_API_KEY = Deno.env.get('REVENUECAT_SECRET_API_KEY');

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function isEntitled(subscriber: any): boolean {
  const ent = subscriber?.entitlements?.[ENTITLEMENT_ID];
  if (!ent) return false;
  // No expires_date means a non-expiring (e.g. lifetime/promotional) grant.
  if (!ent.expires_date) return true;
  return new Date(ent.expires_date).getTime() > Date.now();
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  if (!REVENUECAT_WEBHOOK_AUTH || !REVENUECAT_SECRET_API_KEY) {
    console.error('[revenuecat-webhook] missing REVENUECAT_WEBHOOK_AUTH or REVENUECAT_SECRET_API_KEY secret');
    return new Response('Server misconfigured', { status: 500 });
  }

  // RevenueCat sends the shared secret verbatim in the Authorization header
  // (configured in the dashboard's webhook settings) — this is how we know
  // the request is genuinely from RevenueCat and not a forged call.
  if (req.headers.get('authorization') !== REVENUECAT_WEBHOOK_AUTH) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const appUserId = payload?.event?.app_user_id;
  if (!appUserId || typeof appUserId !== 'string') {
    // Nothing to do — ack so RevenueCat doesn't retry a malformed event forever.
    return new Response('OK (no app_user_id)', { status: 200 });
  }

  // RevenueCat-generated anonymous ids (no logged-in Supabase user yet) have
  // no matching profiles row — nothing to sync.
  if (appUserId.startsWith('$RCAnonymousID:')) {
    return new Response('OK (anonymous)', { status: 200 });
  }

  try {
    const rcRes = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`, {
      headers: { Authorization: `Bearer ${REVENUECAT_SECRET_API_KEY}` },
    });

    if (!rcRes.ok) {
      console.error(`[revenuecat-webhook] RevenueCat API returned ${rcRes.status} for ${appUserId}`);
      // 5xx so RevenueCat retries — this might be a transient RC API issue.
      return new Response('Failed to fetch subscriber', { status: 502 });
    }

    const { subscriber } = await rcRes.json();
    const entitled = isEntitled(subscriber);

    const { error } = await supabase
      .from('profiles')
      .update({ is_paid_member: entitled })
      .eq('id', appUserId);

    if (error) {
      console.error(`[revenuecat-webhook] Supabase update failed for ${appUserId}:`, error.message);
      return new Response('Failed to update profile', { status: 500 });
    }

    return new Response('OK', { status: 200 });
  } catch (e) {
    console.error('[revenuecat-webhook] unexpected error:', e);
    return new Response('Internal error', { status: 500 });
  }
});
