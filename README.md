# RedactOps Action

The official RedactOps GitHub Action scans repositories and pull requests for sensitive data before it reaches
source control, CI artifacts, support exports, or LLM prompts.

The Action will be published with the first RedactOps release. Once `v1` is available:

```yaml
name: RedactOps

on:
  pull_request:
  push:
    branches: [main]

jobs:
  privacy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: CurzonMonroe/redactops-action@v1
        with:
          license: ${{ secrets.REDACTOPS_LICENSE }}
          config: .redactops.yml
          fail-on: high
          format: sarif
          output: redactops.sarif
```

The Action installs a versioned, checksummed RedactOps binary from the official
[RedactOps GitHub releases](https://github.com/CurzonMonroe/RedactOps/releases). GitHub Action usage requires a
RedactOps Team licence or higher.

Full installation, licensing, and configuration documentation is maintained in the
[RedactOps distribution repository](https://github.com/CurzonMonroe/RedactOps).
