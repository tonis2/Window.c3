module c3w @if(env::LINUX);
import std::math;
import std::io;
import std::core::types;


alias GlobalEvent = fn void(
	WaylandWindow* data,
	void* wl_registry,
	uint name,
	char* iface,
	uint ver
);
alias RemoveEvent = fn void(WaylandWindow* data, void* wl_registry, uint name);
alias ShellPing = fn void(WaylandWindow* data, Shell shell, uint serial);
alias SeatCapabilitiesEvent = fn void(
	WaylandWindow* data,
	void* wl_registry,
	uint capabilities
);
alias SeatNameEvent = fn void(WaylandWindow* data, void* wl_registry, char* name);

alias KBmapEvent = fn void(
	WaylandWindow* data,
	Keyboard kb,
	uint frmt,
	int fd,
	uint sz
);
alias KBenterEvent = fn void(
	WaylandWindow* data,
	Keyboard kb,
	uint ser,
	Surface surface,
	WLArray* keys
);
alias KBleaveEvent = fn void(
	WaylandWindow* data,
	Keyboard kb,
	uint ser,
	Surface surface
);
alias KBkeyEvent = fn void(
	WaylandWindow* data,
	Keyboard kb,
	uint serial,
	uint type,
	uint key,
	uint state
);
alias KBmodEvent = fn void(
	WaylandWindow* data,
	Keyboard kb,
	uint serial,
	uint dep,
	uint lat,
	uint lock,
	uint group
);
alias KBrepEvent = fn void(WaylandWindow* data, Keyboard kb, int rate, int del);

alias PointerEnter = fn void(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	Surface surface,
	int x,
	int y
);
alias PointerLeave = fn void(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	Surface surface
);
alias PointerMotion = fn void(
	WaylandWindow* data,
	Pointer pointer,
	uint time,
	int x,
	int y
);
alias PointerButton = fn void(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	uint time,
	uint button,
	uint state
);
alias PointerAxis = fn void(
	WaylandWindow* data,
	Pointer pointer,
	uint time,
	uint axis,
	int value
);
alias PointerFrame = fn void(WaylandWindow* data, Pointer pointer);
alias PointerAxisSrc = fn void(WaylandWindow* data, Pointer pointer, uint source);
alias PointerAxisStop = fn void(WaylandWindow* data, Pointer pointer, uint axis);
alias PointerAxisValue = fn void(
	WaylandWindow* data,
	Pointer pointer,
	uint axis,
	int value
);

alias Noop = fn void();

alias Registry = void*;
alias Proxy = void*;
alias Compositor = void*;
alias Shell = void*;
alias Surface = void*;
alias SubCompositor = void*;
alias Display = void*;
alias Seat = void*;
alias Keyboard = void*;
alias Pointer = void*;


struct WaylandWindow
{
	Display display;
	Surface surface;
	Shell shell;
	Seat seat;
	XDG_surface xdg_surface;
	XDG_top_level top_level;
	bool initialized;
	EventMap event_map;
	float[<2>] mouse_pos;
}

struct WLArray
{
	usz size;
	usz alloc;
	void* data;
}

struct WLMessage
{
	char* name;
	char* signature;
	char* types;
}

struct RegistryListener
{
	GlobalEvent global;
	RemoveEvent global_remove;
}

struct ShellListener
{
	ShellPing ping;
}

struct SeatListener
{
	SeatCapabilitiesEvent capabilities;
	SeatNameEvent name;
}

struct KeyboardListener
{
	KBmapEvent keymap;
	KBenterEvent enter;
	KBleaveEvent leave;
	KBkeyEvent key;
	KBmodEvent modifiers;
	KBrepEvent repeat_info;
}

struct PointerListener
{
	PointerEnter enter;
	PointerLeave leave;
	PointerMotion motion;
	PointerButton button;
	PointerAxis axis;
	void* frame;
	void* axis_source;
	void* axis_stop;
	void* axis_disc;
	void* axis_value;
	void* random;
}

struct MouseParams
{
	char type;
	ushort x;
	ushort y;
	ushort root_x;
	ushort root_y;
}

struct Interface
{
	char* name;
	int version;
	int method_count;
	Message* methods;
	int event_count;
	Message* events;
}

const uint WL_DISPLAY_GET_REGISTRY = 1;
const uint WL_REGISTRY_BIND = 0;
const uint WL_MARSHAL_FLAG_DESTROY = 1 << 0;

// Function pointer types for dynamic loading
alias FnWlDisplayConnect = fn Display(uint* window);
alias FnWlDisplayDisconnect = fn void(Display display);
alias FnWlProxyMarshalFlags = fn void*(Proxy proxy, uint opcode, void* inter, uint version, uint flags, ...);
alias FnWlProxyAddListener = fn int(Proxy registry, void* callback, void* data);
alias FnWlProxyDestroy = fn void(Proxy proxy);
alias FnWlProxyGetVersion = fn uint(Proxy proxy);
alias FnWlDisplayDispatch = fn int(Display display);
alias FnWlDisplayRoundtrip = fn int(Display display);
alias FnWlDisplayDispatchPending = fn int(Display display);
alias FnWlDisplayFlush = fn int(Display display);
alias FnWlDisplayPrepareRead = fn int(Display display);
alias FnWlDisplayReadEvents = fn int(Display display);
alias FnWlDisplayCancelRead = fn void(Display display);
alias FnWlDisplayGetFd = fn int(Display display);

// poll() from libc
struct PollFd
{
	int fd;
	short events;
	short revents;
}
const short POLLIN = 1;
extern fn int poll(PollFd* fds, uint nfds, int timeout) @extern("poll");

// Function pointers loaded at runtime via dlsym
FnWlDisplayConnect connect;
FnWlDisplayDisconnect disconnect;
FnWlProxyMarshalFlags proxy_marshal_flags;
FnWlProxyAddListener proxy_add_listener;
FnWlProxyDestroy proxy_destroy;
FnWlProxyGetVersion proxy_get_version;
FnWlDisplayDispatch dispatch;
FnWlDisplayRoundtrip rountrip;
FnWlDisplayDispatchPending dispatch_pending;
FnWlDisplayFlush display_flush;
FnWlDisplayPrepareRead prepare_read;
FnWlDisplayReadEvents read_events;
FnWlDisplayCancelRead cancel_read;
FnWlDisplayGetFd display_get_fd;

// Interface pointers loaded at runtime via dlsym
Interface* wl_registry_interface;
Interface* wl_compositor_interface;
Interface* wl_surface_interface;
Interface* wl_shell_interface;
Interface* wl_output_interface;
Interface* wl_seat_interface;
Interface* wl_subcompositor_interface;
Interface* wl_keyboard_interface;
Interface* wl_pointer_interface;

// Library handle
void* _wl_lib;

fn bool wayland_load()
{
	if (_wl_lib) return true;

	_wl_lib = dlopen("libwayland-client.so.0", RTLD_LAZY);
	if (!_wl_lib) return false;

	// Load functions
	connect = (FnWlDisplayConnect)dlsym(_wl_lib, "wl_display_connect");
	disconnect = (FnWlDisplayDisconnect)dlsym(_wl_lib, "wl_display_disconnect");
	proxy_marshal_flags = (FnWlProxyMarshalFlags)dlsym(_wl_lib, "wl_proxy_marshal_flags");
	proxy_add_listener = (FnWlProxyAddListener)dlsym(_wl_lib, "wl_proxy_add_listener");
	proxy_destroy = (FnWlProxyDestroy)dlsym(_wl_lib, "wl_proxy_destroy");
	proxy_get_version = (FnWlProxyGetVersion)dlsym(_wl_lib, "wl_proxy_get_version");
	dispatch = (FnWlDisplayDispatch)dlsym(_wl_lib, "wl_display_dispatch");
	rountrip = (FnWlDisplayRoundtrip)dlsym(_wl_lib, "wl_display_roundtrip");
	dispatch_pending = (FnWlDisplayDispatchPending)dlsym(_wl_lib, "wl_display_dispatch_pending");
	display_flush = (FnWlDisplayFlush)dlsym(_wl_lib, "wl_display_flush");
	prepare_read = (FnWlDisplayPrepareRead)dlsym(_wl_lib, "wl_display_prepare_read");
	read_events = (FnWlDisplayReadEvents)dlsym(_wl_lib, "wl_display_read_events");
	cancel_read = (FnWlDisplayCancelRead)dlsym(_wl_lib, "wl_display_cancel_read");
	display_get_fd = (FnWlDisplayGetFd)dlsym(_wl_lib, "wl_display_get_fd");

	// Load interface structs (dlsym returns pointer to the Interface)
	wl_registry_interface = (Interface*)dlsym(_wl_lib, "wl_registry_interface");
	wl_compositor_interface = (Interface*)dlsym(_wl_lib, "wl_compositor_interface");
	wl_surface_interface = (Interface*)dlsym(_wl_lib, "wl_surface_interface");
	wl_shell_interface = (Interface*)dlsym(_wl_lib, "wl_shell_interface");
	wl_output_interface = (Interface*)dlsym(_wl_lib, "wl_output_interface");
	wl_seat_interface = (Interface*)dlsym(_wl_lib, "wl_seat_interface");
	wl_subcompositor_interface = (Interface*)dlsym(_wl_lib, "wl_subcompositor_interface");
	wl_keyboard_interface = (Interface*)dlsym(_wl_lib, "wl_keyboard_interface");
	wl_pointer_interface = (Interface*)dlsym(_wl_lib, "wl_pointer_interface");

	// Patch xdg_shell protocol type arrays with loaded interface pointers
	get_xdg_surface[1] = wl_surface_interface;
	get_popup[1] = wl_surface_interface;
	show_window_menu[0] = wl_seat_interface;
	move[0] = wl_seat_interface;
	resize_edge[0] = wl_seat_interface;
	set_fullscreen[0] = wl_output_interface;
	grab[0] = wl_seat_interface;

	return true;
}


fn void surface_commit(
	Surface surface
) => proxy_marshal_flags(surface, 6, null, proxy_get_version(surface), 0);
fn void* registry_bind(
	Registry registry,
	Interface* inter,
	int name,
	int version
) => proxy_marshal_flags(
	registry,
	WL_REGISTRY_BIND,
	inter,
	version,
	0,
	name,
	inter.name,
	version,
	null
);
fn Registry get_registry(
	Display display
) => proxy_marshal_flags(
	display,
	WL_DISPLAY_GET_REGISTRY,
	wl_registry_interface,
	1,
	0,
	null
);
fn double fixed_to_double(int fixed) => fixed / 256.0;

enum SeatCapability : uint (uint value)
{
	POINTER  { 1 },
	KEYBOARD { 2 },
	TOUCH    { 4 },
}

fn void removeRegistry(WaylandWindow* window, Registry registry, uint name)
{
	// window.open = false;
}

fn void shellPing(WaylandWindow* window, Shell shell, uint serial)
{
	// Pong back the compositor's ping to prove we're responsive
	proxy_marshal_flags(shell, 3, null, proxy_get_version(shell), 0, serial);
}

fn void shellSurfaceConfigure(
	WaylandWindow* window,
	XDG_surface surface,
	uint serial
)
{
	// ack_configure
	proxy_marshal_flags(
		surface,
		4,
		null,
		proxy_get_version(surface),
		0,
		serial
	);
	// Commit the surface so the compositor knows we're responsive
	surface_commit(window.surface);
}

fn void topSurfaceClose(WaylandWindow* data, XDG_top_level top_level)
{
	// Window closed
	// data.open = false;
}

fn void topSurfaceConfigure(
	WaylandWindow* data,
	XDG_top_level top_level,
	int width,
	int height,
	void* states
)
{
}
fn void topSurfaceBounds(
	WaylandWindow* data,
	XDG_top_level top_level,
	int width,
	int height
)
{
}
fn void topSurfaceCapabilities(
	WaylandWindow* data,
	XDG_top_level top_level,
	void* capabilities
)
{
}

fn void seatCapabilities(WaylandWindow* data, Seat seat, uint capabilities)
{
	if (capabilities & SeatCapability.KEYBOARD.value)
	{
		Keyboard keyboard = proxy_marshal_flags(
			seat,
			1,
			wl_keyboard_interface,
			proxy_get_version(seat),
			0,
			null
		);
		proxy_add_listener(keyboard, &keyboardListener, data);
	}

	if (capabilities & SeatCapability.POINTER.value)
	{
		Pointer pointer = proxy_marshal_flags(
			seat,
			0,
			wl_pointer_interface,
			proxy_get_version(seat),
			0,
			null
		);
		proxy_add_listener(pointer, &pointerListener, data);
	}
}

fn void seatName(WaylandWindow* data, Seat seat, char* name)
{
	// io::printfn("seat %s", (ZString)name);
}

fn void kbMap(WaylandWindow* data, Keyboard kb, uint frmt, int fd, uint sz)
{
}
fn void kbEnter(
	WaylandWindow* data,
	Keyboard kb,
	uint ser,
	Surface surface,
	WLArray* keys
)
{
}
fn void kbLeave(WaylandWindow* data, Keyboard kb, uint ser, Surface surface)
{
}
fn void noop(
	void* data,
	void* data1,
	void* data2,
	void* data3,
	void* data4,
	void* data5
)
{
}

fn void kbKey(
	WaylandWindow* data,
	void* kb,
	uint serial,
	uint type,
	uint key,
	uint state
)
{
	EventKey keyboard_key = linuxScancodeToEventKey(key + 8);
	if (keyboard_key != EMPTY_KEY)
	{
		data.event_map.set(keyboard_key, (bool)state);
	}
}

fn void kbMod(
	WaylandWindow* data,
	Keyboard kb,
	uint serial,
	uint dep,
	uint lat,
	uint lock,
	uint group
)
{
}
fn void kbRep(WaylandWindow* data, Keyboard kb, int rate, int del)
{
}

fn void pointerEnter(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	Surface surface,
	int x,
	int y
)
{
}
fn void pointerLeave(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	Surface surface
)
{
}

fn void pointerMotion(
	WaylandWindow* data,
	Pointer pointer,
	uint time,
	int x,
	int y
)
{
	data.mouse_pos = { (float)fixed_to_double(x), -(float)fixed_to_double(y) };
}

fn void pointerButton(
	WaylandWindow* data,
	Pointer pointer,
	int serial,
	uint time,
	uint button,
	uint state
)
{
	// Left mouse button
	if (button == 272)
	{
		data.event_map.set(LEFT_MOUSE, (bool)state);
	}

	// Right mouse button
	if (button == 273)
	{
		data.event_map.set(RIGHT_MOUSE, (bool)state);
	}

	// Middle mouse button
	if (button == 274)
	{
		data.event_map.set(MIDDLE_MOUSE, (bool)state);
	}
}

fn void pointerAxis(
	WaylandWindow* data,
	Pointer pointer,
	uint time,
	uint axis,
	int value
)
{
	// Mouse scroll event
	if (value > 0)
	{
		data.event_map.set(MOUSE_SCROLL_UP, true);
	}
	else
	{
		data.event_map.set(MOUSE_SCROLL_DOWN, true);
	}
}


fn void handleRegistry(
	WaylandWindow* window,
	Registry registry,
	uint name,
	char* interface_name,
	uint version
)
{
	String action_name = ((ZString)interface_name).str_view();

	if (action_name == "wl_compositor")
	{
		Compositor compositor = registry_bind(
			registry,
			wl_compositor_interface,
			name,
			version
		);
		window.surface = registry_bind(
			compositor,
			wl_surface_interface,
			name,
			version
		);
	}

	if (action_name == "xdg_wm_base")
	{
		window.shell = registry_bind(
			registry,
			&xdg_wm_base_interface,
			name,
			version
		);
		proxy_add_listener(window.shell, &shellListener, window);
	}

	if (action_name == "wl_seat")
	{
		window.seat = registry_bind(
			registry,
			wl_seat_interface,
			name,
			version
		);
		proxy_add_listener(window.seat, &seatListener, window);
	}
}

KeyboardListener keyboardListener = {
	&kbMap,
	&kbEnter,
	&kbLeave,
	&kbKey,
	&kbMod,
	&kbRep
};

ShellSurfaceListener shellSurfaceListener = { &shellSurfaceConfigure };

RegistryListener registryListener = { &handleRegistry, &removeRegistry };

ShellListener shellListener = { &shellPing, };

TopSurfaceListener topSurfaceListener = {
	&topSurfaceConfigure,
	&topSurfaceClose,
	&topSurfaceBounds,
	&topSurfaceCapabilities
};

SeatListener seatListener = { &seatCapabilities, &seatName, };

PointerListener pointerListener = {
	&pointerEnter,
	&pointerLeave,
	&pointerMotion,
	&pointerButton,
	&pointerAxis,
	&noop,
	&noop,
	&noop,
	&noop,
	&noop,
	&noop
};

// Test if Wayland is available
fn bool wayland_available()
{
	if (!wayland_load()) return false;
	Display dpy = connect(null);
	if (dpy) {
		disconnect(dpy);
		return true;
	}
	return false;
}

// Creates new Wayland window (caller provides heap-allocated WaylandWindow*)
fn void? wayland_create(WaylandWindow* window, Params params, String name)
{
	Display display = connect(null);
	if (display == null) return FAILED_OPENING_WINDOW~;

	window.display = display;

	Registry registry = get_registry(display);
	if (registry == null) return FAILED_OPENING_WINDOW~;
	proxy_add_listener(registry, &registryListener, window);
	rountrip(display);

	assert (window.surface);
	assert (window.shell);

	// Get XDG surface
	window.xdg_surface = proxy_marshal_flags(
		window.shell,
		2,
		&xdg_surface_interface,
		proxy_get_version(window.shell),
		0,
		null,
		window.surface
	);
	assert (window.xdg_surface);
	proxy_add_listener(window.xdg_surface, &shellSurfaceListener, window);

	window.top_level = proxy_marshal_flags(
		window.xdg_surface,
		1,
		&xdg_toplevel_interface,
		proxy_get_version(window.xdg_surface),
		0,
		null
	);
	proxy_add_listener(window.top_level, &topSurfaceListener, window);
	assert (window.top_level);
	// Set title
	proxy_marshal_flags(
		window.top_level,
		1,
		&xdg_toplevel_interface,
		proxy_get_version(window.top_level),
		0,
		null,
		name
	);
	// Set id
	proxy_marshal_flags(
		window.top_level,
		2,
		&xdg_toplevel_interface,
		proxy_get_version(window.top_level),
		0,
		null,
		name
	);
	// Set min size
	proxy_marshal_flags(
		window.top_level,
		8,
		&xdg_toplevel_interface,
		proxy_get_version(window.top_level),
		0,
		null,
		params.width,
		params.height
	);
	// Set max size
	proxy_marshal_flags(
		window.top_level,
		7,
		&xdg_toplevel_interface,
		proxy_get_version(window.top_level),
		0,
		null,
		params.width,
		params.height
	);

	surface_commit(window.surface);
	rountrip(display);
	surface_commit(window.surface);

	window.initialized = true;
}

fn float[<2>] wayland_getMousePos(WaylandWindow* self)
{
	return self.mouse_pos;
}

fn void wayland_pollEvents(WaylandWindow* self)
{
	// Reset mouse scroll
	self.event_map.set(MOUSE_SCROLL_UP, false);
	self.event_map.set(MOUSE_SCROLL_DOWN, false);

	// Non-blocking event dispatch
	while (prepare_read(self.display) != 0)
	{
		dispatch_pending(self.display);
	}
	display_flush(self.display);

	PollFd pfd = { .fd = display_get_fd(self.display), .events = POLLIN, .revents = 0 };
	if (poll(&pfd, 1, 0) > 0)
	{
		read_events(self.display);
	}
	else
	{
		cancel_read(self.display);
	}
	dispatch_pending(self.display);
}

// Free and destroys window instance
fn void wayland_free(WaylandWindow* self)
{
	// proxy_destroy(self.src.keyboard);
	proxy_marshal_flags(
		self.seat,
		3,
		null,
		proxy_get_version(self.seat),
		WL_MARSHAL_FLAG_DESTROY
	);
	proxy_marshal_flags(
		self.surface,
		0,
		null,
		proxy_get_version(self.surface),
		WL_MARSHAL_FLAG_DESTROY
	);
	proxy_marshal_flags(
		self.xdg_surface,
		0,
		null,
		proxy_get_version(self.surface),
		WL_MARSHAL_FLAG_DESTROY
	);
	proxy_marshal_flags(
		self.top_level,
		0,
		null,
		proxy_get_version(self.surface),
		WL_MARSHAL_FLAG_DESTROY
	);
	disconnect(self.display);
	self.initialized = false;
}
