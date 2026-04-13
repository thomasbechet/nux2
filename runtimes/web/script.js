const decoder = new TextDecoder()
const encoder = new TextEncoder()
const decodeString = (data, len) => decoder.decode(new Int8Array(instance.exports.memory.buffer, data, len))
const cartFile = "cart.bin";
let nextHandle = 1;
let instance
let files = []
let cart
let gl
let previousTime = 0.0;

function genHandle() {
  const handle = nextHandle;
  nextHandle += 1;
  return handle;
}
const setU32 = (ptr, value) => {
  const buf = new Int32Array(instance.exports.memory.buffer, ptr, 4)
  buf[0] = value;
}
const getU32 = (ptr) => {
  const buf = new Int32Array(instance.exports.memory.buffer, ptr, 4)
  return buf[0];
}

const importObject = {
  env: {
    STACKTOP: 0,
    STACK_MAX: 65536,
    abortStackOverflow: function (val) { throw new Error("stackoverfow"); },
    memory: new WebAssembly.Memory({ initial: (1 << 16) }),

    // Logger
    logger_log: function (level, data, len) {
      console.log(decodeString(data, len))
    },

    // File
    file_open: (path, len, mode) => {
      path = decodeString(path, len);
      if (path === cartFile) {
        const handle = genHandle();
        files[handle] = {
          cursor: 0,
          data: cart,
        }
        return handle;
      }
      return 0;
    },
    file_close: (handle) => {
      files[handle] = null;
    },
    file_seek: (handle, cursor) => {
      files[handle].cursor = cursor;
      return true;
    },
    file_read: (handle, p, n) => {
      if (n !== 0) {
        const src = new Uint8Array(files[handle].data, files[handle].cursor, n)
        const dst = new Uint8Array(instance.exports.memory.buffer, p, n)
        dst.set(src)
        files[handle].cursor += n
      }
      return true;
    },
    file_stat: (path, len, pstat) => {
      path = decodeString(path, len);
      if (path == cartFile) {
        setU32(pstat, cart.byteLength);
        return true;
      }
      return false;
    },

    // Window
    window_open: (w, h) => {

      // Create canvas
      var canvas = document.createElement('canvas');
      canvas.id = "canvas";
      canvas.width = w;
      canvas.height = h;
      const container = document.getElementById("container")
      container.appendChild(canvas);

      // Initialize WebGL context
      // const canvas = document.getElementById("canvas");
      gl = canvas.getContext("webgl2");
      if (gl === null) {
        alert("Unable to initialize WebGL. Your browser or machine may not support it.");
        return;
      }
      gl.clearColor(0.2, 0.0, 0.0, 1.0);
      gl.clear(gl.COLOR_BUFFER_BIT);
    },
    window_close: () => { },
    window_resize: (w, h) => { },

    // GPU
    gpu_create_device: () => { },
    gpu_delete_device: () => { },
    gpu_create_pipeline: () => {
      console.log(gl instanceof WebGL2RenderingContext);
      console.log(gl.MAX_UNIFORM_BLOCK_SIZE);
      console.log(gl.getParameter(gl.MAX_UNIFORM_BLOCK_SIZE));
      // console.log(gl.getParameter(gl.MAX_UNIFORM_BUFFER_BINDINGS));
      // console.log(gl.getParameter(gl.MAX_VERTEX_UNIFORM_BLOCKS));
      // console.log(gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_BLOCKS));
      return 0;
    },
    gpu_delete_pipeline: (handle) => { },
    gpu_create_texture: (w, h) => {
      return 0;
    },
    gpu_delete_texture: (handle) => { },
    gpu_update_texture: (handle, x, y, w, h, data, len) => { },
    gpu_create_buffer: (size) => {
      return 0;
    },
    gpu_delete_buffer: (handle) => { },
    gpu_update_buffer: (handle, offset, size, data, len) => { },
    gpu_submit_commands: (count, commands) => { },
  },
  wasi_snapshot_preview1: { // Stub wasi interface (never called)
    fd_close: () => { },
    fd_read: () => { },
    fd_seek: () => { },
    fd_write() { },
    fd_fdstat_get: () => { },
    clock_time_get: () => { },
    fd_fdstat_set_flags: () => { },
    fd_filestat_get: () => { },
    fd_prestat_get: () => { },
    fd_prestat_dir_name: () => { },
    fd_pwrite: () => { },
    fd_renumber: () => { },
    path_open: () => { },
    proc_exit: () => { },
    random_get: () => { }
  },
}
const init = async () => {
  // fetch("nux.wasm")
  //   .then(bytes => bytes.arrayBuffer())
  //   .then(mod => WebAssembly.compile(mod))
  //   .then(module => {
  //     console.log(WebAssembly.Module.imports(module))
  //     console.log(WebAssembly.Module.exports(module))
  //   })

  let file = await fetch("cart.bin");
  cart = await file.arrayBuffer();
  let runtime = await fetch("nux.wasm");
  let obj = await WebAssembly.instantiateStreaming(runtime, importObject);
  instance = obj.instance
  instance.exports.runtime_init();
};

const loop = time => {
  const dt = time - previousTime;
  previousTime = time;
  instance.exports.runtime_update();
  window.requestAnimationFrame(loop);
};

window.requestAnimationFrame(async time => {
  previousTime = time;
  await init();
  window.requestAnimationFrame(loop);
});
