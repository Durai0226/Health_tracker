/**
 * Pure request-sanitization for the DailyMinder AI proxy.
 *
 * Kept in its own module (no firebase-admin) so it can be unit-tested under
 * plain Node without initializing the Admin SDK. index.js re-uses it.
 */

// Server pins the model + caps size so a client can't request an expensive
// model / huge generation (count-only quotas don't bound per-request cost).
const ALLOWED_MODELS = ['meta/llama-3.1-8b-instruct'];
const DEFAULT_MODEL = ALLOWED_MODELS[0];
const MAX_OUTPUT_TOKENS = 1024;
const MAX_INPUT_CHARS = 8000; // total across messages

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

module.exports = {
  sanitizeBody,
  ALLOWED_MODELS,
  DEFAULT_MODEL,
  MAX_OUTPUT_TOKENS,
  MAX_INPUT_CHARS,
};
