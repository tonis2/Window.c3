module c3w @if(env::WASM);

const char[] BRIDGE_JS = $embed("c3w.js");

fn char* get_bridge_js() @export("get_bridge_js") {
	return &BRIDGE_JS[0];
}

fn uint get_bridge_js_len() @export("get_bridge_js_len") {
	return (uint)BRIDGE_JS.len;
}
