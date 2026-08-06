#!/usr/bin/env python3
"""Fetch a subscription locally and configure a loopback Mihomo proxy remotely."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

import yaml


def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, check=True)
    return p.stdout


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subscription-url", required=True)
    ap.add_argument("--ssh-target", required=True)
    ap.add_argument("--ssh-port", type=int, default=22)
    ap.add_argument("--identity-file")
    ap.add_argument("--remote-dir", default="/root")
    ap.add_argument("--proxy-port", type=int, default=7890)
    ap.add_argument("--mihomo-version", default="v1.19.20")
    ap.add_argument("--github-proxy", default="https://gh-proxy.com/https://github.com/")
    args = ap.parse_args()

    curl = shutil.which("curl.exe") or shutil.which("curl")
    if not curl:
        raise SystemExit("curl.exe is required on the local machine")
    raw = run([curl, "-fsSL", "--retry", "3", "--connect-timeout", "15",
               "--max-time", "180", args.subscription_url])
    doc = yaml.safe_load(raw)
    proxies = doc.get("proxies") if isinstance(doc, dict) else None
    if not proxies:
        raise SystemExit("subscription did not contain a non-empty proxies list")
    names = [p.get("name") for p in proxies if isinstance(p, dict) and p.get("name")]
    if not names:
        raise SystemExit("subscription proxies have no names")
    minimal = {
        "mixed-port": args.proxy_port,
        "allow-lan": False,
        "bind-address": "127.0.0.1",
        "mode": "rule",
        "log-level": "info",
        "proxies": proxies,
        "proxy-groups": [{"name": "PROXY", "type": "select", "proxies": [names[0]]}],
        "rules": ["MATCH,PROXY"],
    }
    with tempfile.TemporaryDirectory() as td:
        full_path, min_path = Path(td) / "subscription.yaml", Path(td) / "minimal.yaml"
        full_path.write_text(raw, encoding="utf-8")
        min_path.write_text(yaml.safe_dump(minimal, allow_unicode=True, sort_keys=False), encoding="utf-8")
        ssh_base = ["ssh", "-p", str(args.ssh_port)]
        scp_base = ["scp", "-P", str(args.ssh_port)]
        if args.identity_file:
            ssh_base += ["-i", args.identity_file]
            scp_base += ["-i", args.identity_file]
        remote = args.ssh_target
        run(scp_base + [str(full_path), f"{remote}:{args.remote_dir}/proxy-subscription.yaml"])
        run(scp_base + [str(min_path), f"{remote}:{args.remote_dir}/proxy-minimal.yaml"])
        run(ssh_base + [remote, f"chmod 600 {args.remote_dir}/proxy-*.yaml"])
        binary = f"{args.remote_dir}/mihomo"
        url = (args.github_proxy.rstrip("/") + "/MetaCubeX/mihomo/releases/download/"
               f"{args.mihomo_version}/mihomo-linux-amd64-compatible-{args.mihomo_version}.gz")
        install = (f"if [ ! -x {binary} ]; then curl -fsSL --retry 3 --max-time 300 '{url}' "
                   f"| gzip -d > {binary} && chmod 755 {binary}; fi; "
                   f"pkill -f '{binary} -d' 2>/dev/null || true; "
                   f"nohup {binary} -d {args.remote_dir}/mihomo-work -f {args.remote_dir}/proxy-minimal.yaml "
                   f">{args.remote_dir}/mihomo.log 2>&1 </dev/null &")
        run(ssh_base + [remote, install])
        run(ssh_base + [remote, f"sleep 2; curl -fsS --max-time 30 -x http://127.0.0.1:{args.proxy_port} https://pypi.org/simple/ >/dev/null"])
    print(f"Proxy configured on {remote}:127.0.0.1:{args.proxy_port}; parsed {len(names)} nodes locally.")


if __name__ == "__main__":
    main()
