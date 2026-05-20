# Submit to the Cursor Marketplace

Steps to get this plugin listed at [cursor.com/marketplace](https://cursor.com/marketplace), where users can install it with `/add-plugin vastai` inside Cursor 2.5+.

## Pre-flight checklist

Verify each before submitting. Cursor's reviewers will reject on any of these.

- [ ] `.cursor-plugin/plugin.json` exists with `name` (lowercase kebab-case)
- [ ] `name` is unique in the marketplace (search at cursor.com/marketplace first)
- [ ] `displayName`, `version`, `description`, `author`, `license` all set
- [ ] `logo` field points to a committed file (we use `assets/logo.svg`)
- [ ] `skills/vastai/SKILL.md` has YAML frontmatter with `name` + `description`
- [ ] `rules/vastai.mdc` has YAML frontmatter with `description`
- [ ] `LICENSE` file at repo root (MIT for this repo)
- [ ] Repo is public on GitHub
- [ ] `README.md` describes what the plugin does and how to use it
- [ ] No `..` or absolute paths anywhere in manifest fields

## Submit

1. Open https://cursor.com/marketplace/publish
2. Paste the repo URL: `https://github.com/vast-ai/vast-cursor-plugin`
3. Submit the form

That's it. Cursor's team reviews every submission manually before listing.

## After submission

- Review can take days or weeks — there's no public SLA.
- If rejected, you'll get feedback via the same channel; fix and re-submit.
- Once accepted, the plugin appears at `cursor.com/marketplace` and is installable via `/add-plugin vastai`.

## Updating after acceptance

For new versions:

1. Bump `version` in `.cursor-plugin/plugin.json` (semver).
2. Push to `main`.
3. Cursor re-pulls from the public Git repo. From their docs: *"we review each update before publishing"* — expect a smaller review pass on each release.

## Distribution before/without marketplace acceptance

Users can install directly from this repo without going through the marketplace:

- **Team Marketplace import** — Dashboard → Settings → Plugins → Team Marketplaces → Import → paste the GitHub URL.
- **install.sh** — clone the repo and run `bash install.sh --user`. See [`README.md`](./README.md).

## References

- [Cursor plugin docs](https://cursor.com/docs/plugins)
- [Plugin reference (manifest schema, component layout)](https://cursor.com/docs/reference/plugins)
- [Plugin template + add-a-plugin walkthrough](https://github.com/cursor/plugin-template)
