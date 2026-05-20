# Local deltas to vendored SKILL.md

When re-vendoring `.cursor/skills/vastai/SKILL.md` from `vast-ai/vast-cli`, re-apply these unless upstream now includes them.

- **Critical-rules section** (numbered 1–7 under `## Critical rules for agents`, near the top of SKILL.md).
- **Broader `description:` frontmatter** (matches env-var / token / billing intents, not only "GPU instances").
- **Expanded Environment Variables section** (prompt-to-call examples for HF_TOKEN, OPENAI_API_KEY, --raw on every line).

For the actual diff content, see `git log -- .cursor/skills/vastai/SKILL.md`.
