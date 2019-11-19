#
# Copyright (C) 2019 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=vpngate
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_MAINTAINER:=Denis Paavilainen <denpa@denpa.pro>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/vpngate
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+coreutils +coreutils-shuf +openvpn
  TITLE:=vpngate.net client
  URL:=https://github.com/denpamusic/openwrt-vpngate
  SUBMENU:=VPN
  PKGARCH:=all
endef

define Package/vpngate/description
	vpngate.net client allows to pull server list from vpngate.net public VPN
	registry and select server based on country, score, maximum ping and uptime.
endef

define Package/vpngate/conffiles
	/etc/vpngate.include
endef

define Build/Compile
endef

define Package/vpngate/install
	$(CP) ./files/* $(1)
endef

$(eval $(call BuildPackage,vpngate))
