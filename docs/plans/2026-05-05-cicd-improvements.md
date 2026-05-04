# CI/CD Pipeline Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add PR build+test CI, SwiftLint enforcement, automated release note drafting, and a PR template to the Pint open source pipeline.

**Architecture:** Five new files and one edit to `release.yml`. No application code changes except auto-fixes from `swiftlint --fix`. Tasks are independent and can be committed separately; all should land before the next tag push.

**Tech Stack:** GitHub Actions, SwiftLint (Homebrew), release-drafter/release-drafter@v6, xcodebuild (macOS 15), softprops/action-gh-release@v2

---

### Task 1: Add SwiftLint config and fix existing violations

**Files:**
- Create: `.swiftlint.yml`
- Modify: various Swift files under `Pint/` (auto-fixed by `swiftlint --fix`)

- [ ] **Step 1: Install SwiftLint locally**

```bash
brew install swiftlint
swiftlint version
```

Expected: version string printed (e.g. `0.57.0`).

- [ ] **Step 2: Create `.swiftlint.yml`**

Create `/Users/imajeetyadav/CodingProtocols/Projects/Pint/.swiftlint.yml`:

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

reporter: "github-actions"
```

- [ ] **Step 3: Check current violation count**

```bash
cd /Users/imajeetyadav/CodingProtocols/Projects/Pint && swiftlint 2>&1 | tail -5
```

Expected: output ending with a summary like `Done linting! Found N violations, M serious in K files.`

Note the total — if it is already ≤ 10, skip Step 4 and go straight to Step 5.

- [ ] **Step 4: Auto-fix fixable violations**

```bash
cd /Users/imajeetyadav/CodingProtocols/Projects/Pint && swiftlint --fix
```

Expected: list of files modified. Handles `closure_spacing`, `explicit_init`, `redundant_nil_coalescing` automatically.

Then re-check:

```bash
swiftlint 2>&1 | tail -3
```

Expected: `Found N violations` where N ≤ 10. If N is still > 10, identify the noisiest rule in the output and add it to `disabled_rules` in `.swiftlint.yml`, then rerun `swiftlint`.

- [ ] **Step 5: Commit**

```bash
cd /Users/imajeetyadav/CodingProtocols/Projects/Pint
git add .swiftlint.yml Pint/
git commit -m "chore: add SwiftLint config and fix existing violations"
```

---

### Task 2: Add PR CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-test:
    name: Build & Test
    runs-on: macos-15

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Cache derived data
        uses: actions/cache@v4
        with:
          path: build
          key: derived-data-${{ hashFiles('**/*.swift', 'Pint.xcodeproj/project.pbxproj') }}
          restore-keys: derived-data-

      - name: Install SwiftLint
        run: brew install swiftlint

      - name: Run SwiftLint
        run: swiftlint

      - name: Build
        run: |
          xcodebuild \
            -project Pint.xcodeproj \
            -scheme Pint \
            -configuration Debug \
            -derivedDataPath build \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            build

      - name: Run tests
        run: |
          xcodebuild \
            -project Pint.xcodeproj \
            -scheme Pint \
            -configuration Debug \
            -derivedDataPath build \
            -destination 'platform=macOS' \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            test
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add PR build and test workflow"
```

---

### Task 3: Add release-drafter

**Files:**
- Create: `.github/release-drafter.yml`
- Create: `.github/workflows/release-drafter.yml`

- [ ] **Step 1: Create `.github/release-drafter.yml`**

```yaml
name-template: 'Pint $RESOLVED_VERSION'
tag-template: 'v$RESOLVED_VERSION'

categories:
  - title: '⚠️ Breaking Changes'
    labels: ['breaking']
  - title: '🚀 Enhancements'
    labels: ['enhancement']
  - title: '🐛 Bug Fixes'
    labels: ['bug']
  - title: '🧹 Maintenance'
    labels: ['chore', 'dependencies']
  - title: '📚 Documentation'
    labels: ['documentation']

version-resolver:
  major:
    labels: ['breaking']
  minor:
    labels: ['enhancement']
  patch:
    labels: ['bug', 'chore', 'dependencies', 'documentation']
  default: patch

exclude-labels:
  - 'skip-changelog'

template: |
  $CHANGES

  ### Installation
  1. Download `Pint-$RESOLVED_VERSION.dmg` below
  2. Open the DMG and drag `Pint.app` to `/Applications`
  3. Launch — no "right-click → Open" required (notarized by Apple)

  ### Auto-updates
  Pint will notify you automatically when a new version is available
  via Sparkle. Use **Pint → Check for Updates…** to check manually.

  > **Requires:** macOS 15.0 (Sequoia) or later + [Homebrew](https://brew.sh)

  See [CHANGELOG.md](CHANGELOG.md) for full release notes.
```

- [ ] **Step 2: Create `.github/workflows/release-drafter.yml`**

```yaml
name: Release Drafter

on:
  push:
    branches: [main]
  pull_request:
    types: [opened, reopened, synchronize]

permissions:
  contents: read

jobs:
  update-release-draft:
    name: Update Release Draft
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: release-drafter/release-drafter@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 3: Validate both YAML files**

```bash
python3 -c "
import yaml
for f in ['.github/release-drafter.yml', '.github/workflows/release-drafter.yml']:
    yaml.safe_load(open(f))
    print(f'OK: {f}')
"
```

Expected:
```
OK: .github/release-drafter.yml
OK: .github/workflows/release-drafter.yml
```

- [ ] **Step 4: Commit**

```bash
git add .github/release-drafter.yml .github/workflows/release-drafter.yml
git commit -m "ci: add release-drafter for automated release notes"
```

---

### Task 4: Add PR template

**Files:**
- Create: `.github/pull_request_template.md`

- [ ] **Step 1: Create `.github/pull_request_template.md`**

```markdown
## Summary
<!-- One line — this becomes your release notes entry -->

## Type of change
- [ ] Bug fix (`bug` label)
- [ ] Enhancement (`enhancement` label)
- [ ] Chore / refactor (`chore` label)
- [ ] Documentation (`documentation` label)
- [ ] Breaking change (`breaking` label)

## Testing done

## Checklist
- [ ] Tests pass locally (`xcodebuild test -scheme Pint -destination 'platform=macOS'`)
- [ ] SwiftLint clean (`swiftlint` from project root)
- [ ] Label applied (for release notes categorization)
```

- [ ] **Step 2: Commit**

```bash
git add .github/pull_request_template.md
git commit -m "chore: add PR template"
```

---

### Task 5: Remove hardcoded release body from release.yml

When release-drafter creates a draft and the maintainer pushes a tag, `softprops/action-gh-release` will find the existing draft (matched by tag name) and publish it with the DMG attached — preserving the release-drafter body. The hardcoded `body:` block in `release.yml` overrides that, so remove it.

**Files:**
- Modify: `.github/workflows/release.yml` — remove `body:` block from "Create GitHub Release" step (lines 413–431 approximately)

- [ ] **Step 1: Edit `.github/workflows/release.yml`**

Find the "Create GitHub Release" step. Replace the entire step with:

```yaml
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: Pint ${{ needs.build.outputs.tag }}
          files: ${{ steps.dmg.outputs.DMG_PATH }}
          fail_on_unmatched_files: true
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

(The only change is removing the `body: |` block and its 14 lines of markdown.)

- [ ] **Step 2: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: remove hardcoded release body (release-drafter draft body used instead)"
```

---

### Task 6: One-time label setup (run locally after merging, not a workflow)

These `gh` commands create the labels that release-drafter uses for categorization. Run once from a terminal authenticated to the repo (after all the above PRs/commits are merged to `main`).

- [ ] **Step 1: Create labels**

```bash
gh label create "enhancement"    --color "0075ca" --description "New feature or request"     --force
gh label create "bug"            --color "d73a4a" --description "Something isn't working"     --force
gh label create "chore"          --color "e4e669" --description "Maintenance, refactor, deps"  --force
gh label create "dependencies"   --color "0366d6" --description "Dependency updates"           --force
gh label create "documentation"  --color "0075ca" --description "Documentation only"           --force
gh label create "breaking"       --color "b60205" --description "Breaking change"              --force
gh label create "skip-changelog" --color "ededed" --description "Exclude from release notes"  --force
```

Expected: each line prints `✓ Created label "..."` (or silently updates if it already exists, due to `--force`).

- [ ] **Step 2: Verify**

```bash
gh label list
```

Expected: table includes all 7 labels above.
