---
name: github-release-management
description: Handles professional GitHub release workflows including Semantic Versioning (SemVer), annotated tagging, automated changelogs, and branch protection. Use this skill when finalizing project milestones or versioning production-ready code.
---

# GitHub Release Management Standards (Post-Mortem v1.1)

This skill mandates professional Git and CI/CD standards to prevent unverified code and data leakage.

## Core Mandates

### 1. Branching & PR Hygiene
- **Protected Main:** NEVER commit directly to `main`. Use `feat/`, `fix/`, or `chore/` branches.
- **Mandatory Branching Algorithm:** You MUST follow this exact 4-step sequence when creating a new branch:
  1. `git checkout main`
  2. `git branch <issue-name-(iteration-num)>`
  3. `git push origin <issue-name-(iteration-num)>`
  4. `git checkout <issue-name-(iteration-num)>`
- **Atomic Pull Requests:** Keep PRs focused on a single logical change.
- **Continuous Changelog:** Every PR MUST include a corresponding update to `CHANGELOG.md` to document the changes. Do not wait until the final release to write the changelog.
- **Templates:** Mandatory use of `.github/PULL_REQUEST_TEMPLATE.md`.

### 2. CI/CD & Local Verification
- **Verified Commit Policy:** The agent MUST run verification tools (e.g., Python `pytest`, `flake8`, or relevant scripts) locally and achieve zero warnings/errors BEFORE any commit.
- **Pre-Flight Impact Analysis (DoD):** Before finalizing a task or proposing a PR merge, the agent MUST perform a cross-repository impact analysis. If execution commands (tests, builds) are modified, the agent MUST globally search the `.github/workflows/` directory and update any affected CI pipelines.
- **Definition of Done Check:** The agent is strictly required to read the `.github/PULL_REQUEST_TEMPLATE.md` and complete the **Definition of Done (Impact Analysis)** checklist for every PR to explicitly verify CI/CD pipelines, documentation, and coverage levels.
- **CI Configuration:** Workflows (GitHub Actions) MUST strictly target project files and exclude dependency folders (e.g., `.venv/`).
- **Template Linting:** CI must lint example configurations (`.env.example`) instead of ignored local files.

### 3. Privacy & Security
- **Path Guardrails:** Commit hooks MUST be configured to scan for absolute home paths (e.g., USER_HOME_DIR) and block them.
- **Secret Scanning:** Annotated tagging and releases must only proceed after secret scanning passes.
- **Dynamic Portability:** Prefer `os.getenv("HOME")` or relative path resolution over hardcoded system paths.

### 4. Code Review Loop
- **Analyze Feedback:** Treat reviewer/bot comments with high priority. Analyze for Correctness, Elegance, and Relevance.
- **Resolve Conversation:** Only mark review threads as resolved AFTER implementing a surgical fix and verifying it locally.
- **ABSOLUTE FORBIDDEN:** The agent MUST NEVER use the `--admin` flag to merge a PR. All PRs must remain open until explicitly merged by the human user. No exceptions.
