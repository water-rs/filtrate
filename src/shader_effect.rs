//! Application-supplied WGSL post-processing.
//!
//! [`ShaderEffect`] runs one fragment shader the application writes over the
//! effect's input texture — the captured content of whatever the host applies
//! it to. It is the effect a terminal's custom shader, a CRT or scanline pass,
//! or an animated distortion is built from: the shader samples the input, reads
//! the frame time, the resolution and its own parameters, and writes the
//! output pixel.
//!
//! # Shader contract
//!
//! The application supplies a WGSL module that defines a fragment entry point
//! named `main`. The effect appends a prelude to that module, so the module can
//! use these declarations without writing them:
//!
//! ```wgsl
//! struct ShaderEffectUniforms {
//!     resolution: vec2<f32>,       // output size in physical pixels
//!     input_resolution: vec2<f32>, // input size in physical pixels
//!     time: f32,                   // seconds on the host frame timeline
//!     time_delta: f32,             // seconds since the previous frame
//!     frame: u32,                  // frame number
//!     param_count: u32,            // parameters added with `ShaderEffect::param`
//!     params: array<vec4<f32>, 4>, // the parameters, four per vector
//! }
//! @group(0) @binding(0) var input_texture: texture_2d<f32>;
//! @group(0) @binding(1) var input_sampler: sampler;
//! @group(0) @binding(2) var<uniform> uniforms: ShaderEffectUniforms;
//! fn effect_param(index: u32) -> f32;
//!
//! struct VertexOutput {
//!     @builtin(position) position: vec4<f32>, // output pixel, top-left origin
//!     @location(0) uv: vec2<f32>,            // (0, 0) top-left, (1, 1) bottom-right
//! }
//! ```
//!
//! Those names, and the vertex entry point `shader_effect_vs`, are reserved.
//! `uv` addresses the input texture directly, so
//! `textureSample(input_texture, input_sampler, uv)` reads the pixel under the
//! fragment. The input carries premultiplied alpha and the output is expected
//! to as well (see [`crate::effect`]).
//!
//! ```rust
//! use filtrate::ShaderEffect;
//!
//! let scanlines = ShaderEffect::new(
//!     r"
//!     @fragment
//!     fn main(in: VertexOutput) -> @location(0) vec4<f32> {
//!         let color = textureSample(input_texture, input_sampler, in.uv);
//!         let row = u32(in.position.y) + u32(uniforms.time * 4.0);
//!         let line = select(1.0, 0.0, (row / 2u) % 2u == 1u);
//!         return vec4<f32>(color.rgb * mix(1.0, line, effect_param(0u)), color.a);
//!     }
//!     ",
//! )
//! .expect("the scanline shader is valid WGSL")
//! .param(0.35)
//! .animated();
//! # let _ = scanlines;
//! ```
//!
//! # Errors surface at construction
//!
//! [`ShaderEffect::new`] parses and validates the module on the CPU and
//! returns a [`ShaderEffectError`] carrying the full diagnostic when the WGSL
//! is malformed, fails validation, or lacks the `main` fragment entry point.
//! Applications that load shaders at run time (from a user's configuration
//! file, say) handle the error where they read the file; no invalid shader
//! ever reaches a host.
//!
//! # Redraw
//!
//! A shader that reads `uniforms.time` changes with every frame, and says so
//! with [`ShaderEffect::animated`]: the effect then asks its host for another
//! frame after each one it renders. A shader that does not animate is rendered
//! only when its input or one of its parameters changes. Reactive parameters
//! ([`ShaderEffect::watch_param`]) wake the host through the effect's redraw
//! callback and animate along their interpolators exactly like built-in filter
//! parameters.
//!
//! # Threading
//!
//! The effect is `Send` on native targets: the compiled pipeline and the
//! parameter tracks move to whichever thread encodes GPU work, and
//! [`Effect::encode_render`] records into the host's shared command encoder.
//! Reactive subscriptions stay with the caller (see
//! [`ShaderEffect::watch_param`]).

extern crate alloc;

use alloc::borrow::Cow;
use alloc::string::String;
use alloc::vec::Vec;
use core::fmt;

use filtrate_core::{FilterParam, WatchGuard};

use crate::Effect;
use crate::effect::{
    EffectContext, EffectInput, EffectOutput, EffectRedrawCallback, EffectRenderError,
    EffectRenderResult, EffectSetupError, EffectSetupResult,
};
use crate::runtime::animation::ParamAnimator;
use crate::runtime::is_filterable_texture_format;

/// Maximum number of parameters one [`ShaderEffect`] carries.
pub const SHADER_EFFECT_MAX_PARAMS: usize = 16;

const PARAM_VEC4S: usize = SHADER_EFFECT_MAX_PARAMS / 4;

/// The fragment entry point the application's module defines.
const FRAGMENT_ENTRY_POINT: &str = "main";
/// The vertex entry point the prelude defines.
const VERTEX_ENTRY_POINT: &str = "shader_effect_vs";

const PRELUDE: &str = include_str!(concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/src/shaders/shared/shader_effect_prelude.wgsl"
));

/// Why an application's WGSL cannot become a [`ShaderEffect`].
///
/// Each message carries naga's rendered diagnostic, with line and column
/// numbers counted in the application's own source.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ShaderEffectError {
    /// The source is not well-formed WGSL.
    #[error("shader effect WGSL failed to parse:\n{0}")]
    Parse(String),
    /// The source parsed but is not a valid WGSL module.
    #[error("shader effect WGSL failed validation:\n{0}")]
    Validation(String),
    /// The module declares no `@fragment fn main`.
    #[error("shader effect WGSL declares no `@fragment fn main` entry point")]
    MissingEntryPoint,
}

/// `ShaderEffectUniforms` in the prelude, byte for byte.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, bytemuck::Pod, bytemuck::Zeroable)]
struct ShaderEffectUniforms {
    resolution: [f32; 2],
    input_resolution: [f32; 2],
    time: f32,
    time_delta: f32,
    frame: u32,
    param_count: u32,
    params: [[f32; 4]; PARAM_VEC4S],
}

/// GPU objects built in [`Effect::setup`].
struct ShaderEffectResources {
    input_format: wgpu::TextureFormat,
    output_format: wgpu::TextureFormat,
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
    sampler: wgpu::Sampler,
    uniform_buffer: wgpu::Buffer,
    /// The bind group for the input view it was made with; rebuilt only when
    /// the host hands in a different input texture.
    bind_group: Option<(wgpu::TextureView, wgpu::BindGroup)>,
}

/// An application-supplied WGSL fragment shader run over the effect input.
///
/// See the [module documentation](self) for the shader contract.
pub struct ShaderEffect {
    /// The application's module with the prelude appended.
    source: String,
    /// Parameter tracks and the channel reactive parameters feed. It holds no
    /// subscription, which keeps the effect `Send`.
    animator: ParamAnimator,
    animated: bool,
    resources: Option<ShaderEffectResources>,
}

impl fmt::Debug for ShaderEffect {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ShaderEffect")
            .field("params", &self.animator.param_count())
            .field("animated", &self.animated)
            .finish_non_exhaustive()
    }
}

impl ShaderEffect {
    /// Validates `source` and builds an effect that runs its `main` fragment
    /// entry point over the input.
    ///
    /// # Errors
    ///
    /// Returns [`ShaderEffectError`] when `source` does not parse, does not
    /// validate together with the prelude, or declares no `@fragment fn main`.
    pub fn new(source: impl Into<Cow<'static, str>>) -> Result<Self, ShaderEffectError> {
        let source = source.into();
        let mut full = String::with_capacity(source.len() + PRELUDE.len() + 1);
        full.push_str(&source);
        full.push('\n');
        full.push_str(PRELUDE);
        let module = parse_and_validate(&full)?;
        let has_main = module.entry_points.iter().any(|entry_point| {
            entry_point.name == FRAGMENT_ENTRY_POINT
                && entry_point.stage == naga::ShaderStage::Fragment
        });
        if !has_main {
            return Err(ShaderEffectError::MissingEntryPoint);
        }
        let (animator, _) = ParamAnimator::new(Vec::new(), |_| {});
        Ok(Self {
            source: full,
            animator,
            animated: false,
            resources: None,
        })
    }

    /// Adds a constant parameter, readable in the shader as `effect_param(n)`
    /// where `n` counts the parameters added before it.
    ///
    /// # Panics
    ///
    /// Panics when the effect already carries [`SHADER_EFFECT_MAX_PARAMS`]
    /// parameters.
    #[must_use]
    pub fn param(mut self, value: f32) -> Self {
        self.push_param(value);
        self
    }

    /// Adds a reactive parameter, readable in the shader as `effect_param(n)`
    /// where `n` counts the parameters added before it.
    ///
    /// The effect starts from `param`'s current value; each change `param`
    /// reports re-renders the effect and follows the animation attached to
    /// the change. The returned guard is the subscription: the caller keeps
    /// it for as long as `param` should drive the effect. Holding it outside
    /// the effect keeps [`ShaderEffect`] `Send` while a reactive frontend's
    /// subscription, which is commonly not `Send`, stays on the frontend's
    /// thread.
    ///
    /// # Panics
    ///
    /// Panics when the effect already carries [`SHADER_EFFECT_MAX_PARAMS`]
    /// parameters.
    #[must_use]
    pub fn watch_param<P: FilterParam + ?Sized>(mut self, param: &P) -> (Self, WatchGuard) {
        let index = self.push_param(param.snapshot());
        let guard = self.animator.sender().watch(index, param);
        (self, guard)
    }

    /// The number of parameters added so far.
    #[must_use]
    pub const fn param_count(&self) -> usize {
        self.animator.param_count()
    }

    fn push_param(&mut self, initial: f32) -> usize {
        assert!(
            self.animator.param_count() < SHADER_EFFECT_MAX_PARAMS,
            "a ShaderEffect carries at most {SHADER_EFFECT_MAX_PARAMS} parameters"
        );
        self.animator.push_param(initial)
    }

    /// Marks the shader as time-driven: after every frame it renders, the
    /// effect asks its host for another one.
    #[must_use]
    pub const fn animated(mut self) -> Self {
        self.animated = true;
        self
    }

    fn create_bind_group_layout(device: &wgpu::Device, filterable: bool) -> wgpu::BindGroupLayout {
        device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("shader effect bind group layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(if filterable {
                        wgpu::SamplerBindingType::Filtering
                    } else {
                        wgpu::SamplerBindingType::NonFiltering
                    }),
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: wgpu::BufferSize::new(core::mem::size_of::<
                            ShaderEffectUniforms,
                        >() as u64),
                    },
                    count: None,
                },
            ],
        })
    }

    fn uniforms(&self, input: &EffectInput, output: &EffectOutput) -> ShaderEffectUniforms {
        let mut params = [[0.0; 4]; PARAM_VEC4S];
        for (index, value) in self.animator.current_values().iter().enumerate() {
            params[index / 4][index % 4] = *value;
        }
        ShaderEffectUniforms {
            resolution: [u32_to_f32(output.width), u32_to_f32(output.height)],
            input_resolution: [u32_to_f32(input.width), u32_to_f32(input.height)],
            time: input.timing.presentation_time().as_secs_f32(),
            time_delta: input.timing.delta().as_secs_f32(),
            // The shader sees the frame number modulo 2^32; a wrap after
            // years of continuous frames is the intended behavior.
            #[expect(
                clippy::cast_possible_truncation,
                reason = "the WGSL frame counter is a wrapping u32"
            )]
            frame: input.timing.sequence() as u32,
            param_count: u32::try_from(self.animator.param_count())
                .expect("the parameter count is bounded by SHADER_EFFECT_MAX_PARAMS"),
            params,
        }
    }
}

/// Parses and validates a complete effect module, rendering naga's diagnostic
/// against `source` on failure.
fn parse_and_validate(source: &str) -> Result<naga::Module, ShaderEffectError> {
    let module = naga::front::wgsl::parse_str(source)
        .map_err(|error| ShaderEffectError::Parse(error.emit_to_string(source)))?;
    naga::valid::Validator::new(
        naga::valid::ValidationFlags::all(),
        naga::valid::Capabilities::default(),
    )
    .validate(&module)
    .map_err(|error| ShaderEffectError::Validation(error.emit_to_string(source)))?;
    Ok(module)
}

#[expect(
    clippy::cast_precision_loss,
    reason = "texture dimensions are far below f32's exact integer range"
)]
const fn u32_to_f32(value: u32) -> f32 {
    value as f32
}

impl Effect for ShaderEffect {
    fn set_redraw_callback(&mut self, callback: EffectRedrawCallback) {
        self.animator.install_redraw_callback(callback);
    }

    async fn setup(&mut self, ctx: &EffectContext<'_>) -> EffectSetupResult {
        let filterable = is_filterable_texture_format(ctx.input_format);
        let module = ctx
            .shader_cache
            .module(ctx.device, Some("shader effect"), &self.source);
        let bind_group_layout = Self::create_bind_group_layout(ctx.device, filterable);

        let error_scope = ctx.device.push_error_scope(wgpu::ErrorFilter::Validation);
        let pipeline_layout = ctx
            .device
            .create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("shader effect pipeline layout"),
                bind_group_layouts: &[Some(&bind_group_layout)],
                immediate_size: 0,
            });
        let pipeline = ctx
            .device
            .create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some("shader effect pipeline"),
                layout: Some(&pipeline_layout),
                vertex: wgpu::VertexState {
                    module: &module,
                    entry_point: Some(VERTEX_ENTRY_POINT),
                    buffers: &[],
                    compilation_options: wgpu::PipelineCompilationOptions::default(),
                },
                fragment: Some(wgpu::FragmentState {
                    module: &module,
                    entry_point: Some(FRAGMENT_ENTRY_POINT),
                    targets: &[Some(wgpu::ColorTargetState {
                        format: ctx.output_format,
                        blend: None,
                        write_mask: wgpu::ColorWrites::ALL,
                    })],
                    compilation_options: wgpu::PipelineCompilationOptions::default(),
                }),
                primitive: wgpu::PrimitiveState {
                    topology: wgpu::PrimitiveTopology::TriangleList,
                    ..Default::default()
                },
                depth_stencil: None,
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            });
        if let Some(error) = error_scope.pop().await {
            let message = alloc::format!("{error}");
            tracing::error!("[Filter] shader effect pipeline validation error: {message}");
            return Err(EffectSetupError::PipelineValidation {
                stage: "shader effect",
                message,
            });
        }

        let filter_mode = if filterable {
            wgpu::FilterMode::Linear
        } else {
            wgpu::FilterMode::Nearest
        };
        let sampler = ctx.device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("shader effect sampler"),
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            address_mode_w: wgpu::AddressMode::ClampToEdge,
            mag_filter: filter_mode,
            min_filter: filter_mode,
            mipmap_filter: wgpu::MipmapFilterMode::Nearest,
            ..Default::default()
        });
        let uniform_buffer = ctx.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("shader effect uniforms"),
            size: core::mem::size_of::<ShaderEffectUniforms>() as wgpu::BufferAddress,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        self.resources = Some(ShaderEffectResources {
            input_format: ctx.input_format,
            output_format: ctx.output_format,
            pipeline,
            bind_group_layout,
            sampler,
            uniform_buffer,
            bind_group: None,
        });
        self.animator.ensure_redraw_callback();
        self.animator.apply_targets_to_current();
        Ok(())
    }

    fn encode_render(
        &mut self,
        input: &EffectInput,
        output: &EffectOutput,
        encoder: &mut wgpu::CommandEncoder,
    ) -> EffectRenderResult {
        let parameters_animating = self.animator.update(input.timing.delta());
        let uniforms = self.uniforms(input, output);
        let Some(resources) = self.resources.as_mut() else {
            return Err(EffectRenderError::MissingResource(
                "shader effect rendered before setup",
            ));
        };
        if input.format != resources.input_format || output.format != resources.output_format {
            return Err(EffectRenderError::FormatMismatch {
                input: input.format,
                output: output.format,
                setup_input: resources.input_format,
                setup_output: resources.output_format,
            });
        }

        input
            .queue
            .write_buffer(&resources.uniform_buffer, 0, bytemuck::bytes_of(&uniforms));
        if resources
            .bind_group
            .as_ref()
            .is_none_or(|(view, _)| *view != input.view)
        {
            let bind_group = input.device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("shader effect bind group"),
                layout: &resources.bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: wgpu::BindingResource::TextureView(&input.view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::Sampler(&resources.sampler),
                    },
                    wgpu::BindGroupEntry {
                        binding: 2,
                        resource: resources.uniform_buffer.as_entire_binding(),
                    },
                ],
            });
            resources.bind_group = Some((input.view.clone(), bind_group));
        }
        let (_, bind_group) = resources
            .bind_group
            .as_ref()
            .expect("the shader effect bind group was just made");

        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("shader effect pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &output.view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });
            pass.set_pipeline(&resources.pipeline);
            pass.set_bind_group(0, bind_group, &[]);
            pass.draw(0..6, 0..1);
        }

        self.animator.mark_rendered();
        Ok(self.animated || parameters_animating)
    }

    fn redraw_hint(&self) -> bool {
        self.animated || self.animator.redraw_hint()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const PASS_THROUGH: &str = "
        @fragment
        fn main(in: VertexOutput) -> @location(0) vec4<f32> {
            return textureSample(input_texture, input_sampler, in.uv);
        }
    ";

    /// The Rust uniform block must match the prelude's struct byte for byte,
    /// or every field after the first mismatch reads garbage on the GPU.
    #[test]
    fn uniform_block_matches_the_prelude_layout() {
        let module = parse_and_validate(PRELUDE).expect("the prelude is valid WGSL on its own");
        let mut layouter = naga::proc::Layouter::default();
        layouter
            .update(module.to_ctx())
            .expect("the prelude's types lay out");
        let (handle, _) = module
            .types
            .iter()
            .find(|(_, ty)| ty.name.as_deref() == Some("ShaderEffectUniforms"))
            .expect("the prelude declares ShaderEffectUniforms");
        assert_eq!(
            layouter[handle].size as usize,
            core::mem::size_of::<ShaderEffectUniforms>()
        );
    }

    /// Hosts that move effects to their GPU thread take `Send` effects.
    #[cfg(not(target_family = "wasm"))]
    #[test]
    fn a_shader_effect_is_send() {
        const fn assert_send<T: Send>() {}
        assert_send::<ShaderEffect>();
    }

    #[test]
    fn a_valid_module_builds() {
        ShaderEffect::new(PASS_THROUGH).expect("pass-through shader is valid");
    }

    #[test]
    fn malformed_wgsl_is_a_parse_error_on_the_application_line() {
        let error = ShaderEffect::new("@fragment\nfn main( -> {}").expect_err("malformed WGSL");
        let ShaderEffectError::Parse(message) = error else {
            panic!("expected a parse error, got {error:?}");
        };
        assert!(
            message.contains(":2:"),
            "the diagnostic points at the application's line 2: {message}"
        );
    }

    #[test]
    fn an_ill_typed_module_is_a_validation_error() {
        let error = ShaderEffect::new(
            "@fragment
            fn main(in: VertexOutput) -> @location(0) vec4<f32> {
                return textureSample(input_texture, input_sampler, 1.0);
            }",
        )
        .expect_err("sampling with a scalar coordinate is invalid");
        assert!(
            matches!(
                error,
                ShaderEffectError::Parse(_) | ShaderEffectError::Validation(_)
            ),
            "got {error:?}"
        );
    }

    #[test]
    fn a_module_without_main_is_rejected() {
        let error = ShaderEffect::new(
            "@fragment
            fn shade(in: VertexOutput) -> @location(0) vec4<f32> {
                return vec4<f32>(in.uv, 0.0, 1.0);
            }",
        )
        .expect_err("no main entry point");
        assert_eq!(error, ShaderEffectError::MissingEntryPoint);
    }

    #[test]
    #[should_panic(expected = "at most 16 parameters")]
    fn parameters_are_bounded_by_the_uniform_block() {
        let mut effect = ShaderEffect::new(PASS_THROUGH).expect("valid");
        for value in 0..=SHADER_EFFECT_MAX_PARAMS {
            #[expect(clippy::cast_precision_loss, reason = "small test indices")]
            let value = value as f32;
            effect = effect.param(value);
        }
    }
}
