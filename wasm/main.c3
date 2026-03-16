module c3w @if(env::WASM);

// Event struct layout written by JS into WASM memory:
// offset 0: uint type (1=key_down, 2=key_up, 3=mouse_down, 4=mouse_up, 5=scroll, 6=motion)
// offset 4: uint code (key/button code)
// offset 8: float mouse_x
// offset 12: float mouse_y
struct JsEvent
{
	uint type;
	uint code;
	float mouse_x;
	float mouse_y;
}

struct WasmWindow
{
	EventMap event_map;
	float[<2>] mouse_pos;
}

// JS imports (provided by c3w.js bridge via env object)
extern fn void js_init_canvas(int width, int height) @cname("js_init_canvas");
extern fn void js_destroy_canvas() @cname("js_destroy_canvas");
extern fn int js_poll_event(JsEvent* event) @cname("js_poll_event");

fn Window? new(Params params, String name)
{
	js_init_canvas(params.width, params.height);

	return {
		.src = {},
		.width = params.width,
		.height = params.height,
	};
}

fn float[<2>] Window.getMousePos(self)
{
	return self.src.mouse_pos;
}

fn EventMap Window.getEvent(&self)
{
	JsEvent event;

	// Reset scroll state each frame
	self.src.event_map.set(MOUSE_SCROLL_UP, false);
	self.src.event_map.set(MOUSE_SCROLL_DOWN, false);

	while (js_poll_event(&event) != 0)
	{
		switch (event.type)
		{
			case 1: // key down
				EventKey key = jsKeyToEventKey(event.code);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, true);
				}
			case 2: // key up
				EventKey key = jsKeyToEventKey(event.code);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, false);
				}
			case 3: // mouse button down
				EventKey key = jsMouseToEventKey(event.code);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, true);
				}
			case 4: // mouse button up
				EventKey key = jsMouseToEventKey(event.code);
				if (key != EMPTY_KEY)
				{
					self.src.event_map.set(key, false);
				}
			case 5: // scroll
				if (event.code == 0)
				{
					self.src.event_map.set(MOUSE_SCROLL_UP, true);
				}
				else
				{
					self.src.event_map.set(MOUSE_SCROLL_DOWN, true);
				}
			case 6: // mouse motion
				self.src.mouse_pos = { event.mouse_x, event.mouse_y };
			default:
		}
	}

	return self.src.event_map;
}

fn void Window.free(&self)
{
	js_destroy_canvas();
}

// Convert JS key code to unified EventKey
// JS sends KeyboardEvent.keyCode values (legacy but numeric and simple)
fn EventKey jsKeyToEventKey(uint code)
{
	switch (code)
	{
		// Letters (JS keyCode: A=65..Z=90)
		case 65: return A;
		case 66: return B;
		case 67: return C;
		case 68: return D;
		case 69: return E;
		case 70: return F;
		case 71: return G;
		case 72: return H;
		case 73: return I;
		case 74: return J;
		case 75: return K;
		case 76: return L;
		case 77: return M;
		case 78: return N;
		case 79: return O;
		case 80: return P;
		case 81: return Q;
		case 82: return R;
		case 83: return S;
		case 84: return T;
		case 85: return U;
		case 86: return V;
		case 87: return W;
		case 88: return X;
		case 89: return Y;
		case 90: return Z;
		// Number row (JS keyCode: 0=48..9=57)
		case 48: return KEY_0;
		case 49: return KEY_1;
		case 50: return KEY_2;
		case 51: return KEY_3;
		case 52: return KEY_4;
		case 53: return KEY_5;
		case 54: return KEY_6;
		case 55: return KEY_7;
		case 56: return KEY_8;
		case 57: return KEY_9;
		// Special keys
		case 27: return ESCAPE;
		case 13: return RETURN;
		case 32: return SPACE;
		case 46: return DELETE;
		case 9: return TAB;
		case 8: return BACKSPACE;
		case 45: return INSERT;
		case 20: return CAPS_LOCK;
		// Modifier keys
		case 16: return LEFT_SHIFT;
		case 17: return LEFT_CTRL;
		case 18: return LEFT_ALT;
		case 91: return LEFT_SUPER;
		case 93: return MENU;
		// Arrow keys
		case 37: return LEFT_ARROW;
		case 39: return RIGHT_ARROW;
		case 38: return UP_ARROW;
		case 40: return DOWN_ARROW;
		// Numpad
		case 144: return NUMLOCK;
		case 96: return NUM_0;
		case 97: return NUM_1;
		case 98: return NUM_2;
		case 99: return NUM_3;
		case 100: return NUM_4;
		case 101: return NUM_5;
		case 102: return NUM_6;
		case 103: return NUM_7;
		case 104: return NUM_8;
		case 105: return NUM_9;
		case 107: return KP_ADD;
		case 109: return KP_SUBTRACT;
		case 106: return KP_MULTIPLY;
		case 111: return KP_DIVIDE;
		case 110: return KP_DECIMAL;
		// Function keys
		case 112: return F1;
		case 113: return F2;
		case 114: return F3;
		case 115: return F4;
		case 116: return F5;
		case 117: return F6;
		case 118: return F7;
		case 119: return F8;
		case 120: return F9;
		case 121: return F10;
		case 122: return F11;
		case 123: return F12;
		// Navigation
		case 36: return HOME;
		case 35: return END;
		case 33: return PAGE_UP;
		case 34: return PAGE_DOWN;
		// Punctuation and symbols
		case 189: return MINUS;
		case 187: return EQUALS;
		case 219: return LEFT_BRACKET;
		case 221: return RIGHT_BRACKET;
		case 220: return BACKSLASH;
		case 186: return SEMICOLON;
		case 222: return APOSTROPHE;
		case 192: return GRAVE;
		case 188: return COMMA;
		case 190: return PERIOD_KEY;
		case 191: return SLASH_KEY;
		// Lock keys
		case 145: return SCROLL_LOCK;
		case 19: return PAUSE;
		case 44: return PRINT_SCREEN;
		default: return EMPTY_KEY;
	}
}

// Convert JS mouse button to EventKey
// JS MouseEvent.button: 0=left, 1=middle, 2=right
fn EventKey jsMouseToEventKey(uint button)
{
	switch (button)
	{
		case 0: return LEFT_MOUSE;
		case 1: return MIDDLE_MOUSE;
		case 2: return RIGHT_MOUSE;
		case 3: return MOUSE_4;
		case 4: return MOUSE_5;
		default: return EMPTY_KEY;
	}
}
