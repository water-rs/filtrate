struct NagaConstants {
    int first_vertex;
    int first_instance;
    uint other;
};
ConstantBuffer<NagaConstants> _NagaConstants: register(b0);

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : LOC0;
};

Texture2D<float4> t_source : register(t0);
SamplerState nagaSamplerHeap[2048]: register(s0, space0);
SamplerComparisonState nagaComparisonSamplerHeap[2048]: register(s2048, space0);
StructuredBuffer<uint> nagaGroup0SamplerIndexArray : register(t1, space0);
static const SamplerState s_source = nagaSamplerHeap[nagaGroup0SamplerIndexArray[0]];

struct FragmentInput_fs_main {
    float2 uv : LOC0;
    float4 position : SV_Position;
};

float4 fs_main(FragmentInput_fs_main fragmentinput_fs_main) : SV_Target0
{
    VertexOutput in_ = { fragmentinput_fs_main.position, fragmentinput_fs_main.uv };
    float4 _e5 = t_source.SampleLevel(s_source, in_.uv, 0.0);
    return _e5;
}
