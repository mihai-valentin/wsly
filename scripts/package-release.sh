#!/usr/bin/env bash
# Build the same portable archive and checksum uploaded by the release workflow.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_dir=${1:-"${repo_root}/dist"}
version=$(tr -d '\r\n' < "${repo_root}/VERSION")
package_name="wsly-${version}"
package_dir="${output_dir}/${package_name}"
archive="${output_dir}/${package_name}.zip"
checksum="${archive}.sha256"

if [[ -z "${version}" ]]; then
    printf '%s\n' 'VERSION must not be empty.' >&2
    exit 1
fi

mkdir -p "${output_dir}"
if [[ -e "${package_dir}" || -e "${archive}" || -e "${checksum}" ]]; then
    printf 'Release output already exists in %s; choose an empty output directory.\n' "${output_dir}" >&2
    exit 1
fi

mkdir "${package_dir}"
cp \
    "${repo_root}/CHANGELOG.md" \
    "${repo_root}/LICENSE" \
    "${repo_root}/README.md" \
    "${repo_root}/VERSION" \
    "${repo_root}/install.ps1" \
    "${repo_root}/uninstall.ps1" \
    "${repo_root}/wsly.bash" \
    "${repo_root}/wsly-completion.ps1" \
    "${repo_root}/wsly.ps1" \
    "${package_dir}/"

(
    cd -- "${output_dir}"
    zip -qr "${package_name}.zip" "${package_name}"
    sha256sum "${package_name}.zip" > "${package_name}.zip.sha256"
    unzip -t "${package_name}.zip" >/dev/null
)

printf 'Created %s and %s\n' "${archive}" "${checksum}"
