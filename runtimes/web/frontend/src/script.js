import * as instance from './runtime/instance.js';

let previousTime = 0.0;
let runtime;

const init = async () => {
	runtime = await instance.init();
};

const loop = time => {
	const dt = time - previousTime;
	previousTime = time;
	runtime.update();
	window.requestAnimationFrame(loop);
};

window.requestAnimationFrame(async time => {
	previousTime = time;
	await init();
	window.requestAnimationFrame(loop);
});