::shaderloom::CompiledShader::new(
    "src/shaders/shared/blit.wgsl",
    include_str!(
        concat!(env!("CARGO_MANIFEST_DIR"), "/src/shaders/compiled/filter_blit.wgsl")
    ),
    ::shaderloom::include_packaged_spirv!("src/shaders/compiled/filter_blit.spv"),
    ::shaderloom::include_compiled_metallib!("filter_blit.metallib"),
    &[
        ::shaderloom::CompiledEntryPoint {
            name: "vs_main",
            stage: ::shaderloom::ShaderStage::Vertex,
            metal_name: "vs_main",
            workgroup_size: (0, 0, 0),
            dxil: ::shaderloom::include_compiled_dxil!("filter_blit_vertex_vs_main.dxil"),
        },
        ::shaderloom::CompiledEntryPoint {
            name: "fs_main",
            stage: ::shaderloom::ShaderStage::Fragment,
            metal_name: "fs_main",
            workgroup_size: (0, 0, 0),
            dxil: ::shaderloom::include_compiled_dxil!(
                "filter_blit_fragment_fs_main.dxil"
            ),
        },
    ],
    &[
        ::shaderloom::ReflectedBindGroup {
            entries: &[
                ::shaderloom::wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: ::shaderloom::wgpu::ShaderStages::from_bits_retain(2),
                    ty: ::shaderloom::wgpu::BindingType::Texture {
                        sample_type: ::shaderloom::wgpu::TextureSampleType::Float {
                            filterable: true,
                        },
                        view_dimension: ::shaderloom::wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                ::shaderloom::wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: ::shaderloom::wgpu::ShaderStages::from_bits_retain(2),
                    ty: ::shaderloom::wgpu::BindingType::Sampler(
                        ::shaderloom::wgpu::SamplerBindingType::Filtering,
                    ),
                    count: None,
                },
            ],
        },
    ],
)