#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from cypfr device
$(call inherit-product, device/motorola/cypfr/device.mk)

# Inherit some common Evolution X stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_cypfr
PRODUCT_DEVICE := cypfr
PRODUCT_MANUFACTURER := motorola
PRODUCT_BRAND := motorola
PRODUCT_MODEL := moto g52j 5G

# Evolution X stuff
TARGET_SUPPORTS_QUICK_TAP := true

PRODUCT_GMS_CLIENTID_BASE := android-motorola

# Android 15 generates build.prop in soong, and gen_build_prop.py only accepts
# overrides whose key already exists in product_config.json:
#   Key "TARGET_PRODUCT" isn't a valid prop override
# TARGET_PRODUCT is now DeviceProduct, and PRIVATE_BUILD_DESC is gone -- the
# description is derived, so override the derived values directly. override_config()
# runs after BuildFlavor/BuildDesc are computed, so setting them here takes effect.
PRODUCT_BUILD_PROP_OVERRIDES += \
    DeviceProduct=cypfr_g \
    BuildFlavor=cypfr_g-user \
    BuildDesc="cypfr_g-user 12 S3RYBS32M.168-19-5-7 c7309 release-keys"

BUILD_FINGERPRINT := motorola/cypfr_g/cypfr:12/S3RYBS32M.168-19-5-7/c7309:user/release-keys
