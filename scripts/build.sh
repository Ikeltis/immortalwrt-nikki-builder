#!/usr/bin/env bash
set -euo pipefail

readonly release_branch="25.12"
readonly target="x86/64"
readonly profile="generic"
readonly rootfs_partsize="300"
readonly downloads="https://downloads.immortalwrt.org"
readonly nikki_repo="https://nikkinikki.pages.dev/openwrt-${release_branch}/x86_64/nikki/packages.adb"
readonly nikki_key="https://nikkinikki.pages.dev/public-key.pem"
readonly project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly work_dir="${project_dir}/work"
readonly dist_dir="${project_dir}/dist"
readonly files_dir="${work_dir}/files"

requested_version="${1:-}"
if [[ -n "$requested_version" ]]; then
  version="$requested_version"
else
  version="$(curl --fail --silent --show-error --location \
    "${downloads}/.versions.json" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["stable_version"])')"
fi

if [[ "$version" != "${release_branch}."* ]]; then
  echo "Refusing version '$version': only ${release_branch}.x is allowed." >&2
  exit 1
fi

readonly version
readonly base_url="${downloads}/releases/${version}/targets/${target}"
readonly imagebuilder="immortalwrt-imagebuilder-${version}-x86-64.Linux-x86_64.tar.zst"

mkdir -p "$work_dir" "$dist_dir"
find "$work_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
find "$dist_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

curl --fail --silent --show-error --location \
  --output "${work_dir}/sha256sums" "${base_url}/sha256sums"

imagebuilder_sha="$(awk -v file="${imagebuilder}" '$2 == ("*" file) { print $1; exit }' "${work_dir}/sha256sums")"
if [[ -z "$imagebuilder_sha" ]]; then
  echo "ImageBuilder checksum not found for ${imagebuilder}." >&2
  exit 1
fi

curl --fail --show-error --location \
  --output "${work_dir}/${imagebuilder}" "${base_url}/${imagebuilder}"
printf '%s  %s\n' "$imagebuilder_sha" "${work_dir}/${imagebuilder}" | sha256sum --check --strict

tar --zstd --extract --file "${work_dir}/${imagebuilder}" --directory "$work_dir"
builder_dir="$(find "$work_dir" -mindepth 1 -maxdepth 1 -type d \
  -name "immortalwrt-imagebuilder-${version}-x86-64.Linux-x86_64" -print -quit)"
if [[ -z "$builder_dir" ]]; then
  echo "Extracted ImageBuilder directory not found." >&2
  exit 1
fi

curl --fail --silent --show-error --location \
  --output "${builder_dir}/keys/nikki.pem" "$nikki_key"
printf '%s\n' "$nikki_repo" >> "${builder_dir}/repositories"

# ImageBuilder keys only verify packages during the build. Install the Nikki
# key and repository into the target rootfs too, so `apk update` works after
# sysupgrade without rerunning the upstream feed installer.
mkdir -p "${files_dir}/etc/apk/keys" "${files_dir}/etc/apk/repositories.d"
cp "${builder_dir}/keys/nikki.pem" "${files_dir}/etc/apk/keys/nikki.pem"
chmod 0644 "${files_dir}/etc/apk/keys/nikki.pem"
printf '%s\n' "$nikki_repo" > "${files_dir}/etc/apk/repositories.d/nikki.list"

mapfile -t package_lines < <(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "${project_dir}/packages.txt")
packages="${package_lines[*]}"

make -C "$builder_dir" image \
  PROFILE="$profile" \
  PACKAGES="$packages" \
  FILES="$files_dir" \
  ROOTFS_PARTSIZE="$rootfs_partsize"

output_dir="${builder_dir}/bin/targets/x86/64"
image="$(find "$output_dir" -maxdepth 1 -type f \
  -name '*-x86-64-generic-ext4-combined-efi.img.gz' -print -quit)"
manifest="$(find "$output_dir" -maxdepth 1 -type f -name '*.manifest' -print -quit)"

if [[ -z "$image" || -z "$manifest" ]]; then
  echo "Expected EFI/ext4 image or manifest was not produced." >&2
  exit 1
fi

cp "$image" "$manifest" "$dist_dir/"
(cd "$dist_dir" && sha256sum "$(basename "$image")" > sha256sums)
printf '%s\n' "$version" > "${dist_dir}/immortalwrt-version.txt"

for required in nikki luci-app-nikki luci-i18n-nikki-zh-cn; do
  if ! awk -v package="$required" '$1 == package { found=1 } END { exit !found }' "$manifest"; then
    echo "Required package '$required' is missing from the manifest." >&2
    exit 1
  fi
done

echo "Built: ${dist_dir}/$(basename "$image")"
