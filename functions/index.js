/**
 * DailyMinder AI proxy (Phase C).
 *
 * The production-safe way to offer cloud AI at scale:
 *  - The provider API key lives ONLY here (a Cloud Functions secret) — never in
 *    the app, so it can't be extracted/abused.
 *  - Every request must carry a valid Firebase ID token (authenticated user).
 *  - Per-user daily + monthly quotas (Firestore counters) cap cost.
 *  - Passes the OpenAI-compatible request through and returns the response
 *    verbatim, so the Flutter client parses it exactly as the direct path.
 *
 * Swap providers by changing PROVIDER_URL / the model the client sends and the
 * AI_PROVIDER_KEY secret (e.g. NVIDIA now → Google Gemini's OpenAI-compatible
 * endpoint for production licensing).
 */
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { sanitizeBody } = require('./sanitize');

admin.initializeApp();

const AI_PROVIDER_KEY = defineSecret('AI_PROVIDER_KEY');

// OpenAI-compatible chat-completions endpoint. Change for a different provider.
const PROVIDER_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';

// Cost guardrails (tune to your budget).
const DAILY_LIMIT = 50; // requests / user / day
const MONTHLY_LIMIT = 800; // requests / user / month

// Give back a reserved quota slot when the upstream call didn't succeed.
async function refundQuota(ref, day, month) {
  try {
    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const d = snap.data();
      const dayCount = d.day === day ? Math.max(0, (d.dayCount || 0) - 1) : d.dayCount || 0;
      const monthCount =
        d.month === month ? Math.max(0, (d.monthCount || 0) - 1) : d.monthCount || 0;
      tx.set(ref, { dayCount, monthCount }, { merge: true });
    });
  } catch (_) {
    /* best-effort refund */
  }
}

exports.aiProxy = onRequest(
  { secrets: [AI_PROVIDER_KEY], cors: true, region: 'us-central1', timeoutSeconds: 60 },
  async (req, res) => {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'POST only' });
      }

      // --- Authenticate (Firebase ID token) ---
      const authz = req.get('Authorization') || '';
      const m = authz.match(/^Bearer (.+)$/);
      if (!m) return res.status(401).json({ error: 'missing token' });
      let uid;
      try {
        // checkRevoked: true rejects disabled/revoked sessions.
        const decoded = await admin.auth().verifyIdToken(m[1], true);
        // Reject anonymous identities (cheap to mint → quota-bypass vector).
        if (decoded.firebase?.sign_in_provider === 'anonymous') {
          return res.status(403).json({ error: 'anonymous not allowed' });
        }
        uid = decoded.uid;
      } catch (_) {
        return res.status(401).json({ error: 'invalid token' });
      }

      // --- Per-user quota (atomic Firestore counter) ---
      const now = new Date();
      const day = now.toISOString().slice(0, 10); // YYYY-MM-DD
      const month = day.slice(0, 7); // YYYY-MM
      const ref = admin.firestore().collection('ai_usage').doc(uid);

      // Sanitize once and reject empty requests up front — a guaranteed-400 body
      // must never reserve a quota slot or hit the upstream (that would be an
      // infinitely-refundable loop; see the refund policy below).
      const body = sanitizeBody(req.body);
      if (body.messages.length === 0) {
        return res.status(400).json({ error: 'no messages' });
      }

      const allowed = await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const d = snap.exists ? snap.data() : {};
        const dayCount = d.day === day ? d.dayCount || 0 : 0;
        const monthCount = d.month === month ? d.monthCount || 0 : 0;
        if (dayCount >= DAILY_LIMIT || monthCount >= MONTHLY_LIMIT) return false;
        tx.set(
          ref,
          {
            day,
            month,
            dayCount: dayCount + 1,
            monthCount: monthCount + 1,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return true;
      });
      if (!allowed) return res.status(429).json({ error: 'quota exceeded' });

      // --- Proxy to the provider (key stays server-side; body sanitized) ---
      // Abort a slow upstream well before the 60s function timeout so the
      // instance frees up and the reserved quota slot is refunded (a function
      // timeout would leave it silently consumed).
      const ctrl = new AbortController();
      const abortTimer = setTimeout(() => ctrl.abort(), 45000);
      let upstream;
      try {
        upstream = await fetch(PROVIDER_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${AI_PROVIDER_KEY.value()}`,
          },
          body: JSON.stringify(body),
          signal: ctrl.signal,
        });
      } catch (e) {
        // Network error or abort → transient; refund and surface a gateway error.
        await refundQuota(ref, day, month);
        const timedOut = e && e.name === 'AbortError';
        return res
          .status(timedOut ? 504 : 502)
          .json({ error: timedOut ? 'upstream timeout' : 'upstream unreachable' });
      } finally {
        clearTimeout(abortTimer);
      }
      let text;
      try {
        text = await upstream.text();
      } catch (e) {
        await refundQuota(ref, day, month); // body read failed → transient
        return res.status(502).json({ error: 'upstream read failed' });
      }
      // Refund ONLY transient/provider-side failures. A client-caused 4xx (bad
      // request, content policy) MUST consume quota, else it's an infinitely
      // refundable loop that defeats the cap.
      if (upstream.status >= 500 || upstream.status === 429) {
        await refundQuota(ref, day, month);
      }
      return res
        .status(upstream.status)
        .set('Content-Type', 'application/json')
        .send(text);
    } catch (e) {
      console.error('aiProxy error', e);
      return res.status(500).json({ error: 'proxy error' });
    }
  },
);
