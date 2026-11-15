#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Combine the local OpenWrt packages into one iStore manual installer.
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
dist_dir=${1:-"$project_dir/dist"}

set -- "$dist_dir"/luci-app-codex-istore_*_x86_64.ipk
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo 'Build one x86_64 LuCI package first.' >&2; exit 1; }
main=${1##*/}
version=${main#luci-app-codex-istore_}
version=${version%_x86_64.ipk}
dist_dir=$(CDPATH='' cd -- "$dist_dir" && pwd)
case "$version" in
    ''|*[!a-zA-Z0-9.+-]*) echo 'Invalid package version.' >&2; exit 1;;
esac
set -- "$dist_dir"/app-meta-codex-istore_*_all.ipk
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo 'Use a directory with one metadata package.' >&2; exit 1; }
meta=${1##*/}
case "$meta" in
    *[!a-zA-Z0-9_.+~-]*) echo 'Invalid metadata package name.' >&2; exit 1;;
esac
language=
set -- "$dist_dir"/luci-i18n-codex-istore-zh-cn_*_all.ipk
if [ "$#" -ne 1 ]; then
    echo 'Use a directory with a single translation package version.' >&2
    exit 1
fi
if [ -f "$1" ]; then
    language=${1##*/}
    case "$language" in
        *[!a-zA-Z0-9_.+~-]*) echo 'Invalid translation package name.' >&2; exit 1;;
    esac
fi
set -- "$main"
[ -z "$language" ] || set -- "$@" "$language"
set -- "$@" "$meta"

umask 077
stage=$(mktemp -d)
trap 'rm -f -- "$stage/SHA256SUMS" "$stage/payload.gz" "$stage/bundle.run"; rmdir "$stage"' EXIT
trap 'exit 1' HUP INT TERM
(cd "$dist_dir" && sha256sum "$@") > "$stage/SHA256SUMS"
tar -czf "$stage/payload.gz" -C "$dist_dir" "$@" -C "$stage" SHA256SUMS

{
    printf '#!/bin/sh\n# Codex CLI for iStoreOS community installer\n'
    printf "main='%s'\nmeta='%s'\nlanguage='%s'\n" "$main" "$meta" "$language"
    cat <<'INSTALLER'
set -eu
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
case "${1:-}" in
    '') [ "$#" -eq 0 ] || exit 2;;
    --check) [ "$#" -eq 1 ] || exit 2;;
    *) echo 'Usage: codex-istore.run [--check]' >&2; exit 2;;
esac
umask 077
stage=$(mktemp -d)
cleanup() {
    rm -f -- "$stage/$main" "$stage/$meta" "$stage/SHA256SUMS"
    [ -z "$language" ] || rm -f -- "$stage/$language"
    rmdir "$stage"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
payload_line=$(awk '/^__CODEX_ISTORE_PAYLOAD__$/ { print NR + 1; exit }' "$0")
[ -n "$payload_line" ]
tail -n "+$payload_line" "$0" | tar -xzf - -C "$stage"
(cd "$stage" && sha256sum -c SHA256SUMS)
[ "${1:-}" != '--check' ] || exit 0
[ "$(uname -m)" = x86_64 ] || { echo 'This package requires iStoreOS x86_64.' >&2; exit 1; }
set -- "$stage/$main"
[ -z "$language" ] || set -- "$@" "$stage/$language"
set -- "$@" "$stage/$meta"
opkg install "$@"
exit 0
__CODEX_ISTORE_PAYLOAD__
INSTALLER
    cat "$stage/payload.gz"
} > "$stage/bundle.run"

output="$dist_dir/codex-istore_${version}_x86_64.run"
sh "$stage/bundle.run" --check
cp "$stage/bundle.run" "$output"
chmod 0755 "$output"
printf '%s\n' "$output"
