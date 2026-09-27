# Shaders

`shared/` holds the WGSL sources: the spatial stage pieces are `include_str!`'d
and composed by `src/runtime/shader.rs` at runtime, while `blit.wgsl` and
`multi_input_filter.wgsl` are static and ship pre-translated in `compiled/`
(regenerate with `../package-shaders.sh` at the shaderloom rev pinned in
`Cargo.toml`). Building `filtrate` therefore runs no `naga` on the host; the
build script only invokes `xcrun`/`dxc` on the checked-in translations for
Apple/Windows targets. CI's lint job fails when `compiled/` is stale.
