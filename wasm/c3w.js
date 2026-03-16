// c3w.js - JavaScript bridge for Window.c3 WASM backend
//
// Usage:
//   import { createC3WBridge } from './c3w.js';
//   const bridge = createC3WBridge(canvas);
//   const { instance } = await WebAssembly.instantiateStreaming(fetch('app.wasm'), { env: bridge.env });
//   bridge.setMemory(instance.exports.memory);

export function createC3WBridge(canvas) {
    let memory = null;
    const eventQueue = [];

    function dv() {
        return new DataView(memory.buffer);
    }

    // DOM event listeners installed on the canvas
    const listeners = [];

    function installListeners(canvas) {
        const on = (target, type, handler) => {
            target.addEventListener(type, handler);
            listeners.push({ target, type, handler });
        };

        // Keyboard events
        on(canvas, 'keydown', (e) => {
            e.preventDefault();
            eventQueue.push({ type: 1, code: e.keyCode, x: 0, y: 0 });
        });
        on(canvas, 'keyup', (e) => {
            e.preventDefault();
            eventQueue.push({ type: 2, code: e.keyCode, x: 0, y: 0 });
        });

        // Mouse button events
        on(canvas, 'mousedown', (e) => {
            eventQueue.push({ type: 3, code: e.button, x: 0, y: 0 });
        });
        on(canvas, 'mouseup', (e) => {
            eventQueue.push({ type: 4, code: e.button, x: 0, y: 0 });
        });

        // Mouse motion
        on(canvas, 'mousemove', (e) => {
            const rect = canvas.getBoundingClientRect();
            eventQueue.push({
                type: 6,
                code: 0,
                x: e.clientX - rect.left,
                y: e.clientY - rect.top,
            });
        });

        // Mouse wheel
        on(canvas, 'wheel', (e) => {
            e.preventDefault();
            // code 0 = scroll up, code 1 = scroll down
            eventQueue.push({ type: 5, code: e.deltaY < 0 ? 0 : 1, x: 0, y: 0 });
        }, { passive: false });

        // Prevent context menu on right-click
        on(canvas, 'contextmenu', (e) => {
            e.preventDefault();
        });

        // Make canvas focusable for keyboard events
        canvas.tabIndex = 0;
        canvas.style.outline = 'none';
        canvas.focus();
    }

    function removeListeners() {
        for (const { target, type, handler } of listeners) {
            target.removeEventListener(type, handler);
        }
        listeners.length = 0;
    }

    const env = {
        js_init_canvas(width, height) {
            canvas.width = width;
            canvas.height = height;
            installListeners(canvas);
        },

        js_destroy_canvas() {
            removeListeners();
        },

        // Write next event into JsEvent struct at ptr, return 1 if event available, 0 if empty
        // JsEvent layout: uint type (4), uint code (4), float mouse_x (4), float mouse_y (4) = 16 bytes
        js_poll_event(ptr) {
            if (eventQueue.length === 0) return 0;
            const evt = eventQueue.shift();
            const v = dv();
            v.setUint32(ptr, evt.type, true);
            v.setUint32(ptr + 4, evt.code, true);
            v.setFloat32(ptr + 8, evt.x, true);
            v.setFloat32(ptr + 12, evt.y, true);
            return 1;
        },
    };

    return {
        env,
        setMemory(mem) {
            memory = mem;
        },
    };
}
