module c3w @feat(LINUX) @link("dl");
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

	// The cursor's movement over the last `getEvent`, differenced from where it
	// was at the previous one. `has_last` is what stops the first call
	// reporting the trip from a remembered zero as a hand movement.
	float[<2>] mouse_delta;
	float[<2>] last_mouse;
	bool has_last;
}

// Auto-detect which display server to use
fn BackendType detect_backend()
{
	// Feature flags to force a specific backend
	$if $feat(X11):
		if (x11_available())
		{
			io::printfn("Using X11 display server (forced by feature)");
			return BackendType.X11;
		}
	$else
		$if $feat(WAYLAND):
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

<*
 Make a waiting `getEvent` return, from any thread.

 Both backends block when `getEvent(wait: true)` parks them, and both need a
 second thing to wait on or a worker with work for the main thread waits for
 the user to move the mouse. X11 blocks in `xcb_wait_for_event` and is woken by
 a ClientMessage sent to the window's own id; Wayland blocks in `poll` on the
 display fd and is woken by a byte down a pipe in the same poll set. Neither
 touches anything the main thread owns — see `x11_wake` and `wayland_wake`.

 Delivering a wake nobody was waiting for is harmless: X11 queues an event the
 handler skips, and Wayland leaves a byte the next poll drains.
*>
fn void Window.wake(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_wake((WaylandWindow*)self.src.backend_data);
		case X11:     x11_wake((X11Window*)self.src.backend_data);
		default:      break;
	}
}

// Get events. When wait is set (an on-demand render loop asking to idle), the
// backend blocks on the first fetch until an event arrives, parking the thread
// at ~0% CPU; otherwise it polls and returns immediately.
fn EventMap Window.getEvent(&self, bool wait = false)
{
	EventMap map;
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			wayland_pollEvents(wl, wait);
			map = wl.event_map;
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			x11_pollEvents(x11, wait);
			map = x11.event_map;
		default:
			map = self.src.event_map;
	}

	// Both backends learn their size from an event, so this is the first moment
	// after one arrives that anything could be told. `Window.width` used to be
	// whatever `new` was asked for and stayed that way for the life of the
	// process, which made every reader of it wrong the first time an edge moved.
	self.refresh_size();
	self.track_mouse_delta();
	return map;
}

<*
 Copy the backend's current size up onto the `Window`.

 Called once per `getEvent`, from a latch rather than by asking the display, so
 a frame loop reading `Window.width` pays nothing for it. `getMousePos` is the
 reason it has to be current rather than merely available: the y flip is against
 this height, so a stale one puts the cursor in the wrong place by exactly the
 amount the window was resized by.
*>
fn void Window.refresh_size(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			int[<2>] at = wayland_get_size((WaylandWindow*)self.src.backend_data);
			if (at.x > 0) self.width = (float)at.x;
			if (at.y > 0) self.height = (float)at.y;
		case X11:
			uint[<2>] at = x11_get_size((X11Window*)self.src.backend_data);
			if (at.x > 0) self.width = (float)at.x;
			if (at.y > 0) self.height = (float)at.y;
		default:
			break;
	}
	self.src.width = self.width;
	self.src.height = self.height;
}

<*
 What the mouse did since the previous `getEvent`.

 Two mechanisms, and which one runs is whether the pointer is locked.

 **Unlocked** it is a difference of cursor positions, and that is the weaker of
 the two things a delta can be: it stops at the edge of the screen, because that
 is where the cursor stops.

 **Locked** it is the hand, and the two backends get there differently. X11 has
 no relative pointer, so the cursor is warped back to the middle after every
 reading and the movement is how far it got from there. Wayland cannot warp at
 all and does not need to — `zwp_relative_pointer_v1` reports the hand directly,
 with the cursor held still by the lock beside it.

 Both are converted to the bottom-left origin `getMousePos` answers in, so the
 sign of `[1]` means one thing whichever path produced it.
*>
fn void Window.track_mouse_delta(&self)
{
	if (self.pointerLocked())
	{
		self.src.mouse_delta = self.locked_delta();
		// The cursor is not where the hand is any more, so a difference against
		// this reading would be a lie the moment the lock ends. Seeding it with
		// where the cursor actually sits makes the first unlocked frame report
		// nothing rather than the whole of the lock's travel.
		self.src.last_mouse = self.getMousePos();
		self.src.has_last = true;
		return;
	}

	float[<2>] at = self.getMousePos();
	self.src.mouse_delta = self.src.has_last ? (float[<2>]) { at.x - self.src.last_mouse.x, at.y - self.src.last_mouse.y } : (float[<2>]) { 0, 0 };
	self.src.last_mouse = at;
	self.src.has_last = true;
}

<*
 The hand's movement while the pointer is locked, per backend.

 X11 reads where the cursor got to and puts it back in the middle; Wayland reads
 what the compositor already accumulated. Both answer in the bottom-left origin
 the rest of this file uses, which for X11 falls out of `getMousePos` and for
 Wayland is the one negation below.
*>
fn float[<2>] Window.locked_delta(&self)
{
	switch (self.src.backend)
	{
		case X11:
			X11Window* x11 = (X11Window*)self.src.backend_data;
			float[<2>] at = self.getMousePos();
			float[<2>] centre = { self.width / 2, self.height / 2 };
			x11_warp_to_centre(x11);
			return { at.x - centre.x, at.y - centre.y };
		case WAYLAND:
			// Surface-local, so +y is down where everything this returns to counts
			// it up. The same flip `getMousePos` does, on a movement rather than a
			// position — which is why it is a negation and not a subtraction from
			// the height.
			double[<2>] moved = wayland_relative_motion((WaylandWindow*)self.src.backend_data);
			return { (float)moved.x, (float)-moved.y };
		default:
			return { 0, 0 };
	}
}

<*
 The cursor's movement over the last `getEvent`, in the same points
 `getMousePos` answers in and with the same bottom-left origin — so `[1]` is
 positive UPWARD here, where the darwin backend reports AppKit's downward
 `deltaY`. `scene/input.c3` is where either is turned into image pixels.
*>
fn float[<2>] Window.getMouseDelta(&self) => self.src.mouse_delta;

<*
 Take the pointer out of the user's hands, or give it back.

 What it buys is a look that does not stop. Unlocked, `getMouseDelta` is a
 difference of cursor positions and a cursor stops at the edge of the screen
 while a hand does not; locked, the movement keeps counting.

 Both Linux backends implement it now, and they are not the same mechanism:

 - **X11** hides the cursor with a 1x1 transparent pixmap and warps it back to
   the window's centre after every reading, which is the same recentre the
   darwin backend does.
 - **Wayland** cannot warp a cursor at all — a client moving the pointer is
   outside what the protocol allows — so it asks the compositor to hold the
   cursor still with `zwp_pointer_constraints_v1` and to report the hand
   separately with `zwp_relative_pointer_v1`. Both are optional globals, so a
   compositor without them is a session with no lock.

 **`pointerLocked` is what happened, not what was asked for**, and that has not
 changed from when neither backend could do this. A Wayland compositor refuses a
 lock on a surface that is not focused and can take one back at any time; X11
 has no cursor to hide if the pixmap could not be made. A script that needs a
 look reads the value back and falls back to a drag-look when it comes back
 false, and recording the request instead would leave a game whose look silently
 stops at the edge of the screen.
*>
fn void Window.setPointerLock(&self, bool locked)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_set_pointer_lock((WaylandWindow*)self.src.backend_data, locked);
		case X11:     x11_set_pointer_lock((X11Window*)self.src.backend_data, locked);
		default:      break;
	}
}

fn bool Window.pointerLocked(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_pointer_locked((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_pointer_locked((X11Window*)self.src.backend_data);
		default:      return false;
	}
}

<*
 The key and button transitions the last `getEvent` drained, in order.

 See `EventLog`. The map this sits beside is a latch and cannot describe a press
 that began and ended between two calls; this can.
*>
fn Event[] Window.events(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return ((WaylandWindow*)self.src.backend_data).event_log.view();
		case X11:     return ((X11Window*)self.src.backend_data).event_log.view();
		default:      return {};
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

// The horizontal half of the same call (+ = scroll right).
fn float Window.get_scroll_x(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_scroll_x((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_get_scroll_x((X11Window*)self.src.backend_data);
		default:      return 0;
	}
}

// Whether that scroll came from a trackpad rather than a detented wheel.
fn bool Window.get_scroll_precise(&self)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_scroll_precise((WaylandWindow*)self.src.backend_data);
		case X11:     return x11_get_scroll_precise((X11Window*)self.src.backend_data);
		default:      return false;
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

<*
 Resize the window, in logical units.

 The two backends mean quite different things by it. X11 configures the window
 and the window manager may adjust or refuse the request; the ConfigureNotify
 that follows is what settled. Wayland has no such request at all — a client's
 size *is* the buffer it commits, so the size is recorded on the spot, whoever
 draws is expected to build at it, and the configure that answers the commit
 either agrees or corrects it.

 Either way `Window.width` on the next `getEvent` is what actually happened, and
 on neither backend is it necessarily what was asked for.
*>
fn void Window.set_size(&self, int width, int height)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_set_size((WaylandWindow*)self.src.backend_data, width, height);
		case X11:     x11_set_size((X11Window*)self.src.backend_data, width, height);
		default:      break;
	}
}

<*
 Minimise the window, or restore it.

 **Restoring works on X11 and not on Wayland.** xdg-shell has a `set_minimized`
 request and no counterpart, deliberately — a client that could un-minimise
 itself could jump in front of whatever the user was doing. On Wayland
 `minimized = false` is a no-op.
*>
fn void Window.set_minimized(&self, bool minimized)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_set_minimized((WaylandWindow*)self.src.backend_data, minimized);
		case X11:     x11_set_minimized((X11Window*)self.src.backend_data, minimized);
		default:      break;
	}
}
