// language: metal1.0
#include <metal_stdlib>
#include <simd/simd.h>

using metal::uint;

struct VertexOutput {
    metal::float4 position;
    metal::float2 uv;
    char _pad2[8];
};
struct type_3 {
    metal::float2 inner[6];
};

struct vs_mainInput {
};
struct vs_mainOutput {
    metal::float4 position [[position]];
    metal::float2 uv [[user(loc0), center_perspective]];
};
vertex vs_mainOutput vs_main(
  uint vertex_index [[vertex_id]]
) {
    type_3 positions = type_3 {{metal::float2(-1.0, -1.0), metal::float2(1.0, -1.0), metal::float2(-1.0, 1.0), metal::float2(-1.0, 1.0), metal::float2(1.0, -1.0), metal::float2(1.0, 1.0)}};
    type_3 uvs = type_3 {{metal::float2(0.0, 1.0), metal::float2(1.0, 1.0), metal::float2(0.0, 0.0), metal::float2(0.0, 0.0), metal::float2(1.0, 1.0), metal::float2(1.0, 0.0)}};
    VertexOutput output = {};
    metal::float2 _e44 = positions.inner[vertex_index];
    output.position = metal::float4(_e44, 0.0, 1.0);
    metal::float2 _e50 = uvs.inner[vertex_index];
    output.uv = _e50;
    VertexOutput _e51 = output;
    const auto _tmp = _e51;
    return vs_mainOutput { _tmp.position, _tmp.uv };
}


struct fs_mainInput {
    metal::float2 uv [[user(loc0), center_perspective]];
};
struct fs_mainOutput {
    metal::float4 member_1 [[color(0)]];
};
fragment fs_mainOutput fs_main(
  fs_mainInput varyings_1 [[stage_in]]
, metal::float4 position [[position]]
, metal::texture2d<float, metal::access::sample> t_source [[texture(0)]]
, metal::sampler s_source [[sampler(0)]]
) {
    const VertexOutput in = { position, varyings_1.uv };
    metal::float4 _e5 = t_source.sample(s_source, in.uv, metal::level(0.0));
    return fs_mainOutput { _e5 };
}
