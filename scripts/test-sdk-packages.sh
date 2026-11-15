#!/bin/sh
# Exercise supplied IPKs in an offline opkg root. No host packages are installed.
# The caller supplies the files; only the caller can identify their build origin.
set -eu
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    echo "Usage: $0 <luci-app-codex-istore.ipk> <app-meta-codex-istore.ipk> [<luci-i18n-codex-istore-zh-cn.ipk>]" >&2
    exit 2
fi
app=$(readlink -f "$1")
meta=$(readlink -f "$2")
[ -f "$app" ] && [ -f "$meta" ] || { echo 'Package files not found' >&2; exit 1; }
translation=
if [ "$#" -eq 3 ]; then
    translation=$(readlink -f "$3")
    [ -f "$translation" ] || { echo 'Translation package not found' >&2; exit 1; }
fi
command -v opkg >/dev/null
command -v node >/dev/null
command -v lua >/dev/null
command -v sha256sum >/dev/null
work=$(mktemp -d "${TMPDIR:-/tmp}/codex-sdk-test.XXXXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 1' HUP INT TERM
root=$work/root
mkdir -p "$root/usr/lib/opkg/info" "$root/etc/opkg" "$root/var/lock" "$work/tmp" "$work/lists"
printf 'arch all 1\narch x86_64 100\n' > "$work/opkg.conf"
for dependency in libc luci-base rpcd curl ca-bundle openssl-util tar; do
    printf 'Package: %s\nVersion: 9999\nArchitecture: all\nStatus: install ok installed\n\n' "$dependency" >> "$root/usr/lib/opkg/status"
    : > "$root/usr/lib/opkg/info/$dependency.list"
done
# The original launcher and package database are monitored for changes.
launcher_before=$(sha256sum /usr/bin/codex 2>/dev/null || true)
launcher_target_before=$(readlink /usr/bin/codex 2>/dev/null || true)
installed_before=$(sha256sum /usr/lib/opkg/status 2>/dev/null || true)
runtime_before=absent
[ ! -e /etc/codex-istore-runtime ] && [ ! -L /etc/codex-istore-runtime ] || runtime_before=present

# The offline root has synthetic records for base dependencies; dependency
# declarations are checked below. Maintainer scripts stay deferred by opkg.
opkg_test() {
    opkg -f "$work/opkg.conf" -o "$root" -t "$work/tmp" -l "$work/lists" "$@"
}
opkg_test install "$app"
if [ -n "$translation" ]; then
    [ ! -e "$root/usr/lib/lua/luci/i18n/codex-istore.zh-cn.lmo" ] || { echo 'Translation unexpectedly bundled in main IPK' >&2; exit 1; }
    opkg_test install "$translation"
    opkg_test status luci-i18n-codex-istore-zh-cn | grep -q '^Status: install .* installed$'
fi
opkg_test install "$meta"
opkg_test status luci-app-codex-istore | grep -q '^Status: install .* installed$'
opkg_test status app-meta-codex-istore | grep -q '^Status: install .* installed$'

node - "$root" "$translation" <<'NODE'
const fs = require('fs'), path = require('path');
const root = process.argv[2], at = p => path.join(root, p);
const must = (x, msg) => { if (!x) throw Error(msg); };
const app = fs.readFileSync(at('usr/lib/opkg/info/luci-app-codex-istore.control'), 'utf8');
const meta = fs.readFileSync(at('usr/lib/opkg/info/app-meta-codex-istore.control'), 'utf8');
if (process.argv[3]) {
  const i18n = fs.readFileSync(at('usr/lib/opkg/info/luci-i18n-codex-istore-zh-cn.control'), 'utf8');
  must(/^Architecture:\s*all\s*$/m.test(i18n), 'incorrect translation architecture');
  must(/^Depends:.*\bluci-app-codex-istore\b/m.test(i18n), 'missing translation dependency');
  must(/^Depends:.*\bluci-i18n-codex-istore-zh-cn\b/m.test(meta), 'missing metadata translation dependency');
}
must(/^Architecture:\s*x86_64\s*$/m.test(app), 'incorrect application architecture');
must(/^Architecture:\s*all\s*$/m.test(meta), 'incorrect metadata architecture');
for (const d of ['luci-base', 'rpcd', 'curl', 'ca-bundle', 'openssl-util', 'tar'])
  must(new RegExp('^Depends:.*(?:^|[ ,])' + d + '(?:[ ,(]|$)', 'm').test(app), 'missing dependency: ' + d);
must(/^Depends:.*\bluci-app-codex-istore\b/m.test(meta), 'missing metadata dependency');
const menu = JSON.parse(fs.readFileSync(at('usr/share/luci/menu.d/luci-app-codex-istore.json'), 'utf8'));
const item = menu['admin/services/codex-istore'];
must(item && item.action && item.action.path === 'codex-istore/overview', 'incorrect LuCI menu');
const acl = JSON.parse(fs.readFileSync(at('usr/share/rpcd/acl.d/luci-app-codex-istore.json'), 'utf8'));
must(acl['luci-app-codex-istore'], 'missing ACL');
const metaDir = at('usr/lib/opkg/meta');
const metaFiles = fs.readdirSync(metaDir).filter(f => f.includes('codex-istore') && f.endsWith('.json'));
must(metaFiles.length === 1, 'metadata JSON missing or ambiguous');
const metadata = JSON.parse(fs.readFileSync(path.join(metaDir, metaFiles[0]), 'utf8'));
must(JSON.stringify(metadata).includes('codex-istore'), 'incorrect iStore metadata');
must(fs.existsSync(at('www/luci-static/resources/view/codex-istore/overview.js')), 'view missing');
const desktopPath = '/usr/share/codex-istore/codex-istore-plugin.json';
const desktopLink = at('usr/share/linkease/apps.d/30-codex-istore.json');
must(fs.lstatSync(desktopLink).isSymbolicLink() && fs.readlinkSync(desktopLink) === desktopPath, 'desktop registration missing');
const desktop = JSON.parse(fs.readFileSync(at(desktopPath), 'utf8'));
must(desktop.id === 'codex-istore' && desktop.desktop.mode === 'builtin' && desktop.desktop.component === 'LuciContainer', 'invalid desktop manifest');
must(desktop.desktop.props.initialPath === '/cgi-bin/luci/admin/services/codex-istore' && desktop.standalone.url === '/cgi-bin/luci/admin/services/codex-istore', 'invalid desktop route');
must(fs.readFileSync(at('usr/share/codex-istore/www/logo.png')).subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), 'desktop icon missing or invalid');
const cli = fs.readFileSync(at('usr/bin/codex-istore'), 'utf8');
must(cli.includes('VERSION=0.166.0'), 'unexpected pinned version');
must(cli.includes('https://registry.npmjs.org/@openai/codex/-/codex-0.166.0-linux-x64.tgz'), 'unexpected official URL');
must(cli.includes('CxDm3+D1cpbGJeHrdzINoG+3wn9BVncP4qpZaaNYkxe8iPtRJOYyCJnnPoVjWRIBvI9vPKbRoifsMSA5xDaUpw=='), 'unexpected official SHA-512');
console.log('Package metadata, dependencies, menu, ACL, desktop, view and pinned release: OK');
NODE

helper=$root/usr/share/codex-istore/register-desktop.sh
legacy=$root/usr/share/linkeasefull/desktop-apps.d/30-codex-istore.json
target=/usr/share/codex-istore/codex-istore-plugin.json
if [ -n "$translation" ]; then
    postinst=$root/usr/lib/opkg/info/luci-app-codex-istore.postinst-pkg
    prerm=$root/usr/lib/opkg/info/luci-app-codex-istore.prerm-pkg
    [ -f "$postinst" ] && [ -f "$prerm" ] || { echo 'SDK package lifecycle scripts missing' >&2; exit 1; }
    grep -Fq 'helper="${IPKG_INSTROOT}/usr/share/codex-istore/register-desktop.sh"' "$postinst"
    grep -Fq '[ -n "${IPKG_INSTROOT}" ] && exit 0' "$postinst"
    grep -Fq 'helper="${IPKG_INSTROOT}/usr/share/codex-istore/register-desktop.sh"' "$prerm"
    IPKG_INSTROOT="$root" /bin/sh "$postinst"
    [ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$target" ]
    IPKG_INSTROOT="$root" /bin/sh "$prerm"
    [ ! -L "$legacy" ]
    echo 'SDK lifecycle scripts with isolated IPKG_INSTROOT: OK'
fi
IPKG_INSTROOT=$root "$helper" register
[ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$target" ]
IPKG_INSTROOT=$root "$helper" register
[ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$target" ]
IPKG_INSTROOT=$root "$helper" unregister
[ ! -L "$legacy" ]
mkdir -p "${legacy%/*}"
printf 'preserve\n' > "$legacy"
IPKG_INSTROOT=$root "$helper" register
IPKG_INSTROOT=$root "$helper" unregister
[ "$(cat "$legacy")" = preserve ]
rm "$legacy"
ln -s /other/plugin.json "$legacy"
IPKG_INSTROOT=$root "$helper" register
IPKG_INSTROOT=$root "$helper" unregister
[ -L "$legacy" ] && [ "$(readlink "$legacy")" = /other/plugin.json ]
rm "$legacy"
echo 'Desktop registration and compatibility safeguards: OK'

# Use the router's actual LuCI parser against the isolated installed catalog.
lua - "$root/usr/lib/lua/luci/i18n" <<'LUA'
local p = require 'luci.template.parser'
assert(p.load_catalog('zh-cn', arg[1]))
assert(p.change_catalog('zh-cn'))
assert(p.translate('Installed') == '已安装', 'translation missing')
assert(p.translate('Codex CLI') == 'Codex 命令行工具', 'translation mismatch')
print('LuCI translation loader: OK')
LUA

opkg_test remove app-meta-codex-istore
if [ -n "$translation" ]; then
    opkg_test remove luci-i18n-codex-istore-zh-cn
fi
opkg_test remove luci-app-codex-istore
[ ! -e "$root/usr/bin/codex-istore" ]
[ ! -e "$root/usr/share/luci/menu.d/luci-app-codex-istore.json" ]
[ ! -e "$root/usr/lib/lua/luci/i18n/codex-istore.zh-cn.lmo" ]
[ ! -e "$root/usr/lib/opkg/meta/codex-istore.json" ]
[ ! -e "$root/usr/share/codex-istore/codex-istore-plugin.json" ]
[ ! -L "$root/usr/share/linkease/apps.d/30-codex-istore.json" ]
launcher_after=$(sha256sum /usr/bin/codex 2>/dev/null || true)
launcher_target_after=$(readlink /usr/bin/codex 2>/dev/null || true)
installed_after=$(sha256sum /usr/lib/opkg/status 2>/dev/null || true)
runtime_after=absent
[ ! -e /etc/codex-istore-runtime ] && [ ! -L /etc/codex-istore-runtime ] || runtime_after=present
[ "$launcher_before" = "$launcher_after" ] && [ "$launcher_target_before" = "$launcher_target_after" ] && [ "$installed_before" = "$installed_after" ] && [ "$runtime_before" = "$runtime_after" ] || { echo 'Host state changed' >&2; exit 1; }
echo 'Offline install/removal and monitored host state: OK'
echo 'Note: base dependencies were simulated; automatic opkg lifecycle execution was not tested.'
