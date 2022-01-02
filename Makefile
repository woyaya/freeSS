CONFIG_DIR=configs

USER=$(shell whoami)
#ifneq ($(USER),root)
#  $(error Run as root, please)
#endif

EXECUTE:=$(shell which haProxy2SS)
ifeq ($(EXECUTE),)
  EXECUTE:=./freeSS.sh
endif

MODULE_LIST=dnscrypt-proxy redsocks haproxy shadowsocks-libev
dnscrypt-proxy_config=/etc/dnscrypt-proxy/dnscrypt-proxy.toml
redsocks_config=/etc/redsocks.conf
haproxy_config=/etc/haproxy/haproxy.cfg
shadowsocks-libev_config=/etc/init.d/shadowsocks-firewall
shadowsocks-libev_restart=/etc/init.d/shadowsocks-firewall restart

SEARCH_PARAM=$(shell echo $(MODULE_LIST) | sed 's/ /\/\\|/g;s/$$/\//')
INSTALLED_LIST=$(shell apt list --installed 2>/dev/null | grep "$(SEARCH_PARAM)" | sed 's/\/.*//')
PACKAGE_LIST=$(filter-out $(INSTALLED_LIST),$(MODULE_LIST))

INSTALL_LIST=$(addsuffix _install,$(PACKAGE_LIST))
BACKUP_LIST=$(addsuffix _backup,$(INSTALLED_LIST))
UNINSTALL_LIST=$(addsuffix _uninstall,$(INSTALLED_LIST))
CONFIG_LIST=$(addsuffix _config,$(MODULE_LIST))

define RESTART_VALUE
$1_restart=$(if $($(1)_restart),$($(1)_restart),systemctl restart $(1))
endef
$(foreach mod,$(MODULE_LIST),$(eval $(call RESTART_VALUE,$(mod))))
$(foreach mod,$(MODULE_LIST),$(eval $(mod)_config=$($(mod)_config)))
$(foreach mod,$(PACKAGE_LIST),$(eval $(mod)_install=$(mod)_install))
$(foreach mod,$(INSTALLED_LIST),$(eval $(mod)_backup=$(mod)_backup))
$(foreach mod,$(INSTALLED_LIST),$(eval $(mod)_uninstall=$(mod)_uninstall))

define BUILD_DEPS
$(1)_install:
	@echo "Install $(1)"
	@echo "apt install -y $(1)"
$(1)_uninstall:
	@echo "Uninstall $(1)"
	@echo "apt purge -y $(1)"
$(1)_backup:
	@echo "Backup config file of $(1)"
	@cp -rfu $($(1)_config) $(CONFIG_DIR)/
$(1)_config : $($(1)_config)

$($(1)_config) : $(CONFIG_DIR)/$(notdir $($(1)_config))
	@echo "Update $$@ from $$^"
	@echo "cp -rfu $$^ $$@"
	@echo "Restart $1"
	echo "$($1_restart)"
endef

.PHONY: all update install backup uninstall config

update:
	@$(EXECUTE)

all: install update

install : $(INSTALL_LIST)
backup : $(BACKUP_LIST)
uninstall : $(UNINSTALL_LIST)
config : $(CONFIG_LIST)

$(foreach mod,$(MODULE_LIST),$(eval $(call BUILD_DEPS,$(mod))))

shadowsocks-libev_install:
	@systemctl stop shadowsocks-libev
	@systemctl disable shadowsocks-libev
