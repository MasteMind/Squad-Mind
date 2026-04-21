---
title: "[MEDIUM] nightly_brain_sync.sh invoked without bash interpreter"
labels: ["bug", "medium", "vault"]
---

## Description
The cron job that runs nightly brain sync calls the script directly without specifying `bash`, causing it to fail on systems where the script lacks execute permissions or has a non-bash shebang.

## Fix
Change the cron entry from:
```
0 4 * * * /path/to/nightly_brain_sync.sh
```
to:
```
0 4 * * * bash /path/to/nightly_brain_sync.sh
```

Or ensure the script has `chmod +x` and a proper shebang.

## Acceptance Criteria
- [ ] Cron job uses `bash /path/to/script.sh` or script is executable with `#!/bin/bash`
- [ ] Test: `run-parts` or manual cron execution succeeds
