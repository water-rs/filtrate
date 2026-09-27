//! Platform packaging of the pre-translated Filtrate GPU shaders.
//!
//! The two static shaders (blit, multi-input composite) ship pre-translated
//! under `src/shaders/compiled` — regenerate with `package-shaders.sh`, which
//! runs `shaderloom wgsl-package` at the pinned rev (see src/shaders/README.md)
//! — so this script runs no `naga`. On Apple/Windows targets it only invokes
//! the platform toolchain (`xcrun`/`dxc`) on the checked-in translations.

fn main() {
    const PACKAGED_SHADERS: &str = "src/shaders/compiled";

    println!("cargo:rerun-if-changed=build.rs");
    for name in ["filter_blit", "multi_input_filter"] {
        if std::env::var("CARGO_CFG_TARGET_VENDOR").as_deref() == Ok("apple") {
            shaderloom::packaged::compile_packaged_metallib(PACKAGED_SHADERS, name);
        }
        if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
            shaderloom::packaged::compile_packaged_dxil(PACKAGED_SHADERS, name);
        }
    }
}
