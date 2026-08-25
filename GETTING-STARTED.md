# Getting Started with RedactOps

RedactOps is a local-first command-line tool for finding and irreversibly redacting sensitive data in source
repositories, configuration, logs, support exports, test fixtures and text intended for LLM prompts. Scanned content
stays on the machine running the CLI.

This guide covers installation, Free and purchased licensing, scanning, configuration, reporting and redaction.

## 1. Choose an Installation Method

RedactOps is currently distributed through GitHub Releases as self-contained archives and through Homebrew, which
also installs from the GitHub release. Confirm any installation with:

```bash
redactops version
```

### Homebrew on macOS or Linux

```bash
brew tap CurzonMonroe/redactops
brew install redactops
redactops version
```

Upgrade with:

```bash
brew update
brew upgrade redactops
```

### Self-contained release archive

Self-contained archives do not require a separately installed .NET runtime. Download the archive for the target system
from the [RedactOps releases page](https://github.com/CurzonMonroe/RedactOps/releases):

| Platform | Archive |
|---|---|
| Apple Silicon macOS | `redactops-osx-arm64.tar.gz` |
| Intel macOS | `redactops-osx-x64.tar.gz` |
| ARM64 Linux | `redactops-linux-arm64.tar.gz` |
| x64 Linux | `redactops-linux-x64.tar.gz` |
| x64 Windows | `redactops-win-x64.zip` |

Download `checksums.txt` from the same release and compare the archive's SHA-256 digest before installation:

```bash
shasum -a 256 redactops-<platform>.tar.gz
```

On Windows PowerShell:

```powershell
Get-FileHash .\redactops-win-x64.zip -Algorithm SHA256
```

Extract the archive into a durable application directory and add that directory to `PATH`. Keep the included
`LICENSE`, `THIRD-PARTY-NOTICES.md` and `licenses` directory with the executable.

Early-access binaries may not yet carry platform publisher signatures. Verify the checksum and follow the local
organisation's software-execution policy if macOS or Windows blocks an unsigned download.

### .NET global tool from a GitHub release

Each GitHub release also includes `RedactOps.Cli.<version>.nupkg`. Until NuGet.org Trusted Publishing is enabled,
download that package and `checksums.txt` from the release page, verify its checksum, and install it from the download
directory:

```bash
dotnet tool install --global RedactOps.Cli \
  --version <version> \
  --add-source /path/to/download-directory \
  --ignore-failed-sources
redactops version
```

The native self-contained archive is the simpler installation and does not require the .NET SDK. Direct
`dotnet tool install --global RedactOps.Cli` installation will be documented when NuGet.org publication is enabled.

## 2. Understand Licensing

Every release contains a signed `RedactOps_Free` entitlement, valid for six calendar months from its build date. No key
entry or account setup is required for Free use. Free includes:

- Console and JSON scanning.
- CMPatternEngine and built-in sensitive-data detection.
- Local configuration.
- Local irreversible redaction and prompt protection.

Install updates regularly. RedactOps plans refreshed releases every three months, and a Free installation must be
updated before its embedded six-month entitlement expires.

Team and higher licences additionally enable SARIF, Markdown reports, baselines and the official GitHub Action.

### Configure a purchased licence

For the current macOS/Linux shell:

```bash
export REDACTOPS_LICENSE='CML1.<payload>.<signature>'
```

For the current Windows PowerShell session:

```powershell
$env:REDACTOPS_LICENSE = 'CML1.<payload>.<signature>'
```

To persist it for the current Windows user:

```powershell
[Environment]::SetEnvironmentVariable(
  'REDACTOPS_LICENSE',
  'CML1.<payload>.<signature>',
  'User')
```

On macOS/Linux, a shell profile can export the variable persistently, but a credential manager or an environment
injection mechanism is preferable on managed systems. In CI, store the key in the platform's protected secret store
and expose it as `REDACTOPS_LICENSE` only to the scan step.

Persistent user environment variables are a convenience, not a secret vault. Use the organisation's credential or
endpoint-management tooling when the licence key requires stronger local protection.

Do not place a purchased key in `.redactops.yml`, source control, container image layers or shared shell scripts.

For a one-off command, `--license` overrides the environment and embedded key:

```bash
redactops scan . --license 'CML1.<payload>.<signature>'
```

RedactOps selects exactly one key in this order:

1. `--license`
2. `REDACTOPS_LICENSE`
3. The legacy `REDACTOPS_LICENSE_KEY` environment alias
4. The embedded Free entitlement

An invalid configured key produces a licence error; RedactOps does not silently fall back to Free. Team-or-higher
customers can confirm that paid automation is enabled with:

```bash
redactops license check github-action
```

## 3. Run the First Scan

Change to the root of the repository or directory to inspect:

```bash
cd /path/to/project
redactops scan .
```

RedactOps scans matching text files recursively, skips common build and dependency directories, and writes a console
report without exposing raw sensitive values. It uses context-free redaction markers and hashes in report findings.

List the installed detector catalogue with:

```bash
redactops patterns list
```

The catalogue includes email, phone, payment-card, API-key, password-assignment, connection-string, private-key,
IP-address and focused CMPatternEngine PII detection.

### Exit codes

| Code | Meaning |
|---:|---|
| `0` | The command completed with no blocking findings. |
| `1` | Blocking findings were detected. For redaction, output may still have been written successfully. |
| `2` | Arguments, configuration or licensing are invalid. |
| `3` | A runtime scanning error occurred. |

Exit code `1` is a policy result, not a crashed scan. CI should normally treat it as a failed privacy check.

## 4. Add Repository Configuration

Create the default configuration in the current directory:

```bash
redactops config init
```

This creates `.redactops.yml`. Commit it when the policy should apply to the whole repository. A compact example is:

```yaml
version: 1
fail_on: high
include:
  - "**/*.cs"
  - "**/*.json"
  - "**/*.md"
  - "**/*.yml"
  - "**/*.csv"
  - "**/*.log"
  - "**/*.txt"
exclude:
  - "**/bin/**"
  - "**/obj/**"
  - "**/node_modules/**"
  - "**/.git/**"
detectors:
  email: warn
  phone: warn
  credit_card: block
  api_key: block
  password_assignment: block
  connection_string: block
  private_key: block
  ip_address: warn
redaction:
  mode: typed-token
report:
  console: true
  json: false
  sarif: false
  markdown: false
max_file_size: 1048576
```

Detector decisions are `allow`, `warn`, `block` or `ignore`. Findings without an explicit detector decision block when
their severity is at or above `fail_on`; otherwise they warn.

Command-line options can override common configuration values:

```bash
redactops scan . \
  --config .redactops.yml \
  --fail-on medium \
  --include '**/*.json' \
  --exclude '**/fixtures/approved/**' \
  --max-file-size 2097152
```

`--include` and `--exclude` may be repeated.

### Intentional values

Suppress one finding inline with `redactops-ignore`, or suppress the following line with
`redactops-ignore-next-line`:

```text
example@example.com # redactops-ignore

# redactops-ignore-next-line
example@example.com
```

For a repository-wide accepted finding, add its report hash to the configuration:

```yaml
suppressions:
  - "<finding-hash>"
```

Review ignores and suppressions like code. Avoid broad exclusions that could conceal new secrets.

## 5. Create Reports

Console output is the default. Write a JSON report for local automation with:

```bash
redactops scan . --format json --out artifacts/redactops/scan.json
```

With a Team-or-higher licence, create SARIF or Markdown:

```bash
redactops scan . --format sarif --out artifacts/redactops/scan.sarif
redactops scan . --format markdown --out artifacts/redactops/scan.md
```

Reports contain detector, category, severity, confidence, location, context-free preview, value hash, remediation and
policy decision. They do not contain the raw matched value by default.

## 6. Redact or Protect Text

Redaction is irreversible. Keep the source and output paths separate and inspect the result before distributing it.

Redact one file:

```bash
redactops redact support-export.csv --out support-export.redacted.csv
```

Redact a directory tree:

```bash
redactops redact ./support-export --out ./support-export-redacted
```

Directory redaction requires `--out`. The output tree preserves relative paths for scanned files.

Protect a prompt or other text before sharing it with an AI system:

```bash
redactops protect prompt.txt --out prompt.safe.txt
```

Available redaction modes in `.redactops.yml` are `typed-token`, `fixed-token`, `hash-only` and `remove`. The default is
`typed-token`, which produces markers such as `[REDACTED_EMAIL]`.

## 7. Use Baselines and GitHub Actions

Baselines require Team or higher. Create an approved snapshot and then report only new findings:

```bash
redactops baseline create . --out redactops-baseline.json
redactops baseline compare . --baseline redactops-baseline.json
```

The official GitHub Action also requires Team or higher. Store the purchased key as a GitHub Actions secret named
`REDACTOPS_LICENSE`:

```yaml
name: RedactOps

on:
  pull_request:

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

## 8. Troubleshooting

### `redactops: command not found`

Restart the shell and confirm that the Homebrew binary directory, extracted release directory, or .NET global-tools
directory is on `PATH`.

### Licence error after configuring a purchased key

Confirm that the complete key was copied without quotes becoming part of its value. Purchased keys must use the signed
`CML1` format and be valid for a RedactOps product. A configured invalid key intentionally prevents fallback to Free.

### Embedded Free licence has expired

Install the latest RedactOps release. Free entitlements last six months and releases are intended to refresh every
three months.

### A successful redaction returned exit code `1`

The command found blocking sensitive data and wrote the redacted output. Inspect the output and use the exit status as
evidence that the input contained material requiring protection.

### Expected files were skipped

Review `include`, `exclude` and `max_file_size` in `.redactops.yml`. RedactOps is currently a text-focused tool and does
not extract content from PDF, Word, Excel or PowerPoint documents.

## Data-Handling Notes

- Processing is local; RedactOps does not upload scanned content to a hosted service.
- Reports avoid raw findings and surrounding source context by default.
- Redaction cannot be reversed and no rehydration map is created.
- RedactOps helps reduce sensitive-data exposure; it is not a compliance certification.

RedactOps is proprietary software. Copyright (c) 2026 Curzon Monroe (UK) Limited. Distribution terms are in `LICENSE`,
and bundled component terms are in `THIRD-PARTY-NOTICES.md`.
