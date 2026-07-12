module c3w @if(env::LINUX);

// libxkbcommon bindings, loaded via dlopen (libxkbcommon.so.0 and, for X11,
// libxkbcommon-x11.so.0 — the runtime SONAMEs, present on any desktop; no -dev
// package needed). These turn key events into typed text with full keyboard
// layout, dead-key and modifier awareness. When the library or a keymap is
// unavailable the backends fall back to the US-QWERTY table in linux/main.c3.

alias XkbContext = void*;
alias XkbKeymap = void*;
alias XkbState = void*;

const uint XKB_KEYMAP_FORMAT_TEXT_V1 = 1;
const uint XKB_KEY_UP                = 0;
const uint XKB_KEY_DOWN              = 1;

// libxkbcommon
alias FnXkbContextNew = fn XkbContext(uint flags);
alias FnXkbContextUnref = fn void(XkbContext);
alias FnXkbKeymapNewFromString = fn XkbKeymap(XkbContext, char* str, uint format, uint flags);
alias FnXkbKeymapUnref = fn void(XkbKeymap);
alias FnXkbStateNew = fn XkbState(XkbKeymap);
alias FnXkbStateUnref = fn void(XkbState);
alias FnXkbStateKeyGetUtf8 = fn int(XkbState, uint key, char* buffer, usz size);
alias FnXkbStateUpdateKey = fn uint(XkbState, uint key, uint direction);
alias FnXkbStateUpdateMask = fn uint(XkbState, uint dep, uint lat, uint lock, uint dep_layout, uint lat_layout, uint lock_layout);

// libxkbcommon-x11
alias FnXkbX11SetupExtension = fn int(void* conn, ushort maj, ushort min, uint flags, ushort* maj_out, ushort* min_out, char* base_event, char* base_error);
alias FnXkbX11GetCoreKbdDevice = fn int(void* conn);
alias FnXkbX11KeymapNewFromDevice = fn XkbKeymap(XkbContext, void* conn, int device, uint flags);
alias FnXkbX11StateNewFromDevice = fn XkbState(XkbKeymap, void* conn, int device);

FnXkbContextNew xkb_context_new;
FnXkbContextUnref xkb_context_unref;
FnXkbKeymapNewFromString xkb_keymap_new_from_string;
FnXkbKeymapUnref xkb_keymap_unref;
FnXkbStateNew xkb_state_new;
FnXkbStateUnref xkb_state_unref;
FnXkbStateKeyGetUtf8 xkb_state_key_get_utf8;
FnXkbStateUpdateKey xkb_state_update_key;
FnXkbStateUpdateMask xkb_state_update_mask;

FnXkbX11SetupExtension xkb_x11_setup_xkb_extension;
FnXkbX11GetCoreKbdDevice xkb_x11_get_core_keyboard_device_id;
FnXkbX11KeymapNewFromDevice xkb_x11_keymap_new_from_device;
FnXkbX11StateNewFromDevice xkb_x11_state_new_from_device;

void* _xkb_lib;
void* _xkb_x11_lib;

// Load the core library. Returns false (falling the caller back to the ASCII
// table) if it isn't present or a symbol is missing.
fn bool xkb_load()
{
	if (_xkb_lib) return true;

	_xkb_lib = dlopen("libxkbcommon.so.0", RTLD_LAZY);
	if (!_xkb_lib) return false;

	xkb_context_new = (FnXkbContextNew)dlsym(_xkb_lib, "xkb_context_new");
	xkb_context_unref = (FnXkbContextUnref)dlsym(_xkb_lib, "xkb_context_unref");
	xkb_keymap_new_from_string = (FnXkbKeymapNewFromString)dlsym(_xkb_lib, "xkb_keymap_new_from_string");
	xkb_keymap_unref = (FnXkbKeymapUnref)dlsym(_xkb_lib, "xkb_keymap_unref");
	xkb_state_new = (FnXkbStateNew)dlsym(_xkb_lib, "xkb_state_new");
	xkb_state_unref = (FnXkbStateUnref)dlsym(_xkb_lib, "xkb_state_unref");
	xkb_state_key_get_utf8 = (FnXkbStateKeyGetUtf8)dlsym(_xkb_lib, "xkb_state_key_get_utf8");
	xkb_state_update_key = (FnXkbStateUpdateKey)dlsym(_xkb_lib, "xkb_state_update_key");
	xkb_state_update_mask = (FnXkbStateUpdateMask)dlsym(_xkb_lib, "xkb_state_update_mask");

	return xkb_context_new != null && xkb_keymap_new_from_string != null && xkb_state_key_get_utf8 != null;
}

// Load the X11 helper (in addition to the core library).
fn bool xkb_x11_load()
{
	if (!xkb_load()) return false;
	if (_xkb_x11_lib) return true;

	_xkb_x11_lib = dlopen("libxkbcommon-x11.so.0", RTLD_LAZY);
	if (!_xkb_x11_lib) return false;

	xkb_x11_setup_xkb_extension = (FnXkbX11SetupExtension)dlsym(_xkb_x11_lib, "xkb_x11_setup_xkb_extension");
	xkb_x11_get_core_keyboard_device_id = (FnXkbX11GetCoreKbdDevice)dlsym(_xkb_x11_lib, "xkb_x11_get_core_keyboard_device_id");
	xkb_x11_keymap_new_from_device = (FnXkbX11KeymapNewFromDevice)dlsym(_xkb_x11_lib, "xkb_x11_keymap_new_from_device");
	xkb_x11_state_new_from_device = (FnXkbX11StateNewFromDevice)dlsym(_xkb_x11_lib, "xkb_x11_state_new_from_device");

	return xkb_x11_keymap_new_from_device != null && xkb_x11_state_new_from_device != null;
}

// Decode one key into text and append it. `scancode` is the X11 keycode
// (evdev + 8). Lone control characters (Tab, Return, Escape, Backspace, Delete)
// are skipped — get_text carries printable typed text only, matching the darwin
// backend. Modifier state must already be current (see the update_mask /
// update_key calls in the backends).
fn void xkb_append_text(XkbState state, uint scancode, DString* text)
{
	char[64] buf;
	int n = xkb_state_key_get_utf8(state, scancode, &buf[0], buf.len);
	if (n <= 0 || n >= 64) return;
	if (n == 1 && (buf[0] < 0x20 || buf[0] == 0x7f)) return;
	text.append_string((String)buf[:n]);
}

// Release a window's xkb objects (safe on nulls / when never initialised).
fn void xkb_free(XkbContext context, XkbKeymap keymap, XkbState state)
{
	if (state != null && xkb_state_unref != null) xkb_state_unref(state);
	if (keymap != null && xkb_keymap_unref != null) xkb_keymap_unref(keymap);
	if (context != null && xkb_context_unref != null) xkb_context_unref(context);
}
