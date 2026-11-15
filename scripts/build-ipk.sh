#!/bin/sh
# Build OpenWrt 24.10 IPKs with iStore's ipkg-build, without installation.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR=${1:-"$PROJECT_DIR/dist"}
IPKG_BUILD=${IPKG_BUILD:-/usr/libexec/istore/ipkg-build}
[ -x "$IPKG_BUILD" ] || { echo "Missing executable ipkg-build: $IPKG_BUILD" >&2; exit 1; }
mkdir -p "$OUT_DIR"
OUT_DIR=$(CDPATH= cd -- "$OUT_DIR" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/codex-ipk.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1704067200}
APP="$WORK/app"
META="$WORK/meta"
mkdir -p "$APP/CONTROL" "$APP/www" "$META/CONTROL" "$META/usr/lib/opkg/meta" "$META/www/luci-static/resources/app-icons"
cp -R "$PROJECT_DIR/luci-app-codex-istore/root/." "$APP/"
cp -R "$PROJECT_DIR/luci-app-codex-istore/htdocs/." "$APP/www/"
chmod 755 "$APP/usr/bin/codex-istore" "$APP/usr/libexec/rpcd/luci.codex-istore"
command -v node >/dev/null 2>&1 || { echo "Node.js is required to compile LuCI translations at build time" >&2; exit 1; }
mkdir -p "$APP/usr/lib/lua/luci/i18n"
node "$PROJECT_DIR/scripts/compile-lmo.cjs" "$PROJECT_DIR/luci-app-codex-istore/po/zh_Hans/codex-istore.po" "$APP/usr/lib/lua/luci/i18n/codex-istore.zh-cn.lmo"
cat > "$APP/CONTROL/control" <<'CONTROL'
Package: luci-app-codex-istore
Version: 0.1.0-1
Architecture: x86_64
Maintainer: PristineStream
Section: luci
Priority: optional
Depends: luci-base, rpcd, curl, ca-bundle, openssl-util, tar
License: Apache-2.0
Description: Community LuCI plugin for Codex CLI on iStoreOS
Installed-Size: 0
CONTROL
cat > "$APP/CONTROL/postinst" <<'POSTINST'
#!/bin/sh
[ "${IPKG_NO_SCRIPT:-}" = 1 ] && exit 0
helper="${IPKG_INSTROOT:-}/usr/share/codex-istore/register-desktop.sh"
[ ! -x "$helper" ] || "$helper" register || exit $?
[ -n "${IPKG_INSTROOT:-}" ] && exit 0
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache/
/etc/init.d/rpcd reload 2>/dev/null || true
exit 0
POSTINST
cat > "$APP/CONTROL/prerm" <<'PRERM'
#!/bin/sh
[ "${IPKG_NO_SCRIPT:-}" = 1 ] && exit 0
helper="${IPKG_INSTROOT:-}/usr/share/codex-istore/register-desktop.sh"
[ ! -x "$helper" ] || "$helper" unregister
PRERM
chmod 755 "$APP/CONTROL/postinst" "$APP/CONTROL/prerm"
cat > "$META/CONTROL/control" <<'CONTROL'
Package: app-meta-codex-istore
Version: 0.1.0-1
Architecture: all
Maintainer: PristineStream
Section: meta
Priority: optional
Depends: luci-app-codex-istore
Description: iStore metadata for Codex CLI for iStoreOS
Installed-Size: 0
CONTROL
cat > "$META/usr/lib/opkg/meta/codex-istore.json" <<'JSON'
{"name":"codex-istore","title":"Codex CLI for iStoreOS（社区插件）","title_en":"Codex CLI for iStoreOS (community plugin)","entry":"/cgi-bin/luci/admin/services/codex-istore","author":"PristineStream","website":"https://github.com/PristineStream/codex-istore","tutorial":"https://github.com/PristineStream/codex-istore/blob/main/README.md","version":"0.1.0","release":1,"arch":["x86_64"],"description":"在 iStoreOS 中管理 Codex CLI 的社区插件。","description_en":"Community plugin to manage Codex CLI on iStoreOS.","tags":["tool"],"depends":["luci-app-codex-istore"]}
JSON
cp "$PROJECT_DIR/app-meta-codex-istore/logo.png" "$META/www/luci-static/resources/app-icons/codex-istore.png"
"$IPKG_BUILD" "$APP" "$OUT_DIR"
"$IPKG_BUILD" "$META" "$OUT_DIR"
printf 'Created IPKs in %s\n' "$OUT_DIR"
