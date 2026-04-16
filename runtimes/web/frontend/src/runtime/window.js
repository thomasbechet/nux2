export function init(core) {
  const env = core.imports.env;
  env.window_open = function (w, h) {
    var canvas = document.createElement('canvas');
    canvas.id = "canvas";
    canvas.width = w;
    canvas.height = h;
    const container = document.getElementById("container")
    container.appendChild(canvas);
  }
  env.window_close = function () { }
  env.window_resize = function (w, h) { }
}