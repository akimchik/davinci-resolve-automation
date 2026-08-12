---
name: github-release-management
description: Handles professional GitHub release workflows including Semantic Versioning (SemVer), annotated tagging, automated changelogs, and branch protection. Use this skill when finalizing project milestones or versioning production-ready code.
---

# GitHub Release Management Standards (Post-Mortem v1.2)

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
- **Templates:** Mandatory use of `.github/PULL_REQUEST_TEMPLATE.md`.

### 2. CI/CD & Local Verification
- **Verified Commit Policy:** The agent MUST run linting tools (e.g., `luacheck`) locally and achieve zero warnings BEFORE any commit.
- **CI Configuration:** Workflows (GitHub Actions) MUST strictly target project files and exclude dependency folders (e.g., `.luarocks/`).
- **Template Linting:** CI must lint example configurations (`config.lua.example`) instead of ignored local files.

### 3. Privacy & Security
- **Path Guardrails:** Commit hooks MUST be configured to scan for absolute home paths (e.g., USER_HOME_DIR) and block them.
- **Secret Scanning:** Annotated tagging and releases must only proceed after secret scanning passes.
- **Dynamic Portability:** Prefer `os.getenv("HOME")` or relative path resolution over hardcoded system paths.

### 4. Code Review Loop
- **Analyze Feedback:** Treat reviewer/bot comments with high priority. Analyze for Correctness, Elegance, and Relevance.
- **Resolve Conversation:** Only mark review threads as resolved AFTER implementing a surgical fix and verifying it locally.
- **Admin Merge:** As a last resort for self-approval, use `gh pr merge --admin` only after all CI checks are green.
