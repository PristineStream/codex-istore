#!/bin/sh
# Maintain only this package's legacy entry during the compatibility window.
set -e
root=${IPKG_INSTROOT:-}
manifest=/usr/share/codex-istore/codex-istore-plugin.json
legacy="${root}/usr/share/linkeasefull/desktop-apps.d/30-codex-istore.json"
case "$1" in
    register)
        [ -f "${root}${manifest}" ] || exit 0
        if [ ! -e "$legacy" ] && [ ! -L "$legacy" ]; then
            mkdir -p "${legacy%/*}"
            ln -s "$manifest" "$legacy"
        fi
        ;;
    unregister)
        if [ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$manifest" ]; then
            rm -f "$legacy"
            rmdir "${legacy%/*}" 2>/dev/null || true
        fi
        ;;
    *) exit 1 ;;
esac
