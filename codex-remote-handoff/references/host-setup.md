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

Ensure the installed `codex` is on the remote login shell's `PATH`, because the desktop app starts and manages remote services through SSH using that shell. Install `bubblewrap` when the Linux sandbox reports it missing. `tmux` is not required for the Desktop-visible persistent-runtime path.

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

## Start and verify the persistent remote runtime

Start the managed daemon with:

```bash
codex remote-control start --json
```

The command is experimental and its JSON schema may change. Do not print pairing codes, credentials, or unrelated daemon metadata. From a new SSH connection, verify that the managed app-server and proxy processes remain alive after the start command has exited. Prefer a supported status response when the installed CLI provides one. Otherwise inspect process ownership and require a long-lived manager rather than an interactive SSH shell.

If start fails with an error equivalent to `app server is running but is not managed by codex app-server daemon`:

1. Inspect the target host's threads in the Codex app.
2. If any remote thread is active, do not stop, kill, or replace the existing app-server. Report that a controlled daemon transition must wait until the task is idle.
3. If no remote thread is active, identify the exact unmanaged app-server and proxy processes. Transition them only as part of an explicitly requested host preparation/repair, then immediately run `codex remote-control start --json` and verify reconnection. Do not use broad `pkill` patterns.
4. Do not treat an orphaned process with PID 1 as proof that it is managed by `remote-control`; require the start command or supported daemon status to recognize it.

Managed SSH workflows use `codex remote-control`; do not replace it with a publicly exposed `codex app-server --listen` endpoint. Create a manual pairing code only when the Desktop connection flow explicitly requires one, and treat the short-lived code as a secret.

Because remote control is experimental, verify the actual Desktop connection and a remote thread before relying on it for unattended work.

## Save the SSH project in the desktop UI

Open **Settings > Connections > SSH**, add or enable the concrete SSH alias, and select the remote folder. Confirm that `list_projects` reports the folder with the expected remote `hostId`. Remote projects may be ordinary directories; Git is required only for product Handoff, not for a new remote continuation chat.

If the host exists but no remote project is saved, stop after opening or identifying the SSH connection setup. Ask the user to select the folder if the UI requires an interactive choice that cannot be made safely on their behalf.

After saving the folder, start a disposable remote chat from the Desktop UI and confirm that it is associated with the remote host. Reconnect to the project once before using it for an unattended task.

## Terminal-only fallback

Use `tmux` only when the user explicitly accepts a terminal-only session that will not appear as a normal Desktop chat. Transfer a redacted handoff packet to the remote folder, start Codex inside a named session, and verify the process. This fallback does not satisfy the UI reconnection goal and must be labeled accordingly.
