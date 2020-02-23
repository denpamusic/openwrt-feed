#
# Copyright (C) 2020 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-lcdproc
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

PKG_MAINTAINER:=Denis Paavilainen <denpa@denpa.pro>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/lua-lcdproc
  SECTION:=lang
  CATEGORY:=Languages
  DEPENDS:=+lua +luasocket
  TITLE:=Lua lcdproc client
  URL:=https://github.com/denpamusic/openwrt-feed
  PKGARCH:=all
endef

define Package/lua-lcdproc/description
	Lua lcdproc is simple lcdproc client.
endef

define Build/Compile
endef

define Package/lua-lcdproc/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(CP) ./files/* $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-lcdproc))
