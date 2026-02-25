---
description: Customizable project conventions template. Adapt these settings to match your specific project's technology stack, structure, and standards.
user_invocable: false
---

# Project Conventions

Customize the sections below to match your project. All agents reference these conventions when making implementation decisions.

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Language | Python | 3.11+ |
| Framework | OpenClaw | — |
| Package Manager | uv | — |
| Linting / Formatting | Ruff | — |
| Type Checking | mypy | — |
| Testing | pytest | — |
| Container | Podman / Docker | — |

## Project Structure

```
openclaw-agent/
├── src/                     # Application source code
│   └── openclaw_agent/      # Main Python package
├── tests/                   # Test files
├── configs/                 # Configuration files (agent configs, guardrails)
├── plans/                   # SDD planning artifacts
│   └── reviews/             # Agent review documents
├── docs/                    # Documentation
├── pyproject.toml           # Python project configuration
└── Makefile                 # Common development commands
```

## Planning Artifacts (SDD Workflow)

When following the Spec-Driven Development workflow (see `workflow-patterns/SKILL.md`), planning artifacts live in `plans/` with agent reviews in `plans/reviews/`.

| Artifact | Path | Produced By |
|----------|------|-------------|
| Architecture design | `plans/architecture.md` | @architect |
| Technical design (per phase) | `plans/technical-design-phase-N.md` | @tech-lead |
| Agent review | `plans/reviews/<artifact>-review-<agent-name>.md` | Reviewing agent |
| Orchestrator review | `plans/reviews/<artifact>-review-orchestrator.md` | Main session (orchestrator) |

### Review File Naming Convention

```
plans/reviews/architecture-review-security-engineer.md
plans/reviews/architecture-review-orchestrator.md
plans/reviews/technical-design-phase-1-review-code-reviewer.md
plans/reviews/technical-design-phase-1-review-orchestrator.md
```

## Cross-References

Detailed conventions are defined in the rules files — do not duplicate here:

- **Naming:** `python-style.md`
- **Error handling:** `error-handling.md`
- **Git workflow:** `git-workflow.md`
- **Security:** `security.md`
