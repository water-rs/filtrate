#!/usr/bin/env bash
# Regenerate src/shaders/compiled from src/shaders/shared.
# Requires the shaderloom CLI (`cargo install --locked --git
# https://github.com/water-rs/shaderloom --rev <PIN> --features build`, where
# <PIN> is the [patch.crates-io] rev in Cargo.toml).
set -euo pipefail
cd "$(dirname "$0")"
shaderloom wgsl-package src/shaders/shared/blit.wgsl \
    --name filter_blit \
    --label src/shaders/shared/blit.wgsl \
    --out src/shaders/compiled
shaderloom wgsl-package src/shaders/shared/multi_input_filter.wgsl \
    --name multi_input_filter \
    --label src/shaders/shared/multi_input_filter.wgsl \
    --out src/shaders/compiled
