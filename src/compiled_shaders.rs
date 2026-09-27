use shaderloom::CompiledShader;

pub const BLIT: CompiledShader = include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/src/shaders/compiled/filter_blit.rs"
));
pub const MULTI_INPUT: CompiledShader = include!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/src/shaders/compiled/multi_input_filter.rs"
));
