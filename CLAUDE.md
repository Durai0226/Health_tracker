@AGENTS.md

## Claude Code specifics

- Prefer the **Dart MCP** tools over shelling out: `analyze_files` on the touched paths instead of a
  full `flutter analyze` dump, `run_tests` instead of `flutter test`, `pub_dev_search` for packages.
  A whole-project analyze produces >1300 lines of output and is rarely what's needed.
- Don't write build or analysis logs into the repo root. Use the session scratchpad.
- `.aiexclude` is for Antigravity/Gemini, not Claude Code. Claude Code's equivalent lives in
  `permissions.deny` in `.claude/settings.json`.
