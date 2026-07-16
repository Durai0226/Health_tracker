# Phase C — Secure cloud AI proxy (deploy guide)

This makes cloud AI **production-safe at scale**: the provider key lives only in
the Cloud Function, every call is Firebase-authenticated, and per-user quotas cap
cost. The Flutter client is already wired — deploying flips it on.

## What's already in the app
- `functions/index.js` — the `aiProxy` HTTPS function (auth + quota + key
  server-side + OpenAI passthrough).
- `LlmService` — when `EnvConfig.aiProxyUrl` is set it POSTs to the proxy with a
  **Firebase ID token** (no client key); otherwise it uses the debug pasted-key
  path. `CloudEngine.isAvailable` is true whenever the proxy is configured.
- Cloud use stays **opt-in** via the Settings "Use cloud AI" consent toggle.

## Deploy (one-time; requires the Firebase Blaze plan)
```bash
# from the repo root (Firebase project already exists for this app)
cd functions && npm install && cd ..

# store the provider key as a secret (NVIDIA nvapi-… or a Gemini key)
firebase functions:secrets:set AI_PROVIDER_KEY

# deploy just the proxy
firebase deploy --only functions:aiProxy
# → note the function URL, e.g. https://us-central1-<project>.cloudfunctions.net/aiProxy
```

## Point the app at it
Build with the proxy URL (no key ships in the app):
```bash
flutter run   -d "iPhone 17 Pro" --dart-define=AI_PROXY_URL=https://us-central1-<project>.cloudfunctions.net/aiProxy
flutter build ipa --dart-define=AI_PROXY_URL=https://…/aiProxy
```
Then in the app: Settings → AI Assistant → turn on **Use cloud AI**. Signed-in
users now get cloud-quality answers; everyone else stays on the free on-device
rule engine. No feature code changes — routing is handled by `AiAssistant`.

## Cost / scale controls (tune in `functions/index.js`)
- `DAILY_LIMIT` / `MONTHLY_LIMIT` — per-user request caps (Firestore counters).
- Add a response cache (hash the messages → Firestore/Memcache) to cut repeats.
- Swap provider for production licensing: change `PROVIDER_URL` + the model the
  client sends + the `AI_PROVIDER_KEY` secret (e.g. Google Gemini's
  OpenAI-compatible endpoint, which permits production use).

## Privacy
Cloud is off unless the user consents (Settings). Prompts are PII-redacted client
-side before leaving the device (`AiAssistant`). Health data stays on-device for
all rule-based / on-device-LLM usage.
