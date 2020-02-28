#
# Copyright (C) 2020 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-lcdproc
PKG_SOURCE_VERSION:=593b93860c73a087f6cae36c190d4c5b088046c9
PKG_VERSION:=1.0.7
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=https://github.com/denpamusic/lua-lcdproc.git
PKG_SOURCE_PROTO:=git
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
	$(CP) $(PKG_BUILD_DIR)/src/lcdproc.lua $(1)/usr/lib/lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/lcdproc
	$(CP) $(PKG_BUILD_DIR)/src/lcdproc/{menu,screen,widgets}.lua $(1)/usr/lib/lua/lcdproc
endef

$(eval $(call BuildPackage,lua-lcdproc))
