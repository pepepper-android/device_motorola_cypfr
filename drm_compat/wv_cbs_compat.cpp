/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * libwvhidl.so was built when BoringSSL still exported CBS_init(), so the
 * Widevine DRM service cannot link on A15:
 *
 *   CANNOT LINK EXECUTABLE "/vendor/bin/hw/android.hardware.drm@1.3-service.widevine":
 *     cannot locate symbol "CBS_init" referenced by "/vendor/lib64/libwvhidl.so"
 *
 * It is the only symbol the whole process is missing - upstream turned CBS_init
 * into an OPENSSL_INLINE in include/openssl/bytestring.h, so it stopped being a
 * symbol in libcrypto while the other 48 CBS_* entry points stayed. Nothing else
 * about the ABI moved: struct cbs_st is still the same two members it has always
 * been, so the definition below is byte-for-byte what the header does.
 *
 * This is LD_PRELOADed into the Widevine service alone (see the setenv in
 * android.hardware.drm@1.3-service.widevine.rc). The struct is declared here
 * rather than pulled from <openssl/bytestring.h> so the inline definition in
 * that header cannot collide with this one.
 */

#include <stddef.h>
#include <stdint.h>

struct cbs_st {
    const uint8_t* data;
    size_t len;
};

extern "C" __attribute__((visibility("default"))) void CBS_init(struct cbs_st* cbs,
                                                                const uint8_t* data, size_t len) {
    cbs->data = data;
    cbs->len = len;
}
