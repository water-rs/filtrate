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

struct VertexOutput_vs_main {
    float2 uv : LOC0;
    float4 position : SV_Position;
};

typedef float2 ret_Constructarray6_float2_[6];
ret_Constructarray6_float2_ Constructarray6_float2_(float2 arg0, float2 arg1, float2 arg2, float2 arg3, float2 arg4, float2 arg5) {
    float2 ret[6] = { arg0, arg1, arg2, arg3, arg4, arg5 };
    return ret;
}

VertexOutput_vs_main vs_main(uint vertex_index : SV_VertexID)
{
    float2 positions[6] = Constructarray6_float2_(float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0, 1.0), float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0));
    float2 uvs[6] = Constructarray6_float2_(float2(0.0, 1.0), float2(1.0, 1.0), float2(0.0, 0.0), float2(0.0, 0.0), float2(1.0, 1.0), float2(1.0, 0.0));
    VertexOutput output = (VertexOutput)0;

    float2 _e44 = positions[(_NagaConstants.first_vertex + vertex_index)];
    output.position = float4(_e44, 0.0, 1.0);
    float2 _e50 = uvs[(_NagaConstants.first_vertex + vertex_index)];
    output.uv = _e50;
    VertexOutput _e51 = output;
    const VertexOutput vertexoutput = _e51;
    const VertexOutput_vs_main vertexoutput_1 = { vertexoutput.uv, vertexoutput.position };
    return vertexoutput_1;
}

