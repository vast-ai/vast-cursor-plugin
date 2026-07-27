---
name: vastai-host-support
description: Diagnose Vast.ai host self-test failures and collect safe support evidence with the Vast CLI. Covers self-test machine, automatic failure support bundles, dump-logs, instance/container/daemon logs, local host artifacts, redaction, bundle review, and cleanup auditing. Use when a host asks why verification failed, needs a support bundle, wants diagnostic logs, or mentions dump-logs, self-test failure codes, kaalia, Docker, NVIDIA, port mapping, or host troubleshooting.
allowed-tools: Bash(vastai:*)
metadata:
  author: vast-ai
  compatibility: Linux, macOS, Windows; local host artifact collection requires running on the actual Linux host
---

# vastai-host-support

Diagnose host self-test failures and produce bounded, redacted evidence for Vast support.

> Use `vastai-host` for listing, pricing, maintenance, and routine provider operations.
> Command is `vastai` (lowercase). Add `--raw` whenever output will be parsed.
> The support-bundle and `dump-logs` workflow requires Vast CLI 1.4.2 or newer.

## Critical rules

1. **A machine self-test is a paid, mutating operation.** It launches a temporary rental on the selected host. Confirm the exact machine ID and acceptance of the small charge before running it. If interrupted, audit the account for a leftover test instance.
2. **Do not disable failure bundles by default.** `self-test machine` creates a diagnostic tarball on failure. Use `--no-support-bundle` only when the user explicitly opts out or local policy forbids writing the artifact.
3. **Local host artifacts must come from the actual host.** Never pass `--include-local-host-artifacts` from a laptop, CI runner, or unrelated server; that would collect the wrong machine's OS, Docker, NVIDIA, network, and kaalia evidence.
4. **Review before sharing.** Bundles apply redaction and are created with owner-only permissions, but still inspect the file list and contents for tenant data, credentials, tokens, environment values, IPs, or other sensitive material before uploading it.
5. **Do not use a custom test image as a recovery guess.** `--test-image` is for explicitly testing self-test image changes. A custom image can invalidate comparison with the production verification path.
6. **`--ignore-requirements` does not qualify a host for verification.** It bypasses the requirements gate for diagnostics only; report that limitation clearly.
7. **Configured port-range scanning is a paired CLI/image feature.** CLI builds containing [vast-cli PR #458](https://github.com/vast-ai/vast-cli/pull/458) map and probe the configured range over TCP and UDP. Confirm `--port-scan-timeout` exists and use a production image that includes the matching TCP/UDP responders. Until the paired image is released, use a custom image only for an explicitly authorized development dogfood run, never as proof of production verification readiness.

## Preflight

```bash
vastai --version
vastai self-test machine --help
vastai show machine <MACHINE_ID> --raw
vastai show instances-v1 --raw --limit 25
```

Confirm the machine is visible to the active API key. If the CLI reports missing `machine_read`, inspect the scoped key rather than rotating credentials blindly.

If `self-test machine --help` does not list `--port-scan-timeout`, the installed CLI does not include configured TCP/UDP range scanning. Do not claim that it tested the full host range.

## Run a self-test

```bash
# Default: creates a support bundle in /tmp if the test fails
vastai self-test machine <MACHINE_ID> --raw

# Put a failure bundle in a user-selected local directory
vastai self-test machine <MACHINE_ID> --support-bundle-dir <DIRECTORY> --raw

# Diagnostic-only bypass; a pass does not qualify the host for verification
vastai self-test machine <MACHINE_ID> --ignore-requirements --raw

# PR #458+ only: increase the timeout for each mapped TCP/UDP probe
vastai self-test machine <MACHINE_ID> --port-scan-timeout 5 --raw
```

On failure, preserve the structured fields such as `stage`, `failure_code`, `reason`, `diagnostics`, and `instance_id`. Surface the server/CLI response as-is before proposing remediation.

After an interrupted or failed run, audit for a leftover temporary instance:

```bash
vastai show instances-v1 --raw --limit 25
```

Do not destroy an unfamiliar instance. Match it to the self-test result and ask for confirmation before cleanup.

## Diagnose configured TCP/UDP range failures

PR #458-aware self-tests can report the configured range, range source, advertised direct-port capacity, missing mappings, and individual failed TCP/UDP probes. Preserve those structured fields exactly before proposing remediation.

Check:

1. The configured range is valid `start-end` syntax within ports `1024-65535`.
2. The machine offer advertises at least the range's port count plus four fixed self-test mappings.
3. Every configured container port has both a TCP and UDP mapping.
4. Host firewall, router/NAT, and upstream rules allow both protocols.
5. The selected self-test image contains the matching TCP listener and UDP echo responder.

Do not describe a timeout as proof that the port is closed—the failure may also be a missing mapping, NAT hairpin behavior, firewall drop, stale offer metadata, or a mismatched test image. Report the exact public endpoint and protocol only in private diagnostic output, and redact them before sharing broadly.

## Create a manual diagnostic bundle

From a workstation or other machine that is not the Vast host:

```bash
vastai dump-logs <MACHINE_ID> --output-dir <DIRECTORY> --raw
vastai dump-logs <MACHINE_ID> --instance-id <INSTANCE_ID> --output-dir <DIRECTORY> --raw
```

`--instance-id` adds CLI-visible instance metadata plus container and daemon logs from the Vast API.

Only when the command is running on the actual Linux host:

```bash
vastai dump-logs <MACHINE_ID> --instance-id <INSTANCE_ID> \
  --include-local-host-artifacts --output-dir <DIRECTORY> --raw
```

Local collection may include bounded/redacted kaalia logs, Docker configuration and status, filtered kernel errors, NVIDIA state, network summaries, and relevant mount information. Collection errors are recorded in the bundle rather than hidden.

## Inspect before sharing

```bash
tar -tzf <BUNDLE_PATH>
```

Expected bundle entries can include:

- `manifest.json` and `collection-errors.json`
- `self-test-result.json` and `self-test-output.log`
- `instance/show-instance.json`, `instance/container.log`, and `instance/daemon.log`
- `host/...` entries only when local host collection was explicitly enabled on the actual host

Confirm the archive path reported by the CLI, inspect sensitive-looking entries in a private location, and share only the minimum bundle needed for the support case.

## Related read-only evidence

```bash
vastai reports <MACHINE_ID> --raw
vastai show machine <MACHINE_ID> --raw
vastai logs <INSTANCE_ID> --tail 200 --raw
```

`reports` surfaces renter-submitted machine reports. `logs` is instance-scoped; do not substitute a machine ID for an instance ID.

## Common failures

| Symptom | Next evidence |
|---|---|
| Requirements/preflight failure | Keep the structured requirement result; use `--ignore-requirements` only for an explicitly diagnostic run |
| Test instance never becomes usable | Preserve `failure_code`, progress endpoint fields, mapped ports, and instance/daemon logs |
| Configured direct-port capacity failure | Compare range count plus four fixed mappings with the offer's `direct_port_count`; do not assume a fixed platform maximum |
| Missing or failed TCP/UDP range probes | Preserve missing mappings and per-protocol failures; verify both firewall protocols, NAT, offer metadata, and the paired responder image |
| Docker, CDI, or NVIDIA startup failure | Run `dump-logs` with the failed instance ID; add local artifacts only on the actual host |
| Support bundle write failure | Choose a writable `--support-bundle-dir` or `--output-dir`; report the exact filesystem error |
| Bundle has collection errors | Keep `collection-errors.json`; partial evidence is useful and should not be represented as complete |
| `401` / missing `machine_read` | Check active key precedence and permission scope; do not reset the key as a first response |

## Environment variables

- `VAST_API_KEY` — overrides the stored API key
- `VAST_SELF_TEST_IMAGE` — custom image override for explicit self-test image development
- `VAST_SELF_TEST_SUPPORT_BUNDLE=0|false|no|off` — disables automatic failure bundles; do not set by default
