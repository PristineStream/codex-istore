#!/bin/sh
# Build OpenWrt 24.10 IPKs with iStore's ipkg-build, without installation.
set -eu
umask 022
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR=${1:-"$PROJECT_DIR/dist"}
IPKG_BUILD=${IPKG_BUILD:-/usr/libexec/istore/ipkg-build}
[ -x "$IPKG_BUILD" ] || { echo "Missing executable ipkg-build: $IPKG_BUILD" >&2; exit 1; }
# Keep the quick packages at the same version as the SDK recipes.
VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$PROJECT_DIR/luci-app-codex-istore/Makefile")
RELEASE=$(sed -n 's/^PKG_RELEASE:=//p' "$PROJECT_DIR/luci-app-codex-istore/Makefile")
case "$VERSION-$RELEASE" in
    ''|*[!a-zA-Z0-9.+~-]*) echo 'Invalid package version or release' >&2; exit 1;;
esac
[ -n "$VERSION" ] && [ -n "$RELEASE" ] || { echo 'Missing package version or release' >&2; exit 1; }
case "$RELEASE" in *[!0-9]*) echo 'Package release must be numeric' >&2; exit 1;; esac
META_VERSION=$(sed -n 's/^PKG_VERSION:=//p' "$PROJECT_DIR/app-meta-codex-istore/Makefile")
META_RELEASE=$(sed -n 's/^PKG_RELEASE:=//p' "$PROJECT_DIR/app-meta-codex-istore/Makefile")
[ "$VERSION-$RELEASE" = "$META_VERSION-$META_RELEASE" ] || { echo 'Application and metadata versions differ' >&2; exit 1; }
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
chmod 755 "$APP/usr/bin/codex-istore" "$APP/usr/libexec/rpcd/luci.codex-istore" "$APP/usr/share/codex-istore/register-desktop.sh"
command -v node >/dev/null 2>&1 || { echo "Node.js is required to compile LuCI translations at build time" >&2; exit 1; }
mkdir -p "$APP/usr/lib/lua/luci/i18n"
node "$PROJECT_DIR/scripts/compile-lmo.cjs" "$PROJECT_DIR/luci-app-codex-istore/po/zh_Hans/codex-istore.po" "$APP/usr/lib/lua/luci/i18n/codex-istore.zh-cn.lmo"
cat > "$APP/CONTROL/control" <<CONTROL
Package: luci-app-codex-istore
Version: $VERSION-$RELEASE
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
cat > "$APP/CONTROL/postrm" <<'POSTRM'
#!/bin/sh
[ "${IPKG_NO_SCRIPT:-}" = 1 ] && exit 0
[ -n "${IPKG_INSTROOT:-}" ] && exit 0
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache/
/etc/init.d/rpcd reload 2>/dev/null || true
exit 0
POSTRM
chmod 755 "$APP/CONTROL/postinst" "$APP/CONTROL/prerm" "$APP/CONTROL/postrm"
cat > "$META/CONTROL/control" <<CONTROL
Package: app-meta-codex-istore
Version: $VERSION-$RELEASE
Architecture: all
Maintainer: PristineStream
Section: meta
Priority: optional
Depends: luci-app-codex-istore
Description: iStore metadata for Codex CLI for iStoreOS
Installed-Size: 0
CONTROL
cat > "$META/usr/lib/opkg/meta/codex-istore.json" <<JSON
{"name":"codex-istore","title":"Codex CLI for iStoreOS（社区插件）","title_en":"Codex CLI for iStoreOS (community plugin)","entry":"/cgi-bin/luci/admin/services/codex-istore","author":"PristineStream","website":"https://github.com/easepi/codex-istore","tutorial":"https://github.com/easepi/codex-istore/blob/main/README.md","version":"$VERSION","release":$RELEASE,"arch":["x86_64"],"description":"在 iStoreOS 中管理 Codex CLI 的社区插件。","description_en":"Community plugin to manage Codex CLI on iStoreOS.","tags":["tool"],"depends":["luci-app-codex-istore"]}
JSON
cp "$PROJECT_DIR/app-meta-codex-istore/logo.png" "$META/www/luci-static/resources/app-icons/codex-istore.png"
# Source checkouts can inherit a shared directory's group-writable modes.
# Do not ship those modes or the developer's UID/GID to a router.
find "$APP" "$META" -type d -exec chmod 755 {} +
find "$APP" "$META" -type f -exec chmod a-s,go-w {} +
CODEX_IPKG_TAR=$(command -v "${TAR:-tar}")
export CODEX_IPKG_TAR
cat > "$WORK/tar" <<'TAR_WRAPPER'
#!/bin/sh
exec "$CODEX_IPKG_TAR" --owner=0 --group=0 --numeric-owner "$@"
TAR_WRAPPER
chmod 755 "$WORK/tar"
TAR="$WORK/tar" "$IPKG_BUILD" "$APP" "$OUT_DIR"
TAR="$WORK/tar" "$IPKG_BUILD" "$META" "$OUT_DIR"
printf 'Created IPKs in %s\n' "$OUT_DIR"
