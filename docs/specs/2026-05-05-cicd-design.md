# CI/CD Pipeline Improvements — Design Spec

**Date:** 2026-05-05
**Branch:** fix/bugs-found-2026-05-04
**Status:** Approved, pending implementation

## Problem

The existing pipeline (`release.yml`) only runs on `v*` tag pushes. There is no automation between a contributor opening a PR and a release being cut:

- Broken code can land on `main` — no build check on PRs
- Unit tests in `PintTests/` never run in CI
- Release notes are hardcoded boilerplate; no connection to merged PRs

## Goals

1. Block broken PRs — build + test must pass before merge
2. Run the test suite automatically on every PR and push to `main`
3. Auto-draft release notes from merged PRs; maintainer edits and publishes

## Out of Scope

- Stale bot, README badges, CONTRIBUTING.md updates (Option C — deferred)
- UI/integration tests
- Changing the existing `release.yml` (beyond stripping its hardcoded release body)

---

## Design

### 1. PR CI Workflow — `.github/workflows/ci.yml`

**Triggers:** `pull_request` (all base branches), `push` to `main`
**Runner:** `macos-15` (matches release runner)

**Steps:**

| # | Step | Notes |
|---|------|-------|
| 1 | Checkout | `actions/checkout@v4` |
| 2 | Setup Xcode | `maxim-lobanov/setup-xcode@v1`, `latest-stable` |
| 3 | Restore derived data cache | Same key as `release.yml`: hash of `**/*.swift` + `project.pbxproj` |
| 4 | Install SwiftLint | `brew install swiftlint` |
| 5 | Run SwiftLint | Exit non-zero if >10 warnings (see SwiftLint section) |
| 6 | Build (no signing) | `xcodebuild build` with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` |
| 7 | Run tests | `xcodebuild test -scheme Pint` with same no-signing flags |

**Fork PR compatibility:** The workflow is fully secret-free. Fork PRs from contributors have no access to signing secrets and will work without modification.

**Concurrency:** Cancel in-progress runs for the same PR/branch on new push (`cancel-in-progress: true`) to avoid queuing up redundant runs.

---

### 2. Release Notes — release-drafter

**New files:**
- `.github/release-drafter.yml` — categorization config
- `.github/workflows/release-drafter.yml` — action workflow

**Workflow trigger:** `push` to `main` (runs after each merged PR, updates the draft).

**Label → category mapping:**

| Label | Category in Draft |
|-------|-------------------|
| `breaking` | ⚠️ Breaking Changes |
| `enhancement` | 🚀 Enhancements |
| `bug` | 🐛 Bug Fixes |
| `chore`, `dependencies` | 🧹 Maintenance |
| `documentation` | 📚 Documentation |
| *(none)* | Other Changes |

**Version bump resolver** (determines suggested next version in draft title):
- `breaking` → major
- `enhancement` → minor
- `bug`, `chore`, `dependencies`, `documentation` → patch

**Draft body template:** Auto-generated PR list inserted above the existing installation + auto-update boilerplate. Maintainer edits the draft freely before publishing.

**Cleanup:** Remove the hardcoded markdown body from `release.yml`'s "Create GitHub Release" step — the body will come from the release-drafter draft instead.

---

### 3. PR Template — `.github/pull_request_template.md`

Shown automatically when a contributor opens a PR. Intentionally lightweight:

```
## Summary
<!-- One line — this becomes the release notes entry -->

## Type of change
- [ ] Bug fix
- [ ] Enhancement
- [ ] Chore / refactor
- [ ] Documentation
- [ ] Breaking change

## Testing done

## Checklist
- [ ] Tests pass locally (`xcodebuild test -scheme Pint`)
- [ ] SwiftLint clean (or warnings explained)
- [ ] Label applied (for release notes categorization)
```

---

### 4. SwiftLint Config — `.swiftlint.yml`

**Philosophy:** Catch real issues; don't rewrite the existing codebase.

```yaml
opt_in_rules:
  - force_unwrapping
  - empty_count
  - closure_spacing
  - explicit_init
  - redundant_nil_coalescing

disabled_rules:
  - line_length
  - trailing_whitespace
  - todo

excluded:
  - .build
  - .worktrees

warning_threshold: 10

reporter: "github-actions"  # inline annotations on PRs
```

`PintTests/` is not excluded — force unwrapping in tests is surfaced as a warning (not error) and counted toward the threshold. This keeps the test suite honest without blocking it.

**Day-one setup:** Before the first CI run, do a local `swiftlint --fix` pass and commit the result so existing code doesn't immediately fail the `warning_threshold`.

---

## Labels to Create (one-time GitHub UI setup)

Run these `gh` commands once after merging:

```bash
gh label create "enhancement" --color "0075ca" --description "New feature or request"
gh label create "bug"         --color "d73a4a" --description "Something isn't working"
gh label create "chore"       --color "e4e669" --description "Maintenance, refactor, deps"
gh label create "dependencies" --color "0366d6" --description "Dependency updates"
gh label create "documentation" --color "0075ca" --description "Documentation only"
gh label create "breaking"    --color "b60205" --description "Breaking change"
```

---

## Files Changed

| File | Action |
|------|--------|
| `.github/workflows/ci.yml` | Create |
| `.github/workflows/release-drafter.yml` | Create |
| `.github/release-drafter.yml` | Create |
| `.github/pull_request_template.md` | Create |
| `.swiftlint.yml` | Create |
| `.github/workflows/release.yml` | Edit — remove hardcoded release body |

---

## Success Criteria

- A PR with a build error shows a failing CI check before it can be merged
- A PR that breaks a unit test shows a failing CI check
- After a PR merges to `main`, a draft GitHub Release is created/updated with that PR listed under the correct category
- SwiftLint annotations appear inline on PR diffs for any new violations
- Fork contributor PRs pass CI without any secret access
