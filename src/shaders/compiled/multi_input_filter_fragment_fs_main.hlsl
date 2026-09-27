struct NagaConstants {
    int first_vertex;
    int first_instance;
    uint other;
};
ConstantBuffer<NagaConstants> _NagaConstants: register(b1);

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : LOC0;
};

struct Uniforms {
    float2 output_size;
    float2 _pad0_;
    float4 op0_;
    float4 op1_;
    float4 op2_;
};

Texture2D<float4> input_texture : register(t0);
SamplerState nagaSamplerHeap[2048]: register(s0, space0);
SamplerComparisonState nagaComparisonSamplerHeap[2048]: register(s2048, space0);
StructuredBuffer<uint> nagaGroup0SamplerIndexArray : register(t3, space0);
static const SamplerState input_sampler = nagaSamplerHeap[nagaGroup0SamplerIndexArray[0]];
Texture2D<float4> aux_texture_0_ : register(t1);
Texture2D<float4> aux_texture_1_ : register(t2);
cbuffer uniforms : register(b0) { Uniforms uniforms; }

struct FragmentInput_fs_main {
    float2 uv_8 : LOC0;
    float4 position : SV_Position;
};

float param(uint index)
{
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
    return uint(clamp(value, 0.0, 4294967000.0));
}

uint op_mode()
{
    float _e3 = uniforms.op0_.x;
    return naga_f2u32((_e3 + 0.5));
}

float4 sample_main(float2 uv)
{
    float4 _e4 = input_texture.SampleLevel(input_sampler, uv, 0.0);
    return _e4;
}

float4 sample_aux0_(float2 uv_1)
{
    float4 _e4 = aux_texture_0_.SampleLevel(input_sampler, uv_1, 0.0);
    return _e4;
}

float4 sample_aux1_(float2 uv_2)
{
    float4 _e4 = aux_texture_1_.SampleLevel(input_sampler, uv_2, 0.0);
    return _e4;
}

float3 blend_overlay(float3 base, float3 top)
{
    float3 low = ((2.0 * base) * top);
    float3 high = ((1.0).xxx - ((2.0 * ((1.0).xxx - base)) * ((1.0).xxx - top)));
    float3 mask = step((0.5).xxx, base);
    return lerp(low, high, mask);
}

float3 rgb_to_hsl_max_min(float3 rgb)
{
    float h = (float)0;

    float max_c = max(max(rgb.x, rgb.y), rgb.z);
    float min_c = min(min(rgb.x, rgb.y), rgb.z);
    float l = ((max_c + min_c) * 0.5);
    if ((max_c == min_c)) {
        return float3(0.0, 0.0, l);
    }
    float d = (max_c - min_c);
    float s = ((l > 0.5) ? (d / (max_c + min_c)) : (d / ((2.0 - max_c) - min_c)));
    if ((max_c == rgb.x)) {
        h = (((rgb.y - rgb.z) / d) + ((rgb.y < rgb.z) ? 6.0 : 0.0));
    } else {
        if ((max_c == rgb.y)) {
            h = (((rgb.z - rgb.x) / d) + 2.0);
        } else {
            h = (((rgb.x - rgb.y) / d) + 4.0);
        }
    }
    float _e56 = h;
    return float3((_e56 / 6.0), s, l);
}

float hue_to_rgb_helper(float p, float q, float t_in)
{
    float t = (float)0;

    t = t_in;
    float _e4 = t;
    if ((_e4 < 0.0)) {
        float _e7 = t;
        t = (_e7 + 1.0);
    }
    float _e10 = t;
    if ((_e10 > 1.0)) {
        float _e13 = t;
        t = (_e13 - 1.0);
    }
    float _e16 = t;
    if ((_e16 < 0.16666667)) {
        float _e22 = t;
        return (p + (((q - p) * 6.0) * _e22));
    }
    float _e25 = t;
    if ((_e25 < 0.5)) {
        return q;
    }
    float _e28 = t;
    if ((_e28 < 0.6666667)) {
        float _e32 = t;
        return (p + (((q - p) * (0.6666667 - _e32)) * 6.0));
    }
    return p;
}

float3 hsl_to_rgb_local(float3 hsl)
{
    if ((hsl.y == 0.0)) {
        return (hsl.z).xxx;
    }
    float q_1 = ((hsl.z < 0.5) ? (hsl.z * (1.0 + hsl.y)) : ((hsl.z + hsl.y) - (hsl.z * hsl.y)));
    float p_1 = ((2.0 * hsl.z) - q_1);
    const float _e29 = hue_to_rgb_helper(p_1, q_1, (hsl.x + 0.33333334));
    const float _e31 = hue_to_rgb_helper(p_1, q_1, hsl.x);
    const float _e35 = hue_to_rgb_helper(p_1, q_1, (hsl.x - 0.33333334));
    return float3(_e29, _e31, _e35);
}

float3 blend_hsl(float3 base_1, float3 top_1, bool take_h_top, bool take_s_top, bool take_l_top)
{
    const float3 _e5 = rgb_to_hsl_max_min(base_1);
    const float3 _e6 = rgb_to_hsl_max_min(top_1);
    float h_1 = (take_h_top ? _e6.x : _e5.x);
    float s_1 = (take_s_top ? _e6.y : _e5.y);
    float l_1 = (take_l_top ? _e6.z : _e5.z);
    const float3 _e17 = hsl_to_rgb_local(float3(h_1, s_1, l_1));
    return _e17;
}

float3 blend_soft_light(float3 base_2, float3 top_2)
{
    float3 low_1 = (base_2 - ((((1.0).xxx - (2.0 * top_2)) * base_2) * ((1.0).xxx - base_2)));
    float3 high_1 = (base_2 + (((2.0 * top_2) - (1.0).xxx) * (sqrt(max(base_2, (0.0).xxx)) - base_2)));
    float3 mask_1 = step((0.5).xxx, top_2);
    return lerp(low_1, high_1, mask_1);
}

float3 blend_color(float3 base_3, float3 top_3, uint mode)
{
    switch(mode) {
        case 1u: {
            return (base_3 * top_3);
        }
        case 2u: {
            return ((1.0).xxx - (((1.0).xxx - base_3) * ((1.0).xxx - top_3)));
        }
        case 3u: {
            const float3 _e14 = blend_overlay(base_3, top_3);
            return _e14;
        }
        case 4u: {
            return min(base_3, top_3);
        }
        case 5u: {
            return max(base_3, top_3);
        }
        case 6u: {
            const float3 _e17 = blend_soft_light(base_3, top_3);
            return _e17;
        }
        case 7u: {
            const float3 _e18 = blend_overlay(top_3, base_3);
            return _e18;
        }
        case 8u: {
            return abs((base_3 - top_3));
        }
        case 9u: {
            return ((base_3 + top_3) - ((2.0 * base_3) * top_3));
        }
        case 10u: {
            return (base_3 / max(((1.0).xxx - top_3), (0.0001).xxx));
        }
        case 11u: {
            return ((1.0).xxx - (((1.0).xxx - base_3) / max(top_3, (0.0001).xxx)));
        }
        case 12u: {
            const float3 _e46 = blend_hsl(base_3, top_3, true, false, false);
            return _e46;
        }
        case 13u: {
            const float3 _e50 = blend_hsl(base_3, top_3, false, true, false);
            return _e50;
        }
        case 14u: {
            const float3 _e54 = blend_hsl(base_3, top_3, true, true, false);
            return _e54;
        }
        case 15u: {
            const float3 _e58 = blend_hsl(base_3, top_3, false, false, true);
            return _e58;
        }
        default: {
            return top_3;
        }
    }
}

int naga_neg(int val) {
    return asint(-asuint(val));
}

float4 box_blur(float2 uv_3, int radius)
{
    float4 sum = (0.0).xxxx;
    float count = 0.0;
    int y = (int)0;
    int x = (int)0;

    if ((radius <= int(0))) {
        const float4 _e4 = sample_main(uv_3);
        return _e4;
    }
    float2 _e7 = uniforms.output_size;
    float2 texel = ((1.0).xx / _e7);
    y = naga_neg(radius);
    bool loop_init = true;
    while(true) {
        if (!loop_init) {
            int _e41 = y;
            y = asint(asuint(_e41) + asuint(int(1)));
        }
        loop_init = false;
        int _e18 = y;
        if ((_e18 <= radius)) {
        } else {
            break;
        }
        {
            x = naga_neg(radius);
            bool loop_init_1 = true;
            while(true) {
                if (!loop_init_1) {
                    int _e38 = x;
                    x = asint(asuint(_e38) + asuint(int(1)));
                }
                loop_init_1 = false;
                int _e22 = x;
                if ((_e22 <= radius)) {
                } else {
                    break;
                }
                {
                    int _e24 = x;
                    int _e26 = y;
                    float2 sample_uv = (uv_3 + (float2(float(_e24), float(_e26)) * texel));
                    float4 _e31 = sum;
                    const float4 _e32 = sample_main(sample_uv);
                    sum = (_e31 + _e32);
                    float _e34 = count;
                    count = (_e34 + 1.0);
                }
            }
        }
    }
    float4 _e43 = sum;
    float _e44 = count;
    return (_e43 / (max(_e44, 1.0)).xxxx);
}

float4 guided_smooth_sample(float2 uv_4, int radius_1, float sigma)
{
    float4 weighted_sum = (0.0).xxxx;
    float weight_total = 0.0;
    int y_1 = (int)0;
    int x_1 = (int)0;

    if ((radius_1 <= int(0))) {
        const float4 _e5 = sample_main(uv_4);
        return _e5;
    }
    const float4 _e6 = sample_aux0_(uv_4);
    float3 center_guide = _e6.xyz;
    float2 _e10 = uniforms.output_size;
    float2 texel_1 = ((1.0).xx / _e10);
    float inv_sigma = (1.0 / max(sigma, 0.0001));
    y_1 = naga_neg(radius_1);
    bool loop_init_2 = true;
    while(true) {
        if (!loop_init_2) {
            int _e55 = y_1;
            y_1 = asint(asuint(_e55) + asuint(int(1)));
        }
        loop_init_2 = false;
        int _e25 = y_1;
        if ((_e25 <= radius_1)) {
        } else {
            break;
        }
        {
            x_1 = naga_neg(radius_1);
            bool loop_init_3 = true;
            while(true) {
                if (!loop_init_3) {
                    int _e52 = x_1;
                    x_1 = asint(asuint(_e52) + asuint(int(1)));
                }
                loop_init_3 = false;
                int _e29 = x_1;
                if ((_e29 <= radius_1)) {
                } else {
                    break;
                }
                {
                    int _e31 = x_1;
                    int _e33 = y_1;
                    float2 sample_uv_1 = (uv_4 + (float2(float(_e31), float(_e33)) * texel_1));
                    const float4 _e38 = sample_aux0_(sample_uv_1);
                    float3 guide_rgb = _e38.xyz;
                    float diff = length((guide_rgb - center_guide));
                    float weight = exp((-(diff) * inv_sigma));
                    float4 _e45 = weighted_sum;
                    const float4 _e46 = sample_main(sample_uv_1);
                    weighted_sum = (_e45 + (_e46 * weight));
                    float _e49 = weight_total;
                    weight_total = (_e49 + weight);
                }
            }
        }
    }
    float4 _e57 = weighted_sum;
    float _e58 = weight_total;
    return (_e57 / (max(_e58, 0.0001)).xxxx);
}

float4 depth_aware_blur_sample(float2 uv_5, int radius_2, float center_depth)
{
    float4 sum_1 = (0.0).xxxx;
    float total_weight = 0.0;
    int y_2 = (int)0;
    int x_2 = (int)0;

    if ((radius_2 <= int(0))) {
        const float4 _e5 = sample_main(uv_5);
        return _e5;
    }
    float2 _e8 = uniforms.output_size;
    float2 texel_2 = ((1.0).xx / _e8);
    y_2 = naga_neg(radius_2);
    bool loop_init_4 = true;
    while(true) {
        if (!loop_init_4) {
            int _e51 = y_2;
            y_2 = asint(asuint(_e51) + asuint(int(1)));
        }
        loop_init_4 = false;
        int _e19 = y_2;
        if ((_e19 <= radius_2)) {
        } else {
            break;
        }
        {
            x_2 = naga_neg(radius_2);
            bool loop_init_5 = true;
            while(true) {
                if (!loop_init_5) {
                    int _e48 = x_2;
                    x_2 = asint(asuint(_e48) + asuint(int(1)));
                }
                loop_init_5 = false;
                int _e23 = x_2;
                if ((_e23 <= radius_2)) {
                } else {
                    break;
                }
                {
                    int _e25 = x_2;
                    int _e27 = y_2;
                    float2 sample_uv_2 = (uv_5 + (float2(float(_e25), float(_e27)) * texel_2));
                    const float4 _e32 = sample_aux0_(sample_uv_2);
                    float sample_depth = _e32.x;
                    float depth_delta = abs((sample_depth - center_depth));
                    float depth_weight = (1.0 - smoothstep(0.0, 0.25, depth_delta));
                    const float4 _e41 = sample_main(sample_uv_2);
                    float4 _e42 = sum_1;
                    sum_1 = (_e42 + (_e41 * depth_weight));
                    float _e45 = total_weight;
                    total_weight = (_e45 + depth_weight);
                }
            }
        }
    }
    float4 _e53 = sum_1;
    float _e54 = total_weight;
    return (_e53 / (max(_e54, 0.0001)).xxxx);
}

uint2 NagaMipDimensions2D(Texture2D<float4> tex, uint mip_level)
{
    uint4 ret;
    tex.GetDimensions(mip_level, ret.x, ret.y, ret.z);
    return ret.xy;
}

float3 lut_texel(uint r, uint g, uint b, uint lut_size)
{
    uint2 dims = NagaMipDimensions2D(aux_texture_0_, int(0));
    uint x_4 = min(((b * lut_size) + r), (dims.x - 1u));
    uint y_3 = min(g, (dims.y - 1u));
    float4 _e22 = aux_texture_0_.Load(int3(int2(int(x_4), int(y_3)), int(0)));
    return _e22.xyz;
}

float3 sample_lut_strip(float3 color, uint lut_size_1)
{
    float3 clamped = clamp(color, (0.0).xxx, (1.0).xxx);
    float size_f = float(lut_size_1);
    float3 grid = (clamped * (size_f - 1.0));
    uint r0_ = naga_f2u32(floor(grid.x));
    uint g0_ = naga_f2u32(floor(grid.y));
    uint b0_ = naga_f2u32(floor(grid.z));
    uint r1_ = min((r0_ + 1u), (lut_size_1 - 1u));
    uint g1_ = min((g0_ + 1u), (lut_size_1 - 1u));
    uint b1_ = min((b0_ + 1u), (lut_size_1 - 1u));
    float fr = (grid.x - float(r0_));
    float fg = (grid.y - float(g0_));
    float fb = (grid.z - float(b0_));
    const float3 _e44 = lut_texel(r0_, g0_, b0_, lut_size_1);
    const float3 _e45 = lut_texel(r1_, g0_, b0_, lut_size_1);
    const float3 _e46 = lut_texel(r0_, g1_, b0_, lut_size_1);
    const float3 _e47 = lut_texel(r1_, g1_, b0_, lut_size_1);
    const float3 _e48 = lut_texel(r0_, g0_, b1_, lut_size_1);
    const float3 _e49 = lut_texel(r1_, g0_, b1_, lut_size_1);
    const float3 _e50 = lut_texel(r0_, g1_, b1_, lut_size_1);
    const float3 _e51 = lut_texel(r1_, g1_, b1_, lut_size_1);
    float3 c00_ = lerp(_e44, _e45, fr);
    float3 c10_ = lerp(_e46, _e47, fr);
    float3 c01_ = lerp(_e48, _e49, fr);
    float3 c11_ = lerp(_e50, _e51, fr);
    float3 c0_ = lerp(c00_, c10_, fg);
    float3 c1_ = lerp(c01_, c11_, fg);
    return lerp(c0_, c1_, fb);
}

float apply_swipe_transition(float2 uv_6, float progress, float softness, uint direction)
{
    float edge = (float)0;

    edge = uv_6.x;
    switch(direction) {
        case 1u: {
            edge = (1.0 - uv_6.x);
            break;
        }
        case 2u: {
            edge = uv_6.y;
            break;
        }
        case 3u: {
            edge = (1.0 - uv_6.y);
            break;
        }
        default: {
            break;
        }
    }
    float _e15 = edge;
    return smoothstep((progress - softness), (progress + softness), _e15);
}

float apply_radial_transition(float2 uv_7, float progress_1, float softness_1, float2 center_)
{
    float radius_3 = (distance(uv_7, center_) * 1.4142135);
    return smoothstep((progress_1 - softness_1), (progress_1 + softness_1), radius_3);
}

float apply_tone_curve_channel(float x_3, float shadows, float midtones, float highlights, float gamma)
{
    float g_1 = pow(clamp(x_3, 0.0, 1.0), (1.0 / max(gamma, 0.001)));
    float shadow_weight = ((1.0 - g_1) * (1.0 - g_1));
    float highlight_weight = (g_1 * g_1);
    float mid_weight = (1.0 - abs(((g_1 * 2.0) - 1.0)));
    float curved = (((g_1 + (shadows * shadow_weight)) + (midtones * mid_weight)) + (highlights * highlight_weight));
    return clamp(curved, 0.0, 1.0);
}

int naga_f2i32(float value) {
    return int(clamp(value, -2147483600.0, 2147483500.0));
}

float4 fs_main(FragmentInput_fs_main fragmentinput_fs_main) : SV_Target0
{
    VertexOutput in_ = { fragmentinput_fs_main.position, fragmentinput_fs_main.uv_8 };
    float2 uv_9 = in_.uv;
    const float4 _e2 = sample_main(uv_9);
    const uint _e3 = op_mode();
    switch(_e3) {
        case 0u: {
            const float _e5 = param(0u);
            uint blend_mode = naga_f2u32((_e5 + 0.5));
            const float _e10 = param(1u);
            float amount = clamp(_e10, 0.0, 1.0);
            const float4 _e14 = sample_aux0_(uv_9);
            const float3 _e17 = blend_color(_e2.xyz, _e14.xyz, blend_mode);
            return float4(lerp(_e2.xyz, _e17, amount), _e2.w);
        }
        case 1u: {
            const float _e23 = param(0u);
            int radius_4 = naga_f2i32(round(max(_e23, 0.0)));
            const float _e29 = param(1u);
            float strength = clamp(_e29, 0.0, 1.0);
            const float4 _e33 = sample_aux0_(uv_9);
            float mask_2 = clamp(_e33.x, 0.0, 1.0);
            const float4 _e38 = box_blur(uv_9, radius_4);
            return lerp(_e2, _e38, (mask_2 * strength));
        }
        case 2u: {
            const float _e42 = param(0u);
            float progress_2 = clamp(_e42, 0.0, 1.0);
            const float _e47 = param(1u);
            float softness_2 = max(_e47, 0.001);
            float edge_1 = smoothstep((progress_2 - softness_2), (progress_2 + softness_2), uv_9.x);
            const float4 _e54 = sample_aux0_(uv_9);
            return lerp(_e2, _e54, edge_1);
        }
        case 3u: {
            const float _e57 = param(0u);
            const float _e59 = param(1u);
            float2 scale = float2(_e57, _e59);
            const float4 _e61 = sample_aux0_(uv_9);
            float2 displacement = ((_e61.xy * 2.0) - (1.0).xx);
            float2 _e71 = uniforms.output_size;
            float2 warped_uv = (uv_9 + ((displacement * scale) / _e71));
            const float4 _e74 = sample_main(warped_uv);
            return _e74;
        }
        case 4u: {
            const float _e76 = param(0u);
            int radius_5 = naga_f2i32(round(max(_e76, 0.0)));
            const float _e82 = param(1u);
            float sigma_1 = max(_e82, 0.0001);
            const float _e86 = param(2u);
            float amount_1 = clamp(_e86, 0.0, 1.0);
            const float4 _e90 = guided_smooth_sample(uv_9, radius_5, sigma_1);
            return lerp(_e2, _e90, amount_1);
        }
        case 5u: {
            const float _e93 = param(0u);
            float focus_depth = clamp(_e93, 0.0, 1.0);
            const float _e98 = param(1u);
            float aperture = max(_e98, 0.0);
            const float _e102 = param(2u);
            float max_radius = max(_e102, 0.0);
            const float4 _e105 = sample_aux0_(uv_9);
            float depth = clamp(_e105.x, 0.0, 1.0);
            float coc = ((abs((depth - focus_depth)) * aperture) * max_radius);
            int radius_6 = naga_f2i32(round(coc));
            const float4 _e116 = depth_aware_blur_sample(uv_9, radius_6, depth);
            float mix_t = clamp((coc / max(max_radius, 0.0001)), 0.0, 1.0);
            return lerp(_e2, _e116, mix_t);
        }
        case 6u: {
            const float _e125 = param(0u);
            float history_weight = clamp(_e125, 0.0, 0.99);
            const float4 _e129 = sample_aux1_(uv_9);
            float2 motion = ((_e129.xy * 2.0) - (1.0).xx);
            float2 _e138 = uniforms.output_size;
            float2 history_uv = (uv_9 - (motion / _e138));
            const float4 _e141 = sample_aux0_(history_uv);
            return lerp(_e2, _e141, history_weight);
        }
        case 7u: {
            const float _e144 = param(0u);
            float edge_softness = max(_e144, 0.0001);
            const float4 _e147 = sample_aux0_(uv_9);
            float matte = clamp(_e147.x, 0.0, 1.0);
            float fg_alpha = smoothstep((0.5 - edge_softness), (0.5 + edge_softness), matte);
            const float4 _e157 = sample_aux1_(uv_9);
            return lerp(_e157, _e2, fg_alpha);
        }
        case 8u: {
            const float _e160 = param(0u);
            uint lut_size_2 = max(naga_f2u32(round(_e160)), 2u);
            const float _e166 = param(1u);
            float intensity = clamp(_e166, 0.0, 1.0);
            const float3 _e171 = sample_lut_strip(_e2.xyz, lut_size_2);
            return float4(lerp(_e2.xyz, _e171, intensity), _e2.w);
        }
        case 9u: {
            const float _e177 = param(0u);
            const float _e179 = param(1u);
            const float _e181 = param(2u);
            const float _e183 = param(3u);
            const float _e185 = param(4u);
            float amount_2 = clamp(_e185, 0.0, 1.0);
            const float _e190 = apply_tone_curve_channel(_e2.x, _e177, _e179, _e181, _e183);
            const float _e192 = apply_tone_curve_channel(_e2.y, _e177, _e179, _e181, _e183);
            const float _e194 = apply_tone_curve_channel(_e2.z, _e177, _e179, _e181, _e183);
            float3 curved_1 = float3(_e190, _e192, _e194);
            return float4(lerp(_e2.xyz, curved_1, amount_2), _e2.w);
        }
        case 10u: {
            const float _e201 = param(0u);
            float progress_3 = clamp(_e201, 0.0, 1.0);
            const float _e206 = param(1u);
            float softness_3 = max(_e206, 0.001);
            const float _e210 = param(2u);
            uint direction_1 = naga_f2u32((_e210 + 0.5));
            const float _e214 = apply_swipe_transition(uv_9, progress_3, softness_3, direction_1);
            const float4 _e215 = sample_aux0_(uv_9);
            return lerp(_e2, _e215, _e214);
        }
        case 11u: {
            const float _e218 = param(0u);
            float progress_4 = clamp(_e218, 0.0, 1.0);
            const float _e223 = param(1u);
            float softness_4 = max(_e223, 0.001);
            const float _e227 = param(2u);
            const float _e229 = param(3u);
            float2 center_1 = float2(_e227, _e229);
            float radius_7 = distance(uv_9, center_1);
            float edge_2 = smoothstep((progress_4 - softness_4), (progress_4 + softness_4), (radius_7 * 1.4142135));
            const float4 _e237 = sample_aux0_(uv_9);
            return lerp(_e2, _e237, edge_2);
        }
        case 12u: {
            const float _e240 = param(0u);
            float progress_5 = clamp(_e240, 0.0, 1.0);
            const float _e245 = param(1u);
            float amount_3 = max(_e245, 0.0);
            const float _e249 = param(2u);
            const float _e251 = param(3u);
            float2 center_2 = float2(_e249, _e251);
            float2 to_center = (center_2 - uv_9);
            float2 source_uv = (uv_9 - ((to_center * amount_3) * (1.0 - progress_5)));
            float2 target_uv = (uv_9 + ((to_center * amount_3) * progress_5));
            const float4 _e262 = sample_main(source_uv);
            const float4 _e263 = sample_aux0_(target_uv);
            return lerp(_e262, _e263, progress_5);
        }
        case 13u: {
            const float _e266 = param(0u);
            float progress_6 = clamp(_e266, 0.0, 1.0);
            const float _e271 = param(1u);
            float scale_1 = max(_e271, 0.0);
            const float4 _e274 = sample_aux1_(uv_9);
            float2 displacement_1 = ((_e274.xy * 2.0) - (1.0).xx);
            float2 _e285 = uniforms.output_size;
            float2 source_uv_1 = (uv_9 - (((displacement_1 * scale_1) * progress_6) / _e285));
            float2 _e294 = uniforms.output_size;
            float2 target_uv_1 = (uv_9 + (((displacement_1 * scale_1) * (1.0 - progress_6)) / _e294));
            const float4 _e297 = sample_main(source_uv_1);
            const float4 _e298 = sample_aux0_(target_uv_1);
            return lerp(_e297, _e298, progress_6);
        }
        default: {
            return _e2;
        }
    }
}
