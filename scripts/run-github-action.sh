#!/usr/bin/env bash
set -euo pipefail

input_config="${INPUT_CONFIG:-.redactops.yml}"
input_fail_on="${INPUT_FAIL_ON:-high}"
input_format="${INPUT_FORMAT:-sarif}"
input_output="${INPUT_OUTPUT:-}"
input_sarif="${INPUT_SARIF:-redactops.sarif}"
input_markdown_summary="${INPUT_MARKDOWN_SUMMARY:-true}"
input_baseline="${INPUT_BASELINE:-}"

redactops license check github-action

config_args=()
if [[ -n "${input_config}" && -f "${input_config}" ]]; then
  config_args=(--config "${input_config}")
fi

scan_paths=(".")
if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && -n "${GITHUB_BASE_SHA:-}" ]]; then
  git fetch --no-tags --depth=1 origin "${GITHUB_BASE_SHA}" >/dev/null 2>&1 || true
  mapfile -t changed_paths < <(git diff --name-only --diff-filter=ACMRT "${GITHUB_BASE_SHA}"...HEAD)
  if [[ "${#changed_paths[@]}" -gt 0 ]]; then
    for index in "${!changed_paths[@]}"; do
      if [[ "${changed_paths[${index}]}" == -* ]]; then
        changed_paths[${index}]="./${changed_paths[${index}]}"
      fi
    done
    scan_paths=("${changed_paths[@]}")
  fi
fi

run_report() {
  local format="$1"
  local output="$2"
  local command=(redactops)

  if [[ -n "${input_baseline}" ]]; then
    command+=(baseline compare "${scan_paths[@]}" --baseline "${input_baseline}")
  else
    command+=(scan "${scan_paths[@]}")
  fi

  command+=("${config_args[@]}" --fail-on "${input_fail_on}" --format "${format}")
  if [[ -n "${output}" ]]; then
    command+=(--out "${output}")
  fi

  "${command[@]}"
}

if [[ -z "${input_output}" ]]; then
  case "${input_format}" in
    sarif) input_output="${input_sarif}" ;;
    json) input_output="redactops.json" ;;
    markdown) input_output="redactops.md" ;;
    console) input_output="" ;;
    *)
      echo "Invalid RedactOps Action format: ${input_format}" >&2
      exit 2
      ;;
  esac
fi

primary_status=0
run_report "${input_format}" "${input_output}" || primary_status=$?
if [[ "${primary_status}" -ne 0 && "${primary_status}" -ne 1 ]]; then
  exit "${primary_status}"
fi

json_report="${RUNNER_TEMP}/redactops.json"
json_status=0
run_report json "${json_report}" || json_status=$?
if [[ "${json_status}" -ne 0 && "${json_status}" -ne 1 ]]; then
  exit "${json_status}"
fi

echo "REDACTOPS_EXIT_CODE=${primary_status}" >> "${GITHUB_ENV}"

REDACTOPS_JSON_REPORT="${json_report}" node <<'JS'
const fs = require("fs");

const report = JSON.parse(fs.readFileSync(process.env.REDACTOPS_JSON_REPORT, "utf8"));
const escapeCommandValue = (value) => String(value ?? "")
  .replaceAll("%", "%25")
  .replaceAll("\r", "%0D")
  .replaceAll("\n", "%0A")
  .replaceAll(":", "%3A")
  .replaceAll(",", "%2C");

for (const finding of report.findings ?? []) {
  const location = finding.range ?? {};
  const level = finding.policyDecision === "block" ? "error" : "warning";
  const filePath = escapeCommandValue(finding.filePath);
  const line = location.startLine ?? 1;
  const col = location.startColumn ?? 1;
  const message = escapeCommandValue(`${finding.detectorName ?? ""}: ${finding.redactedPreview ?? ""}`);
  console.log(`::${level} file=${filePath},line=${line},col=${col}::${message}`);
}
JS

if [[ "${input_markdown_summary}" == "true" ]]; then
  markdown_report="${RUNNER_TEMP}/redactops-summary.md"
  markdown_status=0
  run_report markdown "${markdown_report}" || markdown_status=$?
  if [[ "${markdown_status}" -ne 0 && "${markdown_status}" -ne 1 ]]; then
    exit "${markdown_status}"
  fi
  cat "${markdown_report}" >> "${GITHUB_STEP_SUMMARY}"
fi

if [[ "${primary_status}" -eq 1 ]]; then
  echo "::error::RedactOps found blocking sensitive-data findings."
  exit 1
fi
