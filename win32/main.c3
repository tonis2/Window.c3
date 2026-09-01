module c3w @feat(WIN32);
import std::math;
import std::os::win32;
import std::io;

// Win32 message constants
const uint WM_PAINT       = 0x000F;
const uint WM_DESTROY     = 0x0002;
const uint WM_SIZE        = 0x0005;
const uint WM_CLOSE       = 0x0010;
const uint WM_QUIT        = 0x0012;
const uint WM_KEYDOWN     = 0x0100;
const uint WM_KEYUP       = 0x0101;
const uint WM_MOUSEMOVE   = 0x0200;
const uint WM_LBUTTONDOWN = 0x0201;
const uint WM_LBUTTONUP   = 0x0202;
const uint WM_RBUTTONDOWN = 0x0204;
const uint WM_RBUTTONUP   = 0x0205;
const uint WM_MBUTTONDOWN = 0x0207;
const uint WM_MBUTTONUP   = 0x0208;
const uint WM_MOUSEWHEEL  = 0x020A;
const uint WM_MOUSEHWHEEL = 0x020E;
const uint WM_CHAR        = 0x0102;

// One notch of a detented wheel. Windows reports rotation in multiples of this
// so that a free-spinning wheel can send fractions of a notch; dividing by it
// puts the answer in the same units the X11 backend reports, which is notches.
const float WHEEL_DELTA = 120.0;

// PeekMessage flags
const uint PM_REMOVE   = 0x0001;
const uint PM_NOREMOVE = 0x0000;

// Class styles
const uint CS_HREDRAW = 0x0002;
const uint CS_VREDRAW = 0x0001;
const uint CS_OWNDC   = 0x0020;

// ShowWindow commands
const int SW_SHOW     = 5;
const int SW_HIDE     = 0;
const int SW_MINIMIZE = 6;
const int SW_RESTORE  = 9;

// SetWindowPos flags
// Fullscreen, which on Windows is a style change and a move rather than a mode:
// the borderless-over-the-monitor-rect shape, so the compositor never switches
// the display and alt-tab stays instant.
const int GWL_STYLE = -16;
const uint SWP_NOSIZE          = 0x0001;
const uint SWP_FRAMECHANGED    = 0x0020;
const uint SWP_NOOWNERZORDER   = 0x0200;
const uint MONITOR_DEFAULTTONEAREST = 2;

typedef HMonitor = void*;

struct MonitorInfo
{
	uint cbSize;
	Rect rcMonitor;
	Rect rcWork;
	uint dwFlags;
}

<*
 What `GetWindowPlacement` fills, so leaving fullscreen puts the window back
 exactly where it was — including the fact that it was maximised.
*>
struct WindowPlacement
{
	uint length;
	uint flags;
	uint showCmd;
	Point ptMinPosition;
	Point ptMaxPosition;
	Rect rcNormalPosition;
}

extern fn bool setWindowTextW(HWnd hwnd, Char16* text) @cname("SetWindowTextW");
extern fn iptr getWindowLongPtrW(HWnd hwnd, int index) @cname("GetWindowLongPtrW");
extern fn iptr setWindowLongPtrW(HWnd hwnd, int index, iptr value) @cname("SetWindowLongPtrW");
extern fn HMonitor monitorFromWindow(HWnd hwnd, uint flags) @cname("MonitorFromWindow");
extern fn bool getMonitorInfoW(HMonitor monitor, MonitorInfo* info) @cname("GetMonitorInfoW");
extern fn bool getWindowPlacement(HWnd hwnd, WindowPlacement* placement) @cname("GetWindowPlacement");
extern fn bool setWindowPlacement(HWnd hwnd, WindowPlacement* placement) @cname("SetWindowPlacement");

const uint SWP_NOMOVE     = 0x0002;
const uint SWP_NOZORDER   = 0x0004;
const uint SWP_NOACTIVATE = 0x0010;

// Default window icons/cursors
const uptr IDI_APPLICATION = 32512;
const uptr IDC_ARROW       = 32512;

// Window background
const iptr COLOR_WINDOW = 5;

// Type aliases matching C3 std::os::win32 naming
alias HWnd = win32::Win32_HWND;
alias HInstance = win32::Win32_HINSTANCE;
alias HDc = win32::Win32_HDC;
alias HIcon = win32::Win32_HICON;
alias HCursor = win32::Win32_HCURSOR;
alias HBrush = win32::Win32_HBRUSH;
alias HMenu = win32::Win32_HMENU;
alias LResult = win32::Win32_LRESULT;
alias WParam = win32::Win32_WPARAM;
alias LParam = win32::Win32_LPARAM;
alias Atom = win32::Win32_ATOM;
alias Point = win32::Win32_POINT;
alias Rect = win32::Win32_RECT;
alias Msg = win32::Win32_MSG;
alias WndClassExW = win32::Win32_WNDCLASSEXW;
alias Char16 = win32::Win32_WCHAR;

extern fn int peekMessageW(Msg* msg, HWnd hwnd, uint filterMin, uint filterMax, uint removeMsg) @cname("PeekMessageW");


extern fn void postQuitMessage(int exitCode) @cname("PostQuitMessage");


extern fn HCursor loadCursorW(HInstance instance, Char16* name) @cname("LoadCursorW");


extern fn HIcon loadIconW(HInstance instance, Char16* name) @cname("LoadIconW");


extern fn bool getCursorPos(Point* point) @cname("GetCursorPos");
extern fn bool setCursorPos(int x, int y) @cname("SetCursorPos");
extern fn bool clientToScreen(HWnd hwnd, Point* point) @cname("ClientToScreen");
extern fn bool clipCursor(Rect* rect) @cname("ClipCursor");
extern fn int showCursor(bool show) @cname("ShowCursor");


extern fn bool screenToClient(HWnd hwnd, Point* point) @cname("ScreenToClient");


extern fn bool destroyWindow(HWnd hwnd) @cname("DestroyWindow");


extern fn int releaseDC(HWnd hwnd, HDc hdc) @cname("ReleaseDC");


extern fn HDc getDC(HWnd hwnd) @cname("GetDC");


extern fn HInstance getModuleHandleW(Char16* name) @cname("GetModuleHandleW");

extern fn bool setWindowPos(HWnd hwnd, HWnd insertAfter, int x, int y, int cx, int cy, uint flags) @cname("SetWindowPos");

extern fn bool showWindow(HWnd hwnd, int cmdShow) @cname("ShowWindow");

extern fn bool getWindowRect(HWnd hwnd, Rect* rect) @cname("GetWindowRect");

extern fn bool getClientRect(HWnd hwnd, Rect* rect) @cname("GetClientRect");

// Windows 10 1607 and later. Answers in dots per inch for the display this
// window is on, 96 being 1:1 — and answers 96 whatever the display is doing
// unless the process has declared itself DPI-aware, which `new` does below.
extern fn uint getDpiForWindow(HWnd hwnd) @cname("GetDpiForWindow");

// The same for the primary display, and the only one of the two that can be
// asked before a window exists. Windows 10 1607 and later.
extern fn uint getDpiForSystem() @cname("GetDpiForSystem");

// Windows 10 1703 and later. Fails — harmlessly — when the awareness has
// already been set, which is what happens if the application ships a manifest
// that says so; the manifest wins and this is a no-op.
extern fn bool setProcessDpiAwarenessContext(void* context) @cname("SetProcessDpiAwarenessContext");

// DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2. A pseudo-handle rather than a
// pointer to anything, which is why it is written as a cast of -4 and not as a
// constant with a type.
const void* DPI_PER_MONITOR_AWARE_V2 = (void*)(uptr)(iptr)-4;

// What Windows calls 100%: the DPI at which one logical unit is one pixel.
const float USER_DEFAULT_SCREEN_DPI = 96.0;


struct Win32Window
{
	HWnd hwnd;
	HInstance instance;
	HDc hdc;
	EventMap event_map;
	EventLog event_log;     // the transitions behind the map, same call
	bool close_requested;   // set by WM_QUIT, queried via Window.should_close
	float[<2>] mouse_pos;
	double scroll_delta;    // accumulated over the last getEvent call (+ = away)
	double scroll_delta_x;  // the horizontal half (+ = right)
	DString text;           // UTF-8 typed during the last getEvent call
	// A WM_CHAR carries one UTF-16 code unit, so anything past the basic plane
	// arrives as two messages. The first is held here until the second comes.
	Char16 pending_surrogate;

	// The cursor's movement over the last `getEvent`, differenced from where it
	// was at the previous one. `has_last` is what stops the first call
	// reporting the trip from a remembered zero as a hand movement.
	float[<2>] mouse_delta;
	float[<2>] last_mouse;
	bool has_last;

	bool pointer_locked;

	// Fullscreen is a style change here, so leaving it needs what was replaced:
	// the placement (position, size, and whether it was maximised) and the style
	// bits that were taken out. Meaningless unless `is_fullscreen`.
	WindowPlacement saved_placement;
	iptr saved_style;
	bool is_fullscreen;
}

// Window procedure callback
fn LResult windowProc(HWnd hwnd, uint msg, WParam wparam, LParam lparam) @cname("c3w_window_proc")
{
	switch (msg)
	{
		case WM_CLOSE:
			postQuitMessage(0);
			return 0;
		case WM_DESTROY:
			return 0;
		default:
			return win32::defWindowProcW(hwnd, msg, wparam, lparam);
	}
}

<*
 Open a window.

 **`params` are logical units, and this is where Windows is made to agree.**
 Every other backend reports a cursor, a size and a scale in units that are the
 same size on screen whatever the display density, and answers `get_scale` with
 the ratio between those and pixels. Windows only does that for a process that
 has said it understands DPI: without the declaration the compositor stretches
 the whole window afterwards, `GetDpiForWindow` answers 96 to keep the lie
 consistent, and a 4K display gets a blurry window and a scale of 1.

 So the declaration is made here, before any window exists, and the requested
 size is multiplied by the display's DPI — which keeps a window the same
 physical size it was before this line was added, and makes `get_scale` mean
 what it means everywhere else.

 It is a library making a process-wide decision, which is worth being uneasy
 about. The defence is that it is the same decision the other backends have
 already had made for them by their platform, that a window library is the piece
 that knows what a "logical unit" is meant to be, and that an application which
 disagrees can say so in its manifest — the manifest is applied first and this
 call then fails and changes nothing.

 **Not yet per-monitor in practice.** The context asked for is the per-monitor
 one, but nothing here handles `WM_DPICHANGED`, so a window dragged between
 displays of different densities keeps the size it was given and `get_scale`
 starts answering the new display's ratio. The parts that read the scale every
 frame — a cursor, a pan — follow it correctly; the window's own size does not.
*>
fn Window? new(Params params, String name)
{
	// Before the window, and before anything reads a coordinate: this changes
	// what every number in the process means.
	setProcessDpiAwarenessContext(DPI_PER_MONITOR_AWARE_V2);

	uint dpi = getDpiForSystem();
	if (dpi == 0) dpi = (uint)USER_DEFAULT_SCREEN_DPI;
	int scaled_width  = (int)((float)params.width * (float)dpi / USER_DEFAULT_SCREEN_DPI);
	int scaled_height = (int)((float)params.height * (float)dpi / USER_DEFAULT_SCREEN_DPI);

	HInstance instance = getModuleHandleW(null);

	// Convert name to wide string
	Char16[256] class_name_wide;
	Char16[256] window_name_wide;

	ZString class_name  = "c3w_window_class";
	ZString window_name = (ZString)name;

	// Simple ASCII to UTF-16 conversion
	sz i = 0;
	while (class_name[i] != 0 && i < 255)
	{
		class_name_wide[i] = (Char16)class_name[i];
		i++;
	}
	class_name_wide[i] = 0;

	i = 0;
	while (window_name[i] != 0 && i < 255)
	{
		window_name_wide[i] = (Char16)window_name[i];
		i++;
	}
	window_name_wide[i] = 0;

	WndClassExW wc = {
		.cbSize = WndClassExW::size,
		.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC,
		.lpfnWndProc = &windowProc,
		.cbClsExtra = 0,
		.cbWndExtra = 0,
		.hInstance = instance,
		.hIcon = loadIconW(null, (Char16*)IDI_APPLICATION),
		.hCursor = loadCursorW(null, (Char16*)IDC_ARROW),
		.hbrBackground = (HBrush)(COLOR_WINDOW + 1),
		.lpszMenuName = null,
		.lpszClassName = &class_name_wide,
		.hIconSm = null,
		};

	Atom atom = win32::registerClassExW(&wc);
	if (atom == 0)
	{
		return FAILED_OPENING_WINDOW~;
	}

	HWnd hwnd = win32::createWindowExW(
		0, // Extended style
		&class_name_wide, // Class name
		&window_name_wide, // Window name
		win32::WS_OVERLAPPEDWINDOW, // Style
		params.x, // X position
		params.y, // Y position
		scaled_width, // Width, in the pixels a DPI-aware process is measured in
		scaled_height, // Height
		null, // Parent
		null, // Menu
		instance, // Instance
		null // lpParam
	);

	if (hwnd == null)
	{
		return FAILED_OPENING_WINDOW~;
	}

	HDc hdc = getDC(hwnd);
	win32::showWindow(hwnd, SW_SHOW);
	win32::updateWindow(hwnd);

	return {
		.src = { .hwnd = hwnd, .instance = instance, .hdc = hdc, .text = dstring::new(mem) },
		.width = params.width,
		.height = params.height,
	};
}

<*
 Where the pointer is, window-relative.

 **Two conversions, and neither is optional if this is to answer the question
 the other backends answer.** Win32 reports the client area in physical pixels
 with a top-left origin; the c3w contract is the window's own logical units with
 a bottom-left one — Cocoa's, which the Linux backends also convert to and which
 the reference renderer flips back.

 The height is read off `GetClientRect` rather than off `Window.height`, because
 the flip has to use the size the window *is* and `Window.height` is only ever
 the size `new` was asked for. A window that has been resized would otherwise
 report a cursor offset by however much it grew, and only vertically, which is
 the sort of thing that reads as a bad picker rather than as a stale field.
*>
fn float[<2>] Window.getMousePos(&self)
{
	Point point;
	getCursorPos(&point);
	screenToClient(self.src.hwnd, &point);

	Rect client;
	if (!getClientRect(self.src.hwnd, &client)) return { 0, 0 };

	float scale = self.get_scale();
	if (scale <= 0.0f) scale = 1.0f;

	float bottom_up = (float)(client.bottom - client.top) - (float)point.y;
	return { (float)point.x / scale, bottom_up / scale };
}

<*
 Make a waiting `getEvent` return, from any thread.

 Nothing to do here: this backend drains the queue with PeekMessage and never
 blocks, `wait` or not, so the loop is already reachable from any thread — it
 spins rather than parks. Present so a caller can wake a window without asking
 which platform it is on.
*>
fn void Window.wake(&self)
{
}

fn EventMap Window.getEvent(&self, bool wait = false)
{
	Msg msg;

	// Per-frame state: scroll, typed text and the transition log accumulate over
	// this call only; the latched key/button map persists across frames.
	self.src.event_map.set(MOUSE_SCROLL_UP, false);
	self.src.event_map.set(MOUSE_SCROLL_DOWN, false);
	self.src.scroll_delta = 0;
	self.src.scroll_delta_x = 0;
	self.src.text.clear();
	self.src.event_log.clear();

	while (peekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0)
	{
		win32::translateMessage(&msg);
		win32::dispatchMessage(&msg);

		switch (msg.message)
		{
			case WM_QUIT:
				// Posted by `windowProc`'s WM_CLOSE. It used to latch ESCAPE
				// here, which worked only because the one application reading
				// this happened to exit on Escape — and cost that application
				// the Escape key, which reads as held for the rest of the run.
				self.src.close_requested = true;
			case WM_KEYDOWN:
				EventKey key = win32VkToEventKey((uint)msg.wParam);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, true);
					self.src.event_log.push_key(key, true);
				}
			case WM_KEYUP:
				EventKey key = win32VkToEventKey((uint)msg.wParam);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, false);
					self.src.event_log.push_key(key, false);
				}
			case WM_CHAR:
				// Posted by TranslateMessage above, so it arrives on a later
				// turn of this same loop. It carries the layout, the dead keys
				// and the shift state already applied, which is the whole reason
				// to read it rather than translating the key map by hand.
				self.append_typed((Char16)(msg.wParam & 0xFFFF));
			case WM_LBUTTONDOWN:
				self.src.event_map.set(LEFT_MOUSE, true);
				self.src.event_log.push_button(LEFT_MOUSE, true);
			case WM_LBUTTONUP:
				self.src.event_map.set(LEFT_MOUSE, false);
				self.src.event_log.push_button(LEFT_MOUSE, false);
			case WM_RBUTTONDOWN:
				self.src.event_map.set(RIGHT_MOUSE, true);
				self.src.event_log.push_button(RIGHT_MOUSE, true);
			case WM_RBUTTONUP:
				self.src.event_map.set(RIGHT_MOUSE, false);
				self.src.event_log.push_button(RIGHT_MOUSE, false);
			case WM_MBUTTONDOWN:
				self.src.event_map.set(MIDDLE_MOUSE, true);
				self.src.event_log.push_button(MIDDLE_MOUSE, true);
			case WM_MBUTTONUP:
				self.src.event_map.set(MIDDLE_MOUSE, false);
				self.src.event_log.push_button(MIDDLE_MOUSE, false);
			case WM_MOUSEWHEEL:
				short delta = (short)((msg.wParam >> 16) & 0xFFFF);
				self.src.scroll_delta += (double)delta / WHEEL_DELTA;
				if (delta > 0)
				{
					self.src.event_map.set(MOUSE_SCROLL_UP, true);
				}
				else
				{
					self.src.event_map.set(MOUSE_SCROLL_DOWN, true);
				}
			case WM_MOUSEHWHEEL:
				// Positive is a tilt to the right, which is the direction the
				// other backends call positive too.
				short h_delta = (short)((msg.wParam >> 16) & 0xFFFF);
				self.src.scroll_delta_x += (double)h_delta / WHEEL_DELTA;
			case WM_MOUSEMOVE:
				self.src.mouse_pos = { (float)(msg.lParam & 0xFFFF), (float)((msg.lParam >> 16) & 0xFFFF) };
			default:
		}
	}

	// After the drain, so the recentre's own WM_MOUSEMOVE lands in the next
	// call's queue rather than in this frame's delta.
	self.track_mouse_delta();
	self.keep_pointer_centred();

	return self.src.event_map;
}

fn void Window.free(&self)
{
	self.src.text.free();
	if (self.src.hdc != null)
	{
		releaseDC(self.src.hwnd, self.src.hdc);
	}
	if (self.src.hwnd != null)
	{
		destroyWindow(self.src.hwnd);
	}
}

// Convert Win32 virtual key code to unified EventKey
fn EventKey win32VkToEventKey(uint vk)
{
	switch (vk)
	{
		// Special keys
		case 0x1B:
			return ESCAPE; // VK_ESCAPE
		case 0x0D:
			return RETURN; // VK_RETURN
		case 0x20:
			return SPACE; // VK_SPACE
		case 0x2E:
			return DELETE; // VK_DELETE
		case 0x09:
			return TAB; // VK_TAB
		case 0x08:
			return BACKSPACE; // VK_BACK
		case 0x2D:
			return INSERT; // VK_INSERT
		case 0x14:
			return CAPS_LOCK; // VK_CAPITAL
			// Modifier keys
		case 0xA0:
			return LEFT_SHIFT; // VK_LSHIFT
		case 0xA1:
			return RIGHT_SHIFT; // VK_RSHIFT
		case 0xA2:
			return LEFT_CTRL; // VK_LCONTROL
		case 0xA3:
			return RIGHT_CTRL; // VK_RCONTROL
		case 0xA4:
			return LEFT_ALT; // VK_LMENU
		case 0xA5:
			return RIGHT_ALT; // VK_RMENU
		case 0x5B:
			return LEFT_SUPER; // VK_LWIN
		case 0x5C:
			return RIGHT_SUPER; // VK_RWIN
		case 0x5D:
			return MENU; // VK_APPS
			// Also handle generic shift/ctrl/alt
		case 0x10:
			return LEFT_SHIFT; // VK_SHIFT
		case 0x11:
			return LEFT_CTRL; // VK_CONTROL
		case 0x12:
			return LEFT_ALT; // VK_MENU
			// Number row
		case 0x30:
			return KEY_0;
		case 0x31:
			return KEY_1;
		case 0x32:
			return KEY_2;
		case 0x33:
			return KEY_3;
		case 0x34:
			return KEY_4;
		case 0x35:
			return KEY_5;
		case 0x36:
			return KEY_6;
		case 0x37:
			return KEY_7;
		case 0x38:
			return KEY_8;
		case 0x39:
			return KEY_9;
			// Letters
		case 0x41:
			return A;
		case 0x42:
			return B;
		case 0x43:
			return C;
		case 0x44:
			return D;
		case 0x45:
			return E;
		case 0x46:
			return F;
		case 0x47:
			return G;
		case 0x48:
			return H;
		case 0x49:
			return I;
		case 0x4A:
			return J;
		case 0x4B:
			return K;
		case 0x4C:
			return L;
		case 0x4D:
			return M;
		case 0x4E:
			return N;
		case 0x4F:
			return O;
		case 0x50:
			return P;
		case 0x51:
			return Q;
		case 0x52:
			return R;
		case 0x53:
			return S;
		case 0x54:
			return T;
		case 0x55:
			return U;
		case 0x56:
			return V;
		case 0x57:
			return W;
		case 0x58:
			return X;
		case 0x59:
			return Y;
		case 0x5A:
			return Z;
			// Arrow keys
		case 0x25:
			return LEFT_ARROW; // VK_LEFT
		case 0x27:
			return RIGHT_ARROW; // VK_RIGHT
		case 0x26:
			return UP_ARROW; // VK_UP
		case 0x28:
			return DOWN_ARROW; // VK_DOWN
			// Numpad
		case 0x90:
			return NUMLOCK; // VK_NUMLOCK
		case 0x60:
			return NUM_0; // VK_NUMPAD0
		case 0x61:
			return NUM_1;
		case 0x62:
			return NUM_2;
		case 0x63:
			return NUM_3;
		case 0x64:
			return NUM_4;
		case 0x65:
			return NUM_5;
		case 0x66:
			return NUM_6;
		case 0x67:
			return NUM_7;
		case 0x68:
			return NUM_8;
		case 0x69:
			return NUM_9;
		case 0x6B:
			return KP_ADD; // VK_ADD
		case 0x6D:
			return KP_SUBTRACT; // VK_SUBTRACT
		case 0x6A:
			return KP_MULTIPLY; // VK_MULTIPLY
		case 0x6F:
			return KP_DIVIDE; // VK_DIVIDE
		case 0x6E:
			return KP_DECIMAL; // VK_DECIMAL
			// Function keys
		case 0x70:
			return F1;
		case 0x71:
			return F2;
		case 0x72:
			return F3;
		case 0x73:
			return F4;
		case 0x74:
			return F5;
		case 0x75:
			return F6;
		case 0x76:
			return F7;
		case 0x77:
			return F8;
		case 0x78:
			return F9;
		case 0x79:
			return F10;
		case 0x7A:
			return F11;
		case 0x7B:
			return F12;
		case 0x7C:
			return F13;
		case 0x7D:
			return F14;
		case 0x7E:
			return F15;
		case 0x7F:
			return F16;
		case 0x80:
			return F17;
		case 0x81:
			return F18;
		case 0x82:
			return F19;
		case 0x83:
			return F20;
			// Navigation
		case 0x24:
			return HOME; // VK_HOME
		case 0x23:
			return END; // VK_END
		case 0x21:
			return PAGE_UP; // VK_PRIOR
		case 0x22:
			return PAGE_DOWN; // VK_NEXT
			// Punctuation and symbols (US keyboard layout)
		case 0xBD:
			return MINUS; // VK_OEM_MINUS
		case 0xBB:
			return EQUALS; // VK_OEM_PLUS (= key)
		case 0xDB:
			return LEFT_BRACKET; // VK_OEM_4 ([)
		case 0xDD:
			return RIGHT_BRACKET; // VK_OEM_6 (])
		case 0xDC:
			return BACKSLASH; // VK_OEM_5 (\)
		case 0xBA:
			return SEMICOLON; // VK_OEM_1 (;)
		case 0xDE:
			return APOSTROPHE; // VK_OEM_7 (')
		case 0xC0:
			return GRAVE; // VK_OEM_3 (`)
		case 0xBC:
			return COMMA; // VK_OEM_COMMA
		case 0xBE:
			return PERIOD_KEY; // VK_OEM_PERIOD
		case 0xBF:
			return SLASH_KEY; // VK_OEM_2 (/)
			// Lock keys
		case 0x91:
			return SCROLL_LOCK; // VK_SCROLL
		case 0x13:
			return PAUSE; // VK_PAUSE
		case 0x2C:
			return PRINT_SCREEN; // VK_SNAPSHOT
		default:
			return EMPTY_KEY;
	}
}


// Vulkan code
extern fn void* loadLibraryA(char* name) @cname("LoadLibraryA");
extern fn void* getProcAddress(void* mod, char* name) @cname("GetProcAddress");
extern fn bool freeLibrary(void* mod) @cname("FreeLibrary");

struct VkWin32SurfaceCreateInfo
{
	uint sType;
	void* pNext;
	uint flags;
	void* hinstance;
	void* hwnd;
}

alias VkCreateSurfaceFn = fn int(void*, void*, void*, void*);
alias VkSurface = void*;

// See the note in darwin/main.c3: a caller that links Vulkan itself passes
// vkGetInstanceProcAddr in, which is the only way to reach a statically linked
// loader. Left null, vulkan-1.dll is loaded by name as before.
alias VkGetInstanceProcAddrFn = fn void*(void*, char*);

fn VkSurface? Window.create_vk_surface(&self, void* vk_instance, VkGetInstanceProcAddrFn get_instance_proc_addr = null)
{
	VkCreateSurfaceFn create_fn = null;
	void* vk_lib = null;

	if (get_instance_proc_addr != null)
	{
		create_fn = (VkCreateSurfaceFn)get_instance_proc_addr(vk_instance, "vkCreateWin32SurfaceKHR");
	}

	if (create_fn == null)
	{
		vk_lib = loadLibraryA("vulkan-1.dll");
		if (vk_lib == null) return FAILED_OPENING_WINDOW~;

		create_fn = (VkCreateSurfaceFn)getProcAddress(vk_lib, "vkCreateWin32SurfaceKHR");
		if (create_fn == null) return FAILED_OPENING_WINDOW~;
	}
	defer { if (vk_lib != null) freeLibrary(vk_lib); }

	VkWin32SurfaceCreateInfo create_info = {
		.sType = 1000009000,
		.pNext = null,
		.flags = 0,
		.hinstance = self.src.instance,
		.hwnd = self.src.hwnd,
	};

	void* surface;
	int result = create_fn(vk_instance, &create_info, null, &surface);
	if (result != 0) return FAILED_OPENING_WINDOW~;

	return surface;
}

// --- API parity with the darwin backend (real implementations TODO) ---
<*
 Resize the window, in the same logical points `new` took.

 Those are a *client* size, and `SetWindowPos` takes a whole-window size, so
 the chrome is measured as the difference between the two rects and added back.
 Deriving it that way rather than from `AdjustWindowRect` means the window's
 actual style — menu bar, borders, whatever a later change adds — is accounted
 for without this having to know about it.
*>
fn void Window.set_size(&self, int width, int height)
{
	if (self.src.hwnd == null) return;

	Rect frame;
	Rect client;
	if (!getWindowRect(self.src.hwnd, &frame)) return;
	if (!getClientRect(self.src.hwnd, &client)) return;

	int chrome_width  = (frame.right - frame.left) - (client.right - client.left);
	int chrome_height = (frame.bottom - frame.top) - (client.bottom - client.top);

	// The rects are physical pixels — `new` declared this process DPI-aware —
	// and the arguments are logical units, which is the contract this shares
	// with every other backend. The chrome is already physical and stays so.
	float scale = self.get_scale();
	if (scale <= 0.0f) scale = 1.0f;

	setWindowPos(
		self.src.hwnd,
		(HWnd)null,
		0,
		0,
		(int)((float)width * scale) + chrome_width,
		(int)((float)height * scale) + chrome_height,
		SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE
	);
}

<*
 Rename the window's title bar.

 `SetWindowTextW` and a real UTF-16 conversion, rather than the ASCII widening
 `new` does for the class name: a title is a game's own name and is as likely to
 carry an accent as not.
*>
fn void Window.set_title(&self, String title)
{
	if (self.src.hwnd == null) return;
	@pool()
	{
		WString wide = title.to_temp_wstring() ?? (WString)null;
		if (wide == null) return;
		setWindowTextW(self.src.hwnd, (Char16*)wide);
	};
}

<*
 Whether the window is currently filling a monitor.

 Remembered rather than read back, unlike macOS. There is no Windows state that
 says "fullscreen" — the window is merely borderless and the size of a display —
 so the only honest answer is what this library last did.
*>
fn bool Window.fullscreen(&self)
{
	return self.src.is_fullscreen;
}

<*
 Enter or leave borderless fullscreen.

 Borderless over the monitor's rect rather than an exclusive mode change: the
 display's resolution never moves, so alt-tab is instant, the desktop behind is
 undisturbed and a crash cannot leave a monitor in a mode nobody asked for. The
 render size is a boot argument anyway — the swapchain stretches the offscreen
 target over whatever the window became — so an exclusive mode would buy the
 picture nothing.
*>
fn void Window.set_fullscreen(&self, bool on)
{
	if (self.src.hwnd == null || self.src.is_fullscreen == on) return;

	if (on)
	{
		self.src.saved_placement.length = (uint)@sizeof(self.src.saved_placement);
		if (!getWindowPlacement(self.src.hwnd, &self.src.saved_placement)) return;

		MonitorInfo info;
		info.cbSize = (uint)@sizeof(info);
		HMonitor monitor = monitorFromWindow(self.src.hwnd, MONITOR_DEFAULTTONEAREST);
		if (!getMonitorInfoW(monitor, &info)) return;

		self.src.saved_style = getWindowLongPtrW(self.src.hwnd, GWL_STYLE);
		setWindowLongPtrW(self.src.hwnd, GWL_STYLE, self.src.saved_style & ~(iptr)win32::WS_OVERLAPPEDWINDOW);
		setWindowPos(
			self.src.hwnd,
			(HWnd)null,
			info.rcMonitor.left,
			info.rcMonitor.top,
			info.rcMonitor.right - info.rcMonitor.left,
			info.rcMonitor.bottom - info.rcMonitor.top,
			SWP_NOOWNERZORDER | SWP_FRAMECHANGED
		);
		self.src.is_fullscreen = true;
		return;
	}

	setWindowLongPtrW(self.src.hwnd, GWL_STYLE, self.src.saved_style);
	setWindowPlacement(self.src.hwnd, &self.src.saved_placement);
	setWindowPos(
		self.src.hwnd,
		(HWnd)null,
		0,
		0,
		0,
		0,
		SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED
	);
	self.src.is_fullscreen = false;
}

<*
 Minimise the window to the taskbar, or restore it.
*>
fn void Window.set_minimized(&self, bool minimized)
{
	if (self.src.hwnd == null) return;
	showWindow(self.src.hwnd, minimized ? SW_MINIMIZE : SW_RESTORE);
}

// Accumulated wheel rotation over the last getEvent call, in notches
// (positive = away from the user), matching the X11 backend's units.
fn float Window.get_scroll(&self) => (float)self.src.scroll_delta;

// The horizontal half, same call and same units (positive = tilt right).
fn float Window.get_scroll_x(&self) => (float)self.src.scroll_delta_x;

<*
 Always false here, and that is the truth rather than a stub.

 The flag means "this came from a trackpad, in continuous units" — which on
 macOS is `hasPreciseScrollingDeltas`. The classic WM_MOUSEWHEEL path reports
 notches whatever the hardware is; a precision touchpad reports through the
 Pointer Input Stack instead, which this backend does not read.
*>
fn bool Window.get_scroll_precise(&self) => false;

// Text typed during the last getEvent call, as UTF-8. Borrowed — valid until
// the next one.
fn String Window.get_text(&self) => self.src.text.str_view();

<*
 Whether the window manager has asked this window to close.

 `windowProc` answers WM_CLOSE with `PostQuitMessage`, which lands here as
 WM_QUIT on the next drain. One flag on the window rather than one for the
 process, which is what the darwin backend has and what it would want.
*>
fn bool Window.should_close(&self) => self.src.close_requested;
fn void Window.set_cursor(&self, CursorShape shape) { }

<*
 Framebuffer pixels per logical window unit.

 1.0 on a standard-density display and 2.0 at 200%, matching what the darwin and
 wayland backends report. It is only meaningful because `new` declared the
 process DPI-aware; without that Windows answers 96 here whatever the display is
 doing, and says so on purpose — see `new`.
*>
fn float Window.get_scale(&self)
{
	if (self.src.hwnd == null) return 1.0;
	uint dpi = getDpiForWindow(self.src.hwnd);
	if (dpi == 0) return 1.0;
	return (float)dpi / 96.0f;
}

<*
 The key and button transitions the last `getEvent` drained, in order.

 See `EventLog`. The map this sits beside is a latch and cannot describe a press
 that began and ended between two calls; this can.
*>
fn Event[] Window.events(&self) => self.src.event_log.view();

<*
 One UTF-16 code unit from a WM_CHAR, as UTF-8.

 Surrogate pairs are the whole reason this is a function. A character past the
 basic plane arrives as two messages — a high unit then a low one — and
 appending each on its own writes two replacement characters where one emoji was
 meant. Control characters are dropped here for the same reason the other
 backends drop them: `get_text` is what a text field wants, and a text field
 does not want a backspace in the middle of its string.
*>
fn void Window.append_typed(&self, Char16 unit)
{
	if (unit >= 0xD800 && unit <= 0xDBFF)
	{
		self.src.pending_surrogate = unit;
		return;
	}

	Char32 c = unit;
	if (unit >= 0xDC00 && unit <= 0xDFFF)
	{
		// A low surrogate with nothing before it is a broken pair; dropping it
		// is better than emitting an unpaired one.
		if (self.src.pending_surrogate == 0) return;
		c = 0x10000
			+ (((Char32)self.src.pending_surrogate - 0xD800) << 10)
			+ ((Char32)unit - 0xDC00);
	}
	self.src.pending_surrogate = 0;

	if (c < 0x20 || c == 0x7F) return;
	self.src.text.append_char32(c);
}

<*
 The cursor's movement over the last `getEvent`, differenced against the
 previous one.

 In the same points `getMousePos` answers in, with the same bottom-up origin —
 so `[1]` is positive UPWARD here, where the darwin backend reports AppKit's
 downward `deltaY`. `scene/input.c3` turns either into image pixels.

 A difference rather than raw input. `WM_INPUT` and `RegisterRawInputDevices`
 are the better source and would keep reporting past the edge of the screen on
 their own; the recentre below is what stands in for that, and it is enough
 because a locked cursor never reaches an edge.
*>
fn float[<2>] Window.getMouseDelta(&self) => self.src.mouse_delta;

fn void Window.track_mouse_delta(&self)
{
	float[<2>] at = self.getMousePos();
	self.src.mouse_delta = self.src.has_last
		? (float[<2>]) { at.x - self.src.last_mouse.x, at.y - self.src.last_mouse.y }
		: (float[<2>]) { 0, 0 };
	self.src.last_mouse = at;
	self.src.has_last = true;
}

<*
 Take the cursor out of the user's hands, or give it back.

 Three things, and each covers a different half of what a lock has to be.
 `ShowCursor` makes it invisible; `ClipCursor` confines it to this window's
 client area so a click cannot land on another application; and
 `keep_pointer_centred` stops it resting against the clip rectangle, where the
 position stops changing and the differenced delta would go to nought — which
 is the failure a lock exists to remove, arriving through the clip that was
 meant to help.

 **`ShowCursor` is counted, exactly as `[NSCursor hide]` is on darwin.** Two
 hides need two shows, so this is guarded by the flag and is a no-op when it
 would be a repeat.

 **Untested.** No window from this backend has been on screen since any of the
 mouse work — `plan.md` §1 — so this is written to the documented behaviour of
 four calls and has never been watched.
*>
fn void Window.setPointerLock(&self, bool locked)
{
	if (locked == self.src.pointer_locked) return;
	self.src.pointer_locked = locked;

	if (!locked)
	{
		clipCursor(null);
		showCursor(true);
		return;
	}

	showCursor(false);
	self.clip_to_client();
	self.keep_pointer_centred(force: true);
}

fn bool Window.pointerLocked(&self) => self.src.pointer_locked;

// The client area in screen coordinates, which is what ClipCursor takes.
fn void Window.clip_to_client(&self)
{
	Rect client;
	if (!getClientRect(self.src.hwnd, &client)) return;

	Point top_left = { client.left, client.top };
	Point bottom_right = { client.right, client.bottom };
	if (!clientToScreen(self.src.hwnd, &top_left)) return;
	if (!clientToScreen(self.src.hwnd, &bottom_right)) return;

	Rect screen = { top_left.x, top_left.y, bottom_right.x, bottom_right.y };
	clipCursor(&screen);
}

<*
 Put the cursor back in the middle of the client area, if it has strayed far
 enough to be worth doing.

 The same rule the darwin backend follows and for the same reason: a warp is a
 round trip and perturbs the event stream, and the cursor only has to stay away
 from the edges. Left alone in the middle half, snapped back when it leaves.
*>
fn void Window.keep_pointer_centred(&self, bool force = false)
{
	if (!self.src.pointer_locked) return;

	Rect client;
	if (!getClientRect(self.src.hwnd, &client)) return;
	int width = client.right - client.left;
	int height = client.bottom - client.top;
	if (width <= 0 || height <= 0) return;

	Point at;
	if (!getCursorPos(&at)) return;
	Point local = at;
	if (!screenToClient(self.src.hwnd, &local)) return;

	if (!force)
	{
		int margin_x = width / 4;
		int margin_y = height / 4;
		bool inside = local.x > margin_x && local.x < width - margin_x
			&& local.y > margin_y && local.y < height - margin_y;
		if (inside) return;
	}

	Point centre = { width / 2, height / 2 };
	if (!clientToScreen(self.src.hwnd, &centre)) return;
	setCursorPos(centre.x, centre.y);
	// The tracker's last reading is now wrong by the whole warp, and the next
	// difference would report it as a hand movement across the window. Dropped
	// rather than corrected: one frame with no delta at the moment the cursor
	// is recentred is invisible, and a corrected one is a second place for the
	// two coordinate systems to disagree.
	self.src.has_last = false;
}
