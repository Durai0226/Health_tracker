/**
 * Backend unit tests for the AI-proxy request sanitizer.
 * Plain Node (node:assert + node:test) — no Firebase runtime needed.
 * Run: node --test   (from functions/)
 */
const { test } = require('node:test');
const assert = require('node:assert');
const {
  sanitizeBody,
  DEFAULT_MODEL,
  MAX_OUTPUT_TOKENS,
  MAX_INPUT_CHARS,
} = require('../sanitize');

test('pins the model when the client asks for a different/expensive one', () => {
  const out = sanitizeBody({ model: 'gpt-4-turbo', messages: [] });
  assert.strictEqual(out.model, DEFAULT_MODEL);
});

test('keeps an allowed model', () => {
  const out = sanitizeBody({ model: DEFAULT_MODEL, messages: [] });
  assert.strictEqual(out.model, DEFAULT_MODEL);
});

test('clamps max_tokens to the ceiling and disables streaming', () => {
  const out = sanitizeBody({ max_tokens: 999999, stream: true, messages: [] });
  assert.strictEqual(out.max_tokens, MAX_OUTPUT_TOKENS);
  assert.strictEqual(out.stream, false);
});

test('non-numeric max_tokens falls back to the default', () => {
  const out = sanitizeBody({ max_tokens: 'lots', messages: [] });
  assert.strictEqual(out.max_tokens, MAX_OUTPUT_TOKENS);
});

test('clamps temperature into [0,1]', () => {
  assert.strictEqual(sanitizeBody({ temperature: 5, messages: [] }).temperature, 1);
  assert.strictEqual(sanitizeBody({ temperature: -3, messages: [] }).temperature, 0);
  assert.strictEqual(sanitizeBody({ messages: [] }).temperature, 0.3);
});

test('normalizes roles to system|user only', () => {
  const out = sanitizeBody({
    messages: [
      { role: 'system', content: 'sys' },
      { role: 'assistant', content: 'should become user' },
      { role: 'user', content: 'u' },
    ],
  });
  assert.deepStrictEqual(out.messages.map((m) => m.role), ['system', 'user', 'user']);
});

test('drops non-string / empty content messages', () => {
  const out = sanitizeBody({
    messages: [
      { role: 'user', content: 123 },
      { role: 'user', content: '' },
      { role: 'user' },
      null,
      { role: 'user', content: 'ok' },
    ],
  });
  assert.strictEqual(out.messages.length, 1);
  assert.strictEqual(out.messages[0].content, 'ok');
});

test('caps total input characters across messages', () => {
  const big = 'x'.repeat(6000);
  const out = sanitizeBody({
    messages: [
      { role: 'user', content: big },
      { role: 'user', content: big },
    ],
  });
  const total = out.messages.reduce((n, m) => n + m.content.length, 0);
  assert.ok(total <= MAX_INPUT_CHARS, `total ${total} <= ${MAX_INPUT_CHARS}`);
});

test('garbage / missing body yields an empty, safe payload (proxy will 400)', () => {
  for (const bad of [undefined, null, 'string', 42, []]) {
    const out = sanitizeBody(bad);
    assert.strictEqual(out.model, DEFAULT_MODEL);
    assert.deepStrictEqual(out.messages, []);
    assert.strictEqual(out.stream, false);
  }
});
