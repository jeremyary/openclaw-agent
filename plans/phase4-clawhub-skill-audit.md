# Phase 4: ClawHub Skill Auditing

## Context

ClawHub has a documented malicious skill problem -- 341+ confirmed malicious skills, ~37% of audited skills contain security flaws, and a coordinated supply chain attack (ClawHavoc) planted 1,184 trojanized skills. Before we ever install a community skill on our OpenClaw instance, we need a repeatable vetting process.

This plan builds a practical skill vetting checklist by auditing 5+ skills (mix of popular and suspicious), then documents the methodology so it can eventually be handed to Rook as an automated triage capability.

**Goal:** Produce a documented, repeatable skill vetting checklist validated against real ClawHub skills.

## Tasks

### Task 1: Set Up Audit Environment

**What:** Create an isolated workspace and config for skill auditing, separate from production.

**Steps:**
- Create `workspace/skill-audit/` directory for audit artifacts
- Create a skill audit config variant (`config/openclaw-audit.json`) that:
  - Keeps `sandbox.mode: all`, `network: none`, `capDrop: ALL`
  - Removes all secrets (no API keys mounted during skill testing)
  - Enables `openclaw skills list` and `clawhub` CLI commands
  - Keeps `fs.workspaceOnly: true`
- Document the audit environment setup in `docs/skill-audit-methodology.md`
- Install `clawhub` CLI if not already available in the gateway container

**Exit condition:** `openclaw skills list` runs successfully in audit config; no secrets accessible in audit workspace.

**Files:** `config/openclaw-audit.json`, `docs/skill-audit-methodology.md`, `Dockerfile` (if clawhub CLI needs adding)

### Task 2: Discover and Select Skills

**What:** Research ClawHub to select 5+ skills for auditing -- 2-3 popular/well-regarded and 2-3 suspicious.

**Steps:**
- Use web search to browse ClawHub categories, popular skills, and the awesome-openclaw-skills list
- For each candidate, record: name, publisher, download count, permission declarations, age
- Selection criteria for "suspicious": excessive permissions, new publisher, obfuscated code, shell: true without clear justification
- Selection criteria for "popular": high download count, active maintenance, clear use case
- Document selections with rationale in `workspace/skill-audit/skill-selection.md`

**Exit condition:** 5+ skills selected with documented rationale for each choice.

**Files:** `workspace/skill-audit/skill-selection.md`

### Task 3: Build Static Analysis Checklist

**What:** Define what to inspect in a skill before installation, based on known attack patterns.

**Steps:**
- Review the documented attack patterns from ClawHavoc and audit reports:
  - Prompt injection in SKILL.md descriptor
  - Hidden reverse shells / curl to C2 (often base64-encoded)
  - Credential exfiltration from config/env vars
  - Dynamic code execution (eval, exec, require)
  - Obfuscated payloads (base64, hex, unicode)
- Build a checklist covering:
  - SKILL.md frontmatter review (permissions declared vs needed)
  - Script content inspection (grep for suspicious patterns)
  - Publisher history check (account age, other skills, reports)
  - Version history review (sudden changes, new maintainers)
  - Dependency audit (external URLs, package references)
- Document as `docs/skill-vetting-checklist.md`

**Exit condition:** Checklist document exists with concrete inspection steps and grep patterns for each category.

**Files:** `docs/skill-vetting-checklist.md`

### Task 4: Audit Selected Skills (Static)

**What:** Apply the checklist from Task 3 to each selected skill. This is pre-install inspection only.

**Steps:**
- For each of the 5+ selected skills:
  - Use `clawhub inspect <slug>` to view without installing
  - Review SKILL.md frontmatter (capabilities, permissions, env vars)
  - Review all executable content (scripts, commands)
  - Check for known malicious patterns (base64 payloads, curl to unknown domains, eval/exec)
  - Check publisher profile and version history
  - Record findings in per-skill audit file
- Classify each skill: SAFE / SUSPICIOUS / MALICIOUS with evidence

**Exit condition:** 5+ per-skill audit reports in `workspace/skill-audit/reports/`. Each report has a classification with supporting evidence.

**Files:** `workspace/skill-audit/reports/<skill-name>-audit.md` (one per skill)

### Task 5: Behavioral Analysis (Runtime)

**What:** Install SAFE-classified skills in the isolated audit environment and observe runtime behavior.

**Steps:**
- Only install skills classified as SAFE in Task 4
- Install one at a time: `clawhub install <slug> --version <X>`
- Invoke the skill with a controlled prompt
- Capture and review JSONL transcripts:
  - What tools did the skill actually invoke?
  - Did tool usage match declared permissions?
  - Any unexpected file access, network attempts, or memory writes?
  - Any prompt injection attempts in skill output?
- Compare declared capabilities vs observed behavior
- Update audit reports with runtime findings

**Exit condition:** Runtime audit data added to each SAFE skill's report. Declared vs actual behavior comparison documented.

**Files:** `workspace/skill-audit/reports/<skill-name>-audit.md` (updated), JSONL transcripts preserved

### Task 6: Finalize Checklist and Document Findings

**What:** Refine the vetting checklist based on what we learned, write up findings.

**Steps:**
- Update `docs/skill-vetting-checklist.md` with lessons learned:
  - Which checklist items caught real issues?
  - What did we miss that should be added?
  - What was noise that can be deprioritized?
- Write summary findings in `docs/skill-audit-findings.md`:
  - Per-skill summaries
  - Common patterns observed
  - Recommendations for our OpenClaw instance
- Update `docs/threat-model.md` T7 entry with concrete findings
- Assess whether the checklist is automatable enough to hand to Rook

**Exit condition:** Final checklist + findings docs committed. Threat model updated.

**Files:** `docs/skill-vetting-checklist.md`, `docs/skill-audit-findings.md`, `docs/threat-model.md`

## Task Dependencies

```
Task 1 (environment) -> Task 2 (discover skills)
Task 2 -> Task 3 (build checklist) -- can run in parallel with Task 2
Task 2 + Task 3 -> Task 4 (static audit)
Task 4 -> Task 5 (runtime audit, SAFE skills only)
Task 4 + Task 5 -> Task 6 (finalize)
```

## Verification

- `openclaw skills check` passes in audit config
- 5+ per-skill audit reports exist with classifications
- Vetting checklist is concrete enough that someone unfamiliar could follow it
- Threat model T7 entry updated with real findings
- No secrets were exposed during any audit step

## Out of Scope

- Automated scanning tooling (future work, potentially Rook-driven)
- Multi-agent trust boundary testing (Phase 4 Area 3, deferred)
- Identity persistence attacks (Phase 4 Area 4, deferred)
- LangGraph comparison (Phase 4 Area 1, deferred)
