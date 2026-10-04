#!/usr/bin/env bash
set -euo pipefail

repository="${TARVOS_REPOSITORY:-repo-tech/tarvos-engine}"
version="${TARVOS_VERSION:-v1.3.1}"
asset="tarvos-linux-x86_64"
bin_dir="${HOME}/.tarvos/bin"
destination="${bin_dir}/tarvos"

# Every transfer gets an explicit connect timeout and one retry. Without them a
# host that accepts the connection and then stalls leaves the user watching an
# installer that will never finish, which is indistinguishable from a slow
# download. A connect timeout turns that silence into a clear failure, and the
# transfer is verified afterwards, so a partial download is caught here rather
# than becoming a confusing error later.
curl_common=(--fail --location --silent --show-error
             --connect-timeout 15 --retry 2 --retry-delay 2)

fetch() {
  local url="$1" out="$2" what="$3"
  # Captured before the transfer so the reported rate covers the transfer itself.
  local FETCH_STARTED
  FETCH_STARTED="$(date +%s)"
  # --max-time is generous: the binary is a few megabytes and a slow link is
  # still a legitimate way to fetch it. It exists to stop an endless stall, not
  # to cut a real download short.
  if ! curl "${curl_common[@]}" --max-time 1800 -o "$out" "$url"; then
    echo "Tarvos: could not download ${what}." >&2
    echo "  url: ${url}" >&2
    if [[ "$version" != "latest" ]]; then
      echo "  Check that ${version} is published at https://github.com/${repository}/releases" >&2
    fi
    echo "  If this machine reaches GitHub slowly or not at all, download the asset" >&2
    echo "  in a browser and re-run this script against the local file." >&2
    exit 1
  fi
  if [[ ! -s "$out" ]]; then
    echo "Tarvos: ${what} downloaded as an empty file; refusing to continue." >&2
    exit 1
  fi
  # Report what the transfer cost, so a slow link is visible as a number rather
  # than as silence followed by an unexplained pause.
  local bytes elapsed rate
  bytes="$(wc -c < "$out" | tr -d ' ')"
  elapsed="$(awk -v n="${FETCH_STARTED:-0}" 'BEGIN{printf "%.1f", systime()-n}')"
  rate="$(awk -v b="$bytes" -v s="$elapsed" 'BEGIN{if(s>0) printf "%.1f", b/s/1048576; else print "?"}')"
  printf '  fetched %s (%s MiB in %ss, %s MiB/s)\n' \
    "$what" \
    "$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1048576}')" \
    "$elapsed" \
    "$rate" >&2
}

mkdir -p "$bin_dir"
if [[ "$version" == "latest" ]]; then
  base="https://github.com/${repository}/releases/latest/download"
else
  base="https://github.com/${repository}/releases/download/${version}"
fi

temporary="${destination}.tmp"
fetch "${base}/${asset}" "$temporary" "the ${asset} binary"
fetch "${base}/${asset}.sha256" "${temporary}.sha256" "its checksum"

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
