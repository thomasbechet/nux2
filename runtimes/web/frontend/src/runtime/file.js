const cartFile = "cart.bin";

export async function init(core) {

  let file = await fetch(cartFile);
  let cart = await file.arrayBuffer();
  let files = [];

  const env = core.imports.env;
  env.file_open = function (path, len, mode) {
    path = core.decodeString(path, len);
    if (path === cartFile) {
      const handle = core.generateHandle();
      files[handle] = {
        cursor: 0,
        data: cart,
      }
      return handle;
    }
    return 0;
  }
  env.file_close = function (handle) {
    files[handle] = null;
  }
  env.file_seek = function (handle, cursor) {
    files[handle].cursor = cursor;
    return true;
  }
  env.file_read = function (handle, p, n) {
    if (n !== 0) {
      const src = new Uint8Array(files[handle].data, files[handle].cursor, n)
      const dst = new Uint8Array(core.memory.buffer, p, n)
      dst.set(src)
      files[handle].cursor += n
    }
    return true;
  }
  env.file_stat = function (path, len, pstat) {
    path = core.decodeString(path, len);
    if (path == cartFile) {
      core.setU32(pstat, cart.byteLength);
      return true;
    }
    return false;
  }
}