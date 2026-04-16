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

export async function init(core) {

  let gl;

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
      var vertexShader = createShader(gl.VERTEX_SHADER, canvasVertexShader);
      var fragmentShader = createShader(gl.FRAGMENT_SHADER, canvasFragmentShader);
      var program = createProgram(vertexShader, fragmentShader);
      console.log(program);
    }
    return 0;
  }
  env.gpu_delete_pipeline = function (handle) { }
  env.gpu_create_texture = function (w, h) {
    return 0;
  }
  env.gpu_delete_texture = function (handle) { }
  env.gpu_update_texture = function (handle, x, y, w, h, data, len) { }
  env.gpu_create_buffer = function (size) {
    return 0;
  }
  env.gpu_delete_buffer = function (handle) { }
  env.gpu_update_buffer = function (handle, offset, size, data, len) { }
  env.gpu_submit_commands = function (count, commands) {
    console.log(core.getU32(commands));
    for (let i = 0; i < count; ++i) {
    }
  }
}
