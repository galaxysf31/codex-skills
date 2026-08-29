---
name: windows-proxy-diagnostics
description: Diagnose Windows connectivity failures by separating DNS resolution, direct TCP/TLS reachability, local proxy health, and application proxy inheritance. Use when some sites work but OpenAI, GitHub, package indexes, or other domains fail, especially with Clash, Mihomo, SSR, or another loopback proxy. Do not use for configuring a remote Linux proxy over SSH.
---

# Windows Proxy Diagnostics

Diagnose before changing configuration. A working Google request does not prove another domain has correct DNS or uses the same route.

## Workflow

1. Run the bundled read-only script with the failing domains. Pass the expected local proxy URL when known:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose_network.ps1 `
     -Domains api.openai.com,chatgpt.com `
     -ProxyUrl http://127.0.0.1:7890
   ```

2. Interpret the layers independently:
   - Local DNS differs from both public DNS-over-HTTPS answers: DNS pollution, router/ISP rewriting, or a stale override is likely.
   - Correct IP connects but TLS fails or resets: the direct network path is blocked; changing DNS alone is insufficient.
   - The proxy succeeds while direct access fails: keep the domain on the proxy route.
   - The proxy listener and proxy request both succeed, but the application fails: the application is probably bypassing the Windows user proxy, using WinHTTP direct mode, or missing `HTTP_PROXY`/`HTTPS_PROXY`.
   - Any nonzero HTTP response after a completed TLS handshake—including `401`, `403`, or `421`—proves network reachability; treat authentication, routing policy, or bot-policy errors separately.

3. Report evidence before proposing remediation: configured DNS server, local and DoH answers, hosts overrides, direct TLS result, proxy listener/process, proxy TLS result, and the differences among WinHTTP, Windows user proxy, and proxy environment variables.

4. Recommend the narrowest fix. Typical options are enabling system/TUN mode in the existing proxy client, adding the affected domains to its proxy rules, configuring the specific application to use the loopback proxy, or enabling secure DNS. State explicitly when secure DNS fixes only name resolution and direct routing still requires the proxy.

## Safety

- The script must remain read-only. Do not change DNS, hosts, routes, registry proxy settings, WinHTTP proxy, firewall rules, or proxy-client configuration without explicit user authorization.
- Never print proxy credentials, subscription URLs, API keys, or full environment-variable values. Show only proxy host and port.
- Do not diagnose reachability with ICMP alone; many edge networks intentionally drop ping. Prefer HTTPS/TLS tests with correct SNI.
- If proposing `netsh winhttp import proxy source=ie`, explain that it is a system-wide mutation, may require elevation, and can be reverted with `netsh winhttp reset proxy`.
