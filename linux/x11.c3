module c3w @if(env::LINUX);
import std::math;

import std::io;
import std::core::types;

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
}

// Function pointer types for dynamic loading
alias FnOpenDisplay = fn X11Display(char* name);
alias FnXCloseDisplay = fn void(X11Display);
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
alias FnXcbCreateWindow = fn uint(Connection, char, XCB_Window, uint, short, short, ushort, ushort, ushort, ushort, uint, uint, void*);

// Function pointers loaded at runtime via dlsym
FnOpenDisplay openDisplay;
FnXCloseDisplay x_close_display;
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
	CW_EVENT_MASK              { 2048 },
	BACK_PIXEL                 { 2 },
	CW_CURSOR                  { 16384 },
	EVENT_MASK_NO_EVENT        { 0 },
	EVENT_MASK_EXPOSURE        { 32768 },
	EVENT_MASK_BUTTON_PRESS    { 4 },
	EVENT_MASK_BUTTON_RELEASE  { 8 },
	EVENT_MASK_KEY_PRESS       { 1 },
	EVENT_MASK_KEY_RELEASE     { 2 },
	EVENT_MASK_POINTER_MOTION  { 64 },
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
	if (dpy) {
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

	Connection connection = xcbConnect(null, null);
	XCB_setup setup = xcbGetSetup(connection);
	XScreenIterator* screen_iterator = xcbRootsIterator(setup);

	XCB_Window window = xcbWindowId(connection);

	uint mask = XcbEventMask.BACK_PIXEL.value
		| XcbEventMask.CW_EVENT_MASK.value;
	uint[] event_masks = {
		screen_iterator.data.black_pixel,
		XcbEventMask.EVENT_MASK_EXPOSURE.value
			| XcbEventMask.EVENT_MASK_KEY_PRESS.value
			| XcbEventMask.EVENT_MASK_KEY_RELEASE.value
			| XcbEventMask.EVENT_MASK_BUTTON_PRESS.value
			| XcbEventMask.EVENT_MASK_BUTTON_RELEASE.value
	};

	uint cookie = createWindow(
		connection,
		0,
		window,
		screen_iterator.data.root,
		(short)params.x,
		(short)params.y,
		(short)params.width,
		(short)params.height,
		(short)1.0,
		1,
		screen_iterator.data.root_visual,
		mask,
		&event_masks[0]
	);

	xcbMapWindow(connection, window);
	xcbFlush(connection);

	// Change window name
	// XCB_ATOM_WM_NAME, XCB_ATOM_STRING
	xcbChangeProperty(
		connection,
		XcbProp.PROP_MODE_REPLACE,
		window,
		39,
		31,
		8,
		name.len,
		name
	);
	X11Window response = {
		.window = window,
		.connection = connection,
		.display = dpy,
		.display_width = screen_iterator.data.width_in_pixels,
		.display_height = screen_iterator.data.height_in_pixels,
		.initialized = true,
	};

	return response;
}

fn float[<2>] x11_getMousePos(X11Window* self)
{
	void* err;
	KeyPressEvent* mouse_pos = xcbQueryPointerReply(
		self.connection,
		xcbQueryPointer(self.connection, self.window),
		&err
	);
	float[<2>] response = { mouse_pos.root_x, mouse_pos.root_y };
	free(mouse_pos);
	free(err);
	return response;
}

fn void x11_pollEvents(X11Window* self, EventMap* event_map)
{
	KeyPressEvent* event = xcbPollEvent(self.connection);
	defer free(event);

	if (event != null)
	{
		EventType type = EventType.lookup_field(code, event.type)!!;
		EventKey key = EventKey.lookup_field(code, (uint)event.value)!!;

		switch (type)
		{
			case KEY_RELEASED:
			case MOUSE_RELEASED:
				{
					event_map.set(key, false);
				}
			case KEY_PRESSED:
			case MOUSE_PRESSED:
				{
					event_map.set(key, true);
					break;
				}
			default:
				{
				};
		}
	}
}

// Free and destroys window instance
fn void x11_free(X11Window* self)
{
	xcbDestroy(self.connection, self.window);
	xcbDisconnect(self.connection);
	self.initialized = false;
}
