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

admin.initializeApp();

const AI_PROVIDER_KEY = defineSecret('AI_PROVIDER_KEY');

// OpenAI-compatible chat-completions endpoint. Change for a different provider.
const PROVIDER_URL = 'https://integrate.api.nvidia.com/v1/chat/completions';

// Server pins the model + caps size so a client can't request an expensive
// model / huge generation (count-only quotas don't bound per-request cost).
const ALLOWED_MODELS = ['meta/llama-3.1-8b-instruct'];
const DEFAULT_MODEL = ALLOWED_MODELS[0];
const MAX_OUTPUT_TOKENS = 1024;
const MAX_INPUT_CHARS = 8000; // total across messages

// Cost guardrails (tune to your budget).
const DAILY_LIMIT = 50; // requests / user / day
const MONTHLY_LIMIT = 800; // requests / user / month

// Build a safe upstream body from the (untrusted) client body.
function sanitizeBody(raw) {
  const b = raw && typeof raw === 'object' ? raw : {};
  const model = ALLOWED_MODELS.includes(b.model) ? b.model : DEFAULT_MODEL;
  let messages = Array.isArray(b.messages) ? b.messages : [];
  // Cap total content size.
  let total = 0;
  messages = messages
    .filter((m) => m && typeof m.content === 'string')
    .map((m) => {
      const room = Math.max(0, MAX_INPUT_CHARS - total);
      const content = m.content.slice(0, room);
      total += content.length;
      return { role: m.role === 'system' ? 'system' : 'user', content };
    })
    .filter((m) => m.content.length > 0);
  const maxTokens = Math.min(
    Number.isFinite(b.max_tokens) ? b.max_tokens : MAX_OUTPUT_TOKENS,
    MAX_OUTPUT_TOKENS,
  );
  const temperature =
    typeof b.temperature === 'number' ? Math.max(0, Math.min(1, b.temperature)) : 0.3;
  return { model, messages, max_tokens: maxTokens, temperature, stream: false };
}

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
      let upstream;
      try {
        upstream = await fetch(PROVIDER_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${AI_PROVIDER_KEY.value()}`,
          },
          body: JSON.stringify(sanitizeBody(req.body)),
        });
      } catch (e) {
        await refundQuota(ref, day, month); // don't burn the user's budget
        throw e;
      }
      const text = await upstream.text();
      if (!upstream.ok) {
        await refundQuota(ref, day, month); // provider error → refund the slot
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
