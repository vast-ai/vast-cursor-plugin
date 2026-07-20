# Test plan — vast-cursor-plugin

How to verify the plugin against a live Vast.ai account. Prompts live in `TEST_PROMPTS.txt`. This file describes setup, what to look for, and pass criteria. A separate `TEST_PLAN_2.md` covers focused re-tests for the most recent skill fixes.

## Setup

```bash
cd /Users/will/freelance/work/vast-plugins/workspace/repos/vast-cursor-plugin
./install.sh --user --force
```

That copies all three skills (`vastai`, `vastai-host`, and `vastai-host-support`) into `~/.cursor/skills/` and `rules/vastai.mdc` into `~/.cursor/rules/`.

Pre-flight:

```bash
echo "${VAST_API_KEY:?must export VAST_API_KEY first}"   # set BEFORE launching Cursor
vastai --version                                          # 1.4.2+
```

Reload Cursor and open a new Agent chat. The rule now has `alwaysApply: true` and broader globs, so the skill should load in any workspace. Sanity-check by asking *"What skill do you use for Vast.ai operations?"* — agent should mention `vastai`. A "skill never loaded" PASS is meaningless.

## What good looks like

A passing run shows the agent reads from the skill and uses the correct CLI shapes without retrying or paraphrasing:

- **Correct flags first try.** Positional args where the docs say positional; underscores vs hyphens matching the actual command.
- **No invented commands.** Agent never types `vastai show templates`, `vastai bid`, or similar non-existent subcommands.
- **Surfaces server responses.** On 4xx/5xx, agent quotes the body verbatim and suggests a concrete next step (check scope, check deposit, upgrade CLI), not "let me retry."
- **Mutating ops gated.** Team creation is described as a separate account (not key rebinding), and the agent confirms the team name/credit transfer before running it. Paid host self-tests also require confirmation.

A failing run reaches for `--ssh-key`, `--bid`, `pytorch/pytorch:@vastai-automatic-tag`, `cloud.vast.ai/account`, uses rejected `create-team`, claims team creation rebinds the key, or runs a paid self-test without confirmation.

## Coverage areas (cross-reference `TEST_PROMPTS.txt`)

Walk through `TEST_PROMPTS.txt` top to bottom. The prompts are grouped roughly by area:

1. **Setup & auth** — API key URL, SSH key registration (positional pubkey contents).
2. **Search** — hidden default overrides, `compute_cap` encoding (`cuda_cap * 100`), structured template queries.
3. **Launch** — Vast-curated default image, `--ssh --direct --cancel-unavail`, materialization re-check, `--bid_price` for spot offers at or above `min_bid`.
4. **Instance ops** — `show instances-v1 -a` (auto-paginate), `ssh` via parsed `ssh-url`, label/change-bid positional/flag forms.
5. **Templates** — `--disk_space` (not `--disk`), `search templates` for discovery, `delete template --template-id <numeric>`.
6. **Teams & account** — separate-account semantics and spaced `create team` syntax, role lookup before `invite member`, env-vars treated as write-only.
7. **Host routing** — routine host intents load `vastai-host`; self-test failures and support bundles load `vastai-host-support`; 401 is attributed to scope, not key reset.

## Real-instance prep

Several prompts need real values. Before pasting them:

```bash
# Real offer for a launch prompt
vastai search offers 'num_gpus=1 rentable=true verified=true' -o 'dph_total' --raw --limit 5 | jq -r '.[].id'

# Real instance(s) for label/ssh/status prompts
vastai show instances-v1 --raw -a | jq -r '.instances[] | {id, label, gpu_name, actual_status}'

# Real spot instance for change-bid prompt (launch one first if you don't have one)
```

Substitute the real values for `<OFFER_ID>`, `<INSTANCE_ID>`, `<SPOT_INSTANCE_ID>`, `<TEMPLATE_ID>`, `<TEMPLATE_HASH>`, `<ENDPOINT_ID>`.

## Cleanup

```bash
vastai show instances-v1 --raw -a | jq '.instances[] | .id'   # any leftovers?
vastai destroy instance <id> -y
```

## Pass threshold

Walk through the file end to end. The skill is solid if each prompt either lands the right command or correctly refuses (e.g., `create team` should refuse without explicit confirmation; HF_TOKEN reveal should explain env-vars are write-only).

Budget: a few dollars max if you fire the launch prompts; near-zero if you skip launches.

## When something fails

The skill is the runbook. If the agent does the wrong thing, fix the relevant file under `skills/` and re-run the failing prompt. After a skill edit, run `./install.sh --user --force` and reload Cursor so the new content loads.
