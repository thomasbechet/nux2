export function init(core) {
  const env = core.imports.env;
  env.system_timestamp = function (w, h) {
    return BigInt(Date.now()) * 1000000n;
  }
}