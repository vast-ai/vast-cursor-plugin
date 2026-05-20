# vast-cursor-plugin

A [Cursor](https://cursor.com) plugin for [Vast.ai](https://vast.ai). Rent, launch, monitor, and tear down GPU instances — plus volumes, serverless endpoints, and billing.

- **A bundled `vastai` skill** at `skills/vastai/SKILL.md` gives Cursor full command-reference knowledge of the `vastai` CLI (ssh, copy, logs, exec, destroy, volumes, serverless, environment variables, …).
- **An auto-attach rule** at `rules/vastai.mdc` fires when you're editing IaC files (`*.tf`, `*.yaml`, `infra/`, `deploy/`) and points Cursor at the skill.
- **A `.cursor-plugin/plugin.json` manifest** so the repo is a valid Cursor 2.5 plugin, eligible for the Marketplace and the `/add-plugin` install flow.

Cursor's UX is single-skill + natural-language, so there are no slash commands to memorise — just describe what you want.

## Natural language

> *"Find a verified 4090 under $0.40/hr and launch it with pytorch."*
>
> *"SSH into instance 12345 and tail `/var/log/nvidia-installer.log`."*
>
> *"Set `HF_TOKEN` to `hf_xxxxx` on my running instance."*
>
> *"Destroy everything except instance 12345."*

Every `vastai` invocation includes `--raw` so responses come back as parseable JSON.

## Install

### Prerequisites

```bash
pip install vastai          # the vastai CLI itself (1.0.x or newer)
vastai --version
```

A working Vast.ai account; grab an API key from <https://cloud.vast.ai/account>.

### Marketplace (recommended once published)

In Cursor 2.5+, browse [cursor.com/marketplace](https://cursor.com/marketplace) or run `/add-plugin vastai` inside the editor. The `.cursor-plugin/plugin.json` manifest in this repo makes it eligible for that flow.

### Clone + install.sh

For installs ahead of marketplace acceptance, or for power users who want to track upstream with `git pull`:

```bash
git clone https://github.com/vast-ai/vast-cursor-plugin.git ~/code/vast-cursor-plugin
~/code/vast-cursor-plugin/install.sh --user   # → ~/.cursor/ (global)
# or
cd /path/to/your/project
~/code/vast-cursor-plugin/install.sh          # → ./.cursor/ (project-local)
```

`--force` to upgrade in place. `--dry-run` to preview. Running from inside the cloned plugin repo auto-promotes to `--user` (since `$PWD/.cursor` would self-copy).

## First run

In Cursor's Agent chat:

> *"Configure my Vast.ai CLI."*

The skill auto-loads and walks through `vastai set api-key …` → `vastai create ssh-key …` → `vastai show user`.

## Layout

```
vast-cursor-plugin/
├── .cursor-plugin/
│   └── plugin.json                  # Cursor 2.5 manifest (name, version, author, …)
├── skills/vastai/
│   └── SKILL.md                     # vendored from vast-ai/vast-cli
├── rules/
│   └── vastai.mdc                   # auto-attach rule for IaC files
├── install.sh                       # pre-marketplace install: copies into ./.cursor/ or ~/.cursor/
├── VENDORED_FROM.md                 # pins the upstream SHA
└── PATCHES.md                       # local deltas pending upstream PRs
```

## License

MIT — see [LICENSE](./LICENSE). `skills/vastai/SKILL.md` is vendored from [`vast-ai/vast-cli`](https://github.com/vast-ai/vast-cli) (also MIT); local edits are tracked in [`PATCHES.md`](./PATCHES.md) for upstream propagation.
