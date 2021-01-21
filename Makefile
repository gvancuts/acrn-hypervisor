# acrn-hypervisor/Makefile

# Explicitly set the shell to be used
SHELL := /bin/bash

# global helper variables
T := $(CURDIR)

ifdef TARGET_DIR
  $(warning TARGET_DIR is obsoleted because generated configuration files are now stored in the build directory)
endif

ifdef KCONFIG_FILE
  $(warning KCONFIG_FILE is no longer supported)
  $(error To specify the target board and scenario, define BOARD/SCENARIO variables on the command line)
endif

# BOARD/SCENARIO/BOARD_FILE/SCENARIO_FILE parameters sanity check:
#
# Only below usages are VALID: (target = all | hypervisor)
# 1. make <target>
# 2. make <target> BOARD=xxx SCENARIO=xxx
# 3. make <target> BOARD_FILE=xxx SCENARIO_FILE=xxx
#
# For case 1 that no any parameters are specified, the default BOARD/SCENARIO will be loaded:
#       i.e. equal: make <target> BOARD=kbl-nuc-i7 SCENARIO=industry
#
# For case 2/3, configurations are from XML files and saved to HV_OUT

ifneq ($(BOARD)$(SCENARIO),)
  ifneq ($(BOARD_FILE)$(SCENARIO_FILE),)
    $(error BOARD/SCENARIO parameter could not coexist with BOARD_FILE/SCENARIO_FILE)
  endif
endif

ifneq ($(BOARD_FILE)$(SCENARIO_FILE),)
  ifneq ($(BOARD_FILE), $(wildcard $(BOARD_FILE)))
    $(error BOARD_FILE: $(BOARD_FILE) does not exist)
  endif
  ifneq ($(SCENARIO_FILE), $(wildcard $(SCENARIO_FILE)))
    $(error SCENARIO_FILE: $(SCENARIO_FILE) does not exist)
  endif

  override BOARD := $(realpath $(BOARD_FILE))
  override SCENARIO := $(realpath $(SCENARIO_FILE))
else
  # BOARD/SCENARIO pointing to XML files must be converted to absolute paths before being passed to hypervisor/Makefile
  # because paths relative to acrn-hypervisor/ are typically invalid when relative to acrn-hypervisor/Makefile
  ifneq ($(realpath $(BOARD)),)
    override BOARD := $(realpath $(BOARD))
  endif
  ifneq ($(realpath $(SCENARIO)),)
    override SCENARIO := $(realpath $(SCENARIO))
  endif
endif

BOARD ?= kbl-nuc-i7

ifeq ($(BOARD), apl-nuc)
  override BOARD := nuc6cayh
else ifeq ($(BOARD), kbl-nuc-i7)
  override BOARD := nuc7i7dnb
endif

SCENARIO ?= industry

O ?= build
ROOT_OUT := $(shell mkdir -p $(O);cd $(O);pwd)
HV_OUT := $(ROOT_OUT)/hypervisor
DM_OUT := $(ROOT_OUT)/devicemodel
TOOLS_OUT := $(ROOT_OUT)/misc/tools
DOC_OUT := $(ROOT_OUT)/doc
BUILD_VERSION ?=
BUILD_TAG ?=
HV_CFG_LOG = $(HV_OUT)/cfg.log
VM_CONFIGS_DIR = $(T)/misc/vm_configs

export TOOLS_OUT BOARD SCENARIO RELEASE

#help all: The default target for make. It will build all ACRN components;
#help 'hypervisor' (ACRN hypervisor [acrn.bin]), 'devicemodel' (ACRN Device Model [acrn-dm])
#help and 'tools' (additional ACRN tools and services).
.PHONY: all hypervisor devicemodel tools doc
all: hypervisor devicemodel tools
	@cat $(HV_CFG_LOG)

# help functions to build acrn and install acrn/acrn symbols
define build_acrn
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT)/$(1) clean
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT)/$(1) BOARD=$(1) SCENARIO=$(2) RELEASE=$(RELEASE)
endef

define install_acrn
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT)/$(1) BOARD=$(1) SCENARIO=$(2) RELEASE=$(RELEASE) install
endef

define install_acrn_debug
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT)/$(1) BOARD=$(1) SCENARIO=$(2) RELEASE=$(RELEASE) install-debug
endef

#help hypervisor: This target builds the ACRN hypervisor only.
hypervisor:
	$(MAKE) -C $(T)/hypervisor BOARD=$(BOARD) SCENARIO=$(SCENARIO) HV_OBJDIR=$(HV_OUT) RELEASE=$(RELEASE)
	@echo -e "\n\033[47;30mACRN Configuration Summary:\033[0m \nBOARD = $(BOARD)\t SCENARIO = $(SCENARIO)" > $(HV_CFG_LOG); \
	echo -e "BUILD type = \c" >> $(HV_CFG_LOG); \
	if [ "$(RELEASE)" = "0" ]; then echo -e "DEBUG" >> $(HV_CFG_LOG); else echo -e "RELEASE" >> $(HV_CFG_LOG); fi; \
	echo -e "VM configuration is based on:" >> $(HV_CFG_LOG); \
	echo -e "\tSource code at:\t\t\t$(HV_OUT)/configs" >> $(HV_CFG_LOG);
	@cat $(HV_CFG_LOG)

#help devicemodel: This target builds the ACRN Device Model (acrn-dm). It will also build the ACRN tools (as a dependency).
devicemodel: tools
	$(MAKE) -C $(T)/devicemodel DM_OBJDIR=$(DM_OUT) DM_BUILD_VERSION=$(BUILD_VERSION) DM_BUILD_TAG=$(BUILD_TAG) DM_ASL_COMPILER=$(ASL_COMPILER) RELEASE=$(RELEASE)

#help tools: This target builds the ACRN additional tools and services.
tools:
	mkdir -p $(TOOLS_OUT)
	$(MAKE) -C $(T)/misc OUT_DIR=$(TOOLS_OUT) RELEASE=$(RELEASE)

#help doc: This target generates the ACRN documentation in HTML format.
doc:
	$(MAKE) -C $(T)/doc html BUILDDIR=$(DOC_OUT)

#help clean: It removes all previous builds.
.PHONY: clean
clean:
	$(MAKE) -C $(T)/misc OUT_DIR=$(TOOLS_OUT) clean
	$(MAKE) -C $(T)/doc BUILDDIR=$(DOC_OUT) clean
	rm -rf $(ROOT_OUT)

#help install: It installs the ACRN hypervisor, Device Model and tools on the system.
.PHONY: install
install: hypervisor-install devicemodel-install tools-install

hypervisor-install:
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT) BOARD=$(BOARD) SCENARIO=$(SCENARIO) RELEASE=$(RELEASE) install

hypervisor-install-debug:
	$(MAKE) -C $(T)/hypervisor HV_OBJDIR=$(HV_OUT) BOARD=$(BOARD) SCENARIO=$(SCENARIO) RELEASE=$(RELEASE) install-debug

kbl-nuc-i7-industry:
	$(call build_acrn,nuc7i7dnb,industry)
apl-up2-hybrid:
	$(call build_acrn,apl-up2,hybrid)

sbl-hypervisor: kbl-nuc-i7-industry \
                apl-up2-hybrid

kbl-nuc-i7-industry-install:
	$(call install_acrn,nuc7i7dnb,industry)
apl-up2-hybrid-install:
	$(call install_acrn,apl-up2,hybrid)

sbl-hypervisor-install: kbl-nuc-i7-industry-install \
                        apl-up2-hybrid-install

kbl-nuc-i7-industry-install-debug:
	$(call install_acrn_debug,nuc7i7dnb,industry)
apl-up2-hybrid-install-debug:
	$(call install_acrn_debug,apl-up2,hybrid)

sbl-hypervisor-install-debug: kbl-nuc-i7-industry-install-debug \
			      apl-up2-hybrid-install-debug

devicemodel-install:
	$(MAKE) -C $(T)/devicemodel DM_OBJDIR=$(DM_OUT) install

tools-install:
	$(MAKE) -C $(T)/misc OUT_DIR=$(TOOLS_OUT) RELEASE=$(RELEASE) install

.PHONY: help
##### Code
# Make sure that HELPSPACE has exactly HELPLEN spaces in it
EMPTY:= # An empty string
HELPSPACE :=${EMPTY}                  ${EMPTY}
HELPLEN := 18
define HELPSCRIPTBODY :=
# Skip all non help lines
/^#help[ \t]/!d
# see if this is a target, defined to be "#help" a single space or tab a word
# and then a ":". You can therefore escape something like http://localhost
# by adding an extra space. We lose extra indent, but we will anyhow
# as we will feed this to fmt -t
s/^#help[ \t]\([^ \t]*:\)[ \t]*/\1\n/
ttarget
# This is a continuation line
s/^#help[ \t]*/${HELPSPACE}/
b
:target
# Add on spaces to pad it out, then remove extra ones and the newline
# almost does the correct thing if there are not enough spaces
s/[\t ]*\n[ \t]*/${HELPSPACE}\n/
s/^\(.\{${HELPLEN}\}\) */\1/
s/\n//
endef

# Debugging hint, add 	'@echo "$${HELPSCRIPT}" | hexdump -C'
help: export HELPSCRIPT=${HELPSCRIPTBODY}
help:
	@printf "%s\n" "The output below describes commands that can be invoked in this directory."
	@printf "\n\nPossible commands:\n\n"
	@sed "$${HELPSCRIPT}" ${MAKEFILE_LIST} | { fmt -t -w $${COLUMNS:-75} || cat ; }
