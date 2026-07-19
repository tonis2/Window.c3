module c3w @if(env::DARWIN);
import std::math;
import std::io;
import std::core::types;
import std::core::runtime;
import std::os::macos::objc;
import std::os::macos::objc::ns;

struct DarwinWindow
{
	NSWindow window;
	NSApplication app;
	NSView view;
	CALayer layer;
	EventMap event_map;
	double scroll_delta;    // accumulated over the last getEvent call
	DString text;           // UTF-8 typed during the last getEvent call
}

// Set by the windowShouldClose: delegate; queried via Window.should_close.
// One flag for the process — c3w manages a single window.
bool close_requested = false;

fn bool on_close(ObjcId self)
{
	close_requested = true;
	if (catch self.get_ivar("NSWindow")) return true;
	return true;
}

fn NSSize resize_window(ObjcId self, NSSize frame)
{
	if (catch self.get_ivar("NSWindow")) return frame;
	io::printfn("window sresized to %f %f", frame.width, frame.height);
	return frame;
}

fn Window? new(Params params, String name)
{
	NSObject object = new_object("NSObject");
	object.add_method("windowShouldClose:", &on_close)!!;

	NSApplication app = { .cls = objc::getClass("NSApplication") };
	app.sharedApplication();
	app.setActivationPolicy(NSApplicationActivationPolicy.REGULAR);

	NSWindow win = new_object("NSWindow");
	win.alloc();

	ulong window_style = NSWindowStyleMask.CLOSABLE | NSWindowStyleMask.MINIATURIZABLE | NSBackingStoreType.BUFFERED
		| NSWindowStyleMask.TITLED
		| NSWindowStyleMask.RESIZABLE;
	win.initWithContentRect(
		(NSRect) { { params.x, params.y }, { params.width, params.height } },
		window_style,
		window_style,
		false
	);

	NSString window_title = new_object("NSString");
	window_title.stringWithUTF8String((ZString)name);
	win.setTitle(window_title);

	NSObject delegate = new_object("NSObject");
	delegate.alloc_class_pair("WindowDelegate", 0);
	delegate.add_ivar("NSWindow", @sizeof(win), math::@intlog2(@sizeof(win)), "L")!!;
	delegate.add_method("windowWillResize:toSize:", &resize_window, "{NSSize=ff}@:{NSSize=ff}")!!;
	// delegate.add_method("windowDidMiniaturize::", &resize_window, "")!!;
	// delegate.add_method("windowDidDeminiaturize::", &resize_window, "")!!;


	delegate.alloc();
	delegate.init();
	delegate.setInstanceVariable("NSWindow", win);
	win.setDelegate(delegate);

	win.makeKeyAndOrderFront((ObjcSelector)null);
	win.setIsVisible(true);

	app.activateIgnoringOtherApps(true);
	app.finishLaunching();

	NSView view = win.get_view();
	// new_object("NSView");

	// view.alloc();

	// view.init();


	CALayer layer = new_object("CAMetalLayer");
	layer.alloc();
	layer.init();

	view.set_layer(layer);
	view.wants_Layer(true);
	win.set_view(view);

	// A layer attached by hand makes the view layer-HOSTING: AppKit leaves the
	// layer's contentsScale at 1.0, so on a retina display the Metal drawable
	// would be half the window's physical resolution and every frame upscaled.
	// Match the window's backing scale — CAMetalLayer then derives drawableSize
	// as bounds * contentsScale, and the Vulkan surface reports that size.
	layer.set_contents_scale(win.backing_scale_factor());

	Window response = {
		.src = { .window = win, .app = app, .view = view, .layer = layer, .text = dstring::new(mem) },
		.width = params.width,
		.height = params.height
	};

	return response;
}

fn float[<2>] Window.getMousePos(self)
{
	NSPoint point = self.src.window.get_mouse_pos();
	return { (float)point.x, (float)point.y };
}

fn EventMap Window.getEvent(&self, bool wait = false)
{
	NSAutoreleasePool pool = new_object("NSAutoreleasePool");
	pool.alloc();
	pool.init();
	defer pool.release();

	NSString loop = new_object("NSString");
	loop.stringWithUTF8String("kCFRunLoopDefaultMode");

	// A nil date makes nextEventMatchingMask return immediately when the queue
	// is empty (a poll). When wait is set — an on-demand render loop asking to
	// idle — the *first* fetch instead blocks on distantFuture: the thread
	// sleeps in the kernel at 0% CPU until an event arrives, and input wakes
	// it. Once woken, the remaining events are drained with the nil poll date
	// so no edges are lost.
	NSDate poll;
	NSDate first = poll;
	if (wait)
	{
		first = new_object("NSDate");
		first.distantFuture();
	}
	bool is_first = true;

	// Per-frame state: scroll and typed text accumulate over this call's
	// events only; the latched key/button map persists across frames.
	self.src.event_map.set(MOUSE_SCROLL_UP, false);
	self.src.event_map.set(MOUSE_SCROLL_DOWN, false);
	self.src.scroll_delta = 0;
	self.src.text.clear();

	// Drain everything queued since the last call — handling a single event
	// per frame loses press/release edges and lags typing.
	while (true)
	{
		NSDate until = is_first ? first : poll;
		is_first = false;
		NSEvent event = self.src.app.nextEventMatchingMask(long::max, until, loop, true);
		if (!(void*)event) break;

		int type = event.get_type();
		DarwinEventType? event_type_opt = runtime::@enum_lookup(DarwinEventType, "value", (uint)type);
		if (catch event_type_opt)
		{
			self.src.window.sendEvent(event);
			continue;
		}
		switch (event_type_opt)
		{
			case SCROLL_WHEEL:

				{
					double delta = event.get_scrolling_delta();
					self.src.scroll_delta += delta;
					if (delta > 0)
					{
						self.src.event_map.set(MOUSE_SCROLL_UP, true);
					}
					else if (delta < 0)
					{
						self.src.event_map.set(MOUSE_SCROLL_DOWN, true);
					}
					break;
				}
			case LEFT_MOUSE_UP:

				{
					self.src.event_map.set(LEFT_MOUSE, false);
					break;
				}
			case RIGHT_MOUSE_UP:

				{
					self.src.event_map.set(RIGHT_MOUSE, false);
					break;
				}
			case LEFT_MOUSE_DOWN:

				{
					self.src.event_map.set(LEFT_MOUSE, true);
					break;
				}
			case RIGHT_MOUSE_DOWN:

				{
					self.src.event_map.set(RIGHT_MOUSE, true);
					break;
				}
			case OTHER_MOUSE_DOWN:

				{
					self.src.event_map.set(MIDDLE_MOUSE, true);
					break;
				}
			case OTHER_MOUSE_UP:

				{
					self.src.event_map.set(MIDDLE_MOUSE, false);
					break;
				}
			case KEY_PRESSED:

				{
					int key              = event.get_key();
					EventKey event_value = darwinKeycodeToEventKey(key);
					if (event_value != EMPTY_KEY)
					{
						self.src.event_map.set(event_value, true);
					}
					// Typed text: skip command/control chords, control chars
					// and the 0xF700 function-key range (arrows, F-keys).
					// Decode to runes first — iterating a String yields raw
					// bytes, which would leak the function keys' UTF-8
					// bytes (EF 9C xx) past the range filter.
					int mods = event.get_modifierFlags();
					if ((mods & 0x14_0000) == 0)
					{
						String chars = event.get_characters_utf8().str_view();
						@pool()
						{
							if (try runes = chars.to_utf32(tmem))
							{
								foreach (Char32 c : runes)
								{
									if (c < 0x20 || c == 0x7F) continue;
									if (c >= 0xF700 && c <= 0xF8FF) continue;
									self.src.text.append_char32(c);
								}
							}
						};
					}
				}
			case KEY_RELEASED:

				{
					int key              = event.get_key();
					EventKey event_value = darwinKeycodeToEventKey(key);
					if (event_value != EMPTY_KEY)
					{
						self.src.event_map.set(event_value, false);
					}
				}
			default:

				{
				};
		}
		self.src.window.sendEvent(event);
	}

	self.src.app.updateWindows();
	return self.src.event_map;
}

// Accumulated scroll-wheel delta over the last getEvent call, in points
// (positive = scroll up / away from the user).
fn float Window.get_scroll(&self) => (float)self.src.scroll_delta;

// UTF-8 text typed during the last getEvent call. Borrowed — valid until the
// next getEvent.
fn String Window.get_text(&self) => self.src.text.str_view();

// True once the user has clicked the window's close button.
fn bool Window.should_close(&self) => close_requested;

// Framebuffer pixels per window point: the window's backing scale factor
// (2.0 on retina). new() sets the CAMetalLayer's contentsScale to the same
// value, so the Metal drawable — and the Vulkan surface made from it — is
// this factor times the logical size; render buffers must match.
fn float Window.get_scale(&self) => (float)self.src.window.backing_scale_factor();

fn void Window.set_cursor(&self, CursorShape shape)
{
	ObjcClass cls = objc::getClass("NSCursor");
	void* cursor;
	switch (shape)
	{
		case ARROW:         cursor = objc::msg_send(cls, SendVoid, "arrowCursor");
		case POINTING_HAND: cursor = objc::msg_send(cls, SendVoid, "pointingHandCursor");
		case IBEAM:         cursor = objc::msg_send(cls, SendVoid, "IBeamCursor");
		case CROSSHAIR:     cursor = objc::msg_send(cls, SendVoid, "crosshairCursor");
		case OPEN_HAND:     cursor = objc::msg_send(cls, SendVoid, "openHandCursor");
		case CLOSED_HAND:   cursor = objc::msg_send(cls, SendVoid, "closedHandCursor");
		case RESIZE_H:      cursor = objc::msg_send(cls, SendVoid, "resizeLeftRightCursor");
		case RESIZE_V:      cursor = objc::msg_send(cls, SendVoid, "resizeUpDownCursor");
	}
	if (cursor) objc::msg_send(cursor, SendVoid, "set");
}

fn void Window.free(&self)
{
	self.src.text.free();
	self.src.layer.release();
	self.src.window.release();
	self.src.app.terminate();
}

// Dynamic library loading (POSIX, available on macOS)
extern fn void* dlopen(char* filename, int flags) @cname("dlopen");
extern fn void* dlsym(void* handle, char* symbol) @cname("dlsym");
extern fn int dlclose(void* handle) @cname("dlclose");

const int RTLD_LAZY = 1;

struct VkMetalSurfaceCreateInfo
{
	uint sType;
	void* pNext;
	uint flags;
	void* pLayer;
}

alias VkCreateSurfaceFn = fn int(void*, void*, void*, void*);
alias VkSurface = void*;

// Callers that link Vulkan themselves pass vkGetInstanceProcAddr in. This is not
// a convenience: a statically linked loader is built with hidden visibility, so
// its symbols cannot be reached with dlsym -- there is no library to open and no
// exported symbol to find. Left null, the old behaviour stands and the system
// loader is opened by name.
alias VkGetInstanceProcAddrFn = fn void*(void*, char*);

fn VkSurface? Window.create_vk_surface(&self, void* vk_instance, VkGetInstanceProcAddrFn get_instance_proc_addr = null)
{
	VkCreateSurfaceFn create_fn = null;
	void* vk_lib = null;

	if (get_instance_proc_addr != null)
	{
		create_fn = (VkCreateSurfaceFn)get_instance_proc_addr(vk_instance, "vkCreateMetalSurfaceEXT");
	}

	if (create_fn == null)
	{
		vk_lib = dlopen("libvulkan.1.dylib", RTLD_LAZY);
		if (vk_lib == null)
		{
			vk_lib = dlopen("libMoltenVK.dylib", RTLD_LAZY);
		}
		if (vk_lib == null) return FAILED_OPENING_WINDOW~;

		create_fn = (VkCreateSurfaceFn)dlsym(vk_lib, "vkCreateMetalSurfaceEXT");
		if (create_fn == null) return FAILED_OPENING_WINDOW~;
	}
	defer { if (vk_lib != null) dlclose(vk_lib); }

	VkMetalSurfaceCreateInfo create_info = {
		.sType = 1000217000,
		.pNext = null,
		.flags = 0,
		.pLayer = self.src.layer.id,
	};

	void* surface;
	int result = create_fn(vk_instance, &create_info, null, &surface);
	if (result != 0) return FAILED_OPENING_WINDOW~;

	return surface;
}

// macOS NSEvent types (for internal use)
enum DarwinEventType : uint (uint value)
{
	EMPTY_KEY           { 0 },
	LEFT_MOUSE_DOWN     { 1 },
	LEFT_MOUSE_UP       { 2 },
	RIGHT_MOUSE_DOWN    { 3 },
	RIGHT_MOUSE_UP      { 4 },
	MOUSE_MOVED         { 5 },
	LEFT_MOUSE_DRAGGED  { 6 },
	RIGHT_MOUSE_DRAGGED { 7 },
	MOUSE_ENTERED       { 8 },
	MOUSE_EXITED        { 9 },
	KEY_PRESSED         { 10 },
	KEY_RELEASED        { 11 },
	FLAGS_CHANGED       { 12 },
	APPKIT_DEFINED      { 13 },
	SYSTEM_DEFINED      { 14 },
	APPLICATION_DEFINED { 15 },
	PERIODIC            { 16 },
	CURSOR_UPDATE       { 17 },
	SCROLL_WHEEL        { 22 },
	TABLET_POINT        { 23 },
	TABLET_PROXIMITY    { 24 },
	OTHER_MOUSE_DOWN    { 25 },
	OTHER_MOUSE_UP      { 26 },
	OTHER_MOUSE_DRAGGED { 27 },
	GESTURE             { 29 },
	MAGNIFY             { 30 },
	SWIPE               { 31 },
	ROTATE              { 18 },
	BEGIN_GESTURE       { 19 },
	END_GESTURE         { 20 },
	SMART_MAGNIFY       { 32 },
	QUICK_LOOK          { 33 },
	PRESSURE            { 34 },
	DIRECT_TOUCH        { 37 },
	CHANGE_MODE         { 38 },
}

// Convert macOS keycode to unified EventKey
fn EventKey darwinKeycodeToEventKey(int keycode)
{
	switch (keycode)
	{
		// Letters
		case 0:
			return A;
		case 11:
			return B;
		case 8:
			return C;
		case 2:
			return D;
		case 14:
			return E;
		case 3:
			return F;
		case 5:
			return G;
		case 4:
			return H;
		case 34:
			return I;
		case 38:
			return J;
		case 40:
			return K;
		case 37:
			return L;
		case 46:
			return M;
		case 45:
			return N;
		case 31:
			return O;
		case 35:
			return P;
		case 12:
			return Q;
		case 15:
			return R;
		case 1:
			return S;
		case 17:
			return T;
		case 32:
			return U;
		case 9:
			return V;
		case 13:
			return W;
		case 7:
			return X;
		case 16:
			return Y;
		case 6:
			return Z;
			// Number row
		case 29:
			return KEY_0;
		case 18:
			return KEY_1;
		case 19:
			return KEY_2;
		case 20:
			return KEY_3;
		case 21:
			return KEY_4;
		case 23:
			return KEY_5;
		case 22:
			return KEY_6;
		case 26:
			return KEY_7;
		case 28:
			return KEY_8;
		case 25:
			return KEY_9;
			// Special keys
		case 53:
			return ESCAPE;
		case 36:
			return RETURN;
		case 49:
			return SPACE;
		case 51:
			return DELETE;
		case 48:
			return TAB;
		case 117:
			return BACKSPACE; // Forward delete
		case 57:
			return CAPS_LOCK;
			// Modifier keys
		case 56:
			return LEFT_SHIFT;
		case 60:
			return RIGHT_SHIFT;
		case 59:
			return LEFT_CTRL;
		case 62:
			return RIGHT_CTRL;
		case 58:
			return LEFT_ALT; // Option
		case 61:
			return RIGHT_ALT; // Right Option
		case 55:
			return LEFT_SUPER; // Command
		case 54:
			return RIGHT_SUPER; // Right Command
		case 110:
			return MENU; // Context menu (if present)
			// Arrow keys
		case 123:
			return LEFT_ARROW;
		case 124:
			return RIGHT_ARROW;
		case 125:
			return DOWN_ARROW;
		case 126:
			return UP_ARROW;
			// Numpad
		case 71:
			return NUMLOCK;
		case 82:
			return NUM_0;
		case 83:
			return NUM_1;
		case 84:
			return NUM_2;
		case 85:
			return NUM_3;
		case 86:
			return NUM_4;
		case 87:
			return NUM_5;
		case 88:
			return NUM_6;
		case 89:
			return NUM_7;
		case 91:
			return NUM_8;
		case 92:
			return NUM_9;
		case 76:
			return KP_RETURN;
		case 69:
			return KP_ADD;
		case 78:
			return KP_SUBTRACT;
		case 67:
			return KP_MULTIPLY;
		case 75:
			return KP_DIVIDE;
		case 65:
			return KP_DECIMAL;
			// Function keys
		case 122:
			return F1;
		case 120:
			return F2;
		case 99:
			return F3;
		case 118:
			return F4;
		case 96:
			return F5;
		case 97:
			return F6;
		case 98:
			return F7;
		case 100:
			return F8;
		case 101:
			return F9;
		case 109:
			return F10;
		case 103:
			return F11;
		case 111:
			return F12;
		case 105:
			return F13;
		case 107:
			return F14;
		case 113:
			return F15;
		case 106:
			return F16;
		case 64:
			return F17;
		case 79:
			return F18;
		case 80:
			return F19;
		case 90:
			return F20;
			// Navigation
		case 115:
			return HOME;
		case 119:
			return END;
		case 116:
			return PAGE_UP;
		case 121:
			return PAGE_DOWN;
		case 114:
			return INSERT; // Help key acts as Insert
			// Punctuation and symbols
		case 27:
			return MINUS;
		case 24:
			return EQUALS;
		case 33:
			return LEFT_BRACKET;
		case 30:
			return RIGHT_BRACKET;
		case 42:
			return BACKSLASH;
		case 41:
			return SEMICOLON;
		case 39:
			return APOSTROPHE;
		case 50:
			return GRAVE;
		case 43:
			return COMMA;
		case 47:
			return PERIOD_KEY;
		case 44:
			return SLASH_KEY;
		default:
			return EMPTY_KEY;
	}
}
