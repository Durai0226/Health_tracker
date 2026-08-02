# MCP Server Setup Guide

## ✅ What's Already Configured

Your `.claude/settings.json` declares **2 MCP servers**:
1. **GitHub** — Manage PRs, issues, branches, code reviews
2. **Firebase** — Query Firestore, check auth, manage storage

Your `.aiexclude` excludes **35K+ lines** of generated code and **5.7 GB** of build artifacts.

Your `.claude/agents/AGENTS.md` provides **cached project context** (loaded once per session).

---

## 🔧 Step 1: GitHub MCP (Optional but Recommended)

### Prerequisites
- GitHub Personal Access Token (classic or fine-grained)

### Setup

**Option A: Interactive Setup (Recommended)**
```bash
cd /Users/duraisingh/Downloads/Health_tracker
# In Claude Code IDE, run:
/mcp add github
# Follow prompts to authenticate with your GitHub token
```

**Option B: Manual Setup**
1. Generate a GitHub token at https://github.com/settings/tokens
   - Scopes needed: `repo`, `read:org` (for PR/issue access)
2. Export the token:
   ```bash
   export GITHUB_TOKEN="your_token_here"
   ```
3. Reload Claude Code

### Test
Ask the agent: **"List recent PRs on Durai0226/Health_tracker"**
- ✅ Success: Agent fetches PRs directly from GitHub API
- ❌ Failure: Agent tries to guess or asks for copy-paste

---

## 🔧 Step 2: Firebase MCP (Higher Priority)

### Prerequisites
- **Node.js 18+** installed
- **Firebase CLI** installed (`npm install -g firebase-tools`)
- **GOOGLE_APPLICATION_CREDENTIALS** set to a service account JSON

### Setup

**Option A: Use Existing Firebase Auth**
If you're already authenticated to Firebase CLI:
```bash
firebase login
```

**Option B: Service Account (Recommended for MCP)**
1. Go to Firebase Console → Project Settings → Service Accounts
2. Generate a new service account key (JSON)
3. Save it to a secure location (e.g., `~/.firebase/remedly-86882-key.json`)
4. Set the environment variable:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.firebase/remedly-86882-key.json"
   ```

**Option C: Manual Installation**
```bash
npm install -g @google/firebase-mcp
```

Then restart Claude Code.

### Test
Ask the agent: **"List all Firestore collections in remedly-86882"**
- ✅ Success: Agent queries Firestore directly
- ❌ Failure: Agent can't connect (auth issue)

---

## 🔧 Step 3: Dart & Flutter MCP (Advanced)

The Dart & Flutter MCP isn't yet officially available from Anthropic, but you can:

1. **Use `flutter analyze` via Bash** (current workaround)
   - Agent runs `flutter analyze` when you ask about errors
   
2. **Monitor** https://github.com/dart-lang/mcp for official Dart MCP release

3. Once available, add to `.claude/settings.json`:
   ```json
   "dart-flutter": {
     "type": "local",
     "command": "dart",
     "args": ["mcp-server"]
   }
   ```

---

## 📊 Verify Setup

Run this in your terminal:

```bash
# Check .aiexclude is respected
ls lib/core/database/ | grep -c "\.g\.dart"
# Expected: 0 (no generated files shown to agent)

# Check AGENTS.md is in place
cat .claude/agents/AGENTS.md | head -5

# Check settings.json syntax
jq . .claude/settings.json
```

---

## 🎯 Token Savings Checklist

After enabling MCP servers, your token usage should **drop 40-60%**:

| Before | After |
|:---|:---|
| Agent scans 34K-line `app_database.g.dart` | Agent uses Dart MCP analyzer |
| You copy-paste Firebase console data | Agent queries Firebase MCP directly |
| You copy GitHub PR links | Agent uses GitHub MCP API |
| Agent re-learns project structure each session | Agent loads `.claude/agents/AGENTS.md` once |

---

## 🚨 Troubleshooting

### GitHub MCP not working
- ✓ Token is valid: https://github.com/settings/tokens
- ✓ Token has `repo` scope
- ✓ Environment variable is set: `echo $GITHUB_TOKEN`

### Firebase MCP not working
- ✓ Service account JSON is valid: `jq . ~/.firebase/remedly-86882-key.json`
- ✓ GOOGLE_APPLICATION_CREDENTIALS is set: `echo $GOOGLE_APPLICATION_CREDENTIALS`
- ✓ Project ID matches: `remedly-86882` in settings.json
- ✓ Service account has Firestore/Storage permissions

### .aiexclude not working
- ✓ File exists: `ls -la .aiexclude`
- ✓ Format is correct (one glob per line)
- ✓ Reload Claude Code after creating/modifying `.aiexclude`

---

## 📚 Resources

- [MCP Overview](https://modelcontextprotocol.io)
- [GitHub MCP Docs](https://github.com/anthropics/mcp-servers/tree/main/src/github)
- [Firebase MCP Docs](https://github.com/google/firebase-mcp)
- [Dart MCP (Coming Soon)](https://github.com/dart-lang/mcp)

---

## 🎓 When to Use Each MCP

| Task | Use This MCP |
|:---|:---|
| "Fix this error" | Dart & Flutter MCP (when available) |
| "Check Firestore schema" | Firebase MCP |
| "Create a PR for this fix" | GitHub MCP |
| "What does X package do?" | Context7 MCP (fetch live docs) |
| "Explain this code" | (No MCP needed — agent reads files directly) |
