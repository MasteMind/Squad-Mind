---
title: "[LOW] sed -i is not portable between GNU and BSD sed"
labels: ["bug", "low", "bootstrap"]
---

## Description
`bootstrap/40-agents-wire.sh` uses `sed -i` which requires an argument on macOS (BSD sed) but not on Linux (GNU sed).

## Fix
Add a `sed_inplace()` helper to `lib/common.sh`:
```bash
sed_inplace() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"  # GNU
    else
        sed -i '' "$@"  # BSD
    fi
}
```

## Acceptance Criteria
- [ ] `common.sh` provides `sed_inplace()` helper
- [ ] All scripts use `sed_inplace` instead of raw `sed -i`
- [ ] Bootstrap passes on macOS
