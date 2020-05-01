#
# Copyright (C) 2008-2015 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

LUCI_NAME?=$(notdir ${CURDIR})
LUCI_TYPE?=$(word 2,$(subst -, ,$(LUCI_NAME)))
LUCI_BASENAME?=$(patsubst luci-$(LUCI_TYPE)-%,%,$(LUCI_NAME))
LUCI_LANGUAGES:=$(sort $(filter-out templates,$(notdir $(wildcard ${CURDIR}/po/*))))
LUCI_DEFAULTS:=$(notdir $(wildcard ${CURDIR}/root/etc/uci-defaults/*))
LUCI_PKGARCH?=$(if $(realpath src/Makefile),,all)

PKG_BUILD_DEPENDS += $(LUCI_BUILD_DEPENDS)
PKG_NAME?=$(LUCI_NAME)

# get the path of ourself, to find luci.mk in the same directory
THIS_DIR=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
include $(THIS_DIR)/luci-common.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=$(if $(LUCI_MENU.$(LUCI_TYPE)),$(LUCI_MENU.$(LUCI_TYPE)),$(LUCI_MENU.app))
  TITLE:=$(if $(LUCI_TITLE),$(LUCI_TITLE),LuCI $(LUCI_NAME) $(LUCI_TYPE))
  DEPENDS:=$(LUCI_DEPENDS)
  VERSION:=$(if $(PKG_VERSION),$(PKG_VERSION),$(PKG_SRC_VERSION))
  $(if $(LUCI_EXTRA_DEPENDS),EXTRA_DEPENDS:=$(LUCI_EXTRA_DEPENDS))
  $(if $(LUCI_PKGARCH),PKGARCH:=$(LUCI_PKGARCH))
endef

ifneq ($(LUCI_DESCRIPTION),)
 define Package/$(PKG_NAME)/description
   $(strip $(LUCI_DESCRIPTION))
 endef
endif

ifneq ($(wildcard ${CURDIR}/src/Makefile),)
 MAKE_PATH := src/
 MAKE_VARS += FPIC="$(FPIC)" LUCI_VERSION="$(PKG_SRC_VERSION)" LUCI_GITBRANCH="$(PKG_GITBRANCH)"

 define Build/Compile
	$(call Build/Compile/Default,clean compile)
 endef
else
 define Build/Compile
 endef
endif


# additional setting luci-base package
ifeq ($(PKG_NAME),luci-base)
 define Package/luci-base/config
   config LUCI_SRCDIET
	bool "Minify Lua sources"
	default n

   config LUCI_JSMIN
	bool "Minify JavaScript sources"
	default y

   config LUCI_CSSTIDY
        bool "Minify CSS files"
        default y

   menu "Translations"$(foreach lang,$(LUCI_LANGUAGES),

     config LUCI_LANG_$(lang)
	   tristate "$(shell echo '$(LUCI_LANG.$(lang))' | sed -e 's/^.* (\(.*\))$$/\1/') ($(lang))")

   endmenu
 endef
endif


LUCI_BUILD_PACKAGES := $(PKG_NAME)

# 1: LuCI language code
# 2: BCP 47 language tag
define LuciTranslation
  define Package/luci-i18n-$(LUCI_BASENAME)-$(1)
    SECTION:=luci
    CATEGORY:=LuCI
    TITLE:=$(PKG_NAME) - $(1) translation
    HIDDEN:=1
    DEFAULT:=LUCI_LANG_$(2)||(ALL&&m)
    DEPENDS:=$(PKG_NAME)
    VERSION:=$(PKG_PO_VERSION)
    PKGARCH:=all
  endef

  define Package/luci-i18n-$(LUCI_BASENAME)-$(1)/description
    Translation for $(PKG_NAME) - $(LUCI_LANG.$(2))
  endef

  define Package/luci-i18n-$(LUCI_BASENAME)-$(1)/install
	$$(INSTALL_DIR) $$(1)/etc/uci-defaults
	echo "uci set luci.languages.$(subst -,_,$(1))='$(LUCI_LANG.$(2))'; uci commit luci" \
		> $$(1)/etc/uci-defaults/luci-i18n-$(LUCI_BASENAME)-$(1)
	$$(INSTALL_DIR) $$(1)$(LUCI_LIBRARYDIR)/i18n
	$(foreach po,$(wildcard ${CURDIR}/po/$(2)/*.po), \
		po2lmo $(po) \
			$$(1)$(LUCI_LIBRARYDIR)/i18n/$(basename $(notdir $(po))).$(1).lmo;)
  endef

  define Package/luci-i18n-$(LUCI_BASENAME)-$(1)/postinst
	[ -n "$$$${IPKG_INSTROOT}" ] || {
		(. /etc/uci-defaults/luci-i18n-$(LUCI_BASENAME)-$(1)) && rm -f /etc/uci-defaults/luci-i18n-$(LUCI_BASENAME)-$(1)
		exit 0
	}
  endef

  LUCI_BUILD_PACKAGES += luci-i18n-$(LUCI_BASENAME)-$(1)

endef

$(foreach lang,$(LUCI_LANGUAGES),$(eval $(call LuciTranslation,$(firstword $(LUCI_LC_ALIAS.$(lang)) $(lang)),$(lang))))
$(foreach pkg,$(LUCI_BUILD_PACKAGES),$(eval $(call BuildPackage,$(pkg))))
