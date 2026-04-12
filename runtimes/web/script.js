const decoder = new TextDecoder()
const encoder = new TextEncoder()
const decodeString = (data, len) => decoder.decode(new Int8Array(instance.exports.memory.buffer, data, len))
const cartFile = "cart.bin";
const cartSlot = 0;
let instance
let files = []
let cart
let previousTime = 0.0;

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
    file_open: (path, len, mode, pslot) => {
      path = decodeString(path, len);
      if (path === cartFile) {
        files[cartSlot] = {
          cursor: 0,
          data: cart,
        }
        setU32(pslot, cartSlot);
        return true;
      }
      return false;
    },
    file_close: (slot) => {
      files[slot] = null;
    },
    file_seek: (slot, cursor) => {
      files[slot].cursor = cursor;
      return true;
    },
    file_read: (slot, p, n) => {
      if (n !== 0) {
        const src = new Uint8Array(files[slot].data, files[slot].cursor, n)
        const dst = new Uint8Array(instance.exports.memory.buffer, p, n)
        dst.set(src)
        files[slot].cursor += n
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
      console.log("OPEN WINDOW", w, h);
    },
    window_close: () => {

    },
    window_resize: (w, h) => {

    },
  },
  wasi_snapshot_preview1: {
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

  const canvas = document.querySelector("#gl-canvas");
  const gl = canvas.getContext("webgl");
  if (gl === null) {
    alert("Unable to initialize WebGL. Your browser or machine may not support it.");
    return;
  }

  gl.clearColor(0.2, 0.0, 0.0, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);
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
