LOCAL_PATH := $(call my-dir)

# Make a static library for clearsilver's regex.
# This prevents multiple symbol definition error....
include $(CLEAR_VARS)
LOCAL_SRC_FILES := ../clearsilver/util/regex/regex.c
LOCAL_MODULE := libclearsilverregex
LOCAL_C_INCLUDES := \
	external/clearsilver \
 	external/clearsilver/util/regex
include $(BUILD_STATIC_LIBRARY)


SUBMAKE := make -s -C $(LOCAL_PATH) CC=$(CC) 

KERNEL_MODULES_DIR?=/system/lib/modules

BUSYBOX_SRC_FILES = $(shell cat $(LOCAL_PATH)/busybox-$(BUSYBOX_CONFIG).sources) \
	libbb/android.c

ifeq ($(TARGET_ARCH),arm)
	BUSYBOX_SRC_FILES += \
        android/libc/arch-arm/syscalls/adjtimex.S \
        android/libc/arch-arm/syscalls/getsid.S \
        android/libc/arch-arm/syscalls/stime.S \
        android/libc/arch-arm/syscalls/swapon.S \
        android/libc/arch-arm/syscalls/swapoff.S \
        android/libc/arch-arm/syscalls/sysinfo.S
endif

BUSYBOX_C_INCLUDES = \
	$(LOCAL_PATH)/include-$(BUSYBOX_CONFIG) \
	$(LOCAL_PATH)/include $(LOCAL_PATH)/libbb \
	external/clearsilver \
	external/clearsilver/util/regex \
	bionic/libc/private \
	bionic/libm/include \
	bionic/libm \
	libc/kernel/common

BUSYBOX_CFLAGS = \
	-std=gnu99 \
	-Werror=implicit \
	-DNDEBUG \
	-DANDROID_CHANGES \
	-include include-$(BUSYBOX_CONFIG)/autoconf.h \
	-D'CONFIG_DEFAULT_MODULES_DIR="$(KERNEL_MODULES_DIR)"' \
	-D'BB_VER="$(strip $(shell $(SUBMAKE) kernelversion)) $(BUSYBOX_SUFFIX)"' -DBB_BT=AUTOCONF_TIMESTAMP

# execute make clean, make prepare and copy profiles required for normal & static busybox (recovery)
include $(CLEAR_VARS)
BUSYBOX_CONFIG := full minimal
$(BUSYBOX_CONFIG):
	@echo GENERATE INCLUDES FOR BUSYBOX $@
	@cd $(LOCAL_PATH) && make clean
	cp $(LOCAL_PATH)/.config-$@ $(LOCAL_PATH)/.config
	cd $(LOCAL_PATH) && make prepare
	cd $(LOCAL_PATH)/include-$@ && ./copy-current.sh
	cd $(LOCAL_PATH)/include && rm usage_compressed.h
	cd $(LOCAL_PATH)
busybox_prepare: $(BUSYBOX_CONFIG)
LOCAL_MODULE := busybox_prepare
LOCAL_MODULE_TAGS := eng
include $(BUILD_STATIC_LIBRARY)


# Build the static lib for the recovery tool

include $(CLEAR_VARS)
BUSYBOX_CONFIG:=minimal
BUSYBOX_SUFFIX:=static
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := -Dmain=busybox_driver $(BUSYBOX_CFLAGS)
LOCAL_CFLAGS += \
  -Dgetusershell=busybox_getusershell \
  -Dsetusershell=busybox_setusershell \
  -Dendusershell=busybox_endusershell \
  -Dttyname_r=busybox_ttyname_r \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dgenerate_uuid=busybox_generate_uuid
LOCAL_MODULE := libbusybox
LOCAL_MODULE_TAGS := eng
LOCAL_STATIC_LIBRARIES += busybox_prepare libclearsilverregex libcutils libc libm
include $(BUILD_STATIC_LIBRARY)


# Bionic Busybox /system/xbin

include $(CLEAR_VARS)
BUSYBOX_CONFIG:=full
BUSYBOX_SUFFIX:=bionic
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_MODULE := busybox
LOCAL_MODULE_TAGS := eng
LOCAL_MODULE_PATH := $(TARGET_OUT_OPTIONAL_EXECUTABLES)
LOCAL_STATIC_LIBRARIES += busybox_prepare libclearsilverregex
include $(BUILD_EXECUTABLE)

BUSYBOX_LINKS := $(shell cat $(LOCAL_PATH)/busybox-$(BUSYBOX_CONFIG).links)
# nc is provided by external/netcat
exclude := nc
SYMLINKS := $(addprefix $(TARGET_OUT_OPTIONAL_EXECUTABLES)/,$(filter-out $(exclude),$(notdir $(BUSYBOX_LINKS))))
$(SYMLINKS): BUSYBOX_BINARY := $(LOCAL_MODULE)
$(SYMLINKS): $(LOCAL_INSTALLED_MODULE)
	@echo "Symlink: $@ -> $(BUSYBOX_BINARY)"
	@mkdir -p $(dir $@)
	@rm -rf $@
	$(hide) ln -sf $(BUSYBOX_BINARY) $@

ALL_DEFAULT_INSTALLED_MODULES += $(SYMLINKS)

# We need this so that the installed files could be picked up based on the
# local module name
ALL_MODULES.$(LOCAL_MODULE).INSTALLED := \
    $(ALL_MODULES.$(LOCAL_MODULE).INSTALLED) $(SYMLINKS)


# Build a static busybox (sample, no more used)
ifeq (1,0)

include $(CLEAR_VARS)
BUSYBOX_CONFIG:=full
BUSYBOX_SUFFIX:=static
LOCAL_SRC_FILES := $(BUSYBOX_SRC_FILES)
LOCAL_C_INCLUDES := $(BUSYBOX_C_INCLUDES)
LOCAL_CFLAGS := $(BUSYBOX_CFLAGS)
LOCAL_CFLAGS += \
  -Dgetusershell=busybox_getusershell \
  -Dsetusershell=busybox_setusershell \
  -Dendusershell=busybox_endusershell \
  -Dttyname_r=busybox_ttyname_r \
  -Dgetmntent=busybox_getmntent \
  -Dgetmntent_r=busybox_getmntent_r \
  -Dgenerate_uuid=busybox_generate_uuid
LOCAL_FORCE_STATIC_EXECUTABLE := true
LOCAL_MODULE := bootmenu_busybox
LOCAL_MODULE_TAGS := optional
LOCAL_STATIC_LIBRARIES += libclearsilverregex libcutils libc libm
LOCAL_MODULE_CLASS := UTILITY_EXECUTABLES
# LOCAL_MODULE_PATH := $(PRODUCT_OUT)/system/bootmenu/binary
LOCAL_UNSTRIPPED_PATH := $(PRODUCT_OUT)/symbols/utilities
LOCAL_MODULE_STEM := busybox
include $(BUILD_EXECUTABLE)

endif

