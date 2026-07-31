/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * nfc_nci.nqx.default.hw.so predates the removal of fmtlib from libbase: it was
 * built against the Android 11 (VNDK 30) libbase, which re-exported fmt v6 and
 * still had a non-template android::base::Trim().  A15's libbase has neither, so
 * the NFC HAL dies before it ever runs:
 *
 *   CANNOT LINK EXECUTABLE "/vendor/bin/hw/vendor.nxp.hardware.nfc@2.0-service":
 *     cannot locate symbol "_ZN3fmt2v68internal7vformatIcEE..." referenced by
 *     "/vendor/lib64/nfc_nci.nqx.default.hw.so"
 *
 * Those two are the only symbols the whole NFC process cannot resolve, so rather
 * than put the VNDK 30 libbase on the vendor search path - which would also hand
 * it to libcutils and server_configurable_flags, both of which need symbols that
 * only the A15 libbase has - this shim is LD_PRELOADed into the NFC service
 * alone and forwards just those two calls to a private copy of it.  The copy is
 * opened RTLD_LOCAL so it never enters the global symbol group: nothing else in
 * the process can bind to it by accident, and everything but these two calls
 * keeps using the A15 libbase.
 *
 * The declarations below only have to mangle like fmt v6's did and have the same
 * calling convention; both types are two pointer-sized POD members passed in
 * registers, so forwarding is a straight pass-through.  basic_format_context is
 * never completed - it appears only as a template argument.
 */

#include <dlfcn.h>
#include <stddef.h>

#include <iterator>
#include <string>

#define LOG_TAG "nfc_fmt_compat"
#include <log/log.h>

namespace {

constexpr char kVndk30Libbase[] = "/vendor/lib64/nfc_compat/libbase.so";

// Exactly as referenced by nfc_nci.nqx.default.hw.so.
constexpr char kVformatSym[] =
        "_ZN3fmt2v68internal7vformatIcEENSt3__112basic_stringIT_NS3_11char_traitsIS5_EENS3_"
        "9allocatorIS5_EEEENS0_17basic_string_viewIS5_EENS0_17basic_format_argsINS0_"
        "20basic_format_contextINS3_20back_insert_iteratorINS1_6bufferIS5_EEEES5_EEEE";
constexpr char kTrimSym[] =
        "_ZN7android4base4TrimERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE";

void* Resolve(const char* symbol) {
    static void* handle = dlopen(kVndk30Libbase, RTLD_NOW | RTLD_LOCAL);
    LOG_ALWAYS_FATAL_IF(handle == nullptr, "dlopen(%s) failed: %s", kVndk30Libbase, dlerror());

    void* fn = dlsym(handle, symbol);
    LOG_ALWAYS_FATAL_IF(fn == nullptr, "%s is missing from %s", symbol, kVndk30Libbase);
    return fn;
}

}  // namespace

namespace fmt {
inline namespace v6 {

template <typename Char>
struct basic_string_view {
    const Char* data;
    size_t size;
};

namespace internal {
template <typename T>
class buffer {
  public:
    using value_type = T;
};
}  // namespace internal

template <typename OutputIt, typename Char>
class basic_format_context;

template <typename Context>
struct basic_format_args {
    unsigned long long desc;
    const void* values;
};

namespace internal {

template <typename Char>
using format_args_for =
        basic_format_args<basic_format_context<std::back_insert_iterator<buffer<Char>>, Char>>;

// Written out rather than spelled std::string so the return type mangles as
// basic_string<T_, ...>, the way the original template's did.
template <typename Char>
using string_for = std::basic_string<Char, std::char_traits<Char>, std::allocator<Char>>;

template <typename Char>
__attribute__((visibility("default"))) string_for<Char> vformat(basic_string_view<Char> format_str,
                                                                format_args_for<Char> args) {
    using Fn = string_for<Char> (*)(basic_string_view<Char>, format_args_for<Char>);
    static auto fn = reinterpret_cast<Fn>(Resolve(kVformatSym));
    return fn(format_str, args);
}

template string_for<char> vformat<char>(basic_string_view<char>, format_args_for<char>);

}  // namespace internal
}  // namespace v6
}  // namespace fmt

namespace android {
namespace base {

__attribute__((visibility("default"))) std::string Trim(const std::string& s) {
    using Fn = std::string (*)(const std::string&);
    static auto fn = reinterpret_cast<Fn>(Resolve(kTrimSym));
    return fn(s);
}

}  // namespace base
}  // namespace android
