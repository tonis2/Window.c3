module c3w @if(env::LINUX) @link("dl");
import std::io;

extern fn char* getenv(char* name) @cname("getenv");

// Dynamic library loading
extern fn void* dlopen(char* filename, int flags) @cname("dlopen");
extern fn void* dlsym(void* handle, char* symbol) @cname("dlsym");
extern fn int dlclose(void* handle) @cname("dlclose");


const int RTLD_LAZY   = 1;
const int RTLD_NOW    = 2;
const int RTLD_GLOBAL = 256;

enum BackendType
{
	NONE,
	WAYLAND,
	X11,
}

struct LinuxWindow
{
	BackendType backend;
	void* backend_data; // Pointer to either WaylandWindow or X11Window
	float width;
	float height;
	EventMap event_map;
	float[<2>] mouse_pos;
}

// Auto-detect which display server to use
fn BackendType detect_backend()
{
	// Feature flags to force a specific backend
	$if $feature(X11):
		if (x11_available())
		{
			io::printfn("Using X11 display server (forced by feature)");
			return BackendType.X11;
		}
	$else
		$if $feature(WAYLAND):
			if (wayland_available())
			{
				io::printfn("Using Wayland display server (forced by feature)");
				return BackendType.WAYLAND;
			}
		$endif
	$endif

	// Check XDG_SESSION_TYPE environment variable
	char* session_type = getenv("XDG_SESSION_TYPE");

	if (session_type != null)
	{
		String session = ((ZString)session_type).str_view();

		if (session == "wayland")
		{
			// Try Wayland first
			if (wayland_available())
			{
				io::printfn("Auto-detected Wayland display server");
				return BackendType.WAYLAND;
			}
			// Fall back to X11 (XWayland)
			if (x11_available())
			{
				io::printfn("Wayland not available, falling back to X11 (XWayland)");
				return BackendType.X11;
			}
		}
		else if (session == "x11")
		{
			if (x11_available())
			{
				io::printfn("Auto-detected X11 display server");
				return BackendType.X11;
			}
		}
	}

	// No XDG_SESSION_TYPE or unknown value, try both
	// Prefer Wayland for modern systems
	if (wayland_available())
	{
		io::printfn("Auto-detected Wayland display server");
		return BackendType.WAYLAND;
	}

	if (x11_available())
	{
		io::printfn("Auto-detected X11 display server");
		return BackendType.X11;
	}

	return BackendType.NONE;
}

// Creates a new window with auto-detected backend
fn Window? new(Params params, String name)
{
	BackendType backend = detect_backend();

	LinuxWindow linux_window = {
		.backend = backend,
		.backend_data = null,
		.width = params.width,
		.height = params.height,
	};

	switch (backend)
	{
		case WAYLAND:

			{
				WaylandWindow* wl = mem::new(WaylandWindow);
				*wl = { };
				wayland_create(wl, params, name)!;
				linux_window.backend_data = wl;
			}
		case X11:

			{
				X11Window x11_win   = x11_create(params, name)!;
				X11Window* heap_win = mem::new(X11Window);
				*heap_win = x11_win;
				linux_window.backend_data = heap_win;
			}
		default:

			{
				io::printfn("No display server available (tried Wayland and X11)");
				return FAILED_OPENING_WINDOW~;
			}
	}

	Window result = { .src = linux_window, .width = params.width, .height = params.height, };
	return result;
}

// Get mouse position. The backends report window-relative coordinates with a
// top-left origin (native to X11 and Wayland); the c3w contract — matching the
// darwin/Cocoa backend that the reference renderer flips back — is bottom-left,
// so the y is converted here against the window height.
fn float[<2>] Window.getMousePos(self)
{
	float[<2>] pos;
	switch (self.src.backend)
	{
		case WAYLAND:
			pos = wayland_getMousePos((WaylandWindow*)self.src.backend_data);
		case X11:
			pos = x11_getMousePos((X11Window*)self.src.backend_data);
		default:
			return { 0, 0 };
	}
	return { pos.x, self.height - pos.y };
}

// Get events. When wait is set (an on-demand render loop asking to idle), the
// backend blocks on the first fetch until an event arrives, parking the thread
// at ~0% CPU; otherwise it polls and returns immediately.
fn EventMap Window.getEvent(&self, bool wait = false)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			wayland_pollEvents(wl, wait);
			return wl.event_map;
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			x11_pollEvents(x11, wait);
			return x11.event_map;
		default:
			return self.src.event_map;
	}
}

// Free window resources
fn void Window.free(self)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			wayland_free(wl);
			mem::free(wl);
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			x11_free(x11);
			mem::free(x11);
		default:
	}
}

// Get which backend is being used
fn BackendType Window.getBackend(self)
{
	return self.src.backend;
}

// Minimal Vulkan structs for surface creation (matches C ABI layout)
struct VkWaylandSurfaceCreateInfo
{
	uint sType;
	void* pNext;
	uint flags;
	void* display;
	void* surface;
}

struct VkXcbSurfaceCreateInfo
{
	uint sType;
	void* pNext;
	uint flags;
	void* connection;
	uint window;
}

alias VkCreateSurfaceFn = fn int(void*, void*, void*, void*);
alias VkSurface = void*;

// See the note in darwin/main.c3: a caller that links Vulkan itself passes
// vkGetInstanceProcAddr in, which is the only way to reach a statically linked
// loader. Left null, the system loader is opened by name as before.
alias VkGetInstanceProcAddrFn = fn void*(void*, char*);

fn void* Window.vk_proc(&self, void* vk_instance, VkGetInstanceProcAddrFn get_instance_proc_addr, void* vk_lib, char* name)
{
	if (get_instance_proc_addr != null) return get_instance_proc_addr(vk_instance, name);
	return dlsym(vk_lib, name);
}

fn VkSurface? Window.create_vk_surface(&self, void* vk_instance, VkGetInstanceProcAddrFn get_instance_proc_addr = null)
{
	void* vk_lib = null;
	if (get_instance_proc_addr == null)
	{
		vk_lib = dlopen("libvulkan.so.1", RTLD_LAZY);
		if (vk_lib == null) return FAILED_OPENING_WINDOW~;
	}
	defer { if (vk_lib != null) dlclose(vk_lib); }

	void* surface;

	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			VkCreateSurfaceFn create_fn = (VkCreateSurfaceFn)self.vk_proc(vk_instance, get_instance_proc_addr, vk_lib, "vkCreateWaylandSurfaceKHR");
			if (create_fn == null) return FAILED_OPENING_WINDOW~;

			VkWaylandSurfaceCreateInfo create_info = {
				.sType = 1000006000,
				.pNext = null,
				.flags = 0,
				.display = wl.display,
				.surface = wl.surface,
			};
			int result = create_fn(vk_instance, &create_info, null, &surface);
			if (result != 0) return FAILED_OPENING_WINDOW~;

		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			VkCreateSurfaceFn create_fn = (VkCreateSurfaceFn)self.vk_proc(vk_instance, get_instance_proc_addr, vk_lib, "vkCreateXcbSurfaceKHR");
			if (create_fn == null) return FAILED_OPENING_WINDOW~;

			VkXcbSurfaceCreateInfo create_info = {
				.sType = 1000005000,
				.pNext = null,
				.flags = 0,
				.connection = x11.connection,
				.window = (uint)(uptr)x11.window,
			};
			int result = create_fn(vk_instance, &create_info, null, &surface);
			if (result != 0) return FAILED_OPENING_WINDOW~;

		default:
			return FAILED_OPENING_WINDOW~;
	}

	return surface;
}

// --- API parity with the darwin backend ---

// Accumulated scroll-wheel delta over the last getEvent call (+ = scroll up).
fn float Window.get_scroll(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_scroll((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_get_scroll((X11Window*)self.src.backend_data);
		default:      return 0;
	}
}

// Text typed during the last getEvent call. Borrowed — valid until the next
// getEvent. US-QWERTY only (see linux/main.c3).
fn String Window.get_text(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_text((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_get_text((X11Window*)self.src.backend_data);
		default:      return "";
	}
}

// Framebuffer pixels per logical window unit (1.0 on standard-density
// displays). On Wayland this is the highest scale of the connected outputs and
// the surface's buffer scale is already declared to match — render buffers at
// logical size * scale, or the compositor scales them and text blurs. Window
// size, mouse coordinates and the Params stay in logical units.
fn float Window.get_scale(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_scale((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_get_scale((X11Window*)self.src.backend_data);
		default:      return 1.0;
	}
}

// True once the window manager / compositor has asked the window to close.
fn bool Window.should_close(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_should_close((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_should_close((X11Window*)self.src.backend_data);
		default:      return false;
	}
}

// Set the pointer cursor shape. X11 uses the cursor font; Wayland uses the
// cursor-shape-v1 protocol and is a no-op if the compositor lacks it.
fn void Window.set_cursor(&self, CursorShape shape)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_set_cursor((WaylandWindow*)self.src.backend_data, shape);
		case X11:     x11_set_cursor((X11Window*)self.src.backend_data, shape);
		default:      break;
	}
}
