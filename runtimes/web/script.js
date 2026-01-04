const decoder = new TextDecoder()
const encoder = new TextEncoder()
const decodeString = (data, len) => decoder.decode(new Int8Array(instance.exports.memory.buffer, data, len))
let instance
let files = []
let file
let cart
let previousTime = 0.0;

const importObject = {
  env: {
    STACKTOP: 0,
    STACK_MAX: 65536,
    abortStackOverflow: function (val) { throw new Error("stackoverfow"); },
    memory: new WebAssembly.Memory({ initial: (1 << 16) }),
    runtime_log: function (level, data, len) {
      console.log(decodeString(data, len))
    },
    nux_os_file_open: (userdata, slot, path, len, mode) => {
      path = decodeString(path, len);
      if (path === "cart.bin") {
        files[slot] = {
          cursor: 0,
          data: cart,
        }
        return 1;
      }
      return 0;
    },
    nux_os_file_close: (userdata, slot) => {
      files[slot] = null;
    },
    nux_os_file_stat: (userdata, slot, pstat) => {
      const buf = new Int32Array(instance.exports.memory.buffer, pstat, 4)
      buf[0] = files[slot].data.length;
      return 1;
    },
    nux_os_file_seek: (userdata, slot, cursor) => {
      files[slot].cursor = cursor;
      return 1;
    },
    nux_os_file_read: (userdata, slot, p, n) => {
      const src = new Uint8Array(files[slot].data, files[slot].cursor, n)
      const dst = new Uint8Array(instance.exports.memory.buffer, p, n)
      dst.set(src)
      files[slot].cursor += n
      return n;
    },
    nux_os_file_write: (userdata, slot, p, n) => { return 1; },
    nux_os_pipeline_create: (userdata, slot, pinfo) => { return 1; },
    nux_os_pipeline_delete: (userdata, slot) => { return 1; },
    nux_os_framebuffer_create: (userdata, slot, texture) => { return 1; },
    nux_os_framebuffer_delete: (userdata, slot) => { return 1; },
    nux_os_texture_create: (userdata, slot, pinfo) => { return 1; },
    nux_os_texture_delete: (userdata, slot) => { return 1; },
    nux_os_texture_update: (userdata, slot, x, y, w, h, pdata) => { return 1; },
    nux_os_buffer_create: (userdata, slot, type, size) => { return 1; },
    nux_os_buffer_delete: (userdata, slot) => { return 1; },
    nux_os_buffer_update: (userdata, slot, offset, size, data) => { return 1; },
    nux_os_gpu_submit: (userdata, pcmds, count) => { return 1; },
    nux_os_input_update: (userdata, pbuttons, paxis) => { return 1; },
    // nux_os_stats_update: (userdata, pstats) => { return 1; },
  },
  wasi_snapshot_preview1: {
    // fd_close: fd => { return 0; },
    // fd_read: fd => { return 0; },
    // fd_seek: (fd, offset_low, offset_high, whence, newOffset) => { return 0; },
    // fd_write(fd, iovsPtr, iovsLength, bytesWrittenPtr) { return 0; },
    // fd_fdstat_get: (fd, stat) => { return 0; },
    // clock_time_get: () => { },
    // fd_fdstat_set_flags: () => { },
    // fd_filestat_get: () => { },
    // fd_prestat_get: () => { },
    // fd_prestat_dir_name: () => { },
    // fd_pwrite: () => { },
    // fd_renumber: () => { },
    // path_open: () => { },
    // proc_exit: () => { },
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

  // file = await fetch("cart.bin");
  let runtime = await fetch("nux.wasm");
  // cart = await file.arrayBuffer();
  // console.log(cart)
  let obj = await WebAssembly.instantiateStreaming(runtime, importObject);
  instance = obj.instance
  console.log(instance.exports)
  instance.exports.runtime_init();

  const canvas = document.querySelector("#gl-canvas");
  const gl = canvas.getContext("webgl");
  if (gl === null) {
    alert("Unable to initialize WebGL. Your browser or machine may not support it.");
    return;
  }

  gl.clearColor(0.2, 0.0, 0.0, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);
};;

const loop = time => {
  const dt = time - previousTime;
  previousTime = time;
  instance.exports.instance_update();
  window.requestAnimationFrame(loop);
};

window.requestAnimationFrame(async time => {
  previousTime = time;
  await init();
  // window.requestAnimationFrame(loop);
});
