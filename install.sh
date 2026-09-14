#!/usr/bin/env bash
set -euo pipefail

repository="${TARVOS_REPOSITORY:-repo-tech/tarvos-engine}"
version="${TARVOS_VERSION:-v1.0.0}"
asset="tarvos-linux-x86_64"
bin_dir="${HOME}/.tarvos/bin"
destination="${bin_dir}/tarvos"

mkdir -p "$bin_dir"
if [[ "$version" == "latest" ]]; then
  base="https://github.com/${repository}/releases/latest/download"
else
  base="https://github.com/${repository}/releases/download/${version}"
fi

temporary="${destination}.tmp"
curl --fail --location --silent --show-error "${base}/${asset}" -o "$temporary"
curl --fail --location --silent --show-error "${base}/${asset}.sha256" -o "${temporary}.sha256"

expected="$(awk '{print tolower($1)}' "${temporary}.sha256")"
actual="$(sha256sum "$temporary" | awk '{print tolower($1)}')"
if [[ "$expected" != "$actual" ]]; then
  rm -f "$temporary" "${temporary}.sha256"
  echo "Tarvos checksum verification failed." >&2
  exit 1
fi

mv "$temporary" "$destination"
rm -f "${temporary}.sha256"
chmod 0755 "$destination"

profile="${HOME}/.profile"
if [[ -n "${ZSH_VERSION:-}" ]]; then
  profile="${ZDOTDIR:-${HOME}}/.zshrc"
fi
if ! grep -Fqx "export PATH=\"${bin_dir}:\$PATH\"" "$profile" 2>/dev/null; then
  printf '\n# Tarvos user-local CLI\nexport PATH="%s:$PATH"\n' "$bin_dir" >> "$profile"
fi
export PATH="${bin_dir}:${PATH}"

echo "Tarvos ${version} installed at ${destination}"
