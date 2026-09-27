// language: metal1.0
#include <metal_stdlib>
#include <simd/simd.h>

using metal::uint;

struct VertexOutput {
    metal::float4 position;
    metal::float2 uv;
    char _pad2[8];
};
struct type_4 {
    metal::float2 inner[6];
};
struct Uniforms {
    metal::float2 output_size;
    metal::float2 _pad0_;
    metal::float4 op0_;
    metal::float4 op1_;
    metal::float4 op2_;
};

float param(
    uint index,
    constant Uniforms& uniforms
) {
    switch(index) {
        case 0u: {
            float _e4 = uniforms.op0_.y;
            return _e4;
        }
        case 1u: {
            float _e8 = uniforms.op0_.z;
            return _e8;
        }
        case 2u: {
            float _e12 = uniforms.op0_.w;
            return _e12;
        }
        case 3u: {
            float _e16 = uniforms.op1_.x;
            return _e16;
        }
        case 4u: {
            float _e20 = uniforms.op1_.y;
            return _e20;
        }
        case 5u: {
            float _e24 = uniforms.op1_.z;
            return _e24;
        }
        case 6u: {
            float _e28 = uniforms.op1_.w;
            return _e28;
        }
        default: {
            float _e32 = uniforms.op2_.x;
            return _e32;
        }
    }
}

uint naga_f2u32(float value) {
    return static_cast<uint>(metal::clamp(value, 0.0, 4294967000.0));
}

uint op_mode(
    constant Uniforms& uniforms
) {
    float _e3 = uniforms.op0_.x;
    return naga_f2u32(_e3 + 0.5);
}

metal::float4 sample_main(
    metal::float2 uv,
    metal::texture2d<float, metal::access::sample> input_texture,
    metal::sampler input_sampler
) {
    metal::float4 _e4 = input_texture.sample(input_sampler, uv, metal::level(0.0));
    return _e4;
}

metal::float4 sample_aux0_(
    metal::float2 uv_1,
    metal::sampler input_sampler,
    metal::texture2d<float, metal::access::sample> aux_texture_0_
) {
    metal::float4 _e4 = aux_texture_0_.sample(input_sampler, uv_1, metal::level(0.0));
    return _e4;
}

metal::float4 sample_aux1_(
    metal::float2 uv_2,
    metal::sampler input_sampler,
    metal::texture2d<float, metal::access::sample> aux_texture_1_
) {
    metal::float4 _e4 = aux_texture_1_.sample(input_sampler, uv_2, metal::level(0.0));
    return _e4;
}

metal::float3 blend_overlay(
    metal::float3 base,
    metal::float3 top
) {
    metal::float3 low = (2.0 * base) * top;
    metal::float3 high = metal::float3(1.0) - ((2.0 * (metal::float3(1.0) - base)) * (metal::float3(1.0) - top));
    metal::float3 mask = metal::step(metal::float3(0.5), base);
    return metal::mix(low, high, mask);
}

metal::float3 rgb_to_hsl_max_min(
    metal::float3 rgb
) {
    float h = {};
    float max_c = metal::max(metal::max(rgb.x, rgb.y), rgb.z);
    float min_c = metal::min(metal::min(rgb.x, rgb.y), rgb.z);
    float l = (max_c + min_c) * 0.5;
    if (max_c == min_c) {
        return metal::float3(0.0, 0.0, l);
    }
    float d = max_c - min_c;
    float s = (l > 0.5) ? (d / (max_c + min_c)) : (d / ((2.0 - max_c) - min_c));
    if (max_c == rgb.x) {
        h = ((rgb.y - rgb.z) / d) + ((rgb.y < rgb.z) ? 6.0 : 0.0);
    } else {
        if (max_c == rgb.y) {
            h = ((rgb.z - rgb.x) / d) + 2.0;
        } else {
            h = ((rgb.x - rgb.y) / d) + 4.0;
        }
    }
    float _e56 = h;
    return metal::float3(_e56 / 6.0, s, l);
}

float hue_to_rgb_helper(
    float p,
    float q,
    float t_in
) {
    float t = {};
    t = t_in;
    float _e4 = t;
    if (_e4 < 0.0) {
        float _e7 = t;
        t = _e7 + 1.0;
    }
    float _e10 = t;
    if (_e10 > 1.0) {
        float _e13 = t;
        t = _e13 - 1.0;
    }
    float _e16 = t;
    if (_e16 < 0.16666667) {
        float _e22 = t;
        return p + (((q - p) * 6.0) * _e22);
    }
    float _e25 = t;
    if (_e25 < 0.5) {
        return q;
    }
    float _e28 = t;
    if (_e28 < 0.6666667) {
        float _e32 = t;
        return p + (((q - p) * (0.6666667 - _e32)) * 6.0);
    }
    return p;
}

metal::float3 hsl_to_rgb_local(
    metal::float3 hsl
) {
    if (hsl.y == 0.0) {
        return metal::float3(hsl.z);
    }
    float q_1 = (hsl.z < 0.5) ? (hsl.z * (1.0 + hsl.y)) : ((hsl.z + hsl.y) - (hsl.z * hsl.y));
    float p_1 = (2.0 * hsl.z) - q_1;
    float _e29 = hue_to_rgb_helper(p_1, q_1, hsl.x + 0.33333334);
    float _e31 = hue_to_rgb_helper(p_1, q_1, hsl.x);
    float _e35 = hue_to_rgb_helper(p_1, q_1, hsl.x - 0.33333334);
    return metal::float3(_e29, _e31, _e35);
}

metal::float3 blend_hsl(
    metal::float3 base_1,
    metal::float3 top_1,
    bool take_h_top,
    bool take_s_top,
    bool take_l_top
) {
    metal::float3 _e5 = rgb_to_hsl_max_min(base_1);
    metal::float3 _e6 = rgb_to_hsl_max_min(top_1);
    float h_1 = take_h_top ? _e6.x : _e5.x;
    float s_1 = take_s_top ? _e6.y : _e5.y;
    float l_1 = take_l_top ? _e6.z : _e5.z;
    metal::float3 _e17 = hsl_to_rgb_local(metal::float3(h_1, s_1, l_1));
    return _e17;
}

metal::float3 blend_soft_light(
    metal::float3 base_2,
    metal::float3 top_2
) {
    metal::float3 low_1 = base_2 - (((metal::float3(1.0) - (2.0 * top_2)) * base_2) * (metal::float3(1.0) - base_2));
    metal::float3 high_1 = base_2 + (((2.0 * top_2) - metal::float3(1.0)) * (metal::sqrt(metal::max(base_2, metal::float3(0.0))) - base_2));
    metal::float3 mask_1 = metal::step(metal::float3(0.5), top_2);
    return metal::mix(low_1, high_1, mask_1);
}

metal::float3 blend_color(
    metal::float3 base_3,
    metal::float3 top_3,
    uint mode
) {
    switch(mode) {
        case 1u: {
            return base_3 * top_3;
        }
        case 2u: {
            return metal::float3(1.0) - ((metal::float3(1.0) - base_3) * (metal::float3(1.0) - top_3));
        }
        case 3u: {
            metal::float3 _e14 = blend_overlay(base_3, top_3);
            return _e14;
        }
        case 4u: {
            return metal::min(base_3, top_3);
        }
        case 5u: {
            return metal::max(base_3, top_3);
        }
        case 6u: {
            metal::float3 _e17 = blend_soft_light(base_3, top_3);
            return _e17;
        }
        case 7u: {
            metal::float3 _e18 = blend_overlay(top_3, base_3);
            return _e18;
        }
        case 8u: {
            return metal::abs(base_3 - top_3);
        }
        case 9u: {
            return (base_3 + top_3) - ((2.0 * base_3) * top_3);
        }
        case 10u: {
            return base_3 / metal::max(metal::float3(1.0) - top_3, metal::float3(0.0001));
        }
        case 11u: {
            return metal::float3(1.0) - ((metal::float3(1.0) - base_3) / metal::max(top_3, metal::float3(0.0001)));
        }
        case 12u: {
            metal::float3 _e46 = blend_hsl(base_3, top_3, true, false, false);
            return _e46;
        }
        case 13u: {
            metal::float3 _e50 = blend_hsl(base_3, top_3, false, true, false);
            return _e50;
        }
        case 14u: {
            metal::float3 _e54 = blend_hsl(base_3, top_3, true, true, false);
            return _e54;
        }
        case 15u: {
            metal::float3 _e58 = blend_hsl(base_3, top_3, false, false, true);
            return _e58;
        }
        default: {
            return top_3;
        }
    }
}

int naga_neg(int val) {
    return as_type<int>(-as_type<uint>(val));
}

metal::float4 box_blur(
    metal::float2 uv_3,
    int radius,
    metal::texture2d<float, metal::access::sample> input_texture,
    metal::sampler input_sampler,
    constant Uniforms& uniforms
) {
    metal::float4 sum = metal::float4(0.0);
    float count = 0.0;
    int y = {};
    int x = {};
    if (radius <= 0) {
        metal::float4 _e4 = sample_main(uv_3, input_texture, input_sampler);
        return _e4;
    }
    metal::float2 _e7 = uniforms.output_size;
    metal::float2 texel = metal::float2(1.0) / _e7;
    y = naga_neg(radius);
    bool loop_init = true;
    while(true) {
        if (!loop_init) {
            int _e41 = y;
            y = as_type<int>(as_type<uint>(_e41) + as_type<uint>(1));
        }
        loop_init = false;
        int _e18 = y;
        if (_e18 <= radius) {
        } else {
            break;
        }
        {
            x = naga_neg(radius);
            bool loop_init_1 = true;
            while(true) {
                if (!loop_init_1) {
                    int _e38 = x;
                    x = as_type<int>(as_type<uint>(_e38) + as_type<uint>(1));
                }
                loop_init_1 = false;
                int _e22 = x;
                if (_e22 <= radius) {
                } else {
                    break;
                }
                {
                    int _e24 = x;
                    int _e26 = y;
                    metal::float2 sample_uv = uv_3 + (metal::float2(static_cast<float>(_e24), static_cast<float>(_e26)) * texel);
                    metal::float4 _e31 = sum;
                    metal::float4 _e32 = sample_main(sample_uv, input_texture, input_sampler);
                    sum = _e31 + _e32;
                    float _e34 = count;
                    count = _e34 + 1.0;
                }
            }
        }
    }
    metal::float4 _e43 = sum;
    float _e44 = count;
    return _e43 / metal::float4(metal::max(_e44, 1.0));
}

metal::float4 guided_smooth_sample(
    metal::float2 uv_4,
    int radius_1,
    float sigma,
    metal::texture2d<float, metal::access::sample> input_texture,
    metal::sampler input_sampler,
    metal::texture2d<float, metal::access::sample> aux_texture_0_,
    constant Uniforms& uniforms
) {
    metal::float4 weighted_sum = metal::float4(0.0);
    float weight_total = 0.0;
    int y_1 = {};
    int x_1 = {};
    if (radius_1 <= 0) {
        metal::float4 _e5 = sample_main(uv_4, input_texture, input_sampler);
        return _e5;
    }
    metal::float4 _e6 = sample_aux0_(uv_4, input_sampler, aux_texture_0_);
    metal::float3 center_guide = _e6.xyz;
    metal::float2 _e10 = uniforms.output_size;
    metal::float2 texel_1 = metal::float2(1.0) / _e10;
    float inv_sigma = 1.0 / metal::max(sigma, 0.0001);
    y_1 = naga_neg(radius_1);
    bool loop_init_2 = true;
    while(true) {
        if (!loop_init_2) {
            int _e55 = y_1;
            y_1 = as_type<int>(as_type<uint>(_e55) + as_type<uint>(1));
        }
        loop_init_2 = false;
        int _e25 = y_1;
        if (_e25 <= radius_1) {
        } else {
            break;
        }
        {
            x_1 = naga_neg(radius_1);
            bool loop_init_3 = true;
            while(true) {
                if (!loop_init_3) {
                    int _e52 = x_1;
                    x_1 = as_type<int>(as_type<uint>(_e52) + as_type<uint>(1));
                }
                loop_init_3 = false;
                int _e29 = x_1;
                if (_e29 <= radius_1) {
                } else {
                    break;
                }
                {
                    int _e31 = x_1;
                    int _e33 = y_1;
                    metal::float2 sample_uv_1 = uv_4 + (metal::float2(static_cast<float>(_e31), static_cast<float>(_e33)) * texel_1);
                    metal::float4 _e38 = sample_aux0_(sample_uv_1, input_sampler, aux_texture_0_);
                    metal::float3 guide_rgb = _e38.xyz;
                    float diff = metal::length(guide_rgb - center_guide);
                    float weight = metal::exp(-(diff) * inv_sigma);
                    metal::float4 _e45 = weighted_sum;
                    metal::float4 _e46 = sample_main(sample_uv_1, input_texture, input_sampler);
                    weighted_sum = _e45 + (_e46 * weight);
                    float _e49 = weight_total;
                    weight_total = _e49 + weight;
                }
            }
        }
    }
    metal::float4 _e57 = weighted_sum;
    float _e58 = weight_total;
    return _e57 / metal::float4(metal::max(_e58, 0.0001));
}

metal::float4 depth_aware_blur_sample(
    metal::float2 uv_5,
    int radius_2,
    float center_depth,
    metal::texture2d<float, metal::access::sample> input_texture,
    metal::sampler input_sampler,
    metal::texture2d<float, metal::access::sample> aux_texture_0_,
    constant Uniforms& uniforms
) {
    metal::float4 sum_1 = metal::float4(0.0);
    float total_weight = 0.0;
    int y_2 = {};
    int x_2 = {};
    if (radius_2 <= 0) {
        metal::float4 _e5 = sample_main(uv_5, input_texture, input_sampler);
        return _e5;
    }
    metal::float2 _e8 = uniforms.output_size;
    metal::float2 texel_2 = metal::float2(1.0) / _e8;
    y_2 = naga_neg(radius_2);
    bool loop_init_4 = true;
    while(true) {
        if (!loop_init_4) {
            int _e51 = y_2;
            y_2 = as_type<int>(as_type<uint>(_e51) + as_type<uint>(1));
        }
        loop_init_4 = false;
        int _e19 = y_2;
        if (_e19 <= radius_2) {
        } else {
            break;
        }
        {
            x_2 = naga_neg(radius_2);
            bool loop_init_5 = true;
            while(true) {
                if (!loop_init_5) {
                    int _e48 = x_2;
                    x_2 = as_type<int>(as_type<uint>(_e48) + as_type<uint>(1));
                }
                loop_init_5 = false;
                int _e23 = x_2;
                if (_e23 <= radius_2) {
                } else {
                    break;
                }
                {
                    int _e25 = x_2;
                    int _e27 = y_2;
                    metal::float2 sample_uv_2 = uv_5 + (metal::float2(static_cast<float>(_e25), static_cast<float>(_e27)) * texel_2);
                    metal::float4 _e32 = sample_aux0_(sample_uv_2, input_sampler, aux_texture_0_);
                    float sample_depth = _e32.x;
                    float depth_delta = metal::abs(sample_depth - center_depth);
                    float depth_weight = 1.0 - metal::smoothstep(0.0, 0.25, depth_delta);
                    metal::float4 _e41 = sample_main(sample_uv_2, input_texture, input_sampler);
                    metal::float4 _e42 = sum_1;
                    sum_1 = _e42 + (_e41 * depth_weight);
                    float _e45 = total_weight;
                    total_weight = _e45 + depth_weight;
                }
            }
        }
    }
    metal::float4 _e53 = sum_1;
    float _e54 = total_weight;
    return _e53 / metal::float4(metal::max(_e54, 0.0001));
}

metal::float3 lut_texel(
    uint r,
    uint g,
    uint b,
    uint lut_size,
    metal::texture2d<float, metal::access::sample> aux_texture_0_
) {
    metal::uint2 dims = metal::uint2(aux_texture_0_.get_width(0), aux_texture_0_.get_height(0));
    uint x_4 = metal::min((b * lut_size) + r, dims.x - 1u);
    uint y_3 = metal::min(g, dims.y - 1u);
    metal::float4 _e22 = aux_texture_0_.read(metal::uint2(metal::int2(static_cast<int>(x_4), static_cast<int>(y_3))), 0);
    return _e22.xyz;
}

metal::float3 sample_lut_strip(
    metal::float3 color,
    uint lut_size_1,
    metal::texture2d<float, metal::access::sample> aux_texture_0_
) {
    metal::float3 clamped = metal::clamp(color, metal::float3(0.0), metal::float3(1.0));
    float size_f = static_cast<float>(lut_size_1);
    metal::float3 grid = clamped * (size_f - 1.0);
    uint r0_ = naga_f2u32(metal::floor(grid.x));
    uint g0_ = naga_f2u32(metal::floor(grid.y));
    uint b0_ = naga_f2u32(metal::floor(grid.z));
    uint r1_ = metal::min(r0_ + 1u, lut_size_1 - 1u);
    uint g1_ = metal::min(g0_ + 1u, lut_size_1 - 1u);
    uint b1_ = metal::min(b0_ + 1u, lut_size_1 - 1u);
    float fr = grid.x - static_cast<float>(r0_);
    float fg = grid.y - static_cast<float>(g0_);
    float fb = grid.z - static_cast<float>(b0_);
    metal::float3 _e44 = lut_texel(r0_, g0_, b0_, lut_size_1, aux_texture_0_);
    metal::float3 _e45 = lut_texel(r1_, g0_, b0_, lut_size_1, aux_texture_0_);
    metal::float3 _e46 = lut_texel(r0_, g1_, b0_, lut_size_1, aux_texture_0_);
    metal::float3 _e47 = lut_texel(r1_, g1_, b0_, lut_size_1, aux_texture_0_);
    metal::float3 _e48 = lut_texel(r0_, g0_, b1_, lut_size_1, aux_texture_0_);
    metal::float3 _e49 = lut_texel(r1_, g0_, b1_, lut_size_1, aux_texture_0_);
    metal::float3 _e50 = lut_texel(r0_, g1_, b1_, lut_size_1, aux_texture_0_);
    metal::float3 _e51 = lut_texel(r1_, g1_, b1_, lut_size_1, aux_texture_0_);
    metal::float3 c00_ = metal::mix(_e44, _e45, fr);
    metal::float3 c10_ = metal::mix(_e46, _e47, fr);
    metal::float3 c01_ = metal::mix(_e48, _e49, fr);
    metal::float3 c11_ = metal::mix(_e50, _e51, fr);
    metal::float3 c0_ = metal::mix(c00_, c10_, fg);
    metal::float3 c1_ = metal::mix(c01_, c11_, fg);
    return metal::mix(c0_, c1_, fb);
}

float apply_swipe_transition(
    metal::float2 uv_6,
    float progress,
    float softness,
    uint direction
) {
    float edge = {};
    edge = uv_6.x;
    switch(direction) {
        case 1u: {
            edge = 1.0 - uv_6.x;
            break;
        }
        case 2u: {
            edge = uv_6.y;
            break;
        }
        case 3u: {
            edge = 1.0 - uv_6.y;
            break;
        }
        default: {
            break;
        }
    }
    float _e15 = edge;
    return metal::smoothstep(progress - softness, progress + softness, _e15);
}

float apply_radial_transition(
    metal::float2 uv_7,
    float progress_1,
    float softness_1,
    metal::float2 center
) {
    float radius_3 = metal::distance(uv_7, center) * 1.4142135;
    return metal::smoothstep(progress_1 - softness_1, progress_1 + softness_1, radius_3);
}

float apply_tone_curve_channel(
    float x_3,
    float shadows,
    float midtones,
    float highlights,
    float gamma
) {
    float g_1 = metal::pow(metal::clamp(x_3, 0.0, 1.0), 1.0 / metal::max(gamma, 0.001));
    float shadow_weight = (1.0 - g_1) * (1.0 - g_1);
    float highlight_weight = g_1 * g_1;
    float mid_weight = 1.0 - metal::abs((g_1 * 2.0) - 1.0);
    float curved = ((g_1 + (shadows * shadow_weight)) + (midtones * mid_weight)) + (highlights * highlight_weight);
    return metal::clamp(curved, 0.0, 1.0);
}

struct vs_mainInput {
};
struct vs_mainOutput {
    metal::float4 position [[position]];
    metal::float2 uv [[user(loc0), center_perspective]];
};
vertex vs_mainOutput vs_main(
  uint vertex_index [[vertex_id]]
) {
    type_4 positions = type_4 {{metal::float2(-1.0, -1.0), metal::float2(1.0, -1.0), metal::float2(-1.0, 1.0), metal::float2(-1.0, 1.0), metal::float2(1.0, -1.0), metal::float2(1.0, 1.0)}};
    type_4 uvs = type_4 {{metal::float2(0.0, 1.0), metal::float2(1.0, 1.0), metal::float2(0.0, 0.0), metal::float2(0.0, 0.0), metal::float2(1.0, 1.0), metal::float2(1.0, 0.0)}};
    VertexOutput output = {};
    metal::float2 _e44 = positions.inner[vertex_index];
    output.position = metal::float4(_e44, 0.0, 1.0);
    metal::float2 _e50 = uvs.inner[vertex_index];
    output.uv = _e50;
    VertexOutput _e51 = output;
    const auto _tmp = _e51;
    return vs_mainOutput { _tmp.position, _tmp.uv };
}

int naga_f2i32(float value) {
    return static_cast<int>(metal::clamp(value, -2147483600.0, 2147483500.0));
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
, metal::texture2d<float, metal::access::sample> input_texture [[texture(0)]]
, metal::sampler input_sampler [[sampler(0)]]
, metal::texture2d<float, metal::access::sample> aux_texture_0_ [[texture(1)]]
, metal::texture2d<float, metal::access::sample> aux_texture_1_ [[texture(2)]]
, constant Uniforms& uniforms [[buffer(0)]]
) {
    const VertexOutput in = { position, varyings_1.uv };
    metal::float2 uv_8 = in.uv;
    metal::float4 _e2 = sample_main(uv_8, input_texture, input_sampler);
    uint _e3 = op_mode(uniforms);
    switch(_e3) {
        case 0u: {
            float _e5 = param(0u, uniforms);
            uint blend_mode = naga_f2u32(_e5 + 0.5);
            float _e10 = param(1u, uniforms);
            float amount = metal::clamp(_e10, 0.0, 1.0);
            metal::float4 _e14 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            metal::float3 _e17 = blend_color(_e2.xyz, _e14.xyz, blend_mode);
            return fs_mainOutput { metal::float4(metal::mix(_e2.xyz, _e17, amount), _e2.w) };
        }
        case 1u: {
            float _e23 = param(0u, uniforms);
            int radius_4 = naga_f2i32(metal::rint(metal::max(_e23, 0.0)));
            float _e29 = param(1u, uniforms);
            float strength = metal::clamp(_e29, 0.0, 1.0);
            metal::float4 _e33 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            float mask_2 = metal::clamp(_e33.x, 0.0, 1.0);
            metal::float4 _e38 = box_blur(uv_8, radius_4, input_texture, input_sampler, uniforms);
            return fs_mainOutput { metal::mix(_e2, _e38, mask_2 * strength) };
        }
        case 2u: {
            float _e42 = param(0u, uniforms);
            float progress_2 = metal::clamp(_e42, 0.0, 1.0);
            float _e47 = param(1u, uniforms);
            float softness_2 = metal::max(_e47, 0.001);
            float edge_1 = metal::smoothstep(progress_2 - softness_2, progress_2 + softness_2, in.uv.x);
            metal::float4 _e54 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e2, _e54, edge_1) };
        }
        case 3u: {
            float _e57 = param(0u, uniforms);
            float _e59 = param(1u, uniforms);
            metal::float2 scale = metal::float2(_e57, _e59);
            metal::float4 _e61 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            metal::float2 displacement = (_e61.xy * 2.0) - metal::float2(1.0);
            metal::float2 _e71 = uniforms.output_size;
            metal::float2 warped_uv = uv_8 + ((displacement * scale) / _e71);
            metal::float4 _e74 = sample_main(warped_uv, input_texture, input_sampler);
            return fs_mainOutput { _e74 };
        }
        case 4u: {
            float _e76 = param(0u, uniforms);
            int radius_5 = naga_f2i32(metal::rint(metal::max(_e76, 0.0)));
            float _e82 = param(1u, uniforms);
            float sigma_1 = metal::max(_e82, 0.0001);
            float _e86 = param(2u, uniforms);
            float amount_1 = metal::clamp(_e86, 0.0, 1.0);
            metal::float4 _e90 = guided_smooth_sample(uv_8, radius_5, sigma_1, input_texture, input_sampler, aux_texture_0_, uniforms);
            return fs_mainOutput { metal::mix(_e2, _e90, amount_1) };
        }
        case 5u: {
            float _e93 = param(0u, uniforms);
            float focus_depth = metal::clamp(_e93, 0.0, 1.0);
            float _e98 = param(1u, uniforms);
            float aperture = metal::max(_e98, 0.0);
            float _e102 = param(2u, uniforms);
            float max_radius = metal::max(_e102, 0.0);
            metal::float4 _e105 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            float depth = metal::clamp(_e105.x, 0.0, 1.0);
            float coc = (metal::abs(depth - focus_depth) * aperture) * max_radius;
            int radius_6 = naga_f2i32(metal::rint(coc));
            metal::float4 _e116 = depth_aware_blur_sample(uv_8, radius_6, depth, input_texture, input_sampler, aux_texture_0_, uniforms);
            float mix_t = metal::clamp(coc / metal::max(max_radius, 0.0001), 0.0, 1.0);
            return fs_mainOutput { metal::mix(_e2, _e116, mix_t) };
        }
        case 6u: {
            float _e125 = param(0u, uniforms);
            float history_weight = metal::clamp(_e125, 0.0, 0.99);
            metal::float4 _e129 = sample_aux1_(uv_8, input_sampler, aux_texture_1_);
            metal::float2 motion = (_e129.xy * 2.0) - metal::float2(1.0);
            metal::float2 _e138 = uniforms.output_size;
            metal::float2 history_uv = uv_8 - (motion / _e138);
            metal::float4 _e141 = sample_aux0_(history_uv, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e2, _e141, history_weight) };
        }
        case 7u: {
            float _e144 = param(0u, uniforms);
            float edge_softness = metal::max(_e144, 0.0001);
            metal::float4 _e147 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            float matte = metal::clamp(_e147.x, 0.0, 1.0);
            float fg_alpha = metal::smoothstep(0.5 - edge_softness, 0.5 + edge_softness, matte);
            metal::float4 _e157 = sample_aux1_(uv_8, input_sampler, aux_texture_1_);
            return fs_mainOutput { metal::mix(_e157, _e2, fg_alpha) };
        }
        case 8u: {
            float _e160 = param(0u, uniforms);
            uint lut_size_2 = metal::max(naga_f2u32(metal::rint(_e160)), 2u);
            float _e166 = param(1u, uniforms);
            float intensity = metal::clamp(_e166, 0.0, 1.0);
            metal::float3 _e171 = sample_lut_strip(_e2.xyz, lut_size_2, aux_texture_0_);
            return fs_mainOutput { metal::float4(metal::mix(_e2.xyz, _e171, intensity), _e2.w) };
        }
        case 9u: {
            float _e177 = param(0u, uniforms);
            float _e179 = param(1u, uniforms);
            float _e181 = param(2u, uniforms);
            float _e183 = param(3u, uniforms);
            float _e185 = param(4u, uniforms);
            float amount_2 = metal::clamp(_e185, 0.0, 1.0);
            float _e190 = apply_tone_curve_channel(_e2.x, _e177, _e179, _e181, _e183);
            float _e192 = apply_tone_curve_channel(_e2.y, _e177, _e179, _e181, _e183);
            float _e194 = apply_tone_curve_channel(_e2.z, _e177, _e179, _e181, _e183);
            metal::float3 curved_1 = metal::float3(_e190, _e192, _e194);
            return fs_mainOutput { metal::float4(metal::mix(_e2.xyz, curved_1, amount_2), _e2.w) };
        }
        case 10u: {
            float _e201 = param(0u, uniforms);
            float progress_3 = metal::clamp(_e201, 0.0, 1.0);
            float _e206 = param(1u, uniforms);
            float softness_3 = metal::max(_e206, 0.001);
            float _e210 = param(2u, uniforms);
            uint direction_1 = naga_f2u32(_e210 + 0.5);
            float _e214 = apply_swipe_transition(uv_8, progress_3, softness_3, direction_1);
            metal::float4 _e215 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e2, _e215, _e214) };
        }
        case 11u: {
            float _e218 = param(0u, uniforms);
            float progress_4 = metal::clamp(_e218, 0.0, 1.0);
            float _e223 = param(1u, uniforms);
            float softness_4 = metal::max(_e223, 0.001);
            float _e227 = param(2u, uniforms);
            float _e229 = param(3u, uniforms);
            metal::float2 center_1 = metal::float2(_e227, _e229);
            float radius_7 = metal::distance(uv_8, center_1);
            float edge_2 = metal::smoothstep(progress_4 - softness_4, progress_4 + softness_4, radius_7 * 1.4142135);
            metal::float4 _e237 = sample_aux0_(uv_8, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e2, _e237, edge_2) };
        }
        case 12u: {
            float _e240 = param(0u, uniforms);
            float progress_5 = metal::clamp(_e240, 0.0, 1.0);
            float _e245 = param(1u, uniforms);
            float amount_3 = metal::max(_e245, 0.0);
            float _e249 = param(2u, uniforms);
            float _e251 = param(3u, uniforms);
            metal::float2 center_2 = metal::float2(_e249, _e251);
            metal::float2 to_center = center_2 - uv_8;
            metal::float2 source_uv = uv_8 - ((to_center * amount_3) * (1.0 - progress_5));
            metal::float2 target_uv = uv_8 + ((to_center * amount_3) * progress_5);
            metal::float4 _e262 = sample_main(source_uv, input_texture, input_sampler);
            metal::float4 _e263 = sample_aux0_(target_uv, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e262, _e263, progress_5) };
        }
        case 13u: {
            float _e266 = param(0u, uniforms);
            float progress_6 = metal::clamp(_e266, 0.0, 1.0);
            float _e271 = param(1u, uniforms);
            float scale_1 = metal::max(_e271, 0.0);
            metal::float4 _e274 = sample_aux1_(uv_8, input_sampler, aux_texture_1_);
            metal::float2 displacement_1 = (_e274.xy * 2.0) - metal::float2(1.0);
            metal::float2 _e285 = uniforms.output_size;
            metal::float2 source_uv_1 = uv_8 - (((displacement_1 * scale_1) * progress_6) / _e285);
            metal::float2 _e294 = uniforms.output_size;
            metal::float2 target_uv_1 = uv_8 + (((displacement_1 * scale_1) * (1.0 - progress_6)) / _e294);
            metal::float4 _e297 = sample_main(source_uv_1, input_texture, input_sampler);
            metal::float4 _e298 = sample_aux0_(target_uv_1, input_sampler, aux_texture_0_);
            return fs_mainOutput { metal::mix(_e297, _e298, progress_6) };
        }
        default: {
            return fs_mainOutput { _e2 };
        }
    }
}
