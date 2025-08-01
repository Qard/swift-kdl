# GitHub Pages Documentation

This directory is used by GitHub Actions to deploy the generated DocC documentation.

## Setup Instructions

To enable GitHub Pages for your repository:

1. Go to your repository's **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. Save your changes

## Workflow Details

The documentation is automatically deployed when you create a new release tag (e.g., `v1.0.0`).

The `release.yml` workflow will:
1. Build and test the package
2. Create a GitHub release
3. Build and deploy documentation to GitHub Pages

This ensures that the published documentation always reflects the latest stable release, not development changes.

## Local Development

To build and preview the documentation locally:

```bash
# Build documentation
xcodebuild docbuild -scheme KDL -destination 'generic/platform=macOS' -derivedDataPath .build

# Transform for web hosting
DOCC_ARCHIVE=$(find .build -name "*.doccarchive" -type d | head -1)
$(xcrun --find docc) process-archive \
  transform-for-static-hosting "$DOCC_ARCHIVE" \
  --hosting-base-path /kdl-swift \
  --output-path docs

# Serve locally (requires Python)
cd docs && python3 -m http.server 8000
```

Then open http://localhost:8000 in your browser.

## Documentation URL

Once deployed, the documentation will be available at:
```
https://<your-github-username>.github.io/kdl-swift/
```

## Troubleshooting

- Ensure GitHub Pages is enabled in repository settings
- Check the Actions tab for workflow run status
- The first deployment may take a few minutes to become available
- Make sure your repository is public or you have GitHub Pages enabled for private repos