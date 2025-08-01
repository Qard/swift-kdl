# GitHub Actions Documentation

This document explains the GitHub Actions workflows configured for this Swift package.

## Workflows

### CI (`ci.yml`)
- Runs on every push and pull request to the `main` branch
- Tests the package on both macOS and Linux
- Builds the package and runs all tests

### Code Quality (`code-quality.yml`)
- Runs on every push and pull request to the `main` branch
- Checks code formatting using `swift-format` (if available)
- Runs SwiftLint for additional code quality checks

### Cross-Platform Tests (`cross-platform.yml`)
- Runs on every push and pull request to the `main` branch
- Tests compatibility across different Swift versions (5.10, 6.0, 6.1)
- Tests on both macOS and Linux environments

### Release (`release.yml`)
- Runs when a new tag is pushed
- Creates a GitHub release
- Builds and uploads release assets

## Setup Requirements

These workflows require:
- A `GITHUB_TOKEN` secret for creating releases (automatically provided by GitHub)
- Swift 6.1 or compatible versions installed via `swift-actions/setup-swift`

## Customization

To modify the workflows:
1. Edit the `.github/workflows/*.yml` files
2. Adjust Swift versions in the matrix as needed
3. Add or remove platforms as required
4. Update the release process as needed

## Running Locally

To test these workflows locally, you can use tools like `act`:

```bash
# Install act
brew install act

# Run CI workflow
act push -W .github/workflows/ci.yml

# Run specific job
act push -W .github/workflows/ci.yml --job test
```