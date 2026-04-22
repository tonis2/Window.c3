module c3w @if(env::LINUX) @link("dl");
import std::io;

extern fn char* getenv(char* name) @extern("getenv");


// Dynamic library loading
extern fn void* dlopen(char* filename, int flags) @extern("dlopen");

extern fn void* dlsym(void* handle, char* symbol) @extern("dlsym");

extern fn int dlclose(void* handle) @extern("dlclose");


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
		if (x11_available()) {
			io::printfn("Using X11 display server (forced by feature)");
			return BackendType.X11;
		}
	$else
		$if $feature(WAYLAND):
			if (wayland_available()) {
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
				X11Window x11_win = x11_create(params, name)!;
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

// Get mouse position
fn float[<2>] Window.getMousePos(self)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			return wayland_getMousePos(wl);
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			return x11_getMousePos(x11);
		default:
			return { 0, 0 };
	}
}

// Get events
fn EventMap Window.getEvent(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			wayland_pollEvents(wl);
			return wl.event_map;
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			x11_pollEvents(x11, &self.src.event_map);
		default:
	}
	return self.src.event_map;
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
struct VkWaylandSurfaceCreateInfo {
	uint sType;
	void* pNext;
	uint flags;
	void* display;
	void* surface;
}

struct VkXcbSurfaceCreateInfo {
	uint sType;
	void* pNext;
	uint flags;
	void* connection;
	uint window;
}

alias VkCreateSurfaceFn = fn int(void*, void*, void*, void*);
alias VkSurface = void*;

fn VkSurface? Window.create_vk_surface(&self, void* vk_instance)
{
	void* vk_lib = dlopen("libvulkan.so.1", RTLD_LAZY);
	if (vk_lib == null) return FAILED_OPENING_WINDOW~;
	defer dlclose(vk_lib);

	void* surface;

	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			VkCreateSurfaceFn create_fn = (VkCreateSurfaceFn)dlsym(vk_lib, "vkCreateWaylandSurfaceKHR");
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
			VkCreateSurfaceFn create_fn = (VkCreateSurfaceFn)dlsym(vk_lib, "vkCreateXcbSurfaceKHR");
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
