# GitHub Action

The first action is a composite action named `redactops-action`.

Example:

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
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: redactops.sarif
```

The action requires a Team licence or higher. Store the key in a repository or organisation secret and pass it through the `license` input.
The first Action release supports GitHub-hosted Ubuntu runners.

The Action downloads the checksummed native CLI archive for the GitHub runner from the matching RedactOps GitHub
release. The exact version is declared by its `version` input, which defaults to the version paired with the Action
release. Its primary report is controlled by `format` and `output`. When `baseline` is set, every report and annotation
is generated from `baseline compare` rather than a full unfiltered scan.

| Input | Default | Purpose |
|---|---|---|
| `config` | `.redactops.yml` | Optional configuration path. |
| `fail-on` | `high` | Minimum blocking severity. |
| `format` | `sarif` | Primary `console`, `json`, `sarif`, or `markdown` report. |
| `output` | format-specific | Primary report output path. |
| `sarif` | `redactops.sarif` | Compatibility output used for SARIF when `output` is empty. |
| `markdown-summary` | `true` | Append a Markdown summary to the job summary. |
| `baseline` | empty | Optional baseline used for every Action report. |
| `license` | empty | Signed Team-or-higher `CML1` licence. |
| `version` | `0.1.0` | Exact CLI version installed by the Action. |

SARIF upload is documented through `github/codeql-action/upload-sarif` rather than owned directly by the action.
