# Third-Party Provider Contract

Collect these facts before changing Codex configuration:

- The complete provider Base URL, copied from the provider documentation.
- Whether it supports the OpenAI Responses API or only Chat Completions.
- The exact permitted model ID, not a display label or an assumed alias.
- The authentication header and whether a standard Bearer API key is accepted.
- Whether `GET <base_url>/models` returns the provider's documented JSON model list.

For a Responses-compatible setup, verify with one minimal request:

```text
POST <base_url>/responses
Content-Type: application/json
Authorization: Bearer <redacted>

{"model":"<approved-model-id>","input":"Reply with exactly: OK","stream":false}
```

Record the final URI, requested model, returned `model`, and final status. Never record the secret or authorization header.

If a gateway returns HTML for `/models`, it may still proxy `/responses`, but it does not supply the model metadata Codex Desktop needs for its normal model picker. Escalate that incompatibility to the provider instead of treating the model picker as proof that the model changed.
