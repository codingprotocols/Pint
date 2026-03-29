# Contributing to Pint

Thank you for taking the time to contribute.

## Getting Started

1. **Fork** the repository and create your branch from `main`
2. **Build** — open `Pint.xcodeproj` in Xcode and press `⌘R`
3. **Make your changes** — see the architecture notes in the README
4. **Test manually** — there are no automated tests; verify your changes run correctly against a real Homebrew installation
5. **Open a pull request** against `main`

## Branch Naming

| Type | Pattern | Example |
|---|---|---|
| Feature | `feat/description` | `feat/dark-mode-toggle` |
| Bug fix | `fix/description` | `fix/search-crash-on-empty` |
| Chore | `chore/description` | `chore/update-dependencies` |

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Describe what changed and why in the PR body
- Include steps to manually verify the change
- PRs that break the build will not be merged

## Code Style

- Follow existing Swift conventions in the codebase
- Use `@MainActor` and Swift Concurrency patterns consistent with the rest of the app (see README architecture section)
- Avoid adding third-party dependencies without prior discussion

## Releases & Tags

**Only maintainers create version tags.** Tags matching `v*` are protected — pushing one triggers the full release pipeline (code signing, notarization, Sparkle appcast update, GitHub Release). Contributors should not attempt to create or push version tags.

If you believe a new release is warranted, open an issue or mention it in your PR.

## Reporting Bugs

Open a [GitHub Issue](../../issues/new) with:
- macOS version
- Homebrew version (`brew --version`)
- Steps to reproduce
- What you expected vs. what happened

## Feature Requests

Open a [GitHub Issue](../../issues/new) describing the use case. Discussing before implementing avoids wasted effort.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
