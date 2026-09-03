---
name: codex-third-party-provider
description: Configure or diagnose Codex Desktop/CLI with a third-party OpenAI-compatible model provider, including secure API-key storage, Responses API verification, and safe switching back to the official OpenAI provider.
---

# Codex Third Party Provider

Use this skill for a user-requested Codex provider change. Treat a third-party gateway as untrusted until its exact API contract is verified.

## Configure

1. Read the user-level `~/.codex/config.toml`; never place provider settings in a project-local `.codex/config.toml`.
2. Require the exact Base URL and API transport. Do not infer either from an invalid, duplicated, or truncated URL. For a Responses-compatible gateway, configure a custom provider with `wire_api = "responses"` and set the top-level `model_provider` and `model` explicitly.
3. Store the API key in a user-scoped environment variable and reference only its variable name with `env_key`. Do not place key material in TOML, scripts, logs, issue text, or commits. If the key was sent in chat, recommend rotating it.
4. Preserve a reversible official-provider path. A profile such as `~/.codex/openai.config.toml` may set `model_provider = "openai"`; do not edit or remove existing OpenAI login state.
5. Before restarting Desktop, run `codex --strict-config --version`. TOML tables apply until the next table header, so keep all top-level settings before provider tables and do not accidentally nest `notify`, `service_tier`, or unrelated keys under `[model_providers.<id>]`.

## Verify

Use the smallest request the user authorizes. Verify the full request URI, the requested model ID, and the returned response model; redact authorization headers and API keys. A Responses provider with base URL `https://gateway.example/v1` normally receives `POST https://gateway.example/v1/responses`.

Then check `GET <base_url>/models` with the same credential, recording only status, content type, and model IDs. A successful response must be JSON in the provider's documented format. `200 text/html` is a gateway page, not a compatible model list.

## Desktop Model Picker

The Desktop model picker depends on compatible model metadata. A successful `/responses` call does not prove the picker can enumerate or safely switch models.

- When `/models` is incompatible or unavailable, set the intended model as the top-level default and tell the user not to use the picker for that provider.
- Do not create or enable a hand-authored `model_catalog_json` solely to force the picker, unless the user explicitly asks and its schema has been validated against the installed Codex version in a disposable test. A malformed or stale catalog can prevent Codex Desktop from starting.
- If a custom catalog is requested, back up `config.toml`, validate it with `codex --strict-config --version` and `codex debug models`, then require a full Desktop restart. Keep its model allowlist limited to models the user has authorized.

## Switch And Recover

Make provider switching explicit and reversible. Prefer a documented CLI profile for testing. If a Desktop-friendly switch script is requested, have it change only the first top-level `model_provider` (and any deliberately managed catalog line), preserve all unrelated TOML, and validate the resulting config.

If Desktop stops starting after a provider/catalog change, restore the immediately previous user-level configuration or remove only the newly added `model_catalog_json` line. Do not delete login data, model caches, plugins, or the entire `.codex` directory.

See [references/provider-contract.md](references/provider-contract.md) when the gateway's Responses or model-list behavior is uncertain.
