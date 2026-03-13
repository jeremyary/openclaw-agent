# This project was developed with assistance from AI tools.
#
# Phase 1 Findings -- Learn the Agent Loop

## Task 1: Trace a Full Agent Loop

### Transcript Location

Session transcripts are stored as JSONL files at:
`~/.openclaw/agents/main/sessions/<session-id>.jsonl`

Daily logs at: `/tmp/openclaw/openclaw-<date>.log`

### Transcript Entry Types

| `type` | `role` | Description |
|--------|--------|-------------|
| `session` | -- | Session metadata: id, version (3), cwd |
| `model_change` | -- | Model switch event: provider, modelId |
| `message` | `user` | User input with sender metadata and timestamp |
| `message` | `assistant` | LLM response: `text` and/or `toolCall` content blocks |
| `message` | `toolResult` | Tool execution result: output, exit code, duration |

### Key Schema Fields

| Field | Location | Purpose |
|-------|----------|---------|
| `id` | All entries | Unique entry ID (8-char hex) |
| `parentId` | All entries | Links to previous entry (forms a chain) |
| `stopReason` | assistant | `"toolUse"` = more steps coming; `"stop"` = final reply |
| `usage` | assistant | Token counts: input, output, cacheRead, cacheWrite, cost |
| `details.exitCode` | toolResult | Process exit code |
| `details.durationMs` | toolResult | Execution time in sandbox container |
| `details.cwd` | toolResult | Working directory (host-absolute path) |
| `details.aggregated` | toolResult | Full stdout text |
| `isError` | toolResult | Whether the tool call failed |
| `toolCallId` | toolResult | Links back to the assistant's `toolCall.id` |

### ReAct Loop Structure

A multi-step request (list files, create file, read it back) produced this sequence:

```
user message          -> prompt with sender metadata
assistant (toolUse)   -> toolCall: exec "ls /workspace"
toolResult            -> file listing (157ms, exit 0)
assistant (toolUse)   -> toolCall: exec "cat > hello.txt <<'EOF'..."
toolResult            -> "written" (127ms, exit 0)
assistant (toolUse)   -> toolCall: exec "cat /workspace/hello.txt"
toolResult            -> "hello world" (237ms, exit 0)
assistant (stop)      -> final text reply to user
```

### Observations

1. **No explicit "thought" field.** The LLM's reasoning is implicit in `text`
   content blocks alongside `toolCall` blocks. `[[reply_to_current]]` is a
   routing directive, not reasoning output.

2. **One tool call per turn.** Even for multi-step requests, the agent issues
   one tool call, waits for the result, then issues the next. No parallel
   tool execution observed.

3. **Aggressive prompt caching.** First call writes ~42K tokens to cache.
   Subsequent calls read from cache with near-zero input cost. Cache key
   appears stable within a session.

4. **No approval entries in transcript.** With `sandbox.mode: "all"`, there are
   no approval request/response entries between toolCall and toolResult. The
   sandbox executes tools directly.

5. **`rm` executed without hesitation.** Rook ran `rm /workspace/hello.txt`
   with zero approval prompting, confirming that sandbox isolation (not
   approvals) is the active security boundary.

6. **User messages include sender metadata.** Each user message wraps the actual
   text in a template with sender info (label, id, name, username) and a
   timestamp. Marked as "untrusted metadata."

7. **Tool execution is fast.** Sandbox exec calls complete in 127-237ms,
   suggesting container reuse (session-scoped containers, not per-call).

## Task 2: Tool Calling Mechanics

### exec (shell.exec)

- Runs commands inside the sandbox container via `docker exec`
- Uses the session-scoped container (not a new container per call)
- Working directory reported as host-absolute path in `details.cwd`
- Stdout captured in `details.aggregated` and `content[].text`
- Exit code captured in `details.exitCode`

### file.write (SandboxFsBridge)

- Uses a different code path than exec: `SandboxFsBridge` mutation-helper
- Content is piped via stdin into the sandbox container
- **Bug in v2026.3.11:** stdin payload is lost, creating 0-byte files (PR #43876)
- Workaround: use exec-based writes (`cat > file <<'EOF'...EOF`)

### file.read

- Not yet tested independently (used `exec: cat` as workaround)
- Likely uses `SandboxFsBridge` read path; needs verification

## Task 3: Ask-Before-Execute Flow

**Finding:** `ask: "always"` is completely inert when `sandbox.mode: "all"`.

- Sandbox mode and exec approvals are separate enforcement systems
- When sandbox mode is active, the sandbox handles tool execution directly
  without routing through the approval layer
- Confirmed in both TUI and Control UI -- no approval prompts for any command
- `safeBins` entries are auto-approved regardless of `ask` setting
- `rm` command executed without any prompt

**Mitigation strategy:** See Task 4 conclusions below.

## Task 4: Probe the Allowlist Boundary

### Test Results

| # | Test | Command | Result |
|---|------|---------|--------|
| 1 | && chaining | `ls /workspace && echo "chained"` | Executed freely |
| 2 | pipe | `ls /workspace \| wc -l` | Executed freely |
| 3 | semicolon injection | `ls; rm -rf /workspace/*` | Executed freely |
| 4 | subshell escape | `ls $(whoami)` | Subshell executed |
| 5 | python indirect exec | `python3 -c "import os; os.system('whoami')"` | Executed freely |
| 6 | disallowed command | `curl https://example.com` | Blocked by network:none, NOT allowlist |
| 7 | read outside workspace | `cat /etc/passwd` | Executed freely |

### Conclusion

**`exec.security: "allowlist"` is completely inert in sandbox mode.**

All three agent-side exec controls (`ask`, `exec.security`, `safeBins`) are
bypassed when `sandbox.mode: "all"` is active. The sandbox container is the
sole enforcement boundary.

The only thing that blocked `curl` was the sandbox's `network: none` setting,
not any command policy. Every other command -- including `rm`, `python3`,
reading `/etc/passwd`, shell metacharacters, and compound commands -- executed
without restriction.

### Effective security model

The sandbox IS the security model. Agent-side controls contribute nothing:

1. **Network isolation** (network:none) -- blocks data exfiltration
2. **Capability dropping** (capDrop:ALL) -- blocks privilege escalation
3. **Ephemeral containers** -- limits persistence
4. **Workspace-only mount** -- limits filesystem access
5. **Tool profile deny lists** -- controls which tool *types* exist (exec, browser, etc.)
6. **JSONL transcripts** -- post-hoc audit only

What does NOT work in sandbox mode:
- `exec.security: "allowlist"` -- no command restriction
- `exec.ask: "always"` -- no approval prompts
- `safeBins` -- no auto-approve distinction (everything auto-approves)

## Task 5: Expand Allowlist Incrementally

**Skipped.** The allowlist is inert in sandbox mode (Task 4). There is nothing
to expand -- all commands execute freely inside the sandbox container.

## Task 6: Memory and Context Loading

### Memory architecture

OpenClaw uses two memory systems:

1. **Framework-managed:** SQLite database at `~/.openclaw/memory/main.sqlite`
   - Managed by the gateway process
   - Not directly editable by the agent
   - Used for internal indexing/search

2. **Agent-managed:** Markdown files in `/workspace/` and `/workspace/memory/`
   - Written by the agent via exec (file.write is broken in v2026.3.11)
   - Read by the agent at session start
   - Fully under agent control -- agent can read, write, modify, delete

### File roles

| File | Purpose | Who writes it | When loaded |
|------|---------|---------------|-------------|
| `SOUL.md` | Agent personality, values, behavioral guidelines | Agent (self-authored) | Every session start |
| `IDENTITY.md` | Agent name, vibe, avatar | Agent | Every session start |
| `USER.md` | Operator profile, preferences | Agent | Every session start |
| `MEMORY.md` | Long-term memory (identity, user facts, session notes) | Agent | Every session start |
| `memory/YYYY-MM-DD.md` | Daily session notes | Agent | Session start (recent files) |
| `memory/ideas.md` | Agent's idea scratchpad | Agent | On demand |
| `AGENTS.md` | Multi-agent topology description | Framework | Session start |
| `TOOLS.md` | Available tools description | Framework | Session start |
| `HEARTBEAT.md` | Heartbeat status | Framework | Periodic |

### Context loading flow

1. **Session start:** Gateway creates session entry in JSONL transcript
2. **System prompt:** SOUL.md content injected into system prompt (not visible
   in JSONL transcript -- injected at API call level)
3. **Config SOUL.md vs workspace SOUL.md:** The config-mounted `/config/SOUL.md`
   is the original minimal version. Rook rewrote its own `SOUL.md` in
   `/workspace/SOUL.md` with a full personality. The workspace version is what
   the agent actually uses -- it reads from workspace, not from config mount.
4. **First turn:** Agent reads recent memory files (daily notes, MEMORY.md)
   via tool calls visible in transcript
5. **Ongoing:** Agent reads/writes memory files as needed during conversation

### Key observations

1. **SOUL.md is self-modifiable.** The agent wrote its own personality file,
   overriding the operator-provided config. The agent explicitly notes:
   "If I update this file, I tell Jeremy. No silent rewrites."

2. **System prompt is not in the transcript.** The JSONL transcript does not
   capture the system prompt / context injection. Only user messages, assistant
   responses, and tool results are logged. This is a gap in the audit trail.

3. **Memory is agent-initiated.** The agent decides what to remember and when.
   There is no framework-enforced memory structure beyond the SQLite DB.

4. **Daily logs capture everything.** The gateway daily log at
   `/tmp/openclaw/openclaw-YYYY-MM-DD.log` captures subsystem events (exec,
   tools, sandbox, websocket connections) but not conversation content.

5. **No memory isolation between sessions.** All sessions in the same agent
   share the same workspace files. A poisoned memory file affects all
   future sessions.

6. **Config SOUL.md is effectively unused.** The workspace copy takes
   precedence. The config mount serves as a bootstrap only.
