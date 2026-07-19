module c3w @if(env::LINUX);
import std::math;

import std::io;
import std::core::types;
import std::core::runtime;

alias X11Display = void*;
alias Connection = void*;
alias XCB_Window = void*;
alias XCB_setup = void*;

struct X11Window
{
	X11Display display;
	Connection connection;
	XCB_Window window;
	EventMap event_map;
	uint display_width;
	uint display_height;
	bool initialized;
	uint wm_delete_window;  // WM_DELETE_WINDOW atom, watched in the event loop
	bool close_requested;   // set once the window manager asks us to close
	double scroll_delta;    // accumulated over the last poll (+ = up)
	DString text;           // text typed during the last poll
	uint current_cursor;    // active X cursor resource (0 = none created yet)
	XkbContext xkb_context; // libxkbcommon objects for layout-aware text input
	XkbKeymap xkb_keymap;   // (null when libxkbcommon-x11 is unavailable)
	XkbState xkb_state;
}

// Function pointer types for dynamic loading
alias FnOpenDisplay = fn X11Display(char* name);
alias FnXCloseDisplay = fn void(X11Display);
alias FnXCreateFontCursor = fn ulong(X11Display, uint shape);
alias FnXDefineCursor = fn int(X11Display, ulong window, ulong cursor);
alias FnXFreeCursor = fn int(X11Display, ulong cursor);
alias FnXFlush = fn int(X11Display);
alias FnXcbConnect = fn Connection(char* name, uint* window);
alias FnXcbGetSetup = fn XCB_setup(Connection);
alias FnXcbRootsIterator = fn XScreenIterator*(XCB_setup);
alias FnXcbGenerateId = fn XCB_Window(XCB_setup);
alias FnXcbMapWindow = fn XCB_Window(Connection, XCB_Window);
alias FnXcbFlush = fn XCB_Window(Connection);
alias FnXcbPollForEvent = fn KeyPressEvent*(Connection);
alias FnXcbWaitForEvent = fn KeyPressEvent*(Connection);
alias FnXcbChangeProperty = fn void(Connection, XcbProp, XCB_Window, uint, uint, uint, uint, char*);
alias FnXcbQueryPointer = fn uint(Connection, XCB_Window);
alias FnXcbQueryPointerReply = fn KeyPressEvent*(Connection, uint, void*);
alias FnXcbDestroyWindow = fn uint(Connection, XCB_Window);
alias FnXcbDisconnect = fn uint(Connection);
alias FnXcbCreateWindow = fn uint(
	Connection,
	char,
	XCB_Window,
	uint,
	short,
	short,
	ushort,
	ushort,
	ushort,
	ushort,
	uint,
	uint,
	void*
);
alias FnXcbInternAtom = fn uint(Connection, char only_if_exists, ushort name_len, char* name);
alias FnXcbInternAtomReply = fn InternAtomReply*(Connection, uint cookie, void* err);

// xcb_intern_atom_reply_t — only the trailing atom field is needed.
struct InternAtomReply
{
	char response_type;
	char pad0;
	short sequence;
	uint length;
	uint atom;
}

// xcb_client_message_event_t, truncated to the first data32 slot. For a
// WM_PROTOCOLS message that slot holds the specific protocol atom (e.g.
// WM_DELETE_WINDOW).
struct ClientMessageEvent
{
	char response_type;
	char format;
	short sequence;
	uint window;
	uint type;
	uint data0;
}

// xcb_query_pointer_reply_t. root_x/root_y are screen-relative; win_x/win_y are
// relative to the queried window (what hit-testing needs).
struct QueryPointerReply
{
	char response_type;
	char same_screen;
	short sequence;
	uint length;
	uint root;
	uint child;
	short root_x;
	short root_y;
	short win_x;
	short win_y;
	ushort mask;
}

// Function pointers loaded at runtime via dlsym
FnOpenDisplay openDisplay;
FnXCloseDisplay x_close_display;
FnXCreateFontCursor xCreateFontCursor;
FnXDefineCursor xDefineCursor;
FnXFreeCursor xFreeCursor;
FnXFlush xFlush;
FnXcbConnect xcbConnect;
FnXcbGetSetup xcbGetSetup;
FnXcbRootsIterator xcbRootsIterator;
FnXcbGenerateId xcbWindowId;
FnXcbMapWindow xcbMapWindow;
FnXcbFlush xcbFlush;
FnXcbPollForEvent xcbPollEvent;
FnXcbPollForEvent xcbPollQueuedEvent;
FnXcbWaitForEvent xcbWaitForEvent;
FnXcbChangeProperty xcbChangeProperty;
FnXcbQueryPointer xcbQueryPointer;
FnXcbQueryPointerReply xcbQueryPointerReply;
FnXcbDestroyWindow xcbDestroy;
FnXcbDisconnect xcbDisconnect;
FnXcbCreateWindow createWindow;
FnXcbInternAtom xcbInternAtom;
FnXcbInternAtomReply xcbInternAtomReply;

// Library handles
void* _x11_lib;
void* _xcb_lib;

fn bool x11_load()
{
	if (_x11_lib) return true;

	_x11_lib = dlopen("libX11.so.6", RTLD_LAZY);
	if (!_x11_lib) return false;

	_xcb_lib = dlopen("libxcb.so.1", RTLD_LAZY);
	if (!_xcb_lib)
	{
		dlclose(_x11_lib);
		_x11_lib = null;
		return false;
	}

	openDisplay = (FnOpenDisplay)dlsym(_x11_lib, "XOpenDisplay");
	x_close_display = (FnXCloseDisplay)dlsym(_x11_lib, "XCloseDisplay");
	xCreateFontCursor = (FnXCreateFontCursor)dlsym(_x11_lib, "XCreateFontCursor");
	xDefineCursor = (FnXDefineCursor)dlsym(_x11_lib, "XDefineCursor");
	xFreeCursor = (FnXFreeCursor)dlsym(_x11_lib, "XFreeCursor");
	xFlush = (FnXFlush)dlsym(_x11_lib, "XFlush");
	xcbConnect = (FnXcbConnect)dlsym(_xcb_lib, "xcb_connect");
	xcbGetSetup = (FnXcbGetSetup)dlsym(_xcb_lib, "xcb_get_setup");
	xcbRootsIterator = (FnXcbRootsIterator)dlsym(_xcb_lib, "xcb_setup_roots_iterator");
	xcbWindowId = (FnXcbGenerateId)dlsym(_xcb_lib, "xcb_generate_id");
	xcbMapWindow = (FnXcbMapWindow)dlsym(_xcb_lib, "xcb_map_window");
	xcbFlush = (FnXcbFlush)dlsym(_xcb_lib, "xcb_flush");
	xcbPollEvent = (FnXcbPollForEvent)dlsym(_xcb_lib, "xcb_poll_for_event");
	xcbPollQueuedEvent = (FnXcbPollForEvent)dlsym(_xcb_lib, "xcb_poll_for_queued_event");
	xcbWaitForEvent = (FnXcbWaitForEvent)dlsym(_xcb_lib, "xcb_wait_for_event");
	xcbChangeProperty = (FnXcbChangeProperty)dlsym(_xcb_lib, "xcb_change_property");
	xcbQueryPointer = (FnXcbQueryPointer)dlsym(_xcb_lib, "xcb_query_pointer");
	xcbQueryPointerReply = (FnXcbQueryPointerReply)dlsym(_xcb_lib, "xcb_query_pointer_reply");
	xcbDestroy = (FnXcbDestroyWindow)dlsym(_xcb_lib, "xcb_destroy_window");
	xcbDisconnect = (FnXcbDisconnect)dlsym(_xcb_lib, "xcb_disconnect");
	createWindow = (FnXcbCreateWindow)dlsym(_xcb_lib, "xcb_create_window");
	xcbInternAtom = (FnXcbInternAtom)dlsym(_xcb_lib, "xcb_intern_atom");
	xcbInternAtomReply = (FnXcbInternAtomReply)dlsym(_xcb_lib, "xcb_intern_atom_reply");

	return true;
}


enum XcbProp : uint (uint value)
{
	PROP_MODE_REPLACE { 0 },
	PROP_MODE_PREPEND { 1 },
	PROP_MODE_APPEND  { 2 },
}

enum XcbEventMask : uint (uint value)
{
	CW_EVENT_MASK                  { 2048 },
	BACK_PIXEL                     { 2 },
	CW_CURSOR                      { 16384 },
	EVENT_MASK_NO_EVENT            { 0 },
	EVENT_MASK_EXPOSURE            { 32768 },
	EVENT_MASK_BUTTON_PRESS        { 4 },
	EVENT_MASK_BUTTON_RELEASE      { 8 },
	EVENT_MASK_KEY_PRESS           { 1 },
	EVENT_MASK_KEY_RELEASE         { 2 },
	EVENT_MASK_POINTER_MOTION      { 64 },
	EVENT_MASK_POINTER_MOTION_HINT { 128 },
	EVENT_MASK_STRUCTURE_NOTIFY    { 131072 },
	EVENT_MASK_VISIBILITY_CHANGE   { 65536 },
}

enum XcbPropMode : uint (uint value)
{
	PROP_MODE_REPLACE { 0 },
	PROP_MODE_PREPEND { 1 },
	PROP_MODE_APPEND  { 2 },
}

struct XscreenData
{
	uint root;
	uint aliasault_colormap;
	uint white_pixel;
	uint black_pixel;
	uint current_input_masks;
	ushort width_in_pixels;
	ushort height_in_pixels;
	ushort width_in_millimeters;
	ushort height_in_millimeters;
	ushort min_installed_maps;
	ushort max_installed_maps;
	uint root_visual;
	char backing_stores;
	char save_unders;
	char root_depth;
	char allowed_depths_len;
}

struct XScreenIterator
{
	inline XscreenData data;
	int rem;
	int index;
}

struct KeyPressEvent
{
	char type;
	char value;
	short sequence;
	uint time;
	uint root;
	uint event;
	uint child;
	short root_x;
	short root_y;
	short event_x;
	short event_y;
	short state;
	char same_screen;
}

// Test if X11 is available
fn bool x11_available()
{
	if (!x11_load()) return false;
	X11Display dpy = openDisplay(null);
	if (dpy)
	{
		// Don't leak the display, just checking
		x_close_display(dpy);
		return true;
	}
	return false;
}

// Creates new XCB window
fn X11Window? x11_create(Params params, String name)
{
	X11Display dpy = openDisplay(null);

	if (!dpy)
	{
		io::printfn("Failed to open display");
		return FAILED_OPENING_WINDOW~;
	}

	Connection connection            = xcbConnect(null, null);
	XCB_setup setup                  = xcbGetSetup(connection);
	XScreenIterator* screen_iterator = xcbRootsIterator(setup);

	XCB_Window window = xcbWindowId(connection);

	uint mask = XcbEventMask.BACK_PIXEL.value | XcbEventMask.CW_EVENT_MASK.value;
	uint[] event_masks = {
		screen_iterator.data.black_pixel,
		XcbEventMask.EVENT_MASK_EXPOSURE.value | XcbEventMask.EVENT_MASK_KEY_PRESS.value
			| XcbEventMask.EVENT_MASK_KEY_RELEASE.value
			| XcbEventMask.EVENT_MASK_BUTTON_PRESS.value
			| XcbEventMask.EVENT_MASK_BUTTON_RELEASE.value
			| XcbEventMask.EVENT_MASK_POINTER_MOTION.value
	};

	uint cookie = createWindow(
		connection,
		0,
		window,
		screen_iterator.data.root,
		(short)params.x,
		(short)params.y,
		(ushort)params.width,
		(ushort)params.height,
		(ushort)1,
		1,
		screen_iterator.data.root_visual,
		mask,
		&event_masks[0]
	);

	xcbMapWindow(connection, window);
	xcbFlush(connection);

	// Change window name
	// XCB_ATOM_WM_NAME, XCB_ATOM_STRING
	xcbChangeProperty(connection, XcbProp.PROP_MODE_REPLACE, window, 39, 31, 8, name.len, name);

	// Opt into the WM_DELETE_WINDOW protocol: set WM_PROTOCOLS to the single
	// atom WM_DELETE_WINDOW so the window manager sends a ClientMessage when the
	// user closes the window, instead of severing the connection. type = ATOM
	// (4), format = 32, one 32-bit atom.
	uint wm_protocols     = x11_intern_atom(connection, "WM_PROTOCOLS");
	uint wm_delete_window = x11_intern_atom(connection, "WM_DELETE_WINDOW");
	xcbChangeProperty(connection, XcbProp.PROP_MODE_REPLACE, window, wm_protocols, 4, 32, 1, (char*)&wm_delete_window);
	xcbFlush(connection);

	X11Window response = {
		.window = window,
		.connection = connection,
		.display = dpy,
		.display_width = screen_iterator.data.width_in_pixels,
		.display_height = screen_iterator.data.height_in_pixels,
		.initialized = true,
		.wm_delete_window = wm_delete_window,
		.text = dstring::new(mem),
	};

	x11_init_xkb(&response);
	return response;
}

// Build an xkb keymap/state from the X server's current keyboard layout, so
// KeyPress events decode to correct typed text. Leaves xkb_state null (ASCII
// fallback) if libxkbcommon-x11 is missing or the extension can't be set up.
fn void x11_init_xkb(X11Window* self)
{
	if (!xkb_x11_load()) return;

	ushort major_out;
	ushort minor_out;
	char base_event;
	char base_error;
	if (xkb_x11_setup_xkb_extension(self.connection, 1, 0, 0, &major_out, &minor_out, &base_event, &base_error) == 0) return;

	int device = xkb_x11_get_core_keyboard_device_id(self.connection);
	if (device == -1) return;

	self.xkb_context = xkb_context_new(0);
	if (self.xkb_context == null) return;

	self.xkb_keymap = xkb_x11_keymap_new_from_device(self.xkb_context, self.connection, device, 0);
	if (self.xkb_keymap == null) return;

	self.xkb_state = xkb_x11_state_new_from_device(self.xkb_keymap, self.connection, device);
}

// Interns an X atom by name, returning its id (0 on failure).
fn uint x11_intern_atom(Connection connection, String name)
{
	uint cookie          = xcbInternAtom(connection, 0, (ushort)name.len, (char*)name.ptr);
	InternAtomReply* reply = xcbInternAtomReply(connection, cookie, null);
	if (reply == null) return 0;
	uint atom = reply.atom;
	free(reply);
	return atom;
}

fn float[<2>] x11_getMousePos(X11Window* self)
{
	void* err;
	QueryPointerReply* reply = (QueryPointerReply*)xcbQueryPointerReply(
		self.connection,
		xcbQueryPointer(self.connection, self.window),
		&err
	);
	float[<2>] response = reply != null ? (float[<2>]) { reply.win_x, reply.win_y } : (float[<2>]) { 0, 0 };
	free(reply);
	free(err);
	return response;
}

fn void x11_pollEvents(X11Window* self, bool wait = false)
{
	// Per-frame state: scroll and typed text accumulate over this call only; the
	// latched key/button map persists across frames.
	self.event_map.set(MOUSE_SCROLL_UP, false);
	self.event_map.set(MOUSE_SCROLL_DOWN, false);
	self.scroll_delta = 0;
	self.text.clear();

	// Push any queued requests to the server before we (possibly) block.
	xcbFlush(self.connection);

	// Drain everything queued since the last call — handling a single event per
	// frame loses press/release edges and lags typing. On the first fetch of an
	// on-demand frame (wait), block until an event arrives so the thread parks at
	// ~0% CPU; the rest of the queue is then drained without blocking.
	bool first = true;
	while (true)
	{
		KeyPressEvent* event = (first && wait)
			? xcbWaitForEvent(self.connection)
			: xcbPollEvent(self.connection);
		first = false;
		if (event == null) break;

		x11_handleEvent(self, event);
		free(event);
	}
}

fn void x11_handleEvent(X11Window* self, KeyPressEvent* event) @private
{
	// The high bit of response_type marks synthetic (SendEvent) events; mask it.
	uint type = (uint)event.type & 0x7f;

	switch (type)
	{
		case 2: // KeyPress
			{
				uint keycode = (uint)event.value;
				EventKey key = linuxScancodeToEventKey(keycode);
				if (key != EMPTY_KEY) self.event_map.set(key, true);

				// Decode typed text: prefer the layout-aware xkb path (keeping its
				// modifier state in sync via update_key), else the US-QWERTY table
				// with shift read from state bit 0.
				if (self.xkb_state != null)
				{
					xkb_append_text(self.xkb_state, keycode, &self.text);
					xkb_state_update_key(self.xkb_state, keycode, XKB_KEY_DOWN);
				}
				else
				{
					bool shift = (event.state & 1) != 0;
					char c = linuxScancodeToText(keycode, shift);
					if (c != 0) self.text.append_char(c);
				}
			}
		case 3: // KeyRelease
			{
				uint keycode = (uint)event.value;
				EventKey key = linuxScancodeToEventKey(keycode);
				if (key != EMPTY_KEY) self.event_map.set(key, false);
				if (self.xkb_state != null) xkb_state_update_key(self.xkb_state, keycode, XKB_KEY_UP);
			}
		case 4: // ButtonPress
			x11_handleButton(self, (uint)event.value, true);
		case 5: // ButtonRelease
			x11_handleButton(self, (uint)event.value, false);
		case 33: // ClientMessage
			{
				ClientMessageEvent* msg = (ClientMessageEvent*)event;
				if (self.wm_delete_window != 0 && msg.data0 == self.wm_delete_window)
				{
					self.close_requested = true;
				}
			}
		default:
			break;
	}
}

// X11 button numbers: 1/2/3 = left/middle/right, 4/5 = vertical wheel up/down,
// 8/9 = back/forward. Wheel "presses" carry no release we care about.
fn void x11_handleButton(X11Window* self, uint button, bool pressed) @private
{
	switch (button)
	{
		case 1: self.event_map.set(LEFT_MOUSE, pressed);
		case 2: self.event_map.set(MIDDLE_MOUSE, pressed);
		case 3: self.event_map.set(RIGHT_MOUSE, pressed);
		case 4:
			if (pressed)
			{
				self.scroll_delta += 1.0;
				self.event_map.set(MOUSE_SCROLL_UP, true);
			}
		case 5:
			if (pressed)
			{
				self.scroll_delta -= 1.0;
				self.event_map.set(MOUSE_SCROLL_DOWN, true);
			}
		case 8: self.event_map.set(MOUSE_4, pressed);
		case 9: self.event_map.set(MOUSE_5, pressed);
		default:
			break;
	}
}

fn float x11_get_scroll(X11Window* self) => (float)self.scroll_delta;
fn String x11_get_text(X11Window* self) => self.text.str_view();
fn bool x11_should_close(X11Window* self) => self.close_requested;

// X11 windows are already in physical pixels (no compositor-side scaling on a
// native X11 session), so there is nothing to compensate for. A DPI-aware
// scale would come from Xft.dpi; not consulted yet.
fn float x11_get_scale(X11Window* self) => 1.0;

// X11 cursorfont glyph ids (from X11/cursorfont.h) for each unified shape.
fn uint x11_cursor_font(CursorShape shape)
{
	switch (shape)
	{
		case ARROW:         return 68;  // XC_left_ptr
		case POINTING_HAND: return 60;  // XC_hand2
		case IBEAM:         return 152; // XC_xterm
		case CROSSHAIR:     return 34;  // XC_crosshair
		case OPEN_HAND:     return 58;  // XC_hand1
		case CLOSED_HAND:   return 60;  // XC_hand2 (no dedicated closed hand)
		case RESIZE_H:      return 108; // XC_sb_h_double_arrow
		case RESIZE_V:      return 116; // XC_sb_v_double_arrow
		default:            return 68;
	}
}

fn void x11_set_cursor(X11Window* self, CursorShape shape)
{
	if (self.display == null || xCreateFontCursor == null) return;

	ulong cursor = xCreateFontCursor(self.display, x11_cursor_font(shape));
	xDefineCursor(self.display, (ulong)(uptr)self.window, cursor);
	xFlush(self.display);

	// Release the previous cursor now that the new one is installed.
	if (self.current_cursor != 0) xFreeCursor(self.display, (ulong)self.current_cursor);
	self.current_cursor = (uint)cursor;
}

// Free and destroys window instance
fn void x11_free(X11Window* self)
{
	self.text.free();
	xkb_free(self.xkb_context, self.xkb_keymap, self.xkb_state);
	xcbDestroy(self.connection, self.window);
	if (self.display) x_close_display(self.display);
	xcbDisconnect(self.connection);
	self.initialized = false;
}
