# Claude Code setup for this project

## What's active

| File | Purpose |
|:--|:--|
| `CLAUDE.md` (repo root) | The only context file Claude Code auto-loads. Imports `AGENTS.md`. |
| `AGENTS.md` (repo root) | Single source of truth for project context. Also read by Antigravity/Gemini. |
| `.mcp.json` | Declares the **Dart & Flutter MCP server** at project scope. |
| `.claude/settings.json` | Permission rules, plugin/marketplace declarations. |

On your first session after adding `.mcp.json`, Claude Code asks you to approve the `dart` server
(unless `enabledMcpjsonServers` already lists it). Confirm with `/mcp` — it should read `connected`.

## Dart & Flutter MCP server

Already wired up in `.mcp.json`. Requires Dart 3.9+; this project runs Dart 3.12.2, and the server
reports version 0.1.4. No install step — it ships inside the Dart SDK.

It gives Claude `analyze_files`, `run_tests`, `dart_fix`, `dart_format`, `hot_reload`,
`hot_restart`, `widget_inspector`, `get_runtime_errors`, `get_app_logs`, `pub`, `pub_dev_search`,
and `launch_app` / `list_devices`.

**Why it matters here:** targeted analysis instead of a whole-project `flutter analyze`, whose output
runs past 1300 lines. It also drives a running app directly, replacing the sim-screenshot workaround.

The server is marked experimental upstream and evolves quickly.

## Optional: the dart-flutter plugin

`.claude/settings.json` registers the `flutter/agent-plugins` marketplace, so the plugin is one
command away:

```
/plugin install dart-flutter@dart-flutter
/reload-plugins
```

It bundles Flutter skills (responsive layouts, declarative routing, JSON serialization), Dart skills
(unit-test generation, dependency resolution, analysis fixes), **and its own copy of the Dart MCP
server**.

> If you install it, delete the `dart` entry from `.mcp.json`. Otherwise two identical Dart MCP
> servers connect and their tool definitions cost context twice.

## Optional: other plugins

Declared in `settings.json` under `enabledPlugins`, so Claude Code prompts to install them when you
trust the folder. To do it by hand:

```
/plugin install security-guidance@claude-plugins-official   # reviews each change for vulnerabilities
/plugin install commit-commands@claude-plugins-official      # commit / push / PR workflows
```

`security-guidance` earns its place here: this app stores medication, menstrual-cycle, and health
data behind `firestore.rules` and `flutter_secure_storage`.

Not yet set up, each needing a CLI + login first:

```bash
npm i -g firebase-tools && firebase login    # then: /plugin install firebase@claude-plugins-official
brew install gh && gh auth login             # then: /plugin install github@claude-plugins-official
```

The Firebase plugin covers Firestore documents and queries, **security-rules validation**, Auth user
inspection, and index management. Note that Crashlytics tools will return nothing — see below.

## Not applicable to this project

- **Sentry MCP** — no crash-reporting SDK here. `firebase_crashlytics` is absent from
  `pubspec.yaml`; add it and use the Firebase plugin rather than onboarding a second vendor.
- **Playwright / Chrome DevTools MCP** — browser automation; this is a mobile app.
- **Context7** — the Dart MCP already resolves symbols and searches pub.dev.

## `.aiexclude` is not a Claude Code file

`.aiexclude` is an Antigravity / Gemini / Firebase Studio convention. Claude Code ignores it. The
equivalent lives in `permissions.deny` in `.claude/settings.json`, which uses gitignore-style
patterns where a leading `/` anchors at the repo root:

```json
"deny": ["Edit(/lib/**/*.g.dart)", "Read(/build/**)"]
```

A `Read` deny also blocks `Edit` on the same path, so generated Drift code is denied for editing but
still greppable when you need to look up a generated symbol.

## Corrections to the previous version of this doc

Recorded so the same mistakes don't get reintroduced:

- `settings.json` has **no** `mcpServers`, `contextFiles`, or `excludePatterns` keys, and permissions
  use `allow`/`deny`/`ask`, not `allowedTools`. Unknown keys are ignored silently.
- MCP servers belong in `.mcp.json` (project) or `~/.claude.json` (user/local).
- Claude Code reads `CLAUDE.md`, never `AGENTS.md` directly; `.claude/agents/` holds subagent
  definitions, so a plain context file there loads nothing.
- `@google/firebase-mcp` does not exist on npm. The real server is `npx -y firebase-tools@latest mcp`.
- The GitHub MCP endpoint is `https://api.githubcopilot.com/mcp/`, not `https://api.github.com`.
- The Dart & Flutter MCP server shipped and is used here.

## Docs

- <https://code.claude.com/docs/en/mcp>
- <https://code.claude.com/docs/en/discover-plugins>
- <https://code.claude.com/docs/en/settings>
- <https://docs.flutter.dev/ai/mcp-server>
