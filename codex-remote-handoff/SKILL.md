---
name: codex-remote-handoff
description: Prepare an SSH host for Codex and move or continue the current Codex chat on that always-on host through the desktop UI. Use when the user says they are going offline, shutting down, hanging up, or wants a local task to keep running remotely. Prefer a forked-chat handoff; support non-Git folders with a context-preserving remote continuation chat.
---

# Codex Remote Handoff

Move ongoing work to an always-on Codex host and leave the user with a visible remote chat they can reopen in the desktop UI. Invoking this skill for a current task authorizes creating one continuation chat, starting it on the requested remote host, and sending it a continuation prompt. It does not authorize unrelated infrastructure changes or publishing code.

Default personal target when the user does not name another host:

- SSH alias: `ecs-0904`
- Codex host ID: `remote-ssh-discovered:ecs-0904`
- Remote folder: `/root/codex_project`

## Choose the path

1. Inspect available projects and hosts with the Codex app project/thread tools.
2. If the target host, remote project, Codex installation, or authentication is missing, read [references/host-setup.md](references/host-setup.md) and prepare only the missing pieces.
3. Prefer **Fork and hand off** when the app offers a valid destination for the current project.
4. Use **Non-Git continuation** when Handoff is unavailable because the project is not a Git repository, no matching repository exists on the destination, or the user only needs conversational context.

Never initialize a Git repository merely to make Handoff available. Do not claim that a new continuation chat is the same thread.

## Fork and hand off

The calling chat cannot hand itself off. Preserve its full history by forking it first:

1. Fork the calling chat with `fork_thread`, using the same-directory environment unless the user explicitly requests a worktree.
2. Hand the child chat to the target with `handoff_thread`. Include a short `followUpPrompt` that tells the child to continue the active objective autonomously on the remote host, verify its work, and report blockers only when user input is genuinely required.
3. Follow the handoff with `get_handoff_status`. Use a 30–60 second long poll and back off when the revision does not change; do not busy-poll.
4. Confirm completion only when the destination host is the requested remote host and the continuation turn has started. Return the child chat identity and the remote host to the user.

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
4. Call `wait_threads` so the remote thread is confirmed running or reports a real need for attention before telling the user it is safe to shut down.
5. If an earlier fork was created but could not be handed off, archive that abandoned fork after the remote continuation exists; never delete it.
6. In the final response, emit the product's created-thread directive and state clearly that this is a context-preserving continuation chat, not an identical migrated thread.

Do not use `tmux` as the primary path when the user asked for UI control. A detached CLI session is a fallback only when Codex app thread tools are unavailable and the user accepts that it will not be a normal remote UI chat.

## Completion criteria

Before saying the user may power off the local computer, verify all of the following:

- the remote host is online and authenticated;
- the continuation chat is attached to the requested remote host/project;
- the continuation prompt contains enough context to proceed without the local machine;
- the remote chat has started or reached a stable state that survives loss of the local session;
- any files the task needs already exist on the remote host or are explicitly out of scope.

Report the remote chat title, host, project path, current status, and how the user can reopen it. If any criterion is unmet, say that shutdown is not yet safe and identify the exact missing condition.
