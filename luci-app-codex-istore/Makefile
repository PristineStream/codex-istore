include $(TOPDIR)/rules.mk

PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_PO_VERSION:=$(PKG_VERSION)-r$(PKG_RELEASE)
PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=PristineStream

LUCI_TITLE:=Codex CLI for iStoreOS (community plugin)
LUCI_PKGARCH:=x86_64
LUCI_DEPENDS:=+luci-base +rpcd +curl +ca-bundle +openssl-util +tar

define Package/luci-app-codex-istore/postinst
helper="$${IPKG_INSTROOT}/usr/share/codex-istore/register-desktop.sh"
if [ -x "$$helper" ]; then
	"$$helper" register || exit $$?
fi
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -f /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache/
/etc/init.d/rpcd reload 2>/dev/null || true
exit 0
endef

define Package/luci-app-codex-istore/prerm
helper="$${IPKG_INSTROOT}/usr/share/codex-istore/register-desktop.sh"
[ ! -x "$$helper" ] || "$$helper" unregister
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
