module c3w @if(env::WIN32);
import std::math;
import std::os::win32;
import std::io;

// Win32 message constants
const uint WM_PAINT = 0x000F;
const uint WM_DESTROY = 0x0002;
const uint WM_SIZE = 0x0005;
const uint WM_CLOSE = 0x0010;
const uint WM_QUIT = 0x0012;
const uint WM_KEYDOWN = 0x0100;
const uint WM_KEYUP = 0x0101;
const uint WM_MOUSEMOVE = 0x0200;
const uint WM_LBUTTONDOWN = 0x0201;
const uint WM_LBUTTONUP = 0x0202;
const uint WM_RBUTTONDOWN = 0x0204;
const uint WM_RBUTTONUP = 0x0205;
const uint WM_MBUTTONDOWN = 0x0207;
const uint WM_MBUTTONUP = 0x0208;
const uint WM_MOUSEWHEEL = 0x020A;

// PeekMessage flags
const uint PM_REMOVE = 0x0001;
const uint PM_NOREMOVE = 0x0000;

// Class styles
const uint CS_HREDRAW = 0x0002;
const uint CS_VREDRAW = 0x0001;
const uint CS_OWNDC = 0x0020;

// ShowWindow commands
const int SW_SHOW = 5;
const int SW_HIDE = 0;

// Default window icons/cursors
const uptr IDI_APPLICATION = 32512;
const uptr IDC_ARROW = 32512;

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
alias Msg = win32::Win32_MSG;
alias WndClassExW = win32::Win32_WNDCLASSEXW;
alias Char16 = win32::Win32_WCHAR;

extern fn int peekMessageW(
	Msg* msg,
	HWnd hwnd,
	uint filterMin,
	uint filterMax,
	uint removeMsg
) @extern("PeekMessageW");


extern fn void postQuitMessage(int exitCode) @extern("PostQuitMessage");


extern fn HCursor loadCursorW(
	HInstance instance,
	Char16* name
) @extern("LoadCursorW");


extern fn HIcon loadIconW(
	HInstance instance,
	Char16* name
) @extern("LoadIconW");


extern fn bool getCursorPos(Point* point) @extern("GetCursorPos");


extern fn bool screenToClient(
	HWnd hwnd,
	Point* point
) @extern("ScreenToClient");


extern fn bool destroyWindow(HWnd hwnd) @extern("DestroyWindow");


extern fn int releaseDC(HWnd hwnd, HDc hdc) @extern("ReleaseDC");


extern fn HDc getDC(HWnd hwnd) @extern("GetDC");


extern fn HInstance getModuleHandleW(Char16* name) @extern("GetModuleHandleW");



struct Win32Window
{
	HWnd hwnd;
	HInstance instance;
	HDc hdc;
	EventMap event_map;
	float[<2>] mouse_pos;
}

// Window procedure callback
fn LResult windowProc(
	HWnd hwnd,
	uint msg,
	WParam wparam,
	LParam lparam
) @extern("c3w_window_proc")
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

fn Window? new(Params params, String name)
{
	HInstance instance = getModuleHandleW(null);

	// Convert name to wide string
	Char16[256] class_name_wide;
	Char16[256] window_name_wide;

	ZString class_name = "c3w_window_class";
	ZString window_name = (ZString)name;

	// Simple ASCII to UTF-16 conversion
	usz i = 0;
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
		.cbSize = WndClassExW.sizeof,
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
		params.width, // Width
		params.height, // Height
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
		.src = { .hwnd = hwnd, .instance = instance, .hdc = hdc, },
		.width = params.width,
		.height = params.height,
	};
}

fn float[<2>] Window.getMousePos(&self)
{
	Point point;
	getCursorPos(&point);
	screenToClient(self.src.hwnd, &point);
	return { (float)point.x, (float)point.y };
}

fn EventMap Window.getEvent(&self)
{
	Msg msg;

	// Reset scroll state each frame
	self.src.event_map.set(MOUSE_SCROLL_UP, false);
	self.src.event_map.set(MOUSE_SCROLL_DOWN, false);

	while (peekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0)
	{
		win32::translateMessage(&msg);
		win32::dispatchMessage(&msg);

		switch (msg.message)
		{
			case WM_QUIT:
				self.src.event_map.set(ESCAPE, true);
			case WM_KEYDOWN:
				EventKey key = win32VkToEventKey((uint)msg.wParam);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, true);
				}
			case WM_KEYUP:
				EventKey key = win32VkToEventKey((uint)msg.wParam);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, false);
				}
			case WM_LBUTTONDOWN:
				self.src.event_map.set(LEFT_MOUSE, true);
			case WM_LBUTTONUP:
				self.src.event_map.set(LEFT_MOUSE, false);
			case WM_RBUTTONDOWN:
				self.src.event_map.set(RIGHT_MOUSE, true);
			case WM_RBUTTONUP:
				self.src.event_map.set(RIGHT_MOUSE, false);
			case WM_MBUTTONDOWN:
				self.src.event_map.set(MIDDLE_MOUSE, true);
			case WM_MBUTTONUP:
				self.src.event_map.set(MIDDLE_MOUSE, false);
			case WM_MOUSEWHEEL:
				short delta = (short)((msg.wParam >> 16) & 0xFFFF);
				if (delta > 0)
				{
					self.src.event_map.set(MOUSE_SCROLL_UP, true);
				}
				else
				{
					self.src.event_map.set(MOUSE_SCROLL_DOWN, true);
				}
			case WM_MOUSEMOVE:
				self.src.mouse_pos = {
					(float)(msg.lParam & 0xFFFF),
					(float)((msg.lParam >> 16) & 0xFFFF)
				};
			default:
		}
	}

	return self.src.event_map;
}

fn void Window.free(&self)
{
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
