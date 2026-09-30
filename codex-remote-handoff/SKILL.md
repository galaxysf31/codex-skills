---
name: codex-remote-handoff
description: Keep a Codex task running on an always-on SSH host and reopen the same remote chat in Codex Desktop after the local computer restarts. Use when the user is shutting down, going offline, reconnecting to overnight work, or wants local conversational context continued on a persistent remote Codex host. Supports Git Handoff and non-Git remote continuation chats.
---

# Codex Remote Handoff

Make the remote machine the owner of the Codex runtime, session history, files, and execution. Codex Desktop on the user's computer is only a client that may disconnect and later reopen the same remote chat. Invoking this skill for a current task authorizes creating one continuation chat, starting it on the requested remote host, and sending it a continuation prompt. It does not authorize unrelated infrastructure changes or publishing code.

Default personal target when the user does not name another host:

- SSH alias: `ecs-0904`
- Codex host ID: `remote-ssh-discovered:ecs-0904`
- Remote folder: `/root/codex_project`

## Required architecture

The remote host must run the Codex remote-control/app-server daemon independently of the desktop's SSH process. Before dispatching work:

1. Inspect projects and hosts with the Codex app tools.
2. Over SSH, confirm Codex authentication and run `codex remote-control start --json`. A successful call should leave the managed app-server daemon running on the remote host.
3. From a separate SSH command, verify the daemon and its proxy are alive independently of the command that started them. Prefer service/daemon status when available; otherwise verify the app-server process has a long-lived manager such as PID 1 rather than the interactive SSH shell.
4. Confirm the desktop app has a saved project whose `hostId` is the requested host.

If any prerequisite is missing, read [references/host-setup.md](references/host-setup.md) and prepare only the missing pieces. `remote-control` is experimental, so observable liveness is required; command exit status alone is insufficient.

`remote-control start` is not idempotent when an app-server launched by another mechanism already owns its control socket. If it reports that the running app-server is not managed by the daemon, inspect remote threads first. Never kill or replace that process while a remote thread is active. Treat the host as not yet safe for unattended shutdown until a controlled daemon transition can be completed.

Do not expose app-server WebSocket or Unix-socket transports to a public network. Do not use an ordinary `tmux` Codex TUI as the primary route: it survives shutdown but does not become a normal Desktop chat.

## Send work to the remote host

Prefer **Fork and hand off** when the app offers a valid Git destination. Use **Non-Git continuation** when the project is not a Git repository, no matching repository exists on the destination, or only conversational context is required.

Never initialize a Git repository merely to make Handoff available. Do not claim that a new continuation chat is the same thread.

## Fork and hand off

The calling chat cannot hand itself off. Preserve its full history by forking it first:

1. Fork the calling chat with `fork_thread`, using the same-directory environment unless the user explicitly requests a worktree.
2. Hand the child chat to the target with `handoff_thread`. Include a short `followUpPrompt` that tells the child to continue the active objective autonomously on the remote host, verify its work, and report blockers only when user input is genuinely required.
3. Follow the handoff with `get_handoff_status`. Use a 30–60 second long poll and back off when the revision does not change; do not busy-poll.
4. Confirm completion only when the destination host is the requested remote host, the continuation turn has started, and the persistent remote daemon remains healthy. Return the child chat identity and the remote host to the user.

If Handoff fails because there is no compatible Git project, switch to the non-Git path instead of retrying the same operation.

## Non-Git continuation

Create a new UI-visible chat directly in the saved remote project:

1. Use `list_projects` to select the saved project whose `hostId` is the target host. Prefer `/root/codex_project` for the default target. Do not silently select a different host.
2. Build a self-contained handoff packet from the current conversation. Include:
   - the user's concrete objective and definition of done;
   - decisions, constraints, credentials already configured (without secret values), and relevant paths;
   - completed work and observable verification results;
   - remaining steps, current blockers, and the exact next action;
   - instructions to continue on the remote host and remain within the original authorization scope.
3. Call `create_thread` for that remote project with `environment: { type: "local" }`. The skill invocation counts as the user's explicit request for this one continuation chat. Use the handoff packet as the prompt and give the chat a concise title related to the task.
4. Call `wait_threads` so the remote thread is confirmed running or reports a real need for attention.
5. If an earlier fork was created but could not be handed off, archive that abandoned fork after the remote continuation exists; never delete it.
6. In the final response, emit the product's created-thread directive and state clearly that this is a context-preserving continuation chat, not an identical migrated thread.

After the thread starts, check the remote daemon again through a fresh SSH connection. Do not stop the daemon after dispatch.

## Reopen remote work from the desktop

When the user returns and asks to view or continue remote work:

1. Confirm the target SSH host and remote-control daemon are online.
2. Use `list_threads` to locate recent chats associated with the target host/project. Match by exact title and host before using recency; do not guess when multiple chats are plausible.
3. Use `read_thread` or a zero-timeout `wait_threads` snapshot to report its current state.
4. Use `navigate_to_codex_page` when the user asks to open it. The chat continues to execute on the remote host even though it is displayed in the local Desktop app.
5. If the chat is missing, repair the SSH connection or daemon first. Do not create a duplicate continuation unless the user requests one or the original is unrecoverable.

Reopening the chat is not a handoff back to local execution. Keep it attached to the remote host unless the user explicitly asks to migrate execution and the destination is supported.

## Completion criteria

Before saying the user may power off the local computer, verify all of the following:

- the remote host is online and authenticated;
- `codex remote-control` has a persistent, independently verified daemon;
- the continuation chat is attached to the requested remote host/project;
- the continuation prompt contains enough context to proceed without the local machine;
- the remote chat has started and does not need an unresolved approval or local-only resource;
- any files the task needs already exist on the remote host or are explicitly out of scope.

Report the remote chat title, thread identity, host, project path, daemon status, current task status, and how the user can reopen it. If any criterion is unmet, say that shutdown is not yet safe and identify the exact missing condition.

An ordinary detached `tmux` CLI session may be used only when the user explicitly accepts losing normal Desktop-chat visibility. Never describe that fallback as satisfying this skill's UI reconnection outcome.
