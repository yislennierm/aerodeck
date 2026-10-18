# Continue AERODECK work across chats and folders

Changing a repository’s location and continuing a conversation are separate operations. We can keep working in the existing chat by targeting the correct checkout. Files in the repository cannot, by themselves, reassign that chat’s recorded workspace or reproduce its entire transcript.

## Verify before editing

Open the standalone AERODECK folder and run:

```sh
python3 tools/context.py --check
```

The check reports the actual repository root, current working directory, origin, commit, version and runtime identity. It rejects execution from another repository or an equipment submodule unless explicitly allowed. Read [PROJECT-STATE.md](PROJECT-STATE.md), root AGENTS.md and CONTRIBUTING.md after checking the checkout.

## Continue the current conversation

In the IDE, open AERODECK’s folder or `AERODECK.code-workspace`, select the AERODECK root if needed, then select the existing conversation from Recent chats when it is available. Open-file context alone does not prove which repository a command will use; run the check above.

For Codex CLI builds supporting directory changes, wait until the primary chat is idle, then use `/cd /path/to/aerodeck` and `/pwd`. This continues the chat in the selected directory. These CLI commands are not a promise that the same controls exist in every IDE/app version.

For the desktop app, attach AERODECK as a project folder and make it primary for future chats. Confirm the existing chat’s actual directory separately. Official guidance: [Projects and chats](https://learn.chatgpt.com/docs/projects), [CLI directory commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli), and [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## Recover in a new chat when needed

Paste this with the actual checkout path:

```text
Continue AERODECK development in /path/to/aerodeck.
Run python3 tools/context.py --check from that directory first.
Read AGENTS.md, docs/development/PROJECT-STATE.md, docs/PROJECT-STATUS.md
and CONTRIBUTING.md. Inspect git status and current source-bound evidence.
Preserve existing work and the accepted UI/performance constraints.
Do not assume a published version is installed on the radio.
Current task: [the concrete change or defect to work on]
```

The longer [AI handover prompt](../AI-HANDOVER.md) supports a deeper review. Persistent guidance carries engineering decisions; it does not recover missing attachments, tool results or every message in an unavailable chat. Preserve important engineering findings in the project state and source-bound evidence as work progresses.
