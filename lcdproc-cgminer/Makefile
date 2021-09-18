#
# Copyright (C) 2020 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lcdproc-cgminer
PKG_VERSION:=1.0.6
PKG_RELEASE:=1

PKG_MAINTAINER:=Denis Paavilainen <denpa@denpa.pro>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/lcdproc-cgminer
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+lua +lua-cgminer +lua-lcdproc
  TITLE:=cgminer lcdproc client
  URL:=https://github.com/denpamusic/openwrt-feed
  PKGARCH:=all
endef

define Package/lcdproc-cgminer/description
    lcdproc client for cgminer written in lua.
endef

define Package/lcdproc-cgminer/conffiles
/etc/config/lcdproc
endef

define Build/Compile
endef

define Package/lcdproc-cgminer/install
	$(CP) ./files/* $(1)
endef

$(eval $(call BuildPackage,lcdproc-cgminer))
