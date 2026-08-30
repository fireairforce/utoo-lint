import React, { useEffect, useRef, useState } from 'react';

const logoShader = /* wgsl */ `
struct Uniforms {
  viewport: vec4f,
}

@group(0) @binding(0) var logoTexture: texture_2d<f32>;
@group(0) @binding(1) var logoSampler: sampler;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@vertex
fn vertexMain(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4f {
  var positions = array<vec2f, 3>(
    vec2f(-1.0, -1.0),
    vec2f(3.0, -1.0),
    vec2f(-1.0, 3.0),
  );

  return vec4f(positions[vertexIndex], 0.0, 1.0);
}

fn unitMask(point: vec2f) -> f32 {
  return step(0.0, point.x) * step(0.0, point.y) *
    step(point.x, 1.0) * step(point.y, 1.0);
}

fn paddedMask(point: vec2f, padding: f32) -> f32 {
  return step(-padding, point.x) * step(-padding, point.y) *
    step(point.x, 1.0 + padding) * step(point.y, 1.0 + padding);
}

fn markAlpha(logoUv: vec2f) -> f32 {
  return textureSample(
    logoTexture,
    logoSampler,
    clamp(logoUv, vec2f(0.0), vec2f(1.0)),
  ).a * unitMask(logoUv);
}

fn ringAlpha(logoUv: vec2f, radius: f32) -> f32 {
  var value = 0.0;
  value += markAlpha(logoUv + vec2f(radius, 0.0));
  value += markAlpha(logoUv + vec2f(-radius, 0.0));
  value += markAlpha(logoUv + vec2f(0.0, radius));
  value += markAlpha(logoUv + vec2f(0.0, -radius));
  return value * 0.25;
}

@fragment
fn fragmentMain(@builtin(position) position: vec4f) -> @location(0) vec4f {
  let resolution = max(uniforms.viewport.xy, vec2f(1.0));
  let time = uniforms.viewport.z;
  let motion = uniforms.viewport.w;
  let uv = position.xy / resolution;
  let aspect = resolution.x / resolution.y;

  let logoHeight = 0.73;
  let logoWidth = logoHeight * 0.6992 / aspect;
  let logoOrigin = vec2f(0.5 - logoWidth * 0.5, 0.5 - logoHeight * 0.5);
  let logoUv = (uv - logoOrigin) / vec2f(logoWidth, logoHeight);
  if (paddedMask(logoUv, 0.06) < 0.5) {
    return vec4f(0.0);
  }

  let cycle = fract(time / 12.0);
  let scanEnvelope = smoothstep(0.0, 0.018, cycle) *
    (1.0 - smoothstep(0.185, 0.225, cycle)) * motion;
  let scanProgress = smoothstep(0.01, 0.205, cycle);
  let scanPosition = -0.16 + scanProgress * 1.32;
  let scanDistance = abs(logoUv.y - scanPosition);
  let scanGlow = exp(-scanDistance * 26.0) * scanEnvelope * unitMask(logoUv);
  let scanCore = exp(-scanDistance * 118.0) * scanEnvelope * unitMask(logoUv);
  let refraction = sin(logoUv.y * 22.0 + time * 0.12) * 0.0012 * scanGlow;
  let sampleUv = logoUv + vec2f(refraction, 0.0);

  let rawMark = textureSample(
    logoTexture,
    logoSampler,
    clamp(sampleUv, vec2f(0.0), vec2f(1.0)),
  );
  let mark = vec4f(rawMark.rgb, rawMark.a * unitMask(sampleUv));

  let edgeStep = 0.0035;
  let gradient = vec2f(
    markAlpha(sampleUv + vec2f(edgeStep, 0.0)) -
      markAlpha(sampleUv - vec2f(edgeStep, 0.0)),
    markAlpha(sampleUv + vec2f(0.0, edgeStep)) -
      markAlpha(sampleUv - vec2f(0.0, edgeStep)),
  );
  let edge = smoothstep(0.02, 0.34, length(gradient));
  let normal = normalize(gradient + vec2f(0.0001));
  let lightDirection = normalize(vec2f(-0.58, -0.82));
  let facing = 0.5 + 0.5 * dot(normal, lightDirection);
  let bevel = pow(facing, 5.0) * edge;

  let nearHalo = max(ringAlpha(sampleUv, 0.012) - mark.a, 0.0);
  let haloAlpha = clamp(
    nearHalo * (0.12 + scanGlow * 0.06),
    0.0,
    0.1,
  );
  let shadowField = max(
    ringAlpha(sampleUv + vec2f(-0.012, -0.016), 0.016) - mark.a,
    0.0,
  );
  let shadowAlpha = shadowField * 0.1;

  let opticalBlue = vec3f(0.333, 0.78, 0.953);
  var surface = mark.rgb * (0.985 + bevel * 0.025);
  surface = mix(surface, opticalBlue, scanGlow * 0.075 + scanCore * 0.06);
  surface = mix(surface, vec3f(1.0), bevel * (0.035 + scanCore * 0.08));

  let outside = 1.0 - mark.a;
  let alpha = clamp(
    mark.a + (haloAlpha + shadowAlpha) * outside,
    0.0,
    1.0,
  );
  let premultipliedColor = surface * mark.a +
    opticalBlue * haloAlpha * outside;
  let safeColor = min(
    max(premultipliedColor, vec3f(0.0)),
    vec3f(alpha),
  );

  return vec4f(safeColor, alpha);
}
`;

interface WebGPULogoProps {
  label: string;
}

type RendererState = 'loading' | 'ready' | 'fallback';

interface GpuResources {
  abortController: AbortController;
  context?: any;
  destroyed: boolean;
  device?: any;
  logoTexture?: any;
  uncapturedErrorHandler?: (event: any) => void;
  uniformBuffer?: any;
}

export default function WebGPULogo({ label }: WebGPULogoProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [rendererState, setRendererState] = useState<RendererState>('loading');

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;

    let disposed = false;
    let frameId = 0;
    let wakeTimerId = 0;
    let inViewport = true;
    let rendererRun = 0;
    let currentResources: GpuResources | undefined;
    let requestImmediateRender: (() => void) | undefined;
    const reducedMotionQuery = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    );

    const cancelScheduledRender = () => {
      if (frameId) {
        window.cancelAnimationFrame(frameId);
        frameId = 0;
      }
      if (wakeTimerId) {
        window.clearTimeout(wakeTimerId);
        wakeTimerId = 0;
      }
    };

    const destroyResources = (resources?: GpuResources) => {
      if (!resources || resources.destroyed) return;
      resources.destroyed = true;
      resources.abortController.abort();

      if (resources.device && resources.uncapturedErrorHandler) {
        resources.device.removeEventListener?.(
          'uncapturederror',
          resources.uncapturedErrorHandler,
        );
      }

      try {
        resources.context?.unconfigure?.();
      } catch {
        // GPU resources can already be invalid after device loss.
      }
      try {
        resources.logoTexture?.destroy?.();
      } catch {
        // GPU resources can already be invalid after device loss.
      }
      try {
        resources.uniformBuffer?.destroy?.();
      } catch {
        // GPU resources can already be invalid after device loss.
      }
      try {
        resources.device?.destroy?.();
      } catch {
        // GPU resources can already be invalid after device loss.
      }
    };

    const isCurrentRun = (run: number, resources: GpuResources) =>
      !disposed &&
      run === rendererRun &&
      currentResources === resources &&
      !resources.destroyed &&
      !reducedMotionQuery.matches;

    const showFallback = (run: number, resources: GpuResources) => {
      if (run !== rendererRun || currentResources !== resources) {
        destroyResources(resources);
        return;
      }

      rendererRun += 1;
      currentResources = undefined;
      requestImmediateRender = undefined;
      cancelScheduledRender();
      destroyResources(resources);
      if (!disposed) setRendererState('fallback');
    };

    const initialize = async (run: number, resources: GpuResources) => {
      let openErrorScopes = 0;
      const closeErrorScopes = async () => {
        let firstError: any;

        while (openErrorScopes > 0 && resources.device) {
          try {
            const error = await resources.device.popErrorScope();
            if (!firstError && error) firstError = error;
          } catch (error) {
            if (!firstError) firstError = error;
          }
          openErrorScopes -= 1;
        }

        return firstError;
      };

      try {
        const gpu = (navigator as Navigator & { gpu?: any }).gpu;
        resources.context = (canvas as any).getContext('webgpu');

        if (
          !gpu ||
          !resources.context ||
          typeof createImageBitmap !== 'function' ||
          reducedMotionQuery.matches
        ) {
          showFallback(run, resources);
          return;
        }

        const adapter = await gpu.requestAdapter();
        if (!isCurrentRun(run, resources)) {
          destroyResources(resources);
          return;
        }
        if (!adapter) {
          showFallback(run, resources);
          return;
        }

        const device = await adapter.requestDevice();
        if (!isCurrentRun(run, resources)) {
          device.destroy?.();
          destroyResources(resources);
          return;
        }
        resources.device = device;

        resources.uncapturedErrorHandler = (event: any) => {
          event.preventDefault?.();
          showFallback(run, resources);
        };
        device.addEventListener?.(
          'uncapturederror',
          resources.uncapturedErrorHandler,
        );
        device.lost
          .then(() => {
            if (!resources.destroyed) showFallback(run, resources);
          })
          .catch(() => {
            if (!resources.destroyed) showFallback(run, resources);
          });

        const response = await fetch('/utoo-lint-mark.svg', {
          signal: resources.abortController.signal,
        });
        if (!response.ok) throw new Error('Could not load the utoo mark');
        if (!isCurrentRun(run, resources)) {
          destroyResources(resources);
          return;
        }

        const logoUrl = URL.createObjectURL(await response.blob());
        const logoImage = new Image();
        logoImage.decoding = 'async';
        logoImage.src = logoUrl;
        try {
          await logoImage.decode();
        } finally {
          URL.revokeObjectURL(logoUrl);
        }
        if (!isCurrentRun(run, resources)) {
          destroyResources(resources);
          return;
        }
        const rasterCanvas = document.createElement('canvas');
        rasterCanvas.width = 438;
        rasterCanvas.height = 626;
        const rasterContext = rasterCanvas.getContext('2d');
        if (!rasterContext)
          throw new Error('Could not rasterize the utoo mark');
        rasterContext.drawImage(
          logoImage,
          0,
          0,
          rasterCanvas.width,
          rasterCanvas.height,
        );
        const bitmap = await createImageBitmap(rasterCanvas);
        if (!isCurrentRun(run, resources)) {
          bitmap.close();
          destroyResources(resources);
          return;
        }

        const textureUsage = (window as any).GPUTextureUsage;
        const bufferUsage = (window as any).GPUBufferUsage;
        try {
          device.pushErrorScope('internal');
          openErrorScopes += 1;
          device.pushErrorScope('out-of-memory');
          openErrorScopes += 1;
          device.pushErrorScope('validation');
          openErrorScopes += 1;
          resources.logoTexture = device.createTexture({
            size: [bitmap.width, bitmap.height, 1],
            format: 'rgba8unorm',
            usage:
              textureUsage.TEXTURE_BINDING |
              textureUsage.COPY_DST |
              textureUsage.RENDER_ATTACHMENT,
          });
          device.queue.copyExternalImageToTexture(
            { source: bitmap },
            {
              texture: resources.logoTexture,
              premultipliedAlpha: false,
            },
            [bitmap.width, bitmap.height],
          );
        } finally {
          bitmap.close();
        }

        const presentationFormat = gpu.getPreferredCanvasFormat();
        resources.context.configure({
          device,
          format: presentationFormat,
          alphaMode: 'premultiplied',
        });

        const shaderModule = device.createShaderModule({ code: logoShader });
        const pipeline = await device.createRenderPipelineAsync({
          layout: 'auto',
          vertex: { module: shaderModule, entryPoint: 'vertexMain' },
          fragment: {
            module: shaderModule,
            entryPoint: 'fragmentMain',
            targets: [{ format: presentationFormat }],
          },
          primitive: { topology: 'triangle-list' },
        });
        resources.uniformBuffer = device.createBuffer({
          size: 16,
          usage: bufferUsage.UNIFORM | bufferUsage.COPY_DST,
        });
        const sampler = device.createSampler({
          magFilter: 'linear',
          minFilter: 'linear',
        });
        const bindGroup = device.createBindGroup({
          layout: pipeline.getBindGroupLayout(0),
          entries: [
            { binding: 0, resource: resources.logoTexture.createView() },
            { binding: 1, resource: sampler },
            {
              binding: 2,
              resource: { buffer: resources.uniformBuffer },
            },
          ],
        });
        const uniforms = new Float32Array(4);
        let lastFrameTime = 0;
        const animationStartTime = performance.now();

        const resize = () => {
          const bounds = canvas.getBoundingClientRect();
          const pixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
          const width = Math.max(1, Math.round(bounds.width * pixelRatio));
          const height = Math.max(1, Math.round(bounds.height * pixelRatio));
          if (canvas.width !== width || canvas.height !== height) {
            canvas.width = width;
            canvas.height = height;
          }
        };

        const draw = (timestamp: number) => {
          const elapsedSeconds = (timestamp - animationStartTime) / 1000;
          resize();
          uniforms.set([canvas.width, canvas.height, elapsedSeconds, 1]);
          device.queue.writeBuffer(resources.uniformBuffer, 0, uniforms);

          const encoder = device.createCommandEncoder();
          const pass = encoder.beginRenderPass({
            colorAttachments: [
              {
                view: resources.context.getCurrentTexture().createView(),
                clearValue: { r: 0, g: 0, b: 0, a: 0 },
                loadOp: 'clear',
                storeOp: 'store',
              },
            ],
          });
          pass.setPipeline(pipeline);
          pass.setBindGroup(0, bindGroup);
          pass.draw(3);
          pass.end();
          device.queue.submit([encoder.finish()]);
        };

        const requestFrame = () => {
          if (
            isCurrentRun(run, resources) &&
            inViewport &&
            !document.hidden &&
            !frameId
          ) {
            frameId = window.requestAnimationFrame(render);
          }
        };

        function render(timestamp: number) {
          frameId = 0;
          if (!isCurrentRun(run, resources) || !inViewport || document.hidden) {
            return;
          }

          const elapsedSeconds = (timestamp - animationStartTime) / 1000;
          const cycleSeconds = ((elapsedSeconds % 12) + 12) % 12;
          const scanIsActive = cycleSeconds < 2.8;

          if (scanIsActive && timestamp - lastFrameTime < 32) {
            requestFrame();
            return;
          }

          lastFrameTime = timestamp;
          try {
            draw(timestamp);
          } catch {
            showFallback(run, resources);
            return;
          }

          if (scanIsActive) {
            requestFrame();
          } else {
            const delayUntilNextCycle = Math.max(0, (12 - cycleSeconds) * 1000);
            wakeTimerId = window.setTimeout(() => {
              wakeTimerId = 0;
              requestFrame();
            }, delayUntilNextCycle);
          }
        }

        draw(animationStartTime);
        const scopedError = await closeErrorScopes();
        if (scopedError) throw scopedError;
        await device.queue.onSubmittedWorkDone?.();

        if (!isCurrentRun(run, resources)) {
          destroyResources(resources);
          return;
        }

        setRendererState('ready');
        lastFrameTime = animationStartTime;
        requestImmediateRender = () => {
          cancelScheduledRender();
          requestFrame();
        };
        requestFrame();
      } catch (error: any) {
        if (openErrorScopes > 0) await closeErrorScopes();
        if (!isCurrentRun(run, resources)) {
          destroyResources(resources);
          return;
        }
        showFallback(run, resources);
      }
    };

    const stopCurrentRenderer = (fallback: boolean) => {
      rendererRun += 1;
      requestImmediateRender = undefined;
      cancelScheduledRender();
      const resources = currentResources;
      currentResources = undefined;
      destroyResources(resources);
      if (fallback && !disposed) setRendererState('fallback');
    };

    const startRenderer = () => {
      stopCurrentRenderer(false);
      if (disposed) return;
      if (reducedMotionQuery.matches) {
        setRendererState('fallback');
        return;
      }

      const run = rendererRun;
      const resources: GpuResources = {
        abortController: new AbortController(),
        destroyed: false,
      };
      currentResources = resources;
      setRendererState('loading');
      void initialize(run, resources);
    };

    const resizeObserver = new ResizeObserver(() => requestImmediateRender?.());
    resizeObserver.observe(canvas);
    const intersectionObserver = new IntersectionObserver(
      ([entry]) => {
        inViewport = entry?.isIntersecting ?? true;
        if (inViewport) requestImmediateRender?.();
        else cancelScheduledRender();
      },
      { rootMargin: '120px' },
    );
    intersectionObserver.observe(canvas);
    const updateDocumentVisibility = () => {
      if (document.hidden) cancelScheduledRender();
      else requestImmediateRender?.();
    };
    const updateReducedMotion = () => {
      if (reducedMotionQuery.matches) stopCurrentRenderer(true);
      else startRenderer();
    };
    document.addEventListener('visibilitychange', updateDocumentVisibility);
    if (typeof reducedMotionQuery.addEventListener === 'function') {
      reducedMotionQuery.addEventListener('change', updateReducedMotion);
    } else {
      reducedMotionQuery.addListener?.(updateReducedMotion);
    }

    startRenderer();

    return () => {
      disposed = true;
      document.removeEventListener(
        'visibilitychange',
        updateDocumentVisibility,
      );
      if (typeof reducedMotionQuery.removeEventListener === 'function') {
        reducedMotionQuery.removeEventListener('change', updateReducedMotion);
      } else {
        reducedMotionQuery.removeListener?.(updateReducedMotion);
      }
      resizeObserver.disconnect();
      intersectionObserver.disconnect();
      stopCurrentRenderer(false);
    };
  }, []);

  return (
    <figure
      aria-label={label}
      className="utlint-gpu-logo"
      data-renderer={rendererState}
      role="img"
    >
      <img alt="" aria-hidden="true" src="/utoo-lint-mark.svg" />
      <canvas aria-hidden="true" ref={canvasRef} />
    </figure>
  );
}
