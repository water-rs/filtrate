//! The blit and multi-input-filter shaders ship pre-translated under
//! `src/shaders/compiled`. This test is the staleness gate: it re-packages
//! the WGSL exactly as `package-shaders.sh` does and asserts the checked-in
//! artifacts match byte for byte. Run `package-shaders.sh` to regenerate
//! after editing a `.wgsl`.

use std::path::Path;

#[test]
fn packaged_shaders_are_current() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let read = |relative: &str| {
        std::fs::read_to_string(manifest_dir.join(relative))
            .unwrap_or_else(|error| panic!("failed to read {relative}: {error}"))
    };
    for (source, artifact) in [
        ("src/shaders/shared/blit.wgsl", "filter_blit"),
        (
            "src/shaders/shared/multi_input_filter.wgsl",
            "multi_input_filter",
        ),
    ] {
        shaderloom::build::package_wgsl(source, &read(source), artifact, "src/shaders/compiled")
            .assert_current(manifest_dir);
    }
}
