# llm-cli-proxy patches

Our deltas on top of upstream [Slopedrop/llm-cli-proxy](https://github.com/Slopedrop/llm-cli-proxy) v1.0.1 (54baac6), carried on the `squad-mind` branch of [MasteMind/llm-cli-proxy](https://github.com/MasteMind/llm-cli-proxy) — the branch the `tools/llm-cli-proxy` submodule is pinned to.

- `0001-feat-add-environment-variable-support-to-provider-co.patch` — env-var support in provider config (originally 4440bac). Upstream-PR candidate.
- `0002-refactor-isolate-ollama-env-injection-to-talariaProv.patch` — isolate Ollama env injection to talariaProvider (originally 33d889f). Fork-only; talaria is squad-specific.

Regenerate with: `git -C tools/llm-cli-proxy format-patch 54baac6..squad-mind -o patches/`
