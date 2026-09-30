# Remote host setup

Read this only when the requested SSH host or its saved Codex project is not ready.

## Default personal profile

- SSH alias: `ecs-0904`
- Host address: `47.85.15.56`
- Codex host ID: `remote-ssh-discovered:ecs-0904`
- Remote project folder: `/root/codex_project`

Resolve connection details from the user's SSH config. Do not copy private keys into the skill or repository.

## Preflight

1. Confirm non-interactive SSH access with the concrete alias from `~/.ssh/config`.
2. Inspect the remote OS, architecture, login shell, `PATH`, Codex version, and `codex login status`.
3. Check the desktop app's project inventory for a saved project on the same host.

Use read-only checks before installing or modifying anything. Never expose app-server transports directly on a public interface.

## Install or update Codex

On supported Linux hosts, use the current official standalone installer unless the user requests a different method:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Ensure the installed `codex` is on the remote login shell's `PATH`, because the desktop app starts the remote app server through SSH using that shell. Install `bubblewrap` when the Linux sandbox reports it missing. Install `tmux` only for the detached-CLI fallback.

## Authenticate safely

Prefer a supported device login or Codex access token. Treat every authentication artifact as a secret:

- never print tokens or `auth.json` contents;
- never commit credentials;
- store persistent credentials with owner-only permissions;
- do not copy the local `~/.codex/auth.json` to the remote host unless the user explicitly authorizes transferring that login state.

After authentication, require `codex login status` to succeed.

## Verify execution

Run a minimal, ephemeral, read-only smoke test outside any repository and require an exact marker response. For example:

```bash
tmp_dir=$(mktemp -d /tmp/codex-smoke.XXXXXX)
codex exec --ephemeral --skip-git-repo-check --sandbox read-only \
  -C "$tmp_dir" "Reply with exactly: REMOTE_CODEX_OK" </dev/null
rmdir "$tmp_dir"
```

Do not treat installation or login status alone as proof that inference works.

## Save the SSH project in the desktop UI

Open **Settings > Connections > SSH**, add or enable the concrete SSH alias, and select the remote folder. Confirm that `list_projects` reports the folder with the expected remote `hostId`. Remote projects may be ordinary directories; Git is required only for product Handoff, not for a new remote continuation chat.

If the host exists but no remote project is saved, stop after opening or identifying the SSH connection setup. Ask the user to select the folder if the UI requires an interactive choice that cannot be made safely on their behalf.

## Detached CLI fallback

Use this only when UI thread creation/handoff is unavailable and the user accepts the limitation. Transfer a redacted handoff packet to the remote folder, then start Codex inside a named `tmux` session. Confirm the session and Codex process exist before saying shutdown is safe. A `tmux` process is not a UI Handoff and should be described accurately.
