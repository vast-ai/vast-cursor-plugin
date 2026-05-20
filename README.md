# vast-cursor-plugin

A [Cursor](https://cursor.com) plugin for [Vast.ai](https://vast.ai). Rent, launch, monitor, and tear down GPU instances — plus volumes, serverless endpoints, and billing.

- **A bundled `vastai` skill** at `.cursor/skills/vastai/SKILL.md` gives Cursor full command-reference knowledge of the `vastai` CLI (ssh, copy, logs, exec, destroy, volumes, serverless, environment variables, …).
- **An auto-attach rule** at `.cursor/rules/vastai.mdc` fires when you're editing IaC files (`*.tf`, `*.yaml`, `infra/`, `deploy/`) and points Cursor at the skill.

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

### Per-project

```bash
git clone https://github.com/vast-ai/vast-cursor-plugin.git /tmp/vast-cursor-plugin
cd /path/to/your/project
/tmp/vast-cursor-plugin/install.sh           # copies into ./.cursor/
```

### Globally

```bash
/tmp/vast-cursor-plugin/install.sh --user    # copies into ~/.cursor/
```

`--force` to upgrade in place. `--dry-run` to preview.

### Alternative — GitHub URL import

Per [Cursor's docs](https://cursor.com/docs/skills), Cursor can import skills from a GitHub repo URL directly. Point Cursor at `https://github.com/vast-ai/vast-cursor-plugin` and it'll discover `.cursor/skills/vastai/SKILL.md`.

## First run

In Cursor's Agent chat:

> *"Configure my Vast.ai CLI."*

The skill auto-loads and walks through `vastai set api-key …` → `vastai create ssh-key …` → `vastai show user`.

## Layout

```
vast-cursor-plugin/
├── install.sh                       # copies into ./.cursor/ or ~/.cursor/
├── .cursor/
│   ├── skills/vastai/
│   │   └── SKILL.md                 # vendored from vast-ai/vast-cli
│   └── rules/
│       └── vastai.mdc               # auto-attach rule for IaC files
├── VENDORED_FROM.md                 # pins the upstream SHA
└── PATCHES.md                       # local deltas pending upstream PRs
```

## License

MIT — see [LICENSE](./LICENSE). `SKILL.md` is vendored from [`vast-ai/vast-cli`](https://github.com/vast-ai/vast-cli) (also MIT); local edits are tracked in [`PATCHES.md`](./PATCHES.md) for upstream propagation.
