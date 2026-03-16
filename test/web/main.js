async function main() {
    const canvas = document.getElementById('c3w-canvas');

    // Stage 1: Load WASM to extract the embedded bridge JS
    const response = await fetch('test-wasm.wasm');
    const bytes = await response.arrayBuffer();

    // Minimal imports just to instantiate and extract the bridge
    const stubImports = {
        env: {
            js_init_canvas() {},
            js_destroy_canvas() {},
            js_poll_event() { return 0; },
        },
    };
    const { instance: stub } = await WebAssembly.instantiate(bytes, stubImports);

    if (stub.exports._initialize) {
        stub.exports._initialize();
    }

    // Extract bridge JS source from WASM memory
    const bridgePtr = stub.exports.get_bridge_js();
    const bridgeLen = stub.exports.get_bridge_js_len();
    const bridgeSrc = new TextDecoder().decode(
        new Uint8Array(stub.exports.memory.buffer, bridgePtr, bridgeLen)
    );

    // Load the bridge module from the extracted source
    const blob = new Blob([bridgeSrc], { type: 'application/javascript' });
    const bridgeUrl = URL.createObjectURL(blob);
    const { createC3WBridge } = await import(bridgeUrl);
    URL.revokeObjectURL(bridgeUrl);

    // Stage 2: Create bridge and re-instantiate WASM with real imports
    const bridge = createC3WBridge(canvas);
    const { instance } = await WebAssembly.instantiate(bytes, { env: bridge.env });

    bridge.setMemory(instance.exports.memory);

    if (instance.exports._initialize) {
        instance.exports._initialize();
    }

    instance.exports.init();

    function frame() {
        instance.exports.frame();
        requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);

    console.log('c3w running!');
}

main().catch(err => {
    console.error('Fatal error:', err);
    document.body.innerHTML = `<h2>Error</h2><pre>${err.message}\n${err.stack}</pre>`;
});
