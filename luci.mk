#
# Copyright (C) 2008-2015 The LuCI Team <luci@lists.subsignal.org>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

# Language code titles
LUCI_LANG.ca=Català (Catalan)
LUCI_LANG.cs=Čeština (Czech)
LUCI_LANG.de=Deutsch (German)
LUCI_LANG.el=Ελληνικά (Greek)
LUCI_LANG.en=English
LUCI_LANG.es=Español (Spanish)
LUCI_LANG.fr=Français (French)
LUCI_LANG.he=עִבְרִית (Hebrew)
LUCI_LANG.hu=Magyar (Hungarian)
LUCI_LANG.it=Italiano (Italian)
LUCI_LANG.ja=日本語 (Japanese)
LUCI_LANG.ko=한국어 (Korean)
LUCI_LANG.ms=Bahasa Melayu (Malay)
LUCI_LANG.no=Norsk (Norwegian)
LUCI_LANG.pl=Polski (Polish)
LUCI_LANG.pt-br=Português do Brasil (Brazialian Portuguese)
LUCI_LANG.pt=Português (Portuguese)
LUCI_LANG.ro=Română (Romanian)
LUCI_LANG.ru=Русский (Russian)
LUCI_LANG.sk=Slovenčina (Slovak)
LUCI_LANG.sv=Svenska (Swedish)
LUCI_LANG.tr=Türkçe (Turkish)
LUCI_LANG.uk=Українська (Ukrainian)
LUCI_LANG.vi=Tiếng Việt (Vietnamese)
LUCI_LANG.zh-cn=中文 (Chinese)
LUCI_LANG.zh-tw=臺灣華語 (Taiwanese)

# Submenu titles
LUCI_MENU.col=1. Collections
LUCI_MENU.mod=2. Modules
LUCI_MENU.app=3. Applications
LUCI_MENU.theme=4. Themes
LUCI_MENU.proto=5. Protocols
LUCI_MENU.lib=6. Libraries

HTDOCS = /www
LUA_LIBRARYDIR = /usr/lib/lua
LUCI_LIBRARYDIR = $(LUA_LIBRARYDIR)/luci


PKG_VERSION?=$(if $(DUMP),x,$(strip $(shell \
	if svn info >/dev/null 2>/dev/null; then \
		revision="svn-r$$(LC_ALL=C svn info | sed -ne 's/^Revision: //p')"; \
	elif git log -1 >/dev/null 2>/dev/null; then \
		revision="svn-r$$(LC_ALL=C git log -1 | sed -ne 's/.*git-svn-id: .*@\([0-9]\+\) .*/\1/p')"; \
		if [ "$$revision" = "svn-r" ]; then \
			set -- $$(git log -1 --format="%ct %h" --abbrev=7); \
			secs="$$(($$1 % 86400))"; \
			yday="$$(date --utc --date="@$$1" "+%y.%j")"; \
			revision="$$(printf 'git-%s.%05d-%s' "$$yday" "$$secs" "$$2")"; \
		fi; \
	else \
		revision="unknown"; \
	fi; \
	echo "$$revision" \
)))

PKG_GITBRANCH?=$(if $(DUMP),x,$(strip $(shell \
	variant="LuCI"; \
	if git log -1 >/dev/null 2>/dev/null; then \
		branch="$$(git branch --remote --verbose --no-abbrev --contains 2>/dev/null | \
			sed -rne 's|^[^/]+/([^ ]+) [a-f0-9]{40} .+$$|\1|p' | head -n1)"; \
		if [ "$$branch" != "master" ]; then \
			variant="LuCI $$branch branch"; \
		else \
			variant="LuCI Master"; \
		fi; \
	fi; \
	echo "$$variant" \
)))

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Build/Prepare
	for d in luasrc htdocs root src; do \
	  if [ -d ./$$$$d ]; then \
	    mkdir -p $(PKG_BUILD_DIR)/$$$$d; \
		$(CP) ./$$$$d/* $(PKG_BUILD_DIR)/$$$$d/; \
	  fi; \
	done
	$(call Build/Prepare/Default)
endef

define SrcDiet
	$(FIND) $(1) -type f -name '*.lua' | while read src; do \
		if LUA_PATH="$(STAGING_DIR_HOSTPKG)/lib/lua/5.1/?.lua" luasrcdiet --noopt-binequiv -o "$$$$src.o" "$$$$src"; \
		then mv "$$$$src.o" "$$$$src"; fi; \
	done
endef

define JsMin
	$(FIND) $(1) -type f -name '*.js' | while read src; do \
		if jsmin < "$$$$src" > "$$$$src.o"; \
		then mv "$$$$src.o" "$$$$src"; fi; \
	done
endef

define CssTidy
	$(FIND) $(1) -type f -name '*.css' | while read src; do \
		if csstidy "$$$$src" --template=highest --remove_last_semicolon=true "$$$$src.o"; \
		then mv "$$$$src.o" "$$$$src"; fi; \
	done
endef

define SubstituteVersion
	$(FIND) $(1) -type f -name '*.htm' | while read src; do \
		$(SED) 's/<%# *\([^ ]*\)PKG_VERSION *%>/\1$(PKG_VERSION)/g' \
		    -e 's/"\(<%= *\(media\|resource\) *%>[^"]*\.\(js\|css\)\)"/"\1?v=$(PKG_VERSION)"/g' \
			"$$$$src"; \
	done
endef

define Package/$(PKG_NAME)/install
	if [ -d $(PKG_BUILD_DIR)/luasrc ]; then \
	  $(INSTALL_DIR) $(1)$(LUCI_LIBRARYDIR); \
	  cp -pR $(PKG_BUILD_DIR)/luasrc/* $(1)$(LUCI_LIBRARYDIR)/; \
	  $(FIND) $(1)$(LUCI_LIBRARYDIR)/ -type f -name '*.luadoc' | $(XARGS) rm; \
	  $(if $(CONFIG_LUCI_SRCDIET),$(call SrcDiet,$(1)$(LUCI_LIBRARYDIR)/),true); \
	  $(call SubstituteVersion,$(1)$(LUCI_LIBRARYDIR)/); \
	else true; fi
	if [ -d $(PKG_BUILD_DIR)/htdocs ]; then \
	  $(INSTALL_DIR) $(1)$(HTDOCS); \
	  cp -pR $(PKG_BUILD_DIR)/htdocs/* $(1)$(HTDOCS)/; \
	  $(if $(CONFIG_LUCI_JSMIN),$(call JsMin,$(1)$(HTDOCS)/),true); \
	  $(if $(CONFIG_LUCI_CSSTIDY),$(call CssTidy,$(1)$(HTDOCS)/),true); \
	else true; fi
	if [ -d $(PKG_BUILD_DIR)/root ]; then \
	  $(INSTALL_DIR) $(1)/; \
	  cp -pR $(PKG_BUILD_DIR)/root/* $(1)/; \
	else true; fi
	if [ -d $(PKG_BUILD_DIR)/src ]; then \
	  $(call Build/Install/Default) \
	  $(CP) $(PKG_INSTALL_DIR)/* $(1)/; \
	else true; fi
endef
