#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

COMMON_PATH := device/motorola/common

# Boot animation
TARGET_SCREEN_HEIGHT := 2400
TARGET_SCREEN_WIDTH := 1080

# FlokoROM's own animation, carried over from v7 (patch/vendor_addons.diff puts
# it in vendor/addons, where the rest of the ROM's assets live).
#
# TARGET_BOOTANIMATION is crDroid's hook for shipping a finished zip:
# vendor/lineage/config/BoardConfigSoong.mk exports it as the
# lineage_bootanimation.prebuilt_file soong config variable and
# vendor/addons/prebuilt/bootanimation/Android.bp copies it straight through.
#
# Going through the generator instead would not work: gen-bootanimation.sh picks
# bootanimation_1080.tar for a 1080-wide screen and hardcodes a 680x680 desc,
# while these frames are 1080x1080. Set next to TARGET_SCREEN_* because the same
# BoardConfigSoong.mk reads all three.
TARGET_BOOTANIMATION := vendor/addons/prebuilt/bootanimation/floko-bootanimation.zip

# Screen
TARGET_SCREEN_DENSITY := 420

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := 420dpi
PRODUCT_AAPT_PREBUILT_DPI := xxxhdpi xxhdpi xhdpi hdpi

# VNDK
PRODUCT_EXTRA_VNDK_VERSIONS := 30

PRODUCT_SHIPPING_API_LEVEL := 30

PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Product characteristics
PRODUCT_CHARACTERISTICS := default

# ART's userfaultfd GC needs userfaultfd(2) *and* MREMAP_DONTUNMAP. This device
# ships a prebuilt 5.4.210-moto kernel, and MREMAP_DONTUNMAP appears nowhere in
# kernel/motorola/msm-5.4 -- it landed upstream in 5.7 and this vendor kernel
# carries no backport, unlike the GKI android12-5.4 branches.
# build/soong/scripts/uffd_gc_utils.py cannot tell on its own because the
# version string has no -android<release>- tag, so it refuses to guess:
#   Unable to determine UFFD GC flag for kernel version "5.4.210-moto-...".
# Do not flip this to true: ART would pick a GC the kernel cannot support.
PRODUCT_ENABLE_UFFD_GC := false

# Enable project quotas and casefolding for emulated storage without sdcardfs
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# Installs gsi keys into ramdisk, to boot a GSI with verified boot.
$(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)

# Qcom
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.hardware=qcom

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay-lineage

PRODUCT_ENFORCE_RRO_TARGETS := *

PRODUCT_PACKAGES += \
    FrameworksResCypfr \
    LineageSystemUICypfr \
    LineageSettingsCypfr \
    SettingsProviderResCypfr \
    SystemUIResCypfr \
    TelephonyResCommon_Sys \
    CarrierConfigResCommon_Sys \
    AdaptiveSleepOverlayCypfr \
    RegulatoryInfoOverlayCypfr \
    EUICCOverlayCypfr

# A/B
AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=ext4 \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

# Additional native libraries
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/public.libraries.txt:$(TARGET_COPY_OUT_VENDOR)/etc/public.libraries.txt \
    $(LOCAL_PATH)/configs/public.libraries-qti.txt:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/public.libraries-qti.txt

# Libraries the blobs used to get from the VNDK. Stock does not carry any of
# these under /vendor because on Android 12 they came out of the VNDK APEX;
# with the VNDK gone in Android 15 a vendor process cannot reach /system/lib64,
# so the loader simply fails and the process dies before it logs anything of
# its own. All three are vendor_available in AOSP, so build a vendor copy
# rather than lifting one out of prebuilts/vndk:
#
#   libsqlite   - 17 users, among them libqcrilNr.so. qcrilNrd died on every
#                 start with "library "libsqlite.so" not found", which is why
#                 android.hardware.radio never registered and there was no
#                 mobile data at all:
#                   E init: process with updatable components 'vendor.qcrild'
#                           exited 4 times in 4 minutes
#   libjsoncpp  - libqcodec2_platform.so, i.e. vendor.qti.media.c2@1.0-service.
#                 Its absence is why nothing ever answered
#                 android.hardware.media.c2@1.0::IComponentStore/default.
#   libsysutils - libmdmcutback.so and libmotext_inf.so, 32- and 64-bit.
#
# Found by walking every ELF under /vendor and resolving its DT_NEEDED against
# /vendor plus llndk.libraries.txt - checking against /system as well hides
# these, because the file is there, just not reachable from the vendor
# namespace. libandroidicu is the one gap left: it has no vendor variant (it
# lives in the com.android.i18n APEX) and only tcmd/tcmdhelp want it.
PRODUCT_PACKAGES += \
    libjsoncpp.vendor \
    libsqlite.vendor \
    libsysutils.vendor

# These have in-tree modules that install to the same paths the blobs would, and
# a module recipe overrides a PRODUCT_COPY_FILES one - the module gets built and
# the blob is silently ignored. Ask for them explicitly instead of shipping a
# copy that never lands.
PRODUCT_PACKAGES += \
    libqcomvisualizer \
    libqcomvoiceprocessing \
    libtinycompress \
    libvolumelistener \
    vendor.qti.hardware.bluetooth_audio@2.1.vendor

# libwvhidl.so still wants CBS_init(), which BoringSSL turned into an
# OPENSSL_INLINE, so it is no longer a symbol in libcrypto and the Widevine DRM
# service could not link at all. That one symbol is all the process is missing.
PRODUCT_PACKAGES += \
    libwv_cbs_compat

# A/B
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl-qti \
    android.hardware.boot@1.1-impl-qti.recovery \
    android.hardware.boot@1.1-service \
    bootctrl.holi \
    bootctrl.holi.recovery

# USB
# The gadget HAL is deliberately not here. It was added on the theory that since
# Android 12 it is what sets up the configfs gadget, so without it USB would
# never enumerate. That was the wrong diagnosis: what was actually missing was
# the entire vendor init tree, and init.qcom.usb.rc plus init.mmi.usb.rc build
# the gadget themselves. adb comes up fine now with no gadget HAL running at all,
# and v7 never shipped one.
#
# Worse, it cannot work as written. UsbGadget::UsbGadget() aborts unless it can
# access /config/usb_gadget/g1/os_desc/b.1, which is a symlink to configs/b.1,
# and init.qcom.usb.rc creates that as 0770 root:root while the service runs as
# user system:
#
#   android.hardware.usb.gadget@1.1-service: configfs setup not done yet
#
# So it aborted on every start, forever - 74 times in one boot. Because its VINTF
# fragment still declared android.hardware.usb.gadget@1.1, UsbService blocked in
# IUsbGadget::getService() and never returned from onBootPhase(BOOT_COMPLETED),
# so sys.boot_completed was never set, the home activity never launched, and
# entering the PIN appeared to do nothing.
#
# UsbDeviceManager falls back to UsbHandlerLegacy when no gadget HAL is declared
# (UsbDeviceManager.java, "if (mUsbGadgetHal == null)"), which drives USB through
# sys.usb.config - exactly what the vendor rc files are written for.
PRODUCT_PACKAGES += \
    android.hardware.usb-service.moto-common

# Lights
# Same story: this is the LED HAL, and it writes /sys/class/leds/charging, which
# is the node this device actually has.
PRODUCT_PACKAGES += \
    android.hardware.lights-service.moto

# Update engine
PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier \
    libgptutils.cypfr

PRODUCT_PACKAGES_DEBUG += \
    bootctl \
    update_engine_client

# Ant
PRODUCT_PACKAGES += \
    com.dsi.ant@1.0.vendor

# Atrace
PRODUCT_PACKAGES += \
    android.hardware.atrace@1.0-service

# Audio
PRODUCT_PACKAGES += \
    android.hardware.audio@6.0-impl \
    android.hardware.audio.effect@6.0-impl \
    android.hardware.audio.service \
    android.hardware.bluetooth.audio-impl \
    android.hardware.soundtrigger@2.3-impl \
    audioadsprpcd \
    audio.bluetooth.default \
    audio.r_submix.default \
    audio.usb.default \
    libaudiopreprocessing \
    libaudioroute.vendor \
    libbundlewrapper \
    libdownmix \
    libdynproc \
    libeffectproxy \
    libldnhncr \
    libreverbwrapper \
    libvisualizer

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/audio/audio_policy_configuration.xml

# Authsecret
PRODUCT_PACKAGES += \
    android.hardware.authsecret@1.0.vendor

# Bluetooth
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR := $(LOCAL_PATH)/bluetooth/include

# android.hardware.bluetooth@1.0-service-qti is a HIDL server, and nothing builds
# the interface library for it any more: Android 15 moved Bluetooth to AIDL, so
# android.hardware.bluetooth@1.0 is no longer part of any product by default.
# A missing NEEDED fails the whole executable, so the HAL never started at all:
#
#   linker: CANNOT LINK EXECUTABLE ".../android.hardware.bluetooth@1.0-service-qti":
#     library "android.hardware.bluetooth@1.0.so" not found
#   com.android.bluetooth: Abort message: 'Unable to get a Bluetooth service
#     after 500ms, start the HAL before starting Bluetooth'
#
# hardware/interfaces/bluetooth/1.0 is still in the tree, so build the vendor
# variant rather than shipping a blob. The QTI libraries the same service needs -
# btconfigstore@{1.0,2.0} and the @1.0-impl-qti passthrough - are proprietary and
# come from proprietary-files.txt instead.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0.vendor

# Bluetooth Audio (System-side HAL, sysbta)
PRODUCT_PACKAGES += \
    audio.sysbta.default \
    android.hardware.bluetooth.audio-service-system

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bluetooth/audio/config/sysbta_audio_policy_configuration.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/sysbta_audio_policy_configuration.xml \
    $(LOCAL_PATH)/bluetooth/audio/config/sysbta_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/sysbta_audio_policy_configuration_7_0.xml

# Camera
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-impl \
    android.hardware.camera.provider@2.4-service_64 \
    libcamera2ndk_vendor \
    libgui_vendor \
    vendor.qti.hardware.camera.postproc@1.0.vendor

# GCamGo
PRODUCT_PACKAGES += \
    GCamGOPrebuilt-V3_8

# Charger
WITH_LINEAGE_CHARGER := false

# Display
PRODUCT_PACKAGES += \
    android.hardware.graphics.mapper@3.0-impl-qti-display \
    android.hardware.graphics.mapper@4.0-impl-qti-display \
    android.hardware.memtrack@1.0-impl \
    android.hardware.memtrack@1.0-service \
    init.qti.display_boot.rc \
    init.qti.display_boot.sh \
    gralloc.default \
    libdisplayconfig.qti \
    libdisplayconfig.system.qti \
    libqdMetaData \
    libqdMetaData.system \
    libsdmcore \
    libsdmutils \
    libtinyxml \
    libvulkan \
    vendor.display.config@1.15 \
    vendor.display.config@1.15.vendor \
    vendor.display.config@2.0 \
    vendor.display.config@2.0.vendor \
    vendor.qti.hardware.display.allocator-service \
    vendor.qti.hardware.display.composer-service \
    vendor.qti.hardware.display.mapper@1.0.vendor \
    vendor.qti.hardware.display.mapper@1.1.vendor \
    vendor.qti.hardware.display.mapper@2.0.vendor \
    vendor.qti.hardware.display.mapper@3.0.vendor \
    vendor.qti.hardware.display.mapper@4.0.vendor

# DRM
PRODUCT_PACKAGES += \
    android.hardware.drm@1.4.vendor \
    android.hardware.drm-service.clearkey

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl.custom \
    fastbootd

# Fingerprint
PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.1.vendor

# Gatekeeper
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0.vendor

# GPS
PRODUCT_PACKAGES += \
    android.hardware.gnss@2.1-service-qti \
    gnss@2.0-base.policy \
    gnss@2.0-xtra-daemon.policy \
    gnss@2.0-xtwifi-client.policy \
    gnss@2.0-xtwifi-inet-agent.policy \
    libbatching \
    libgeofencing \
    libgnss \
    libgnsspps

PRODUCT_PACKAGES += \
    apdr.conf \
    flp.conf \
    gnss_antenna_info.conf \
    gps.conf \
    izat.conf \
    lowi.conf \
    sap.conf \
    xtwifi.conf

# Health
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-impl.recovery \
    android.hardware.health@2.1-service

# HIDL
PRODUCT_PACKAGES += \
    libhidltransport.vendor \
    libhwbinder.vendor

# Init
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_RAMDISK)/first_stage_ramdisk/fstab.qcom

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.qcom \
    $(LOCAL_PATH)/rootdir/etc/ueventd.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc

$(foreach f,$(wildcard $(LOCAL_PATH)/rootdir/etc/init/hw/*.rc),\
        $(eval PRODUCT_COPY_FILES += $(f):$(TARGET_COPY_OUT_SYSTEM)/etc/init/hw/$(notdir $f)))
$(foreach f,$(wildcard $(LOCAL_PATH)/rootdir/etc/init/*.rc),\
        $(eval PRODUCT_COPY_FILES += $(f):$(TARGET_COPY_OUT_SYSTEM)/etc/init/$(notdir $f)))
$(foreach f,$(wildcard $(LOCAL_PATH)/rootdir/bin/*.sh),\
        $(eval PRODUCT_COPY_FILES += $(f):$(TARGET_COPY_OUT_SYSTEM)/bin/$(notdir $f)))

# Recovery init scripts
PRODUCT_PACKAGES += \
    init.recovery.qcom.rc \
    init.recovery.usb.rc \
    init.recovery.qcom.sh

# IPACM
PRODUCT_PACKAGES += \
    ipacm \
    IPACM_cfg.xml \
    libipanat \
    liboffloadhal

# Keymaster
PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.1.vendor

# LiveDisplay
#PRODUCT_PACKAGES += \
#    vendor.lineage.livedisplay@2.1-service.cypfr

# Media
PRODUCT_COPY_FILES += \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_c2.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_c2.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_c2_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_c2_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_c2_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_c2_video.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_telephony.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video_le.xml

PRODUCT_PACKAGES += \
    libavservices_minijail \
    libavservices_minijail.vendor \
    libcodec2_hidl@1.0.vendor

# Neural Networks
PRODUCT_PACKAGES += \
    android.hardware.neuralnetworks@1.3.vendor

# Net
PRODUCT_PACKAGES += \
    netutils-wrapper-1.0

# NFC
# cypfr has an NXP SN100x controller, not an ST21NFC. The ST HAL that used to be
# listed here (android.hardware.nfc@1.2-service.st, nfc_nci.st21nfc.default)
# builds fine from hardware/st/nfc, which is why the mistake was never noticed --
# it just cannot drive this hardware.
#
# The HAL is built from hardware/nxp/nfc rather than taken from the vendor blobs.
# That tree is already in the manifest (platform/hardware/nxp/nfc), sits at the
# same android-15.0.0_r36 tag as the rest of the base, and covers SN1xx/sn100.
# Building it also gets us off the stock nfc_nci.nqx.default.hw.so, which was
# compiled against the Android 11 libbase and needs symbols A15 no longer has.
#
# android.hardware.nfc-service.nxp is the AIDL 1 service; it pulls in
# nfc_nci_nxp_snxxx (the HAL itself) and ships its own VINTF fragment, so
# manifest.xml must NOT declare NFC as well.
PRODUCT_PACKAGES += \
    android.hardware.nfc-service.nxp \
    com.android.nfc_extras \
    libchrome.vendor \
    Tag

# Kept only so the stock blob HAL can be brought back on-device without a
# rebuild: push the manifest/rc changes back and start nqnfc_2_0_hal_service.
# The blob is still installed but nothing starts it -- see the commented-out
# triggers in vendor.nxp.hardware.nfc@2.0-service.rc.
#
# nfc_nci.nqx.default.hw.so wants fmt::v6::internal::vformat<char>() and the
# non-template android::base::Trim(), both dropped from the A15 libbase.
# libnfc_fmt_compat forwards those two calls to this private copy of the VNDK 30
# libbase, the last one that exported them.
PRODUCT_PACKAGES += \
    android.hardware.nfc@1.0.vendor \
    android.hardware.nfc@1.1.vendor \
    android.hardware.nfc@1.2.vendor \
    libnfc_fmt_compat

PRODUCT_COPY_FILES += \
    prebuilts/vndk/v30/arm64/arch-arm64-armv8-a/shared/vndk-sp/libbase.so:$(TARGET_COPY_OUT_VENDOR)/lib64/nfc_compat/libbase.so

# Secure element. The FeliCa applet used by Osaifu-Keitai lives in the eSE, so
# the SE HAL (reached from apps through OMAPI) and the eSE power manager are
# both required. Services and impl come from the vendor blobs.
PRODUCT_PACKAGES += \
    android.hardware.secure_element@1.0.vendor \
    android.hardware.secure_element@1.1.vendor \
    android.hardware.secure_element@1.2.vendor

# OMX
PRODUCT_PACKAGES += \
    libcodec2_hidl@1.0.vendor \
    libcodec2_vndk.vendor

# Perf
PRODUCT_PACKAGES += \
    vendor.qti.hardware.perf@2.2.vendor

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.pro.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.pro.xml \
    frameworks/native/data/etc/android.hardware.biometrics.face.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.biometrics.face.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.raw.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.hcef.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hcef.xml \
    frameworks/native/data/etc/android.hardware.nfc.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.uicc.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.uicc.xml \
    frameworks/native/data/etc/android.hardware.telephony.cdma.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.cdma.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_1.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.software.device_id_attestation.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_id_attestation.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.sip.voip.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.sip.voip.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml \
    frameworks/native/data/etc/android.software.opengles.deqp.level-2020-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.opengles.deqp.level.xml \
    frameworks/native/data/etc/android.software.vulkan.deqp.level-2020-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/product_privapp-permissions-hotword.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-hotword.xml

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/hotword-hiddenapi-package-whitelist.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/sysconfig/hotword-hiddenapi-package-whitelist.xml

# Power
PRODUCT_PACKAGES += \
    android.hardware.power-service-qti

# PRODUCT_PACKAGES += \
#     android.hardware.power-service.moto-common-libperfmgr

# QMI
PRODUCT_PACKAGES += \
    libjson \
    libqti_vndfwk_detect \
    libqti_vndfwk_detect.vendor \
    libvndfwk_detect_jni.qti \
    libvndfwk_detect_jni.qti.vendor

# QTI service tracker
PRODUCT_PACKAGES += \
    vendor.qti.hardware.servicetracker@1.2.vendor

# RenderScript
PRODUCT_PACKAGES += \
    android.hardware.renderscript@1.0-impl

# RIL
PRODUCT_PACKAGES += \
    android.hardware.radio@1.5.vendor \
    android.hardware.radio.config@1.2.vendor \
    android.hardware.radio.deprecated@1.0.vendor \
    android.system.net.netd@1.1.vendor \
    libprotobuf-cpp-full \
    librmnetctl \
    libxml2

# Sensors
PRODUCT_PACKAGES += \
    android.hardware.sensors@2.0-service.multihal \
    libsensorndkbridge

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    $(COMMON_PATH) \
    hardware/google/interfaces \
    hardware/google/pixel

# Telephony
PRODUCT_PACKAGES += \
    ims-ext-common \
    ims_ext_common.xml \
    qti-telephony-hidl-wrapper \
    qti_telephony_hidl_wrapper.xml \
    qti-telephony-utils \
    qti_telephony_utils.xml \
    telephony-ext

PRODUCT_BOOT_JARS += \
    telephony-ext

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/telephony_system-ext_privapp-permissions-qti.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/telephony_system-ext_privapp-permissions-qti.xml

# Thermal
PRODUCT_PACKAGES += \
    android.hardware.thermal@2.0-service.qti \
    android.hardware.thermal@2.0 \
    android.hardware.thermal@2.0.vendor

# Trusted UI
PRODUCT_PACKAGES += \
    android.hidl.memory.block@1.0.vendor \
    vendor.qti.hardware.systemhelper@1.0.vendor

# Update engine
PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

PRODUCT_PACKAGES_DEBUG += \
    update_engine_client

# USB
# init.qcom.usb.rc is not listed here: it now comes from the stock vendor image
# along with the rest of the vendor init tree (proprietary-files.txt, "Vendor
# init"), and two rules writing the same path would collide. The CAF copy under
# vendor/qcom/opensource/usb/etc is a different lineage from Motorola's, which is
# what init.mmi.usb.rc is written against, and v7 shipped the stock one.
PRODUCT_PACKAGES += \
    android.hardware.usb@1.3-service-qti \
    init.qcom.usb.sh

PRODUCT_SOONG_NAMESPACES += vendor/qcom/opensource/usb/etc

# Recovery
# The generic recovery init.rc builds the configfs gadget from these, so they
# have to name our real VID/PIDs rather than the AOSP 18D1/D001/4EE0 defaults.
# The adb and fastboot PIDs differ, which is what the stock recovery uses and
# what host udev rules expect.
#
# persist.sys.usb.config is not what starts adb in recovery - the recovery
# binary sets sys.usb.config itself (bootable/recovery/recovery_main.cpp, since
# ro.debuggable=1). It is kept only so the value is defined before any of that
# runs; see also init.recovery.usb.rc.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=adb \
    ro.recovery.usb.vid=22B8 \
    ro.recovery.usb.adb.pid=2E81 \
    ro.recovery.usb.fastboot.pid=2E80

PRODUCT_PACKAGES += \
    init.recovery.qcom.sh

# Vendor service manager
PRODUCT_PACKAGES += \
    vndservicemanager

# Vibrator
PRODUCT_PACKAGES += \
    vendor.qti.hardware.vibrator.service

PRODUCT_COPY_FILES += \
    vendor/qcom/opensource/vibrator/excluded-input-devices.xml:$(TARGET_COPY_OUT_VENDOR)/etc/excluded-input-devices.xml

# VNDK
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := strict

# WiFi
# android.hardware.wifi@1.0-service is gone: Android 15 dropped the HIDL Wi-Fi
# HAL (hardware/interfaces/wifi/1.0/default no longer exists), so the request was
# silently discarded by ALLOW_MISSING_DEPENDENCIES and the built vendor image had
# no IWifi implementation at all -- WifiService cannot bring the chip up without
# one. Stock ships android.hardware.wifi@1.0-service; the AIDL service is its
# replacement.
PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    hostapd \
    libwpa_client \
    libwifi-hal-ctrl \
    libwifi-hal-qcom \
    vendor.qti.hardware.wifi.hostapd@1.0.vendor \
    vendor.qti.hardware.wifi.hostapd@1.1.vendor \
    vendor.qti.hardware.wifi.hostapd@1.2.vendor \
    vendor.qti.hardware.wifi.supplicant@2.0.vendor \
    vendor.qti.hardware.wifi.supplicant@2.1.vendor \
    vendor.qti.hardware.wifi.supplicant@2.2.vendor \
    wpa_supplicant \
    wpa_supplicant.conf

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/wifi/WCNSS_qcom_cfg.ini:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/WCNSS_qcom_cfg.ini \
    $(LOCAL_PATH)/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    $(LOCAL_PATH)/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf

PRODUCT_VENDOR_MOVE_ENABLED := true

# WiFi Display
PRODUCT_PACKAGES += \
    libavservices_minijail \
    libnl \
    libwfdaac_vendor

PRODUCT_BOOT_JARS += \
    WfdCommon

# Moto Action
PRODUCT_PACKAGES += \
    MotoActions

# Keylayout
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_SYSTEM)/usr/keylayout/gpio-keys.kl

# Gapps
ifeq ($(WITH_GMS),true)
$(call inherit-product, vendor/gapps/arm64/arm64-vendor.mk)
endif

# For debugging
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
PRODUCT_PACKAGES += MatLog
endif

# FeliCa
$(call inherit-product, vendor/motorola/felica-common/device.mk)

# Inherit from vendor blobs
$(call inherit-product, vendor/motorola/cypfr/cypfr-vendor.mk)
