---
title: "sed -i is not portable between GNU and BSD (macOS)"
labels: ["bug", "low", "bootstrap"]
---

## Problem
`bootstrap/40-agents-wire.sh` uses `sed -i` which requires an empty argument on macOS (BSD sed) but not on Linux (GNU sed).

## Proposed Fix
Add `sed_inplace()` helper to `lib/common.sh`:
```bash
sed_inplace() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"      # GNU
    else
        sed -i '' "$@"   # BSD
    fi
}
```

## Acceptance Criteria
- [ ] `common.sh` exports `sed_inplace()`
- [ ] All scripts use helper instead of raw `sed -i`
- [ ] Bootstrap verified on macOS
