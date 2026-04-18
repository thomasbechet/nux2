import canvasVertexShader from '../assets/canvas.vert?raw'
import canvasFragmentShader from '../assets/canvas.frag?raw'

const PipelineType = {
  UBER: 0,
  CANVAS: 1,
};

const BufferType = {
  CONSTANTS: 0,
  BATCHES: 1,
  QUADS: 2,
  TRANSFORMS: 3,
  VERTICES: 4,
};

const Descriptor = {
  CONSTANTS_BUFFER: 0,
  BATCHES_BUFFER: 1,
  TRANSFORMS_BUFFER: 2,
  VERTICES_BUFFER: 3,
  QUADS_BUFFER: 4,
  BATCH_INDEX: 5,
  TEXTURE: 6,
  TEXTURE_WIDTH: 7,
  TEXTURE_HEIGHT: 8,
};

const VertexPrimitive = {
  TRIANGLES: 0,
  LINES: 1,
  POINTS: 2,
};

const CommandType = {
  BIND_FRAMEBUFFER: 0,
  BIND_PIPELINE: 1,
  BIND_BUFFER: 2,
  BIND_TEXTURE: 3,
  PUSH_U32: 4,
  PUSH_F32: 5,
  DRAW: 6,
  CLEAR_COLOR: 7,
  CLEAR_DEPTH: 8,
  VIEWPORT: 9,
};

const TextureType = {
  IMAGE_RGBA: 0,
  IMAGE_INDEXED: 1,
  RENDER_TARGET: 2,
};

const TextureFiltering = {
  NEAREST: 0,
  LINEAR: 1,
};

export async function init(core) {

  let gl;
  let textures = {};
  let buffers = {};
  let pipelines = {};

  let activePipeline = null;
  let emptyVAO;

  function createShader(type, source) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    var success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (success) {
      return shader;
    }
    console.log(gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
  }

  function createProgram(vertexShader, fragmentShader) {
    var program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    var success = gl.getProgramParameter(program, gl.LINK_STATUS);
    if (success) {
      return program;
    }

    console.log(gl.getProgramInfoLog(program));
    gl.deleteProgram(program);
  }

  const env = core.imports.env;
  env.gpu_create_device = function () {

    // Initialize WebGL context
    gl = canvas.getContext("webgl2");
    if (gl === null) {
      alert("Unable to initialize WebGL2.");
      return;
    }
    emptyVAO = gl.createVertexArray();
  }
  env.gpu_delete_device = function () { }
  env.gpu_create_pipeline = function (
    pipelineType,
    primitive,
    blend,
    depthTest,
  ) {
    if (pipelineType == PipelineType.UBER) {
      // TODO
    } else if (pipelineType == PipelineType.CANVAS) {
      const vertexShader = createShader(gl.VERTEX_SHADER, canvasVertexShader);
      const fragmentShader = createShader(gl.FRAGMENT_SHADER, canvasFragmentShader);
      const program = createProgram(vertexShader, fragmentShader);

      let indices = [];
      indices[Descriptor.CONSTANTS_BUFFER] = gl.getUniformBlockIndex(program, "ConstantBlock");

      let locations = [];
      locations[Descriptor.BATCHES_BUFFER] = gl.getUniformLocation(program, "batchesTexture");
      locations[Descriptor.QUADS_BUFFER] = gl.getUniformLocation(program, "quadsTexture");
      locations[Descriptor.BATCH_INDEX] = gl.getUniformLocation(program, "batchIndex");
      locations[Descriptor.TEXTURE] = gl.getUniformLocation(program, "texture0");

      let units = [];
      units[Descriptor.BATCHES_BUFFER] = gl.TEXTURE0;
      units[Descriptor.QUADS_BUFFER] = gl.TEXTURE1;
      units[Descriptor.TEXTURE] = gl.TEXTURE2;

      const handle = core.generateHandle();
      pipelines[handle] = {
        program: program,
        indices: indices,
        units: units,
        locations: locations,
      };
      return handle;
    }
    return 0;
  }
  env.gpu_delete_pipeline = function (handle) {
    gl.deleteProgram(pipelines[handle].program);
    delete pipelines[handle];
  }
  env.gpu_create_texture = function (w, h, filtering, type) {

    // Create texture
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA8,
      w,
      h,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      null
    );

    // Filtering
    if (filtering === TextureFiltering.NEAREST) {
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    } else if (filtering === TextureFiltering.LINEAR) {
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    }

    // Wrapping (safe default)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    const handle = core.generateHandle();
    textures[handle] = texture;

    return handle;
  }
  env.gpu_delete_texture = function (handle) {
    const texture = textures[handle];
    gl.deleteTexture(texture);
    delete textures[handle];
  }
  env.gpu_update_texture = function (handle, x, y, w, h, data) {
    const texture = textures[handle];
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texSubImage2D(
      gl.TEXTURE_2D,
      0,
      x,
      y,
      w,
      h,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      core.memorySlice(data, w * h * 4),
    );
  }
  env.gpu_create_buffer = function (bufferType, size) {
    let texture;
    let ubo;

    switch (bufferType) {
      case BufferType.CONSTANTS: {
        ubo = gl.createBuffer();
        gl.bindBuffer(gl.UNIFORM_BUFFER, ubo);
        gl.bufferData(gl.UNIFORM_BUFFER, size, gl.DYNAMIC_DRAW);
        break;
      }
      case BufferType.BATCHES:
      case BufferType.QUADS:
      case BufferType.TRANSFORMS:
      case BufferType.VERTICES: {
        const bytesPerPixel = 16; // RGBA32UI
        const pixelCount = Math.ceil(size / bytesPerPixel);

        const widthMax = 16384;
        let width, height;

        if (pixelCount <= widthMax) {
          width = pixelCount;
          height = 1;
        } else {
          width = widthMax;
          height = Math.ceil(pixelCount / widthMax);
        }

        texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texStorage2D(
          gl.TEXTURE_2D,
          1,
          gl.RGBA32UI,
          width,
          height,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        // Initialize to zero
        const zero = new Uint32Array(width * height * 4); // RGBA32UI
        gl.texSubImage2D(
          gl.TEXTURE_2D,
          0,
          0,
          0,
          width,
          height,
          gl.RGBA_INTEGER,
          gl.UNSIGNED_INT,
          zero
        );
        break;
      }
    }

    const handle = core.generateHandle();
    buffers[handle] = {
      type: bufferType,
      texture,
      ubo,
    };

    return handle;
  }
  env.gpu_delete_buffer = function (handle) {
    const buffer = buffers[handle];
    if (!buffer) return;

    if (buffer.texture) {
      gl.deleteTexture(buffer.texture);
    }

    if (buffer.ubo) {
      gl.deleteBuffer(buffer.ubo);
    }

    delete buffers[handle];
  }
  env.gpu_update_buffer = function (handle, offset, len, data) {
    const buffer = buffers[handle];

    if (buffer.ubo) {
      const src = core.memorySlice(data, len);
      gl.bindBuffer(gl.UNIFORM_BUFFER, buffer.ubo);
      gl.bufferSubData(gl.UNIFORM_BUFFER, offset, src);
    } else if (buffer.texture) {

      const bytesPerPixel = 16; // RGBA32UI
      const uintsPerPixel = 4;
      const widthMax = 16384;

      // Convert bytes to pixels
      let pixelOffset = Math.floor(offset / bytesPerPixel);
      let pixelCount = Math.floor(len / bytesPerPixel);

      let x = pixelOffset % widthMax;
      let y = Math.floor(pixelOffset / widthMax);

      let remainingPixels = pixelCount;

      // Convert input data to Uint32
      gl.bindTexture(gl.TEXTURE_2D, buffer.texture);
      const src = core.memorySliceU32(data, len / 4);
      let dataOffset = 0; // in uint32
      while (remainingPixels > 0) {
        const rowSpace = widthMax - x;
        const writePixels = Math.min(remainingPixels, rowSpace);
        const uintCount = writePixels * uintsPerPixel;
        gl.texSubImage2D(
          gl.TEXTURE_2D,
          0,
          x,
          y,
          writePixels,
          1,
          gl.RGBA_INTEGER,
          gl.UNSIGNED_INT,
          src.subarray(dataOffset, dataOffset + uintCount)
        );

        remainingPixels -= writePixels;
        dataOffset += uintCount;

        x = 0;
        y += 1;
      }
    }
  }
  env.gpu_submit_commands = function (count, commands, command_size) {
    for (let i = 0; i < count; ++i) {
      const p = commands + i * command_size;
      const type = core.getU32(p);

      switch (type) {
        case CommandType.BIND_FRAMEBUFFER: {
          const handle = core.getU32(p + 4);
          if (handle !== 0) {
            const fb = framebuffers[handle];
            gl.bindFramebuffer(gl.FRAMEBUFFER, fb.handle);
          } else {
            gl.bindFramebuffer(gl.FRAMEBUFFER, null);
          }
          break;
        }
        case CommandType.BIND_PIPELINE: {
          const handle = core.getU32(p + 4);
          const pipeline = pipelines[handle];

          gl.useProgram(pipeline.program);

          if (pipeline.depth_test) gl.enable(gl.DEPTH_TEST);
          else gl.disable(gl.DEPTH_TEST);

          if (pipeline.blend) {
            gl.enable(gl.BLEND);
            gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
          } else {
            gl.disable(gl.BLEND);
          }

          if (pipeline.type === PipelineType.UBER) {
            gl.enable(gl.SAMPLE_ALPHA_TO_COVERAGE);
          }

          activePipeline = pipeline;
          break;
        }
        case CommandType.BIND_BUFFER: {
          const handle = core.getU32(p + 4);
          const desc = core.getU32(p + 8);

          const buffer = buffers[handle];
          if (buffer.ubo) {
            const index = activePipeline.indices[desc];
            gl.bindBufferBase(gl.UNIFORM_BUFFER, index, buffer.handle);
          } else if (buffer.texture) {
            const location = activePipeline.locations[desc];
            const unit = activePipeline.units[desc];
            const unitIndex = unit - gl.TEXTURE0;
            gl.activeTexture(unit);
            gl.bindTexture(gl.TEXTURE_2D, buffer.texture);
            gl.uniform1i(location, unitIndex);
          }
          break;
        }
        case CommandType.BIND_TEXTURE: {
          const handle = core.getU32(p + 4);
          const desc = core.getU32(p + 8);

          let texHandle = null;
          if (handle !== 0) {
            texHandle = textures[handle].handle;
          }

          const location = activePipeline.locations[desc];
          const unit = activePipeline.units[desc];
          const unitIndex = unit - gl.TEXTURE0;

          gl.activeTexture(unit);
          gl.bindTexture(gl.TEXTURE_2D, texHandle);
          gl.uniform1i(location, unitIndex);

          break;
        }
        case CommandType.PUSH_U32: {
          const value = core.getU32(p + 4);
          const desc = core.getU32(p + 8);

          const location = activePipeline.locations[desc];
          gl.uniform1ui(location, value);
          break;
        }
        case CommandType.PUSH_F32: {
          const value = core.getF32(p + 4);
          const desc = core.getU32(p + 8);

          const location = activePipeline.locations[desc];
          gl.uniform1f(location, value);
          break;
        }
        case CommandType.DRAW: {
          const vertexCount = core.getU32(p + 4);

          gl.bindVertexArray(emptyVAO);
          gl.drawArrays(activePipeline.primitive, 0, vertexCount);
          gl.bindVertexArray(null);

          break;
        }
        case CommandType.CLEAR_COLOR: {
          const color = core.getU32(p + 4);

          const r = ((color >> 0) & 0xFF) / 255;
          const g = ((color >> 8) & 0xFF) / 255;
          const b = ((color >> 16) & 0xFF) / 255;
          const a = ((color >> 24) & 0xFF) / 255;

          gl.clearColor(r, g, b, a);
          gl.clear(gl.COLOR_BUFFER_BIT);
          break;
        }
        case CommandType.CLEAR_DEPTH: {
          gl.clear(gl.DEPTH_BUFFER_BIT);
          break;
        }
        case CommandType.VIEWPORT: {
          const x = core.getU32(p + 4);
          const y = core.getU32(p + 8);
          const width = core.getU32(p + 12);
          const height = core.getU32(p + 16);

          const flippedY = height - (y + height);

          gl.viewport(x, flippedY, width, height);
          gl.enable(gl.SCISSOR_TEST);
          gl.scissor(x, flippedY, width, height);
          break;
        }
      }
    }
  }
}
