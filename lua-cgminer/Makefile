#
# Copyright (C) 2020 Denis Paavilainen
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua-cgminer
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_MAINTAINER:=Denis Paavilainen <denpa@denpa.pro>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/lua-cgminer
  SECTION:=lang
  CATEGORY:=Languages
  DEPENDS:=+lua +luasocket +lua-cjson
  TITLE:=Lua cgminer client
  URL:=https://github.com/denpamusic/openwrt-feed
  PKGARCH:=all
endef

define Package/lua-cgminer/description
	Lua cgminer is simple cgminer API client.
endef

define Build/Compile
endef

define Package/lua-cgminer/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(CP) ./files/* $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,lua-cgminer))
