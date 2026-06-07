---
name: github-release-management
description: Handles professional GitHub release workflows including Semantic Versioning (SemVer), annotated tagging, automated changelogs, and branch protection. Use this skill when finalizing project milestones or versioning production-ready code.
---

# GitHub Release Management Standards

This skill provides a professional framework for versioning and releasing software on GitHub.

## Core Principles

### 1. Semantic Versioning (SemVer)
- Always follow `vMAJOR.MINOR.PATCH` format.
- **MAJOR:** Breaking changes.
- **MINOR:** New backward-compatible features.
- **PATCH:** Backward-compatible bug fixes.

### 2. Immutable Tagging
- Use **Annotated Tags** instead of lightweight tags.
- Command: `git tag -a v1.0.0 -m "Release version 1.0.0"`
- Never re-tag a specific version. If a fix is needed, increment the patch version.

### 3. Automated Changelogs
- Leverage GitHub's "Generate Release Notes" feature.
- Group changes into categories: `Features`, `Fixes`, `Documentation`, `Maintenance`.

## Standard Release Workflow

### Step 1: Finalize Branch
Ensure `main` (or the release branch) is up-to-date and passing all checks.

### Step 2: Tag and Push
1. Create an annotated tag:
   ```bash
   git tag -a v1.0.0 -m "Initial production release"
   ```
2. Push the tag to remote:
   ```bash
   git push origin v1.0.0
   ```

### Step 3: Create GitHub Release
Use the `gh` CLI for professional automation:
```bash
gh release create v1.0.0 --title "v1.0.0: Initial Release" --generate-notes
```

## Branching and Quality Mandate

Professional repositories MUST enforce a structured workflow:

### 1. Branching Strategy
- **`main`:** The protected production branch. No direct commits allowed.
- **`feat/`**: New features or capabilities.
- **`fix/`**: Bug fixes.
- **`chore/`**: Maintenance, CI/CD, or configuration updates.
- **`docs/`**: Documentation improvements.

### 2. CI/CD Infrastructure
- **Pre-commit Hooks:** Must be configured via `.pre-commit-config.yaml` to enforce:
  - Syntax/Linting (e.g., `luacheck` for Lua).
  - Code style (trailing whitespace, end-of-file).
  - Conventional Commit validation.
- **GitHub Actions:** Every Pull Request MUST trigger automated pipelines to:
  - Verify code quality and syntax.
  - Lint commit messages.
  - Run any available tests.

### 3. Pull Request Standards
- **Templates:** Use `.github/PULL_REQUEST_TEMPLATE.md` to ensure consistent descriptions.
- **Review:** Require at least one approving review before merging into `main`.
- **Validation:** All CI checks must pass before the "Merge" button is enabled.

## Code Review & Approval Workflow

Professional contributions MUST follow this feedback loop:

### 1. Analysis of Feedback
- When a reviewer (human or bot) provides comments, analyze them for:
  - **Correctness:** Does the suggestion fix a bug or prevent a crash?
  - **Elegance:** Does it improve readability or maintainability?
  - **Relevance:** Is the suggestion applicable to the current environment?

### 2. Addressing Changes
- **Implement:** Apply valid suggestions immediately using surgical edits.
- **Explain:** If a suggestion is ignored (e.g., sunsetting notifications), provide a technical rationale in the PR thread.
- **Verify:** Re-run local pre-commit hooks and ensure CI passes after changes.

### 3. Final Approval
- Request a re-review after addressing all comments.
- **DO NOT** merge until:
  1. The "Changes Requested" status is cleared.
  2. At least one "Approve" vote is received.
  3. All CI status checks (linting, tests) are GREEN.

