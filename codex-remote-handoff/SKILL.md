---
name: codex-remote-handoff
description: Move the active task and its essential context to Codex CLI in tmux on an always-on SSH host, keep it running after the local computer shuts down, and reconnect to the same remote terminal later. Use for overnight or unattended remote continuation without depending on Codex Desktop runtime or a Git repository.
---

# Codex Remote Handoff

Continue the current task in a persistent Codex CLI session owned entirely by the remote SSH host. Codex Desktop may initiate the handoff, but after launch the desktop process, its SSH connection, and the local computer are not required.

This workflow creates a new remote CLI conversation seeded with a self-contained handoff packet. It does not migrate the current chat's internal thread state, and the remote CLI session will not appear as a normal Codex Desktop chat.

Default personal target when the user does not name another host:

- SSH alias: `ecs-0904`
- Host address: `47.85.15.56`
- Remote folder: `/root/codex_project`

## Prepare the handoff

1. Confirm SSH access and inspect the exact target directory without modifying unrelated files.
2. Verify `tmux`, Codex CLI, and `codex login status` on the remote host. If anything is missing, read [references/host-setup.md](references/host-setup.md) and prepare only the missing prerequisite.
3. Check for an existing tmux session or handoff manifest for the same task. Reattach or resume it instead of creating a duplicate.
4. Build a self-contained Markdown handoff packet containing:
   - the user's objective and observable definition of done;
   - relevant conversational context, decisions, constraints, paths, and environment facts;
   - work already completed and its verification evidence;
   - remaining work, blockers, and the exact next action;
   - authorization boundaries and any actions that still require the user;
   - instructions to work autonomously, verify the outcome, and stop for genuine blockers.

Never place tokens, passwords, private keys, pairing codes, or raw authentication files in the packet. Copy needed project files separately and explicitly; conversational context alone does not transfer local files.

## Start the remote CLI session

Use a short unique tmux name derived from the task, such as `codex-<topic>-<date>`. Store the packet and a small manifest under a task-specific directory inside `/root/codex_project/.handoffs/`. The manifest should record the tmux name, working directory, packet path, start time, and known Codex session ID when available.

Start a detached tmux session in the intended working directory and launch interactive Codex CLI there. Prefer the normal sandbox and non-blocking approval policy appropriate to the task, for example:

```bash
tmux new-session -d -s "$session_name" -c "$work_dir" \
  'exec codex --no-alt-screen --ask-for-approval never --sandbox workspace-write'
```

Do not use `--dangerously-bypass-approvals-and-sandbox` unless the user explicitly requests that risk and the remote environment is externally isolated. Add writable directories or web search only when the task needs them.

After the TUI is ready, paste the handoff packet into the tmux pane as literal input rather than interpolating it into a shell command. For a long-running objective on a CLI version that supports Goals, submit a scoped `/goal` containing the objective, completion evidence, constraints, and a sensible budget, then tell Codex to begin. Goals continue at safe idle boundaries; they are not an unconditional infinite loop.

Use `tmux load-buffer`/`paste-buffer` or another literal-input mechanism so Markdown punctuation cannot execute as shell syntax. Do not put the packet on the remote process command line, where it may be exposed or damaged by quoting.

## Verify before local shutdown

From a fresh SSH connection, verify all of the following:

- the named tmux session exists and is detached or attachable;
- the pane contains a live `codex` process, not only a shell or stale tmux server;
- the first task turn or Goal has started and is not waiting for approval or missing input;
- the handoff packet and all required files exist on the remote host;
- the remote host can reach the required services;
- a second fresh SSH connection can capture the pane without relying on the initiating connection.

Report the SSH alias, tmux session name, remote working directory, current status, and the exact reconnect command. Do not say shutdown is safe until every check passes.

## Reconnect or recover

Reconnect directly from any terminal with:

```bash
ssh -t ecs-0904 'tmux attach -t <session-name>'
```

Detaching with `Ctrl-b d` leaves the remote task running. Closing the local terminal or powering off the local computer does not stop a healthy detached tmux session.

If tmux is alive but Codex is idle, attach and continue in that same TUI. If the Codex process exited, do not claim the task is still running. From the recorded working directory, resume the persisted remote conversation by its recorded ID when available:

```bash
codex resume <session-id>
```

If no ID was recorded, use the interactive `codex resume` picker or, only when unambiguous in that working directory, `codex resume --last`. Codex session history lives on the remote host, so resume commands must run there under the same remote user and `CODEX_HOME`.

## Return the task to the local computer

Treat the return as another context-and-files handoff, not as live process migration:

1. Attach to the remote tmux session and inspect the current turn, Goal, modified files, and any pending tool or approval request. Wait for a safe turn boundary; do not interrupt an active write or deployment.
2. Pause an active Goal with `/goal pause` so the remote agent cannot continue changing files after the handoff snapshot.
3. Ask the remote Codex session to write a redacted return packet under its task-specific `.handoffs/` directory. It must contain the original objective, current status, decisions, commands and evidence, changed-file inventory, unresolved blockers, and the exact next action. Record the remote Codex session ID for rollback or later inspection.
4. Transfer the return packet and every required changed artifact to explicit local paths. Prefer normal version-control transfer when a repository already exists. For non-Git work, copy only the reviewed task directory or enumerated files with SSH/SCP/rsync; never copy remote `~/.codex`, credentials, caches, or unrelated home-directory contents.
5. Verify local file hashes or at least sizes and modification times for material artifacts before starting local work. Do not delete or overwrite unrelated local files; resolve collisions explicitly.
6. Continue from a local Codex chat or CLI session using the return packet as the first context. State clearly that this is a new local conversation carrying forward the remote task state, not the same internal thread.
7. Verify the local agent can read the required files and restates the correct objective and next action. Only then stop or archive the remote tmux session if the user wants it retired. Keeping a paused remote session temporarily provides a rollback point.

If the user invokes this skill from a local Codex chat with a named remote tmux session, perform these checks and retrieve the return packet into the current task when safe. Do not start a second writer against the same files while the remote Goal remains active.

## Boundaries

- No Git repository is required. Do not initialize one solely for this workflow.
- Do not use Desktop `remote-control`, app-server handoff, `fork_thread`, or `create_thread` for the CLI-persistent path.
- Do not expose tmux, SSH, app-server, or Unix sockets publicly.
- A CLI session can be viewed in a Desktop terminal panel, but it is not a native Desktop chat and cannot be navigated to as one.
- Moving execution back to the local computer is a separate context/file handoff; preserve the paused remote session until local continuation is verified.
