# openclaw-agent

> Personal exploration and safe experimentation with the OpenClaw autonomous AI agent framework.

## Project Context

| Attribute | Value |
|-----------|-------|
| Maturity | PoC |
| Domain | AI agents / developer tooling |
| Primary Users | Single developer (personal project) |
| Compliance | None (personal project; follows Red Hat AI policy by convention) |

## Goals

1. Understand how OpenClaw functions internally (agent loop, tool calling, gateway architecture)
2. Establish safe usage patterns — guardrails, permission models, audit logging, kill switches
3. Explore OpenClaw's capabilities through controlled experimentation

## Non-Goals

- Production deployment or hosting for others
- Building a product or service
- Supporting multiple users or tenants

## Constraints

- Personal/home project, single developer
- Security-first approach: all agent capabilities must be explicitly bounded and auditable
- PoC scope: prioritize learning and safety over feature completeness

## Stakeholder Preferences
<!-- Accumulates over time as agents learn from interactions. Run /setup for initial values. -->

| Preference Area | Observed Pattern |
|-----------------|-----------------|

## Maturity Expectations

Maturity level governs **implementation quality**, not **workflow phases**. A PoC still follows the full plan-review-build-verify sequence when SDD criteria are met. See `.claude/rules/maturity-expectations.md` for the full matrix.

## Red Hat AI Compliance

All AI-assisted work in this project must comply with Red Hat's internal AI policies. The full machine-enforceable rules are in `.claude/rules/ai-compliance.md`. Summary of obligations:

1. **Human-in-the-Loop** — All AI-generated code must be reviewed, tested, and validated by a human before merge
2. **Sensitive Data Prohibition** — Never input confidential data, PII, credentials, or internal hostnames into AI tools
3. **AI Marking** — Include `// This project was developed with assistance from AI tools.` (or language equivalent) at the top of AI-assisted files, and use `Assisted-by:` / `Generated-by:` commit trailers
4. **Copyright & Licensing** — Verify generated code doesn't reproduce copyrighted implementations; all dependencies must use [Fedora Allowed Licenses](https://docs.fedoraproject.org/en-US/legal/allowed-licenses/)
5. **Upstream Contributions** — Check upstream project AI policies before contributing AI-generated code; default to disclosure
6. **Security Review** — Treat AI-generated code with the same or higher scrutiny as human-written code, especially for auth, crypto, and input handling

See `docs/ai-compliance-checklist.md` for the developer quick-reference checklist.

## Key Decisions

- **Language:** Python 3.11+
- **Framework:** OpenClaw (autonomous AI agent framework)
- **Package Manager:** uv
- **Linting/Formatting:** Ruff
- **Type Checking:** mypy
- **Testing:** pytest
- **Container:** Podman / Docker

---

## Agent System

This project uses a multi-agent system with specialized Claude Code agents. The main session handles routing and orchestration using the routing matrix in `.claude/CLAUDE.md`. Each agent has a defined role, model tier, and tool set optimized for its task.

### Quick Reference — "I need to..."

| Need | Agent | Command |
|------|-------|---------|
| Plan a feature or large task | **Main session** | Describe what you need; routing matrix and workflow-patterns skill guide orchestration |
| Design system architecture | **Architect** | `@architect` |
| Design feature-level implementation approach | **Tech Lead** | `@tech-lead` |
| Write backend/API code | **Backend Developer** | `@backend-developer` |
| Review code quality | **Code Reviewer** | `@code-reviewer` |
| Write or fix tests | **Test Engineer** | `@test-engineer` |
| Audit security | **Security Engineer** | `@security-engineer` |
| Debug a problem | **Debug Specialist** | `@debug-specialist` |

### How It Works

1. **Describe what you need** — for non-trivial tasks, the main session uses the routing matrix and workflow-patterns skill to select agents and sequence work.
2. **Use a specialist directly** when you know exactly which agent you need (e.g., `@backend-developer`).
3. **Rules files** enforce project conventions automatically — global rules are imported below, and path-scoped rules load automatically for matching files.
4. **Spec-Driven Development** is the default for non-trivial features — plan review before code review, machine-verifiable exit conditions, and anti-rubber-stamping governance.
5. **Skills** provide workflow templates and project convention references.

## Project Conventions

### Always-loaded rules (all sessions)

@.claude/rules/ai-compliance.md
@.claude/rules/python-style.md
@.claude/rules/git-workflow.md
@.claude/rules/testing.md
@.claude/rules/security.md
@.claude/rules/agent-workflow.md
@.claude/rules/review-governance.md

### Path-scoped rules (load automatically when editing matching files)

<!-- These rules are NOT @-imported to reduce context pressure on orchestrator sessions. -->
<!-- They load automatically via path-scoping when agents work on matching files. -->
<!-- - .claude/rules/error-handling.md      → src/** -->
<!-- - .claude/rules/observability.md       → src/** -->
<!-- - .claude/rules/architecture.md        → src/** -->
<!-- - .claude/rules/maturity-expectations.md (no path scope — loaded on demand) -->

## Project Commands

```bash
uv sync                   # Install dependencies
uv run pytest             # Run tests
uv run ruff check .       # Lint
uv run ruff format --check . # Check formatting
uv run mypy .             # Type check
```
