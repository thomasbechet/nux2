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
  let programs = {};

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

    gl.clearColor(0.2, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
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
      const handle = core.generateHandle();
      programs[handle] = program;
      return handle;
    }
    return 0;
  }
  env.gpu_delete_pipeline = function (handle) {
    gl.deleteProgram(programs[handle]);
    delete programs[handle];
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
  env.gpu_update_texture = function (handle, x, y, w, h, data, len) {
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
      core.memorySlice(data, len),
    );
  }
  env.gpu_create_buffer = function (size) {
    // const tex = gl.createTexture();
    // gl.bindTexture(gl.TEXTURE_2D, tex);
    // gl.texStorage2D(
    //   gl.TEXTURE_2D,
    //   1,
    //   gl.RGBA32UI,
    //   width,
    //   height
    // );
    // const handle = core.generateHandle();
    // buffers[handle] = tex;
    // return handle;
    return 0;
  }
  env.gpu_delete_buffer = function (handle) {
    // delete buffers[handle];
  }
  env.gpu_update_buffer = function (handle, offset, size, data, len) {
    // gl.texSubImage2D(
    //   gl.TEXTURE_2D,
    //   0,
    //   0,
    //   0,
    //   width,
    //   height,
    //   gl.RGBA_INTEGER,
    //   gl.UNSIGNED_BYTE,
    //   core.memorySlice(data, len),
    // );
  }
  env.gpu_submit_commands = function (count, commands, command_size) {
    gl.clearColor(0.0, 0.5, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    for (let i = 0; i < count; ++i) {
      const p = commands + i * command_size;
      const type = core.getU32(p);
      switch (type) {
        case CommandType.BIND_FRAMEBUFFER: {
          const handle = core.getU32(p + 4);
          break;
        }
        case CommandType.BIND_PIPELINE: {
          const handle = core.getU32(p + 4);
          break;
        }
        case CommandType.BIND_BUFFER: {
          const handle = core.getU32(p + 4);
          const desc = core.getU32(p + 8);
          break;
        }
        case CommandType.BIND_TEXTURE: {
          const handle = core.getU32(p + 4);
          const desc = core.getU32(p + 8);
          break;
        }
        case CommandType.PUSH_U32: {
          const value = core.getU32(p + 4);
          const desc = core.getU32(p + 8);
          break;
        }
        case CommandType.PUSH_F32: {
          const value = core.getU32(p + 4);
          const desc = core.getU32(p + 8);
          break;
        }
        case CommandType.DRAW: {
          const count = core.getU32(p + 4);
          break;
        }
        case CommandType.CLEAR_COLOR: {
          const color = core.getU32(p + 4);
          break;
        }
        case CommandType.CLEAR_DEPTH: {
          break;
        }
        case CommandType.VIEWPORT: {
          const x = core.getU32(p + 4);
          const y = core.getU32(p + 8);
          const width = core.getU32(p + 12);
          const height = core.getU32(p + 16);
          break;
        }
      }
    }
  }
}
