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
let canvasVertexShader = await fetch("shaders/canvas.vert");
let canvasFragmentShader = await fetch("shaders/canvas.frag");


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

function createShader(gl, type, source) {
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

function createProgram(gl, vertexShader, fragmentShader) {
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
		},
		window_close: () => { },
		window_resize: (w, h) => { },

		// GPU
		gpu_create_device: () => {
			// Initialize WebGL context
			gl = canvas.getContext("webgl2");
			if (gl === null) {
				alert("Unable to initialize WebGL. Your browser or machine may not support it.");
				return;
			}

			gl.clearColor(0.2, 0.0, 0.0, 1.0);
			gl.clear(gl.COLOR_BUFFER_BIT);
		},
		gpu_delete_device: () => { },
		gpu_create_pipeline: (
			pipelineType,
			primitive,
			blend,
			depthTest,
		) => {
			if (pipelineType == PipelineType.UBER) {
				// TODO
			} else if (pipelineType == PipelineType.CANVAS) {
				var vertexShader = createShader(gl, gl.VERTEX_SHADER, canvasVertexShader);
				var fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, canvasFragmentShader);
				var program = createProgram(gl, vertexShader, fragmentShader);
				console.log(program);
			}
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
	let file = await fetch("/cart.bin");
	cart = await file.arrayBuffer();
	let runtime = await fetch("/core.wasm");
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
