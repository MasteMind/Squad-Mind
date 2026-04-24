# Squad-Mind Versioning Policy

We follow [Semantic Versioning 2.0.0](https://semver.org/) with Squad-Mind-specific criteria.

## Format

```
MAJOR.MINOR.PATCH
0.4.0
```

## When to Bump

### PATCH (last digit) — Bug fixes, docs, polish

Bump when the change fixes something without adding new user-facing capabilities.

- Fixes a broken bootstrap stage script
- Fixes portability issue (macOS, WSL)
- Security patch (proxy binding, permissions)
- Documentation corrections
- Template interpolation fixes
- Smoke test false-positive/negative fixes

**Example:** `0.4.0 → 0.4.1` — fixed `sed -i` portability on macOS

### MINOR (middle digit) — New features, completions, non-breaking additions

Bump when users get new capabilities or the kit becomes meaningfully more complete.

- **New bootstrap stage added** (e.g., stages 60-90 completing the pipeline)
- **New script shipped** (backup, health-check, restore)
- **New provider mode** (mixed mode, new CLI proxy)
- **New starter project template** (productivity, travel, learning)
- **New architecture support** (systemd units, Docker healthchecks)
- **CI/testing infrastructure added**
- **Interview schema extended** with new optional questions
- **Obsidian version bumped** to new pinned release

**Backward compatibility is required.** A user on `0.3.x` should be able to run `0.4.0` stages without re-interviewing.

**Example:** `0.3.0 → 0.4.0` — completed bootstrap pipeline (stages 60-90), added mixed provider mode, added CI

### MAJOR (first digit) — Breaking changes, rewrites, incompatible schema

Bump when existing installs would break or require user action to migrate.

- **Interview schema breaking change** (renamed required keys, removed keys)
- **`.env` format change** that breaks existing agent configs
- **Stage script renumbering** that invalidates `hermes-setup.state`
- **Vault path restructuring** (moving `brain/` to `core/`)
- **Dropped platform support** (e.g., removing macOS support)
- **Agent roster format change** that agents cannot parse
- **Complete rewrite** of the bootstrap architecture

**Example:** `0.x.x → 1.0.0` — stable API, interview schema frozen, external users confirmed working

## Pre-1.0 Convention

While `MAJOR == 0`, the public API is considered unstable. MINOR bumps can include significant changes. We aim for `1.0.0` when:

1. All 10 bootstrap stages are complete and tested on 3+ platforms
2. At least one external user has successfully installed without hand-holding
3. Interview schema has been stable across 2+ minor releases
4. CI passes on every PR for 1 month

## Release Checklist

Before tagging any version:

- [ ] Update this file with the version rationale
- [ ] Update `README.md` if user-facing behavior changed
- [ ] Update `AGENTS.md` if agent execution order changed
- [ ] Run `./tests/bootstrap-integration.sh` — must pass
- [ ] Run `./tests/crash-recovery.sh` — must pass
- [ ] Verify no placeholder data (checksums, URLs, example names)
- [ ] Tag: `git tag -a v0.4.0 -m "Complete bootstrap pipeline + hardening"`
- [ ] Push tag: `git push origin v0.4.0`
- [ ] Create GitHub Release with changelog

## Changelog Format

Each release notes section follows this structure:

```markdown
## [0.4.0] — 2026-04-24

### Added
- Stages 60-90: delivery, autostart, starter projects, first-run
- Mixed provider mode support
- scripts/backup-vault.sh, restore-vault.sh, health-check.sh
- CI via GitHub Actions

### Fixed
- sed -i portability (GNU/BSD)
- Unsafe .env export pattern
- Unquoted glob in uninstall.sh

### Security
- Proxy binding locked to 127.0.0.1
```

## Version History

| Version | Date | What Changed |
|---------|------|--------------|
| 0.1.0 | 2026-04-20 | Initial release — bootstrap stages 00-50, health/finance starters |
| 0.2.0 | 2026-04-20 | CLI proxy architecture — dual provider modes (API keys + CLI proxy) |
| 0.3.0 | 2026-04-20 | Ground-up rebuild — reliability, permission handling, systemd proxies |
| 0.4.0 | 2026-04-24 | Complete pipeline (stages 60-90), mixed mode, backup/restore, CI |
