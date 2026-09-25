module c3w @feat(LINUX);
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
	EventLog event_log;     // the transitions behind the map, same poll
	uint display_width;
	uint display_height;
	bool initialized;
	uint wm_delete_window;  // WM_DELETE_WINDOW atom, watched in the event loop
	bool close_requested;   // set once the window manager asks us to close
	double scroll_delta;    // accumulated over the last poll (+ = up)
	double scroll_delta_x;  // the horizontal half (+ = right)
	DString text;           // text typed during the last poll
	uint current_cursor;    // active X cursor resource (0 = none created yet)
	// What was last asked for through `x11_set_fullscreen`. The manager may
	// refuse, and a `_NET_WM_STATE` read back would be the true answer; this is
	// the cheap one, and it is what every other backend reports too.
	bool is_fullscreen;
	// The size the last ConfigureNotify settled on. The window manager is free
	// to adjust or refuse what `x11_set_size` asked for, so this is the only
	// number that is true — `Params` is a request and goes stale the first time
	// anybody drags an edge.
	uint width;
	uint height;
	// `_C3W_WAKE`, the ClientMessage type `x11_wake` sends to this window. Its
	// own atom rather than a reused one so the handler can tell a wake from a
	// WM_DELETE_WINDOW without reading further into the message.
	uint wake_atom;
	// The clipboard (see clipboard.c3): its atoms, interned on first use; the
	// text while this window owns the CLIPBOARD selection; and the events a
	// paste read past while it waited for its answer, for the next poll.
	uint atom_clipboard;
	uint atom_utf8;
	uint atom_targets;
	uint atom_clip_property;
	DString clip_text;
	bool clip_owned;
	KeyPressEvent*[64] stash;
	int stash_count;
	// The screen's root window. `_NET_WM_STATE` is a message to the root rather
	// than to us — the window manager is the one acting on it.
	uint root;
	// Pointer lock. `blank_cursor` is a 1x1 transparent cursor made on the first
	// lock and kept for the window's life — creating one per call would churn a
	// server resource sixty times a second. `shape_cursor` is what
	// `x11_set_cursor` was last asked for, so unlocking puts back the shape the
	// caller believes is showing rather than the arrow.
	bool pointer_locked;
	ulong blank_cursor;
	CursorShape shape_cursor;
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
// xcb_configure_window(c, window, value_mask, value_list). The cookie it
// returns is a one-field struct, which the ABI passes back as a plain uint.
alias FnXcbConfigureWindow = fn uint(Connection, XCB_Window, ushort, void*);
// Xlib rather than xcb: iconifying properly means an ICCCM WM_CHANGE_STATE
// client message sent to the root window, and XIconifyWindow is that, already
// written. The display is open either way — xcb_connect rides on it.
alias FnXIconifyWindow = fn int(X11Display, ulong window, int screen);
// xcb_send_event(c, propagate, destination, event_mask, event). The event is a
// 32-byte buffer whatever its type — the protocol pads every event to that.
alias FnXcbSendEvent = fn uint(Connection, char propagate, XCB_Window destination, uint event_mask, char* event);
// Xlib for the pointer-lock pieces: xcb has no equivalent of
// XCreateBitmapFromData, and the warp wants the display anyway.
alias FnXCreateBitmapFromData = fn ulong(X11Display, ulong drawable, char* data, uint width, uint height);
alias FnXCreatePixmapCursor = fn ulong(X11Display, ulong source, ulong mask, XColor* fg, XColor* bg, uint x, uint y);
alias FnXFreePixmap = fn int(X11Display, ulong pixmap);
alias FnXWarpPointer = fn int(
	X11Display, ulong src, ulong dest, int src_x, int src_y, uint src_w, uint src_h, int dest_x, int dest_y
);
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

// xcb_configure_notify_event_t. The window manager sends one for every geometry
// change it settles, including the ones it made up in answer to a request.
// The same event with all five data words. `_NET_WM_STATE` uses three of them,
// and `ClientMessageEvent` above stops at the first.
struct WmStateEvent
{
	char response_type;
	char format;
	short sequence;
	uint window;
	uint type;
	uint data0;
	uint data1;
	uint data2;
	uint data3;
	uint data4;
}

struct ConfigureNotifyEvent
{
	char response_type;
	char pad0;
	short sequence;
	uint event;
	uint window;
	uint above_sibling;
	short x;
	short y;
	ushort width;
	ushort height;
	ushort border_width;
	char override_redirect;
	char pad1;
}

// XColor. Both colours of a 1x1 transparent cursor are unused — the pixmap has
// no set bits — but XCreatePixmapCursor dereferences them, so they are passed
// as zeroed structs rather than null.
struct XColor
{
	ulong pixel;
	ushort red;
	ushort green;
	ushort blue;
	char flags;
	char pad;
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
FnXcbConfigureWindow xcbConfigureWindow;
FnXIconifyWindow xIconifyWindow;
FnXcbSendEvent xcbSendEvent;
FnXCreateBitmapFromData xCreateBitmapFromData;
FnXCreatePixmapCursor xCreatePixmapCursor;
FnXFreePixmap xFreePixmap;
FnXWarpPointer xWarpPointer;
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
	xcbConfigureWindow = (FnXcbConfigureWindow)dlsym(_xcb_lib, "xcb_configure_window");
	xIconifyWindow = (FnXIconifyWindow)dlsym(_x11_lib, "XIconifyWindow");
	xcbSendEvent = (FnXcbSendEvent)dlsym(_xcb_lib, "xcb_send_event");
	xCreateBitmapFromData = (FnXCreateBitmapFromData)dlsym(_x11_lib, "XCreateBitmapFromData");
	xCreatePixmapCursor = (FnXCreatePixmapCursor)dlsym(_x11_lib, "XCreatePixmapCursor");
	xFreePixmap = (FnXFreePixmap)dlsym(_x11_lib, "XFreePixmap");
	xWarpPointer = (FnXWarpPointer)dlsym(_x11_lib, "XWarpPointer");
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
	// The two the window manager selects on the root window. A `_NET_WM_STATE`
	// message is addressed to the root and is meant for the manager, so it is
	// sent with these rather than with a zero mask.
	EVENT_MASK_SUBSTRUCTURE_NOTIFY   { 524288 },
	EVENT_MASK_SUBSTRUCTURE_REDIRECT { 1048576 },
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
			// ConfigureNotify, and the whole of how this backend learns its own
			// size. Without it the window is however big `Params` said forever.
			| XcbEventMask.EVENT_MASK_STRUCTURE_NOTIFY.value
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
	// Not a protocol anybody else knows: this is only ever sent by this process
	// to this window, to break a `xcb_wait_for_event` that is parked.
	uint wake_atom        = x11_intern_atom(connection, "_C3W_WAKE");
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
		.wake_atom = wake_atom,
		.root = screen_iterator.data.root,
		// What was asked for, until the first ConfigureNotify says otherwise.
		// The server sends one when the window is mapped, so this is the answer
		// for a handful of milliseconds at most.
		.width = (uint)params.width,
		.height = (uint)params.height,
		.shape_cursor = CursorShape.ARROW,
		.text = dstring::new(mem),
		.clip_text = dstring::new(mem),
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
	self.scroll_delta_x = 0;
	self.text.clear();
	self.event_log.clear();

	// What a paste read past, first, so the order holds.
	x11_drain_stash(self);

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
				if (key != EMPTY_KEY)
				{
					self.event_map.set(key, true);
					self.event_log.push_key(key, true);
				}

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
				if (key != EMPTY_KEY)
				{
					self.event_map.set(key, false);
					self.event_log.push_key(key, false);
				}
				if (self.xkb_state != null) xkb_state_update_key(self.xkb_state, keycode, XKB_KEY_UP);
			}
		case 4: // ButtonPress
			x11_handleButton(self, (uint)event.value, true);
		case 5: // ButtonRelease
			x11_handleButton(self, (uint)event.value, false);
		case 22: // ConfigureNotify
			{
				ConfigureNotifyEvent* moved = (ConfigureNotifyEvent*)event;
				// The window manager reparents, so a ConfigureNotify for the frame
				// arrives here too; only this window's own geometry is ours.
				if (moved.window == (uint)(uptr)self.window)
				{
					self.width = (uint)moved.width;
					self.height = (uint)moved.height;
				}
			}
		case 29: // SelectionClear
			x11_selection_clear(self, event);
		case 30: // SelectionRequest
			x11_selection_request(self, event);
		case 33: // ClientMessage
			{
				ClientMessageEvent* msg = (ClientMessageEvent*)event;
				// A wake carries no information beyond having arrived — it exists to
				// make a parked `xcb_wait_for_event` return, and the caller's own
				// work is what happens next.
				if (self.wake_atom != 0 && msg.type == self.wake_atom) break;
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
// 6/7 = horizontal tilt/two-finger left/right, 8/9 = back/forward. Wheel
// "presses" carry no release we care about.
fn void x11_handleButton(X11Window* self, uint button, bool pressed) @private
{
	switch (button)
	{
		case 1: self.event_map.set(LEFT_MOUSE, pressed);   self.event_log.push_button(LEFT_MOUSE, pressed);
		case 2: self.event_map.set(MIDDLE_MOUSE, pressed); self.event_log.push_button(MIDDLE_MOUSE, pressed);
		case 3: self.event_map.set(RIGHT_MOUSE, pressed);  self.event_log.push_button(RIGHT_MOUSE, pressed);
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
		// A core-protocol horizontal scroll arrives as a button too. There is no
		// matching EventKey to latch, and there does not need to be — the delta
		// is what a caller wants, and nothing has ever asked "is the pointer
		// currently scrolled left".
		case 6:
			if (pressed) self.scroll_delta_x -= 1.0;
		case 7:
			if (pressed) self.scroll_delta_x += 1.0;
		case 8: self.event_map.set(MOUSE_4, pressed); self.event_log.push_button(MOUSE_4, pressed);
		case 9: self.event_map.set(MOUSE_5, pressed); self.event_log.push_button(MOUSE_5, pressed);
		default:
			break;
	}
}

<*
 The size the last ConfigureNotify settled on, in pixels.

 Answered from a latch rather than by asking the server, because the caller is
 the frame loop and a round trip per frame to learn a number that changes when
 somebody drags an edge is a poor trade. The latch is exact: X11 sends a
 ConfigureNotify for every geometry change, including the ones nobody asked for.
*>
fn uint[<2>] x11_get_size(X11Window* self) => { self.width, self.height };

<*
 Break a `xcb_wait_for_event` that is parked, from any thread.

 A ClientMessage sent to our own window with an event mask of zero, which is
 delivered to the window's own event queue and nowhere else. Legal from a
 foreign thread: xcb serialises writes on the connection, and this writes and
 flushes and touches nothing else on the window.

 The mask is deliberately zero rather than STRUCTURE_NOTIFY: a zero mask means
 "deliver to the destination itself", where a real mask would also hand it to
 anybody selecting for that event on the window, which for a reparented window
 is the window manager.
*>
fn void x11_wake(X11Window* self)
{
	if (self.connection == null || xcbSendEvent == null || self.wake_atom == 0) return;

	// Every X event is 32 bytes on the wire whatever it holds, and the tail of
	// this one is the ClientMessage's 20 data bytes, which say nothing.
	char[32] message;
	ClientMessageEvent* wake = (ClientMessageEvent*)&message;
	wake.response_type = 33; // ClientMessage
	wake.format = 32;
	wake.window = (uint)(uptr)self.window;
	wake.type = self.wake_atom;

	xcbSendEvent(self.connection, 0, self.window, 0, &message);
	xcbFlush(self.connection);
}

<*
 Rename the window.

 Both properties, because window managers disagree about which one to read:
 `_NET_WM_NAME` is UTF-8 and is what anything current prefers, and `WM_NAME`
 (atom 39, type `STRING` 31) is the core-protocol one `new` already sets and
 older managers still use. Setting one and not the other leaves a title bar
 disagreeing with a taskbar.

 The atoms are interned per call rather than kept. Each is one round trip and
 this happens when a game boots or a person opens a settings menu, which is not
 a rate worth caching against.
*>
fn void x11_set_title(X11Window* self, String title)
{
	if (self.connection == null || xcbChangeProperty == null) return;

	uint net_wm_name = x11_intern_atom(self.connection, "_NET_WM_NAME");
	uint utf8_string = x11_intern_atom(self.connection, "UTF8_STRING");
	if (net_wm_name != 0 && utf8_string != 0)
	{
		xcbChangeProperty(
			self.connection,
			XcbProp.PROP_MODE_REPLACE,
			self.window,
			net_wm_name,
			utf8_string,
			8,
			(uint)title.len,
			(char*)title.ptr
		);
	}
	xcbChangeProperty(self.connection, XcbProp.PROP_MODE_REPLACE, self.window, 39, 31, 8, (uint)title.len, (char*)title.ptr);
	xcbFlush(self.connection);
}

<*
 Ask the window manager to make this window fullscreen, or to stop.

 A `_NET_WM_STATE` ClientMessage to the ROOT window, which is how the EWMH
 spells every state change a client wants: the manager owns the window's
 geometry and decorations, so a client that moved itself over the monitor would
 be fighting whatever the manager did next.

 The mask matters here where `x11_wake`'s zero mask did not. This message is for
 the window manager, which selects `SubstructureRedirect` and
 `SubstructureNotify` on the root, and a zero mask would deliver it to the root
 window itself, where nobody is listening.

 It is a request. A manager may refuse, and a bare X session with no manager at
 all will do nothing — there is no one to act on it.
*>
fn void x11_set_fullscreen(X11Window* self, bool on)
{
	if (self.connection == null || xcbSendEvent == null || self.root == 0) return;

	uint state      = x11_intern_atom(self.connection, "_NET_WM_STATE");
	uint fullscreen = x11_intern_atom(self.connection, "_NET_WM_STATE_FULLSCREEN");
	if (state == 0 || fullscreen == 0) return;

	char[32] message;
	WmStateEvent* ask = (WmStateEvent*)&message;
	ask.response_type = 33; // ClientMessage
	ask.format = 32;
	ask.window = (uint)(uptr)self.window;
	ask.type = state;
	// _NET_WM_STATE_REMOVE 0, _NET_WM_STATE_ADD 1.
	ask.data0 = on ? 1 : 0;
	ask.data1 = fullscreen;
	ask.data2 = 0;
	// Source indication: 1 is "a normal application", which is what a manager
	// with a focus-stealing policy wants to see.
	ask.data3 = 1;
	ask.data4 = 0;

	xcbSendEvent(
		self.connection,
		0,
		(XCB_Window)(uptr)self.root,
		XcbEventMask.EVENT_MASK_SUBSTRUCTURE_REDIRECT.value | XcbEventMask.EVENT_MASK_SUBSTRUCTURE_NOTIFY.value,
		&message
	);
	xcbFlush(self.connection);
	self.is_fullscreen = on;
}

fn bool x11_fullscreen(X11Window* self) => self.is_fullscreen;

fn float x11_get_scroll(X11Window* self) => (float)self.scroll_delta;
fn float x11_get_scroll_x(X11Window* self) => (float)self.scroll_delta_x;

// Core-protocol X11 scrolling is buttons, so every scroll is a detent by
// construction — there is no pixel-precise path to report. A session running
// XInput2 valuators would have one; this backend does not read them.
fn bool x11_get_scroll_precise(X11Window* self) => false;
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

// xcb_config_window_t: WIDTH is bit 2, HEIGHT bit 3.
const ushort XCB_CONFIG_WINDOW_WIDTH  = 1 << 2;
const ushort XCB_CONFIG_WINDOW_HEIGHT = 1 << 3;

<*
 Resize the window, in pixels.

 X11 has no window chrome in the client's rectangle — the frame the window
 manager draws is a separate parent window — so unlike macOS and Win32 there is
 nothing to add back, and this size is the drawable size directly.

 The window manager is free to refuse or adjust it; the ConfigureNotify that
 follows is what actually settled, which is why nothing is recorded here.
*>
fn void x11_set_size(X11Window* self, int width, int height)
{
	if (self.connection == null || xcbConfigureWindow == null) return;
	if (width <= 0 || height <= 0) return;

	uint[2] values = { (uint)width, (uint)height };
	xcbConfigureWindow(
		self.connection,
		self.window,
		XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
		&values
	);
	xcbFlush(self.connection);
}

<*
 Minimise the window, or restore it.

 Restoring is a plain map: an iconified window is unmapped, so mapping it again
 is what brings it back, and that is the same call `new` uses to show it in the
 first place.
*>
fn void x11_set_minimized(X11Window* self, bool minimized)
{
	if (self.connection == null) return;

	if (minimized)
	{
		if (self.display == null || xIconifyWindow == null) return;
		// Screen 0: c3w opens the default display and takes its first screen.
		xIconifyWindow(self.display, (ulong)(uptr)self.window, 0);
		if (xFlush != null) xFlush(self.display);
		return;
	}

	if (xcbMapWindow == null) return;
	xcbMapWindow(self.connection, self.window);
	xcbFlush(self.connection);
}

fn void x11_set_cursor(X11Window* self, CursorShape shape)
{
	// Remembered whatever happens next, so unlocking the pointer can put back the
	// shape the caller believes is showing.
	self.shape_cursor = shape;
	// A locked pointer is a hidden one, and the frame loop goes on asking for
	// shapes underneath the lock — a hover over something clickable still wants
	// a hand. Installing one here would make the cursor reappear in the middle
	// of a mouse look.
	if (self.pointer_locked) return;

	if (self.display == null || xCreateFontCursor == null) return;

	ulong cursor = xCreateFontCursor(self.display, x11_cursor_font(shape));
	xDefineCursor(self.display, (ulong)(uptr)self.window, cursor);
	xFlush(self.display);

	// Release the previous cursor now that the new one is installed.
	if (self.current_cursor != 0) xFreeCursor(self.display, (ulong)self.current_cursor);
	self.current_cursor = (uint)cursor;
}

<*
 A 1x1 transparent cursor, made once and kept.

 The way to hide a pointer in the core protocol: a cursor whose source bitmap
 has no bit set draws nothing, and X has no "no cursor" to define instead. Made
 lazily because a window that never locks should not pay for a server resource,
 and kept afterwards because a lock that made one per call would churn one
 sixty times a second.

 @return `Zero when the X symbols for it are missing, which is a lock that cannot be given.`
*>
fn ulong x11_blank_cursor(X11Window* self) @private
{
	if (self.blank_cursor != 0) return self.blank_cursor;
	if (self.display == null || xCreateBitmapFromData == null || xCreatePixmapCursor == null) return 0;

	char[1] nothing = { 0 };
	ulong pixmap = xCreateBitmapFromData(self.display, (ulong)(uptr)self.window, &nothing[0], 1, 1);
	if (pixmap == 0) return 0;

	// Source and mask are the same empty bitmap, so no pixel of the cursor is
	// drawn and neither colour is ever read. They are passed as zeroed structs
	// rather than null because XCreatePixmapCursor dereferences both.
	XColor unused;
	self.blank_cursor = xCreatePixmapCursor(self.display, pixmap, pixmap, &unused, &unused, 0, 0);
	if (xFreePixmap != null) xFreePixmap(self.display, pixmap);
	return self.blank_cursor;
}

<*
 Take the pointer, or give it back.

 Hiding it is a cursor; keeping it is `x11_warp_to_centre`, called once per poll
 from `Window.track_mouse_delta`. There is no grab: a grab would also take the
 keyboard focus question and every click on the desktop with it, and re-centring
 every frame already means the cursor never travels far enough to leave.

 **Nothing is latched on failure.** If the cursor cannot be made, this stays
 unlocked and `x11_pointer_locked` goes on answering false — which is the signal
 a script branches on to fall back to a drag-look, and a flag recorded here
 would have turned that into a look that silently stops at the edge of a screen.
*>
fn void x11_set_pointer_lock(X11Window* self, bool locked)
{
	if (locked == self.pointer_locked) return;

	if (!locked)
	{
		self.pointer_locked = false;
		x11_set_cursor(self, self.shape_cursor);
		return;
	}

	if (xDefineCursor == null) return;
	ulong blank = x11_blank_cursor(self);
	if (blank == 0) return;

	xDefineCursor(self.display, (ulong)(uptr)self.window, blank);
	xFlush(self.display);
	self.pointer_locked = true;
	x11_warp_to_centre(self);
}

fn bool x11_pointer_locked(X11Window* self) => self.pointer_locked;

<*
 Put the cursor back in the middle of the window.

 What makes the movement a hand's rather than a cursor's: the reading before
 this one is how far it got from the centre, and returning it there means the
 next reading measures from the same place again. Without it the cursor walks to
 an edge of the screen and the look stops turning, which is the whole failure a
 lock exists to remove.

 A no-op unless locked, so the frame loop can call it unconditionally.
*>
fn void x11_warp_to_centre(X11Window* self)
{
	if (!self.pointer_locked || xWarpPointer == null) return;
	if (self.width == 0 || self.height == 0) return;

	// src = None: warp from wherever the pointer is, rather than only when it is
	// inside some source rectangle.
	xWarpPointer(
		self.display, 0, (ulong)(uptr)self.window, 0, 0, 0, 0, (int)(self.width / 2), (int)(self.height / 2)
	);
	xFlush(self.display);
}

// Free and destroys window instance
fn void x11_free(X11Window* self)
{
	if (self.blank_cursor != 0 && xFreeCursor != null) xFreeCursor(self.display, self.blank_cursor);
	self.text.free();
	self.clip_text.free();
	for (int i = 0; i < self.stash_count; i++) free(self.stash[i]);
	self.stash_count = 0;
	xkb_free(self.xkb_context, self.xkb_keymap, self.xkb_state);
	xcbDestroy(self.connection, self.window);
	if (self.display) x_close_display(self.display);
	xcbDisconnect(self.connection);
	self.initialized = false;
}
