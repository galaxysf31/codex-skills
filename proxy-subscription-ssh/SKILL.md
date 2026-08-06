---
name: proxy-subscription-ssh
description: Parse a local Clash or Mihomo subscription, securely transfer a minimal proxy configuration over SSH, start a remote loopback proxy, and verify network/package access. Use when a remote Linux host cannot reach GitHub or package indexes directly and the user provides a subscription URL.
---

# Local subscription to remote SSH proxy

Use `scripts/setup_proxy.py` from the local machine. Fetch and parse the subscription locally; never send the subscription URL to the remote host or print it in logs.

## Workflow

1. Confirm the SSH target, port, identity file, and local subscription URL. Treat the URL and generated YAML as secrets.
2. Run the script with `--subscription-url`, `--ssh-target`, and `--ssh-port`. It downloads locally, extracts `proxies`, and writes a minimal config with a `MATCH` rule.
3. The script uploads the full and minimal configs with `scp`, restricts them to mode 600, installs Mihomo only when absent, and starts it bound to `127.0.0.1`.
4. Verify the proxy with an HTTP request to a package index and relevant upstream site. Keep it running unless asked to stop it.

Example (PowerShell):

```powershell
python scripts/setup_proxy.py `
  --subscription-url $env:CLASH_SUBSCRIPTION_URL `
  --ssh-target dsw-1024 `
  --ssh-port 1024 `
  --identity-file $env:USERPROFILE\.ssh\dsw_rsa
```

Requires local `PyYAML` (`python -m pip install pyyaml`) and OpenSSH `ssh`, `scp`, and `curl.exe`. SSH aliases from `~/.ssh/config` are supported.

## Safety and troubleshooting

- Never commit subscription responses, generated YAML, node names, credentials, or logs.
- Never expose the proxy on `0.0.0.0`; software on the remote host should use `127.0.0.1`.
- If direct remote fetch returns 403/timeout but local fetch succeeds, this workflow separates subscription access from node connectivity.
- If a wheel has no matching Python tag, inspect the package index and choose the interpreter version supported by that wheel.
- The script changes only `/root/proxy-subscription.yaml`, `/root/proxy-minimal.yaml`, Mihomo files, and its process; it does not modify source repositories or virtual environments.
