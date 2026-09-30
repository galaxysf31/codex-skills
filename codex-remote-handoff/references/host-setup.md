# Remote CLI host setup

Read this only when the requested SSH host is missing a prerequisite for the tmux-based Codex CLI workflow.

## Default personal profile

- SSH alias: `ecs-0904`
- Host address: `47.85.15.56`
- Remote project folder: `/root/codex_project`

Resolve usernames, ports, and keys from the user's SSH configuration. Never copy private keys into this skill or repository.

## Preflight

From a fresh non-interactive SSH connection, inspect the remote OS, architecture, login shell, available disk space, `tmux`, `codex --version`, and `codex login status`. Confirm the chosen working directory is writable. Use read-only checks before installing or changing anything.

## Install prerequisites

Install `tmux` through the remote distribution's package manager when it is absent. On supported Linux hosts, install or update Codex with the current official standalone installer unless the user requests another method:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Ensure `codex` is available on the non-interactive and interactive login-shell `PATH`. Install `bubblewrap` if the Linux sandbox reports it missing.

## Authenticate safely

Prefer the supported device-login flow or another supported Codex login method. Treat authentication artifacts as secrets:

- never print tokens or `auth.json` contents;
- never commit credentials;
- keep persistent credentials readable only by the remote user;
- do not copy local authentication files unless the user explicitly authorizes that transfer.

Require `codex login status` to succeed under the same remote user that will own tmux.

## Verify Codex execution

Run a minimal ephemeral read-only smoke test outside a repository and require the exact marker response:

```bash
tmp_dir=$(mktemp -d /tmp/codex-smoke.XXXXXX)
codex exec --ephemeral --skip-git-repo-check --sandbox read-only \
  -C "$tmp_dir" 'Reply with exactly: REMOTE_CODEX_OK' </dev/null
rmdir "$tmp_dir"
```

Installation and login status alone do not prove that model execution works.

## Verify tmux persistence

Create a uniquely named disposable session, confirm it from a second SSH connection, and remove that exact session after the test. Never use broad `kill-server` or process-name termination commands when other sessions may exist.

The production handoff must run Codex inside a named detached session. Verify the pane process and captured output from a fresh SSH connection before declaring the local computer safe to shut down.

## Session recovery

Codex interactive history is stored on the remote host. Prefer a recorded session UUID with `codex resume <session-id>`. Otherwise use the picker; use `--last` only when the latest session in the intended working directory is unambiguous. Keep the same remote user and `CODEX_HOME` or the history may appear missing.
