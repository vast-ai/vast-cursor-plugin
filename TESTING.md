# Self-test plan — `vast-cursor-plugin`

A runbook to verify the plugin end-to-end. Cursor is a GUI app with no scriptable `-p` mode, so the install/mechanics phases are automated and the behavioral phases are a manual checklist you run inside Cursor's Agent chat. Launches real GPU instances and incurs real charges.

---

## Budget

- **Hard cap:** $2.00 of Vast credit.
- **Typical spend:** $0.20–$0.50 (a few minutes of RTX 4090 at ~$0.30/hr).
- **Abort the run if** pre-flight balance is under $2.

---

## Prerequisites

```bash
# 1. vastai CLI
vastai --version                           # → 1.0.13 or newer

# 2. Vast API key in env (must be set BEFORE cursor was launched)
echo "${VAST_API_KEY:?must export VAST_API_KEY first}"

# 3. Cursor 2.5+ installed
ls -d /Applications/Cursor.app 2>/dev/null || echo "Cursor not installed at /Applications/Cursor.app"

# 4. Working tree on the right branch
cd /Users/will/freelance/work/vast-plugins/workspace/repos/vast-cursor-plugin
git rev-parse --abbrev-ref HEAD            # → skills/split-renter-host
PLUGIN=$PWD
```

---

## Phase 0 — Install ($0, automated)

Install user-globally so all Cursor workspaces see the plugin.

```bash
./install.sh --user --dry-run              # preview
./install.sh --user --force                # do it

# Verify files landed
[ -f ~/.cursor/skills/vastai/SKILL.md ]      && echo "renter skill OK"      || echo "RENTER SKILL MISSING"
[ -f ~/.cursor/skills/vastai-host/SKILL.md ] && echo "host skill OK"        || echo "HOST SKILL MISSING"
[ -f ~/.cursor/rules/vastai.mdc ]            && echo "auto-attach rule OK"  || echo "RULE MISSING"

diff -q "$PLUGIN/skills/vastai/SKILL.md"      ~/.cursor/skills/vastai/SKILL.md
diff -q "$PLUGIN/skills/vastai-host/SKILL.md" ~/.cursor/skills/vastai-host/SKILL.md
```

**Restart Cursor** before running behavioral phases — Cursor caches skills on launch.

---

## Pre-flight ($0)

```bash
RUN_ID=cursor-$(date +%Y%m%d-%H%M%S)
OUT=/Users/will/freelance/work/vast-plugins/workspace/test-results/$RUN_ID
mkdir -p "$OUT"

vastai show user --raw         > "$OUT/baseline-user.json"
vastai show instances-v1 --raw > "$OUT/baseline-instances.json"
START_BAL=$(jq -r '.credit' "$OUT/baseline-user.json")
echo "Starting balance: \$$START_BAL"
[ "$(echo "$START_BAL < 2" | bc)" -eq 1 ] && { echo "BUDGET FAIL"; exit 1; }

# Drop a results template you'll fill in by hand for behavioral phases
cat > "$OUT/results.md" <<'EOF'
# Cursor self-test results

## Phase 1 — Knowledge probes
- [ ] p1.1 API key URL → mentions console.vast.ai/manage-keys/
- [ ] p1.2 Shared volumes → says Vast doesn't offer / only local / use S3
- [ ] p1.3 SSH command → does NOT say `ssh $(vastai ssh-url ...)`; shows --raw parsing
- [ ] p1.4 Onstart 6000 chars → identifies arg-length cap (reads from API 400/3471 error) + gzip workaround
- [ ] p1.5 Spot eviction → identifies spot eviction; mentions change bid

## Phase 2 — Command generation (read-only)
- [ ] p2.1 Balance → ran `vastai show user --raw`
- [ ] p2.2 List instances → ran `vastai show instances-v1 --raw --limit ...`
- [ ] p2.3 Search RTX 4090 → ran `vastai search offers ...RTX_4090...--raw`, NO `-n`
- [ ] p2.4 Kill 99999 → ran `vastai destroy instance 99999 -y`
- [ ] p2.5 Set env var → ran `vastai create env-var HF_TOKEN_SELFTEST hf_xxxxx_literal --raw`
- [ ] p2.6 Show machines → ran `vastai show machines --raw` (vastai-host loaded)

## Phase 3 — End-to-end lifecycle
- [ ] p3.1 create-instance command included --disk
- [ ] p3.2 create-instance command included --ssh --direct
- [ ] p3.3 create-instance command included --cancel-unavail
- [ ] p3.4 destroy used -y
- [ ] p3.5 no leftover instances with label selftest-$RUN_ID-e2e

## Phase 4 — Host skill routing
- [ ] p4.1 host-metrics ran `vastai metrics gpu*`
- [ ] p4.2 host-machines ran `vastai show machines`
- [ ] p4.3 On 401, agent suggested checking permissions (NOT "reset api-key")
EOF
echo "Results template at: $OUT/results.md"

# Cleanup script (run by hand at the end)
cat > "$OUT/cleanup.sh" <<EOF
#!/usr/bin/env bash
vastai show instances-v1 --raw --limit 200 \\
  | jq -r '.instances[]? | select(.label | tostring | startswith("selftest-$RUN_ID-")) | .id' \\
  | xargs -I{} vastai destroy instance {} -y --raw
vastai delete env-var HF_TOKEN_SELFTEST --raw 2>/dev/null || true
EOF
chmod +x "$OUT/cleanup.sh"
```

---

## Phase 1 — Knowledge probes (manual, in Cursor Agent chat, $0)

Open Cursor → new chat → make sure the chat is set to Agent mode → paste each prompt below. For each one, copy the agent's response into `$OUT/transcripts/p1-<slug>.txt`, then tick the box in `$OUT/results.md`.

Prompts (paste exactly):

1. *"What URL do I go to to create a Vast.ai API key?"*
   - **PASS if** response includes `console.vast.ai/manage-keys/`.
   - **FAIL if** response says `cloud.vast.ai/account` (broken URL).

2. *"Can I share a single volume across multiple Vast.ai instances at the same time?"*
   - **PASS if** response says Vast doesn't offer that / only local volumes / recommends `cloud copy` to S3.
   - **FAIL if** response suggests `vastai create network-volume`.

3. *"Show me the exact shell command to ssh into Vast instance 12345 using the vastai CLI."*
   - **PASS if** response shows parsing `--raw` JSON (e.g. `ssh_host`/`ssh_port`) or the awk pattern.
   - **FAIL if** response says `ssh $(vastai ssh-url 12345)` (the misleading old example).

4. *"I have a 6000-character onstart-cmd script and the instance never starts. What's wrong?"*
   - **PASS if** response identifies an arg-length cap, says to read the live value from the API `400/3471 Invalid args: len(args) > N` error rather than baking in a literal limit, and suggests gzip+base64 or `--onstart FILE` as the workaround.

5. *"vastai show instance says intended_status=running but actual_status=stopped. What's going on?"*
   - **PASS if** response identifies spot eviction and suggests `change bid` / raising `--bid_price`.

---

## Phase 2 — Command generation (manual, real shell calls, $0)

Same flow as phase 1 but the agent will actually run `vastai`. Cursor surfaces each shell call in its "tool" log — capture each `vastai` invocation. Open a side terminal so you can verify what ran.

Prompts:

1. *"What's my Vast.ai credit balance?"*
   - PASS: agent ran `vastai show user --raw` (or similar with `--raw`).

2. *"Show me a JSON list of my running instances."*
   - PASS: command matches `vastai show instances-v1 --raw .* --limit`.
   - FAIL: no `--raw`, OR no `--limit` (pagination hazard).

3. *"Find the cheapest verified RTX 4090 under $0.40/hr with compute_cap>=70."*
   - PASS: agent recognizes the user-supplied `70` is wrong (encoding is `cuda_cap * 100`) and runs `vastai search offers .* RTX_4090 .* compute_cap>=700 .* --raw`.
   - FAIL: command preserves `compute_cap>=70` verbatim, OR contains ` -n ` or `--no-default`.

4. *"Kill Vast instance 99999."*
   - PASS: `vastai destroy instance 99999 -y` (the 404 from Vast is expected).
   - FAIL: missing `-y`.

5. *"Create a Vast account env var called HF_TOKEN_SELFTEST with the value hf_xxxxx_literal."*
   - PASS: `vastai create env-var HF_TOKEN_SELFTEST hf_xxxxx_literal --raw` — value passed **literally**, not refused as "looks fake."

6. *"Show me my Vast.ai hosted machines."*
   - PASS: agent ran `vastai show machines --raw` AND in its preamble references the `vastai-host` skill (not `vastai`).
   - FAIL: agent ran `vastai show instances`.

Cleanup after phase 2: `vastai delete env-var HF_TOKEN_SELFTEST --raw`.

---

## Phase 3 — End-to-end lifecycle ($0.20–$0.50, manual, in Cursor)

```text
LABEL: selftest-<RUN_ID>-e2e      # paste your actual RUN_ID here
```

Paste this single prompt into Cursor's Agent chat:

> *You are validating the vast-cursor-plugin against a live account. Do all of this end-to-end and report what happened:*
>
> 1. *Find the cheapest verified single-GPU offer with compute_cap>=700 and rentable=true under $0.50/hr. Prefer RTX 4090 but accept anything cheaper that meets those filters.*
> 2. *Launch it with image `vastai/pytorch:@vastai-automatic-tag`, `--disk 20`, `--ssh`, `--direct`, `--cancel-unavail`, and `--label 'selftest-<paste-RUN_ID>-e2e'`.*
> 3. *Poll show instance with a 10-minute deadline until actual_status==running. If actual_status hits exited/unknown/offline, destroy with -y and report failure.*
> 4. *Once running, run `nvidia-smi --query-gpu=name,driver_version --format=csv,noheader` via `vastai execute`. Capture stdout.*
> 5. *Destroy the instance with `-y`. Verify via `show instances-v1 --raw --limit 50` that no instance with that label remains.*
> 6. *Report: offer id picked, instance id, dph_total, elapsed seconds, the nvidia-smi line, final destroy confirmation, AND the exact vastai create-instance command you ran (so I can verify the flags).*

**While it runs, in your side terminal:**

```bash
# Watch for our instance
watch -n 5 "vastai show instances-v1 --raw --limit 50 | jq '[.instances[] | select(.label | tostring | startswith(\"selftest-\"))] | .[] | {id, actual_status, label, dph_total}'"
```

**After it finishes, verify in the side terminal:**

```bash
# Pull the create-instance command from the agent's reported summary
# (paste the create line into $OUT/p3-create.txt first)
grep -q -- '--disk'            "$OUT/p3-create.txt" && echo "p3.disk PASS"            || echo "p3.disk FAIL"
grep -q -- '--ssh'             "$OUT/p3-create.txt" && echo "p3.ssh PASS"             || echo "p3.ssh FAIL"
grep -q -- '--direct'          "$OUT/p3-create.txt" && echo "p3.direct PASS"          || echo "p3.direct FAIL"
grep -q -- '--cancel-unavail'  "$OUT/p3-create.txt" && echo "p3.cancel-unavail PASS"  || echo "p3.cancel-unavail FAIL"

LEFTOVER=$(vastai show instances-v1 --raw --limit 200 | jq "[.instances[]? | select(.label | tostring | startswith(\"selftest-$RUN_ID-\"))] | length")
[ "$LEFTOVER" = "0" ] && echo "p3.no-leftover PASS" || echo "p3.no-leftover FAIL ($LEFTOVER leftover)"
```

**Known false positive:** host self-destruct (CDI errors, container shim) is a Vast bug. If the agent correctly destroys+reports, that's still a P3 PASS; re-run on a different offer to exercise nvidia-smi.

---

## Phase 4 — Host skill routing (manual, $0, expect 401)

Two prompts in Cursor Agent chat. Both should make Cursor load `vastai-host` and try host-only commands, which 401 on a renter key.

1. *"What's the going hourly rate for RTX 4090s in US datacenters right now according to Vast.ai's marketplace metrics?"*
   - PASS: agent ran `vastai metrics gpu` (or `metrics gpu-locations`).
   - PASS: on the 401, agent suggested checking permission scope with `vastai show api-keys --raw` (NOT "reset api-key").

2. *"List my Vast.ai hosted machines."*
   - PASS: agent ran `vastai show machines --raw`.
   - PASS: same 401 guidance.

---

## Phase 5 — Plugin install mechanics (automated, $0)

```bash
# Manifest valid
jq . "$PLUGIN/.cursor-plugin/plugin.json" >/dev/null && echo "p5.manifest PASS" || echo "p5.manifest FAIL"

# install.sh syntax
bash -n "$PLUGIN/install.sh" && echo "p5.install-syntax PASS" || echo "p5.install-syntax FAIL"

# Files in repo
[ -f "$PLUGIN/skills/vastai/SKILL.md" ]      && echo "p5.skill-renter PASS" || echo "p5.skill-renter FAIL"
[ -f "$PLUGIN/skills/vastai-host/SKILL.md" ] && echo "p5.skill-host PASS"   || echo "p5.skill-host FAIL"
[ -f "$PLUGIN/rules/vastai.mdc" ]            && echo "p5.rule PASS"         || echo "p5.rule FAIL"

# Install copied them (--user target)
diff -q "$PLUGIN/skills/vastai/SKILL.md"      ~/.cursor/skills/vastai/SKILL.md      && echo "p5.installed-renter PASS" || echo "p5.installed-renter FAIL"
diff -q "$PLUGIN/skills/vastai-host/SKILL.md" ~/.cursor/skills/vastai-host/SKILL.md && echo "p5.installed-host PASS"   || echo "p5.installed-host FAIL"
diff -q "$PLUGIN/rules/vastai.mdc"            ~/.cursor/rules/vastai.mdc            && echo "p5.installed-rule PASS"   || echo "p5.installed-rule FAIL"

# Project-local install path also works
mkdir -p /tmp/cursor-test-project && cd /tmp/cursor-test-project
"$PLUGIN/install.sh" --dry-run && echo "p5.project-dry-run PASS" || echo "p5.project-dry-run FAIL"
cd - >/dev/null

# Auto-attach rule: open a .tf file in Cursor and confirm the rule fires
echo "MANUAL: open any .tf or infra/ file in Cursor; confirm 'vastai' rule shows in the chat sidebar."
```

---

## Final report

```bash
# Fill in the checkboxes in $OUT/results.md by hand after each phase
# Then summarise:

{
  echo "# Self-test report — $RUN_ID"
  echo
  echo "**Plugin:** vast-cursor-plugin"
  echo "**Branch:** $(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --short HEAD))"
  echo "**Started:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  END_BAL=$(vastai show user --raw | jq -r .credit)
  echo "**Balance:** \$$START_BAL → \$$END_BAL (spent \$$(echo "$START_BAL - $END_BAL" | bc))"
  echo
  cat "$OUT/results.md"
} > "$OUT/REPORT.md"

# Always cleanup
"$OUT/cleanup.sh"

# Confirm no leak
vastai show instances-v1 --raw --limit 200 \
  | jq "[.instances[]? | select(.label | tostring | startswith(\"selftest-$RUN_ID-\"))] | length" \
  | grep -q '^0$' && echo "CLEAN" || echo "LEAK — manual cleanup needed"
```

---

## Pass/fail matrix

| Phase | Tests | Automated? | Failure means |
|---|---:|:---:|---|
| 0 Install | 6 checks | yes | install.sh broken or files missing |
| 1 Knowledge | 5 | no (Cursor GUI) | Skill content didn't surface — content fix in SKILL.md |
| 2 Command-gen | 6 checks | no (Cursor GUI) | Agent dropped a flag or used `-n` — rule fix |
| 3 E2E | 5 checks | partly (real shell verification) | Real launch broken or critical flags missing |
| 4 Host routing | 3 checks | no (Cursor GUI) | Wrong skill loaded or 401 handling regressed |
| 5 Mechanics | 9 checks | yes | Layout broken or install didn't propagate files |

**Total: 34 checks** (15 automated, 19 manual GUI). ≥31/34 to publish.

---

## Why so many manual steps?

Cursor 2.5 has no documented headless / `-p` mode for the Agent chat. If a future Cursor release exposes one, phases 1–4 can be folded into the same subprocess pattern used in the claude/codex `TESTING.md` files. Until then, the Cursor self-test is install-and-mechanics automated + behavioral manual checklist.

---

## Manual followup (always)

```bash
vastai show instances-v1 --raw --limit 200 \
  | jq -r '.instances[]? | select(.label | tostring | startswith("selftest-")) | "\(.id)  \(.label)  \(.actual_status)"'
```

Any output = leak. `vastai destroy instance <id> -y --raw` to clean up.
