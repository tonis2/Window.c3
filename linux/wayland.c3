module c3w @if(env::LINUX);
import std::math;
import std::io;
import std::core::types;


alias GlobalEvent = fn void(WaylandWindow* data, void* wl_registry, uint name, char* iface, uint ver);
alias RemoveEvent = fn void(WaylandWindow* data, void* wl_registry, uint name);
alias ShellPing = fn void(WaylandWindow* data, Shell shell, uint serial);
alias SeatCapabilitiesEvent = fn void(WaylandWindow* data, void* wl_registry, uint capabilities);
alias SeatNameEvent = fn void(WaylandWindow* data, void* wl_registry, char* name);

alias KBmapEvent = fn void(WaylandWindow* data, Keyboard kb, uint frmt, int fd, uint size);
alias KBenterEvent = fn void(WaylandWindow* data, Keyboard kb, uint ser, Surface surface, WLArray* keys);
alias KBleaveEvent = fn void(WaylandWindow* data, Keyboard kb, uint ser, Surface surface);
alias KBkeyEvent = fn void(WaylandWindow* data, Keyboard kb, uint serial, uint type, uint key, uint state);
alias KBmodEvent = fn void(WaylandWindow* data, Keyboard kb, uint serial, uint dep, uint lat, uint lock, uint group);
alias KBrepEvent = fn void(WaylandWindow* data, Keyboard kb, int rate, int del);

alias PointerEnter = fn void(WaylandWindow* data, Pointer pointer, int serial, Surface surface, int x, int y);
alias PointerLeave = fn void(WaylandWindow* data, Pointer pointer, int serial, Surface surface);
alias PointerMotion = fn void(WaylandWindow* data, Pointer pointer, uint time, int x, int y);
alias PointerButton = fn void(WaylandWindow* data, Pointer pointer, int serial, uint time, uint button, uint state);
alias PointerAxis = fn void(WaylandWindow* data, Pointer pointer, uint time, uint axis, int value);
alias PointerFrame = fn void(WaylandWindow* data, Pointer pointer);
alias PointerAxisSrc = fn void(WaylandWindow* data, Pointer pointer, uint source);
alias PointerAxisStop = fn void(WaylandWindow* data, Pointer pointer, uint axis);
alias PointerAxisValue = fn void(WaylandWindow* data, Pointer pointer, uint axis, int value);

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


alias Shm = void*;
alias ShmPool = void*;
alias Buffer = void*;

struct WaylandWindow
{
	Display display;
	Surface surface;
	Shell shell;
	Seat seat;
	Shm shm;
	XDG_surface xdg_surface;
	XDG_top_level top_level;
	Buffer buffer;
	bool initialized;
	EventMap event_map;
	float[<2>] mouse_pos;
	bool close_requested; // set by the xdg_toplevel close event
	double scroll_delta; // accumulated over the last poll (points, + = up)
	DString text; // UTF-8/ASCII typed during the last poll
	Pointer pointer; // the seat pointer, needed to set the cursor shape
	uint pointer_serial; // serial of the latest pointer enter (for set_shape)
	Proxy cursor_shape_manager; // wp_cursor_shape_manager_v1, if the compositor has it
	Proxy cursor_shape_device; // wp_cursor_shape_device_v1, created lazily
	XkbContext xkb_context; // libxkbcommon objects for layout-aware text input
	XkbKeymap xkb_keymap; // (null when libxkbcommon is unavailable)
	XkbState xkb_state;
	int buffer_scale; // highest wl_output scale seen; buffers are rendered
	// at this factor so the compositor never upscales them
	Proxy[8] outputs; // bound wl_outputs, destroyed in wayland_free
	int output_count;
	Proxy decoration_manager; // zxdg_decoration_manager_v1, if the compositor has it
	Proxy toplevel_decoration; // this window's decoration object (server-side titlebar)
}

struct WLArray
{
	sz size;
	sz alloc;
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

alias OutputScaleEvent = fn void(WaylandWindow* data, void* output, int factor);

// wl_output events in protocol order (v4): geometry, mode, done, scale, name,
// description. Only scale is consumed.
struct OutputListener
{
	void* geometry;
	void* mode;
	void* done;
	OutputScaleEvent scale;
	void* name;
	void* description;
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
const uint WL_REGISTRY_BIND        = 0;
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
extern fn int poll(PollFd* fds, uint nfds, int timeout) @cname("poll");

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
Interface* wl_shm_interface;
Interface* wl_shm_pool_interface;
Interface* wl_buffer_interface;

// POSIX syscalls for shared memory
extern fn int memfd_create(char* name, uint flags) @cname("memfd_create");
extern fn int ftruncate(int fd, sz length) @cname("ftruncate");
extern fn void* mmap(void* addr, sz length, int prot, int flags, int fd, long offset) @cname("mmap");
extern fn int munmap(void* addr, sz length) @cname("munmap");
extern fn int close_fd(int fd) @cname("close");

const int PROT_READ               = 1;
const int PROT_WRITE              = 2;
const int MAP_SHARED              = 1;
const int MAP_PRIVATE             = 2;
const uint WL_SHM_FORMAT_ARGB8888 = 0;

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
	wl_shm_interface = (Interface*)dlsym(_wl_lib, "wl_shm_interface");
	wl_shm_pool_interface = (Interface*)dlsym(_wl_lib, "wl_shm_pool_interface");
	wl_buffer_interface = (Interface*)dlsym(_wl_lib, "wl_buffer_interface");

	// Patch xdg_shell protocol type arrays with loaded interface pointers
	get_xdg_surface[1] = wl_surface_interface;
	get_popup[1] = wl_surface_interface;
	show_window_menu[0] = wl_seat_interface;
	move[0] = wl_seat_interface;
	resize_edge[0] = wl_seat_interface;
	set_fullscreen[0] = wl_output_interface;
	grab[0] = wl_seat_interface;

	// cursor-shape-v1: fill the wl_pointer type slot for get_pointer.
	cursor_shape_get_pointer[1] = wl_pointer_interface;

	return true;
}


fn void surface_commit(Surface surface) => proxy_marshal_flags(surface, 6, null, proxy_get_version(surface), 0);
fn void* registry_bind(
	Registry registry,
	Interface* inter,
	int name,
	uint version
) => proxy_marshal_flags(registry, WL_REGISTRY_BIND, inter, version, 0, name, inter.name, version, null);
fn Registry get_registry(
	Display display
) => proxy_marshal_flags(display, WL_DISPLAY_GET_REGISTRY, wl_registry_interface, 1, 0, null);
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

fn void shellSurfaceConfigure(WaylandWindow* window, XDG_surface surface, uint serial)
{
	// ack_configure
	proxy_marshal_flags(surface, 4, null, proxy_get_version(surface), 0, serial);
	// Commit the surface so the compositor knows we're responsive
	surface_commit(window.surface);
}

fn void topSurfaceClose(WaylandWindow* data, XDG_top_level top_level)
{
	// The compositor asked the toplevel to close (title-bar button, etc).
	// Latched and reported through Window.should_close.
	data.close_requested = true;
}

fn void topSurfaceConfigure(WaylandWindow* data, XDG_top_level top_level, int width, int height, void* states)
{
}
fn void topSurfaceBounds(WaylandWindow* data, XDG_top_level top_level, int width, int height)
{
}
fn void topSurfaceCapabilities(WaylandWindow* data, XDG_top_level top_level, void* capabilities)
{
}

fn void seatCapabilities(WaylandWindow* data, Seat seat, uint capabilities)
{
	if (capabilities & SeatCapability.KEYBOARD.value)
	{
		Keyboard keyboard = proxy_marshal_flags(seat, 1, wl_keyboard_interface, proxy_get_version(seat), 0, null);
		proxy_add_listener(keyboard, &keyboardListener, data);
	}

	if (capabilities & SeatCapability.POINTER.value)
	{
		Pointer pointer = proxy_marshal_flags(seat, 0, wl_pointer_interface, proxy_get_version(seat), 0, null);
		proxy_add_listener(pointer, &pointerListener, data);
		data.pointer = pointer;
	}
}

fn void seatName(WaylandWindow* data, Seat seat, char* name)
{
	// io::printfn("seat %s", (ZString)name);
}

fn void kbMap(WaylandWindow* data, Keyboard kb, uint frmt, int fd, uint size)
{
	// The compositor hands us the keyboard layout as an XKB keymap over a shared
	// fd. Build an xkb_state from it so kbKey can decode real typed text; if
	// libxkbcommon is missing kbKey falls back to the US-QWERTY table.
	if (frmt != XKB_KEYMAP_FORMAT_TEXT_V1 || !xkb_load())
	{
		close_fd(fd);
		return;
	}

	char* map = mmap(null, (sz)size, PROT_READ, MAP_PRIVATE, fd, 0);
	close_fd(fd);
	if (map == null || (iptr)map == -1) return; // MAP_FAILED is (void*)-1

	if (data.xkb_context == null) data.xkb_context = xkb_context_new(0);
	XkbKeymap keymap = data.xkb_context != null ? xkb_keymap_new_from_string(
		data.xkb_context,
		map,
		XKB_KEYMAP_FORMAT_TEXT_V1,
		0
	)
		: null;
	munmap(map, (sz)size);
	if (keymap == null) return;

	// Replace any keymap from a previous layout change.
	if (data.xkb_state != null) xkb_state_unref(data.xkb_state);
	if (data.xkb_keymap != null) xkb_keymap_unref(data.xkb_keymap);
	data.xkb_keymap = keymap;
	data.xkb_state = xkb_state_new(keymap);
}
fn void kbEnter(WaylandWindow* data, Keyboard kb, uint ser, Surface surface, WLArray* keys)
{
}
fn void kbLeave(WaylandWindow* data, Keyboard kb, uint ser, Surface surface)
{
}
fn void noop(void* data, void* data1, void* data2, void* data3, void* data4, void* data5)
{
}

fn void kbKey(WaylandWindow* data, void* kb, uint serial, uint type, uint key, uint state)
{
	// Wayland reports the raw evdev keycode; the unified tables use the X11
	// convention (evdev + 8).
	uint scancode = key + 8;

	EventKey keyboard_key = linuxScancodeToEventKey(scancode);
	if (keyboard_key != EMPTY_KEY)
	{
		data.event_map.set(keyboard_key, (bool)state);
	}

	// Typed text: printable characters on key-down only. Prefer the layout-aware
	// xkb decode; fall back to the US-QWERTY table when libxkbcommon is absent,
	// reading shift from the latched map (updated by the shift key's own event).
	if (state == 1)
	{
		if (data.xkb_state != null)
		{
			xkb_append_text(data.xkb_state, scancode, &data.text);
		}
		else
		{
			bool shift = data.event_map.is_pressed(LEFT_SHIFT) || data.event_map.is_pressed(RIGHT_SHIFT);
			char c     = linuxScancodeToText(scancode, shift);
			if (c != 0) data.text.append_char(c);
		}
	}
}

fn void kbMod(WaylandWindow* data, Keyboard kb, uint serial, uint dep, uint lat, uint lock, uint group)
{
	// The compositor is authoritative for modifier state on Wayland; feed it to
	// xkb so the next key decodes at the right shift/caps/AltGr level.
	if (data.xkb_state != null) xkb_state_update_mask(data.xkb_state, dep, lat, lock, 0, 0, group);
}
fn void kbRep(WaylandWindow* data, Keyboard kb, int rate, int del)
{
}

fn void pointerEnter(WaylandWindow* data, Pointer pointer, int serial, Surface surface, int x, int y)
{
	// The enter serial is required to set the cursor shape for this pointer.
	data.pointer_serial = (uint)serial;
}
fn void pointerLeave(WaylandWindow* data, Pointer pointer, int serial, Surface surface)
{
}

fn void pointerMotion(WaylandWindow* data, Pointer pointer, uint time, int x, int y)
{
	// Surface-local coordinates, top-left origin. Window.getMousePos converts to
	// the bottom-left convention the darwin backend and reference renderer use.
	data.mouse_pos = { (float)fixed_to_double(x), (float)fixed_to_double(y) };
}

fn void pointerButton(WaylandWindow* data, Pointer pointer, int serial, uint time, uint button, uint state)
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

fn void pointerAxis(WaylandWindow* data, Pointer pointer, uint time, uint axis, int value)
{
	// axis 0 is vertical scroll; horizontal is ignored for now.
	if (axis != 0 || value == 0) return;

	// wl_pointer.axis: a positive value is a *downward* scroll. Negate so that a
	// wheel-up gives a positive delta, matching X11 (button 4) and the darwin
	// backend's convention where positive == scroll up.
	double delta = -fixed_to_double(value);
	data.scroll_delta += delta;
	data.event_map.set(delta > 0 ? MOUSE_SCROLL_UP : MOUSE_SCROLL_DOWN, true);
}


fn void outputScale(WaylandWindow* data, void* output, int factor)
{
	// Highest scale of any connected output wins: buffers are rendered once at
	// that factor and the compositor downscales them on lower-density outputs,
	// which stays sharp — upscaling (a scale-1 buffer on a scale-2 output)
	// is what blurs.
	if (factor > data.buffer_scale) data.buffer_scale = factor;
}

fn void handleRegistry(WaylandWindow* window, Registry registry, int name, char* interface_name, uint version)
{
	String action_name = ((ZString)interface_name).str_view();

	if (action_name == "wl_compositor")
	{
		Compositor compositor = registry_bind(registry, wl_compositor_interface, name, version);
		window.surface = registry_bind(compositor, wl_surface_interface, name, version);
	}

	if (action_name == "xdg_wm_base")
	{
		window.shell = registry_bind(registry, &xdg_wm_base_interface, name, version);
		proxy_add_listener(window.shell, &shellListener, window);
	}

	if (action_name == "wl_shm")
	{
		window.shm = registry_bind(registry, wl_shm_interface, name, 1);
	}

	if (action_name == "wl_seat")
	{
		window.seat = registry_bind(registry, wl_seat_interface, name, version);
		proxy_add_listener(window.seat, &seatListener, window);
	}

	if (action_name == "wp_cursor_shape_manager_v1")
	{
		window.cursor_shape_manager = registry_bind(registry, &wp_cursor_shape_manager_v1_interface, name, 1);
	}

	if (action_name == "zxdg_decoration_manager_v1")
	{
		window.decoration_manager = registry_bind(registry, &zxdg_decoration_manager_v1_interface, name, 1);
	}

	if (action_name == "wl_output")
	{
		// The scale event needs v2; cap at v4, the newest revision the
		// OutputListener slots cover.
		Proxy output = registry_bind(registry, wl_output_interface, name, version > 4 ? 4 : version);
		proxy_add_listener(output, &outputListener, window);
		if (window.output_count < window.outputs.len) window.outputs[window.output_count++] = output;
	}
}

KeyboardListener keyboardListener = { &kbMap, &kbEnter, &kbLeave, &kbKey, &kbMod, &kbRep };

ShellSurfaceListener shellSurfaceListener = { &shellSurfaceConfigure };

RegistryListener registryListener = { (GlobalEvent)&handleRegistry, &removeRegistry };

ShellListener shellListener = { &shellPing, };

TopSurfaceListener topSurfaceListener = {
	&topSurfaceConfigure,
	&topSurfaceClose,
	&topSurfaceBounds,
	&topSurfaceCapabilities
};

SeatListener seatListener = { &seatCapabilities, &seatName, };

OutputListener outputListener = { &noop, &noop, &noop, &outputScale, &noop, &noop };

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
	if (dpy)
	{
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
	window.text = dstring::new(mem);
	window.buffer_scale = 1;

	Registry registry = get_registry(display);
	if (registry == null) return FAILED_OPENING_WINDOW~;
	proxy_add_listener(registry, &registryListener, window);
	rountrip(display);

	assert(window.surface);
	assert(window.shell);

	// The wl_outputs bound during the dispatch above have their own events
	// (including scale) still in flight; one more roundtrip collects them
	// before the buffer scale is chosen.
	rountrip(display);

	// Declare the buffer scale so the compositor composites 1:1 instead of
	// upscaling (which blurs text on HiDPI outputs). Needs wl_surface >= 3;
	// reported through get_scale so the renderer sizes its framebuffer to
	// logical size * scale.
	if (window.buffer_scale > 1 && proxy_get_version(window.surface) >= 3)
	{
		// wl_surface.set_buffer_scale(scale) → opcode 8
		proxy_marshal_flags(window.surface, 8, null, proxy_get_version(window.surface), 0, window.buffer_scale);
	}
	else
	{
		window.buffer_scale = 1;
	}

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
	assert(window.xdg_surface);
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
	assert(window.top_level);
	// Set title (opcode 2)
	proxy_marshal_flags(window.top_level, 2, null, proxy_get_version(window.top_level), 0, name.ptr);
	// Set app_id (opcode 3)
	proxy_marshal_flags(window.top_level, 3, null, proxy_get_version(window.top_level), 0, name.ptr);
	// Set max size (opcode 7)
	proxy_marshal_flags(window.top_level, 7, null, proxy_get_version(window.top_level), 0, params.width, params.height);
	// Set min size (opcode 8)
	proxy_marshal_flags(window.top_level, 8, null, proxy_get_version(window.top_level), 0, params.width, params.height);

	// A bare xdg_toplevel has no title bar, so nothing to drag or close the
	// window with. Ask the compositor to draw one (server-side decorations).
	// KDE and wlroots compositors honor this; GNOME lacks the protocol and the
	// window stays undecorated there (Super+drag / Alt+F4 still work). Must be
	// requested before the toplevel gets its first buffer.
	if (window.decoration_manager)
	{
		// zxdg_decoration_manager_v1.get_toplevel_decoration(id, toplevel) → opcode 1
		window.toplevel_decoration = proxy_marshal_flags(
			window.decoration_manager,
			1,
			&zxdg_toplevel_decoration_v1_interface,
			proxy_get_version(window.decoration_manager),
			0,
			null,
			window.top_level
		);
		// zxdg_toplevel_decoration_v1.set_mode(mode) → opcode 1, 2 = server-side
		if (window.toplevel_decoration)
		{
			proxy_marshal_flags(window.toplevel_decoration, 1, null, proxy_get_version(window.toplevel_decoration), 0, 2);
		}
	}

	surface_commit(window.surface);
	rountrip(display);

	// Create a shared memory buffer so the window is visible. Buffer pixels are
	// physical (scale times the logical params size): with set_buffer_scale
	// above, this is what keeps the window's logical size at params.
	if (window.shm)
	{
		int buf_width  = params.width * window.buffer_scale;
		int buf_height = params.height * window.buffer_scale;
		int stride     = buf_width * 4;
		int buf_size   = stride * buf_height;

		ZString shm_name = "wl_shm";
		int fd           = memfd_create(shm_name, 0);
		if (fd < 0) return FAILED_OPENING_WINDOW~;
		ftruncate(fd, (sz)buf_size);
		void* data = mmap(null, (sz)buf_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

		// Fill with opaque black (ARGB8888: A=0xFF, R=0, G=0, B=0)
		char* pixels = (char*)data;
		for (int i = 0; i < buf_size; i += 4)
		{
			pixels[i] = 0; // B
			pixels[i + 1] = 0; // G
			pixels[i + 2] = 0; // R
			pixels[i + 3] = (char)255; // A
		}

		// wl_shm.create_pool(fd, size) → opcode 0, signature "nhi"
		ShmPool pool = proxy_marshal_flags(
			window.shm,
			0,
			wl_shm_pool_interface,
			proxy_get_version(window.shm),
			0,
			null,
			fd,
			buf_size
		);

		// wl_shm_pool.create_buffer(offset, width, height, stride, format) → opcode 0, signature "niiiiu"
		window.buffer = proxy_marshal_flags(
			pool,
			0,
			wl_buffer_interface,
			proxy_get_version(pool),
			0,
			null,
			0,
			buf_width,
			buf_height,
			stride,
			WL_SHM_FORMAT_ARGB8888
		);

		// wl_shm_pool.destroy → opcode 1
		proxy_marshal_flags(pool, 1, null, proxy_get_version(pool), WL_MARSHAL_FLAG_DESTROY);

		munmap(data, (sz)buf_size);
		close_fd(fd);

		// wl_surface.attach(buffer, 0, 0) → opcode 1, signature "oii"
		proxy_marshal_flags(window.surface, 1, null, proxy_get_version(window.surface), 0, window.buffer, 0, 0);

		// wl_surface.damage(0, 0, width, height) → opcode 2, signature "iiii"
		proxy_marshal_flags(
			window.surface,
			2,
			null,
			proxy_get_version(window.surface),
			0,
			0,
			0,
			params.width,
			params.height
		);
	}

	surface_commit(window.surface);

	window.initialized = true;
}

fn float[<2>] wayland_getMousePos(WaylandWindow* self)
{
	return self.mouse_pos;
}

fn float wayland_get_scroll(WaylandWindow* self) => (float)self.scroll_delta;
fn String wayland_get_text(WaylandWindow* self) => self.text.str_view();
fn bool wayland_should_close(WaylandWindow* self) => self.close_requested;
fn float wayland_get_scale(WaylandWindow* self) => (float)self.buffer_scale;

// --- cursor-shape-v1 protocol (server-side named cursors) ---
// Definitions mirror the xdg_shell.c3 style. The get_pointer type slot for the
// wl_pointer argument is patched with the real wl_pointer_interface in
// wayland_load(), once dlsym has resolved it.
Interface*[*] cursor_shape_get_pointer = { &wp_cursor_shape_device_v1_interface, null };

Message[*] cursor_shape_manager_methods = {
	{ "destroy", "", null },
	{ "get_pointer", "no", &cursor_shape_get_pointer },
	{ "get_tablet_tool_v2", "no", null },
};

Interface wp_cursor_shape_manager_v1_interface = {
	.name = "wp_cursor_shape_manager_v1",
	.version = 1,
	.method_count = cursor_shape_manager_methods.len,
	.methods = &cursor_shape_manager_methods,
	.event_count = 0,
	.events = null,
};

Message[*] cursor_shape_device_methods = { { "destroy", "", null }, { "set_shape", "uu", null }, };

Interface wp_cursor_shape_device_v1_interface = {
	.name = "wp_cursor_shape_device_v1",
	.version = 1,
	.method_count = cursor_shape_device_methods.len,
	.methods = &cursor_shape_device_methods,
	.event_count = 0,
	.events = null,
};

// --- xdg-decoration-unstable-v1 protocol (server-side window decorations) ---
Interface*[*] decoration_get_toplevel_types = { &zxdg_toplevel_decoration_v1_interface, &xdg_toplevel_interface };

Message[*] decoration_manager_methods = {
	{ "destroy", "", null },
	{ "get_toplevel_decoration", "no", &decoration_get_toplevel_types },
};

Interface zxdg_decoration_manager_v1_interface = {
	.name = "zxdg_decoration_manager_v1",
	.version = 1,
	.method_count = decoration_manager_methods.len,
	.methods = &decoration_manager_methods,
	.event_count = 0,
	.events = null,
};

Message[*] toplevel_decoration_methods = {
	{ "destroy", "", null },
	{ "set_mode", "u", null },
	{ "unset_mode", "", null },
};

// The configure(mode) event needs a signature entry to demarshal, but no
// listener: whichever mode the compositor picks, the client draws nothing.
Message[*] toplevel_decoration_events = { { "configure", "u", null }, };

Interface zxdg_toplevel_decoration_v1_interface = {
	.name = "zxdg_toplevel_decoration_v1",
	.version = 1,
	.method_count = toplevel_decoration_methods.len,
	.methods = &toplevel_decoration_methods,
	.event_count = toplevel_decoration_events.len,
	.events = &toplevel_decoration_events,
};

// wp_cursor_shape_device_v1.shape values (follow the CSS cursor names).
fn uint wayland_cursor_shape_value(CursorShape shape)
{
	switch (shape)
	{
		case ARROW: return 1;  // default
		case POINTING_HAND: return 4;  // pointer
		case IBEAM: return 9;  // text
		case CROSSHAIR: return 8;  // crosshair
		case OPEN_HAND: return 16;  // grab
		case CLOSED_HAND: return 17;  // grabbing
		case RESIZE_H: return 26;  // ew_resize
		case RESIZE_V: return 27;  // ns_resize
		default: return 1;
	}
}

fn void wayland_set_cursor(WaylandWindow* self, CursorShape shape)
{
	// No-op when the compositor lacks cursor-shape-v1 or the pointer has never
	// entered the surface (no serial to authorize the change).
	if (self.cursor_shape_manager == null || self.pointer == null || self.pointer_serial == 0) return;

	if (self.cursor_shape_device == null)
	{
		// wp_cursor_shape_manager_v1.get_pointer(id, pointer) → opcode 1
		self.cursor_shape_device = proxy_marshal_flags(
			self.cursor_shape_manager,
			1,
			&wp_cursor_shape_device_v1_interface,
			proxy_get_version(self.cursor_shape_manager),
			0,
			null,
			self.pointer
		);
	}
	if (self.cursor_shape_device == null) return;

	// wp_cursor_shape_device_v1.set_shape(serial, shape) → opcode 1
	proxy_marshal_flags(
		self.cursor_shape_device,
		1,
		null,
		proxy_get_version(self.cursor_shape_device),
		0,
		self.pointer_serial,
		wayland_cursor_shape_value(shape)
	);
	display_flush(self.display);
}

fn void wayland_pollEvents(WaylandWindow* self, bool wait = false)
{
	// Per-frame state: scroll and typed text accumulate over this call only; the
	// latched key/button map persists across frames.
	self.event_map.set(MOUSE_SCROLL_UP, false);
	self.event_map.set(MOUSE_SCROLL_DOWN, false);
	self.scroll_delta = 0;
	self.text.clear();

	// Non-blocking event dispatch
	while (prepare_read(self.display) != 0)
	{
		dispatch_pending(self.display);
	}
	display_flush(self.display);

	// wait == true (on-demand idle): block in poll() until an event arrives so
	// the thread parks at ~0% CPU; a nil timeout otherwise polls and returns.
	PollFd pfd = { .fd = display_get_fd(self.display), .events = POLLIN, .revents = 0 };
	if (poll(&pfd, 1, wait ? -1 : 0) > 0)
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
	self.text.free();
	xkb_free(self.xkb_context, self.xkb_keymap, self.xkb_state);
	if (self.cursor_shape_device) proxy_marshal_flags(
		self.cursor_shape_device,
		0,
		null,
		proxy_get_version(self.cursor_shape_device),
		WL_MARSHAL_FLAG_DESTROY
	);
	if (self.cursor_shape_manager) proxy_marshal_flags(
		self.cursor_shape_manager,
		0,
		null,
		proxy_get_version(self.cursor_shape_manager),
		WL_MARSHAL_FLAG_DESTROY
	);
	if (self.toplevel_decoration) proxy_marshal_flags(
		self.toplevel_decoration,
		0,
		null,
		proxy_get_version(self.toplevel_decoration),
		WL_MARSHAL_FLAG_DESTROY
	);
	if (self.decoration_manager) proxy_marshal_flags(
		self.decoration_manager,
		0,
		null,
		proxy_get_version(self.decoration_manager),
		WL_MARSHAL_FLAG_DESTROY
	);
	for (int i = 0; i < self.output_count; i++) proxy_destroy(self.outputs[i]);
	// proxy_destroy(self.src.keyboard);
	proxy_marshal_flags(self.seat, 3, null, proxy_get_version(self.seat), WL_MARSHAL_FLAG_DESTROY);
	proxy_marshal_flags(self.surface, 0, null, proxy_get_version(self.surface), WL_MARSHAL_FLAG_DESTROY);
	proxy_marshal_flags(self.xdg_surface, 0, null, proxy_get_version(self.surface), WL_MARSHAL_FLAG_DESTROY);
	proxy_marshal_flags(self.top_level, 0, null, proxy_get_version(self.surface), WL_MARSHAL_FLAG_DESTROY);
	disconnect(self.display);
	self.initialized = false;
}
