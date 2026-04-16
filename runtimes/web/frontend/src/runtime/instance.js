import * as gpu from './gpu.js';
import * as file from './file.js';
import * as window from './window.js';

export async function init(cartPath) {

  let core = {};

  // init memory and basic env
  core.imports = {
    env: {
      STACKTOP: 0,
      STACK_MAX: 65536,
      memory: new WebAssembly.Memory({ initial: (1 << 16) }),
      abortStackOverflow(val) { throw new Error("stackoverfow"); },
      logger_log(level, data, len) {
        console.log(core.decodeString(data, len))
      },
    },
    wasi_snapshot_preview1: { // Stub wasi interface (never called)
      fd_close() { },
      fd_read() { },
      fd_seek() { },
      fd_write() { },
      fd_fdstat_get() { },
      clock_time_get() { },
      fd_fdstat_set_flags() { },
      fd_filestat_get() { },
      fd_prestat_get() { },
      fd_prestat_dir_name() { },
      fd_pwrite() { },
      fd_renumber() { },
      path_open() { },
      proc_exit() { },
      random_get() { }
    },
  }

  // handle generator
  core.nextHandle = 1;
  core.generateHandle = function () {
    const handle = core.nextHandle;
    core.nextHandle += 1;
    return handle;
  }

  // utils functions
  core.setU32 = function (ptr, value) {
    const buf = new Int32Array(core.memory.buffer, ptr, 4);
    buf[0] = value;
  }
  core.getU32 = function (ptr) {
    const buf = new Int32Array(core.memory.buffer, ptr, 4);
    return buf[0];
  }
  core.getU8 = function (ptr) {
    const buf = new Int8Array(core.memory.buffer, ptr, 1);
    return buf[0];
  }
  const decoder = new TextDecoder();
  core.decodeString = function (data, len) {
    return decoder.decode(new Int8Array(core.memory.buffer, data, len));
  }

  // init modules
  window.init(core);
  await file.init(core);
  await gpu.init(core);

  // init
  const wasmData = await fetch("/core.wasm");
  let wasm = await WebAssembly.instantiateStreaming(wasmData, core.imports);
  core.instance = wasm.instance;
  core.memory = core.instance.exports.memory; // Assign generated memory
  core.instance.exports.runtime_init();

  // update function
  core.update = function () {
    core.instance.exports.runtime_update();
  }

  return core;
}