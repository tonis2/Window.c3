module std::core::env;

module c3w;
import std;
import std::os::win32;

struct Window {
    DarwinWindow src @if(env::os_is_darwin());
	LinuxWindow src @if(env::LINUX);
    Win32Window src @if(env::WIN32);
    WasmWindow src @if(env::WASM);
    float width;
    float height;
}

alias EventMap = HashMap{EventKey, bool};

macro uint EventKey.hash(EventKey key) => builtin::@generic_hash(key.ordinal);

fn bool EventMap.is_pressed(self, EventKey key) {
    bool? item = self.get(key);
    if (catch err = item) return false;
    return item;
}

struct Event
{
   EventType type;
   EventKey value;
   float mouse_x;
   float mouse_y;
}

struct Params {
    int x;
    int y;
    int width;
    int height;
}

faultdef FAILED_OPENING_WINDOW;

// Unified EventKey enum - platform-neutral key identifiers
// X11 keycode values for lookup_field
enum EventKey : uint (uint code)
{
    EMPTY_KEY { 0 },
    // Letters (X11 keycodes: a=38, b=56, c=54, d=40, e=26, f=41, g=42, h=43, i=31, j=44, k=45, l=46, m=58)
    A { 38 }, B { 56 }, C { 54 }, D { 40 }, E { 26 }, F { 41 }, G { 42 }, H { 43 }, I { 31 },
    J { 44 }, K { 45 }, L { 46 }, M { 58 },
    // N, O, P, Q, R, S, T, U, V, W, X, Y, Z (X11: n=57, o=32, p=33, q=24, r=27, s=39, t=28, u=30, v=55, w=25, x=53, y=29, z=52)
    N { 57 }, O { 32 }, P { 33 }, Q { 24 }, R { 27 }, S { 39 }, T { 28 }, U { 30 }, V { 55 },
    W { 25 }, X { 53 }, Y { 29 }, Z { 52 },
    // Number row (X11: 1=10, 2=11, 3=12, 4=13, 5=14, 6=15, 7=16, 8=17, 9=18, 0=19)
    KEY_0 { 19 }, KEY_1 { 10 }, KEY_2 { 11 }, KEY_3 { 12 }, KEY_4 { 13 },
    KEY_5 { 14 }, KEY_6 { 15 }, KEY_7 { 16 }, KEY_8 { 17 }, KEY_9 { 18 },
    // Special keys
    ESCAPE { 9 },
    RETURN { 36 },
    SPACE { 65 },
    DELETE { 119 },
    TAB { 23 },
    BACKSPACE { 22 },
    INSERT { 118 },
    CAPS_LOCK { 66 },
    // Modifier keys
    LEFT_SHIFT { 50 },
    RIGHT_SHIFT { 62 },
    LEFT_CTRL { 37 },
    RIGHT_CTRL { 105 },
    LEFT_ALT { 64 },
    RIGHT_ALT { 108 },
    LEFT_SUPER { 133 },    // Windows key / Command key
    RIGHT_SUPER { 134 },
    MENU { 135 },          // Context menu key
    // Arrow keys
    LEFT_ARROW { 113 },
    RIGHT_ARROW { 114 },
    UP_ARROW { 111 },
    DOWN_ARROW { 116 },
    // Numpad (X11 keycodes)
    NUMLOCK { 77 },
    NUM_0 { 90 }, NUM_1 { 87 }, NUM_2 { 88 }, NUM_3 { 89 }, NUM_4 { 83 },
    NUM_5 { 84 }, NUM_6 { 85 }, NUM_7 { 79 }, NUM_8 { 80 }, NUM_9 { 81 },
    KP_RETURN { 104 },
    KP_ADD { 86 },
    KP_SUBTRACT { 82 },
    KP_MULTIPLY { 63 },
    KP_DIVIDE { 106 },
    KP_DECIMAL { 91 },
    // Legacy aliases for numpad
    MULTIPLY { 63 },
    SLASH { 106 },
    SUBTRACT { 82 },
    PERIOD { 91 },
    // Function keys
    F1 { 67 }, F2 { 68 }, F3 { 69 }, F4 { 70 }, F5 { 71 }, F6 { 72 },
    F7 { 73 }, F8 { 74 }, F9 { 75 }, F10 { 76 }, F11 { 95 }, F12 { 96 },
    F13 { 97 }, F14 { 98 }, F15 { 99 }, F16 { 100 }, F17 { 101 }, F18 { 102 }, F19 { 103 }, F20 { 104 },
    // Navigation
    HOME { 110 },
    END { 115 },
    PAGE_UP { 112 },
    PAGE_DOWN { 117 },
    // Punctuation and symbols
    MINUS { 20 },         // -
    EQUALS { 21 },        // =
    LEFT_BRACKET { 34 },  // [
    RIGHT_BRACKET { 35 }, // ]
    BACKSLASH { 51 },     // \
    SEMICOLON { 47 },     // ;
    APOSTROPHE { 48 },    // '
    GRAVE { 49 },         // ` (backtick)
    COMMA { 59 },         // ,
    PERIOD_KEY { 60 },    // .
    SLASH_KEY { 61 },     // /
    // Lock keys
    SCROLL_LOCK { 78 },
    PAUSE { 127 },
    PRINT_SCREEN { 107 },
    // Mouse buttons (X11 button codes: 1-5)
    LEFT_MOUSE { 1 },
    RIGHT_MOUSE { 3 },
    MIDDLE_MOUSE { 2 },
    MOUSE_SCROLL_UP { 4 },
    MOUSE_SCROLL_DOWN { 5 },
    MOUSE_4 { 8 },
    MOUSE_5 { 9 },
}

// Unified EventType enum
// X11 event type values: KeyPress=2, KeyRelease=3, ButtonPress=4, ButtonRelease=5, MotionNotify=6
enum EventType : uint (uint code)
{
    EMPTY_EVENT { 0 },
    KEY_PRESSED { 2 },
    KEY_RELEASED { 3 },
    MOUSE_PRESSED { 4 },
    MOUSE_RELEASED { 5 },
    MOUSE_MOTION { 6 },
    WINDOW_INIT { 7 },
    WINDOW_REFRESH { 8 },
    QUIT { 9 },
    DND { 10 },
    DND_INIT { 11 },
}
