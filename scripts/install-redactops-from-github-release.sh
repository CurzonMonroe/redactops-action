#!/usr/bin/env bash
set -euo pipefail

version="${1:?Usage: scripts/install-redactops-from-github-release.sh <version>}"
repository="${REDACTOPS_RELEASE_REPOSITORY:-CurzonMonroe/RedactOps}"
release_base_url="${REDACTOPS_RELEASE_BASE_URL:-https://github.com/${repository}/releases/download/v${version}}"
runner_os="${RUNNER_OS:-}"
runner_arch="${RUNNER_ARCH:-}"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  echo "RedactOps version must be an exact semantic version; received: ${version}" >&2
  exit 2
fi

case "${runner_os}:${runner_arch}" in
  Linux:ARM64)
    archive="redactops-linux-arm64.tar.gz"
    executable="redactops"
    ;;
  Linux:X64)
    archive="redactops-linux-x64.tar.gz"
    executable="redactops"
    ;;
  macOS:ARM64)
    archive="redactops-osx-arm64.tar.gz"
    executable="redactops"
    ;;
  macOS:X64)
    archive="redactops-osx-x64.tar.gz"
    executable="redactops"
    ;;
  Windows:X64)
    archive="redactops-win-x64.zip"
    executable="redactops.exe"
    ;;
  *)
    echo "RedactOps does not publish a GitHub release archive for ${runner_os:-unknown}/${runner_arch:-unknown}." >&2
    exit 2
    ;;
esac

install_root="${REDACTOPS_INSTALL_ROOT:-${RUNNER_TEMP:-/tmp}/redactops-${version}-${runner_os}-${runner_arch}}"
download_root="${install_root}/download"
bin_root="${install_root}/bin"
mkdir -p "${download_root}" "${bin_root}"

download() {
  local name="$1"
  local destination="$2"
  local source_url="${release_base_url}/${name}"

  if [[ "${source_url}" == file://* ]]; then
    cp "${source_url#file://}" "${destination}"
    return
  fi

  curl --fail-with-body --silent --show-error --location \
    --retry 3 --retry-delay 2 --retry-all-errors \
    --output "${destination}" "${source_url}"
}

download "${archive}" "${download_root}/${archive}"
download checksums.txt "${download_root}/checksums.txt"

expected_checksum="$(awk -v name="${archive}" '$2 == name || $2 == ("*" name) { print $1; exit }' "${download_root}/checksums.txt")"
if [[ -z "${expected_checksum}" ]]; then
  echo "checksums.txt does not contain an entry for ${archive}." >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_checksum="$(sha256sum "${download_root}/${archive}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual_checksum="$(shasum -a 256 "${download_root}/${archive}" | awk '{print $1}')"
else
  echo "A SHA-256 checksum utility (sha256sum or shasum) is required." >&2
  exit 127
fi

if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
  echo "Checksum verification failed for ${archive}." >&2
  exit 1
fi

if [[ "${archive}" == *.zip ]]; then
  unzip -q "${download_root}/${archive}" -d "${bin_root}"
else
  tar -xzf "${download_root}/${archive}" -C "${bin_root}"
fi

if [[ ! -f "${bin_root}/${executable}" ]]; then
  echo "The ${archive} release archive does not contain ${executable}." >&2
  exit 1
fi
chmod +x "${bin_root}/${executable}"

if [[ -z "${GITHUB_PATH:-}" ]]; then
  echo "GITHUB_PATH is required when installing RedactOps for a GitHub Action." >&2
  exit 2
fi
printf '%s\n' "${bin_root}" >> "${GITHUB_PATH}"
echo "Installed RedactOps ${version} from the checksummed GitHub release archive."
