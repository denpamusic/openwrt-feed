#
# Copyright (C) 2019 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=antifilter
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_MAINTAINER:=Denis Paavilainen <denpa@denpa.pro>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/antifilter
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+ipset
  TITLE:=Antifilter ipset managment utility
  URL:=https://github.com/denpamusic/openwrt-feed
  PKGARCH:=all
endef

define Package/antifilter/description
	Antifilter ipset managment utility provides an easy way to manage and update
	IP-lists from antifilter.download service and it's mirror sites.
endef

define Package/antifilter/conffiles
/etc/config/antifilter
endef

define Build/Compile
endef

define Package/antifilter/install
	$(CP) ./files/* $(1)
endef

$(eval $(call BuildPackage,antifilter))
