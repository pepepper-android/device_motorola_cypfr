/*
 * Copyright (C) 2021 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <android-base/properties.h>
#include <libinit_utils.h>
#include <libinit_dalvik_heap.h>

#include "vendor_init.h"

using android::base::GetProperty;

#define SKU_PROP "ro.boot.hardware.sku"

void set_variant_props(const std::string& model, const std::string& name, const std::string& fingerprint, const std::string& desc) {
    set_ro_build_prop("model", model, true);
    set_ro_build_prop("name", name, true);

    set_ro_build_prop("fingerprint", fingerprint);
    property_override("ro.bootimage.build.fingerprint", fingerprint);

    property_override("ro.build.description", desc);
}

void search_variant() {
    std::string current_sku = GetProperty(SKU_PROP, "");

    if (current_sku == "XT2219-1") {
        set_variant_props("moto g52j 5G",
                          "cypfr_g",
                          "motorola/cypfr_g/cypfr:12/S3RYBS32M.168-19-5-3/5e11d:user/release-keys",
                          "cypfr_g-user 12 S3RYBS32M.168-19-5-3 5e11d release-keys");
    } else {
        set_variant_props("Unknown",
                          "cypfr",
                          "motorola/cypfr_g/cypfr:12/S3RYBS32M.168-19-5-3/5e11d:user/release-keys",
                          "cypfr_g-user 12 S3RYBS32M.168-19-5-3 5e11d release-keys");
    }
}

void vendor_load_properties() {
    search_variant();
    set_dalvik_heap();
}