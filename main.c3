module std::core::env;

module c3w;
import std;
import std::os::win32;

struct Window {
    DarwinWindow src @if(env::os_is_darwin());
	LinuxWindow src @if(env::LINUX);
    Win32Window src @if(env::WIN32);
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
enum EventKey : uint
{
    EMPTY_KEY,
    // Letters
    A, B, C, D, E, F, G, H, I, J, K, L, M,
    N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    // Number row
    KEY_0, KEY_1, KEY_2, KEY_3, KEY_4,
    KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
    // Special keys
    ESCAPE,
    RETURN,
    SPACE,
    DELETE,
    TAB,
    BACKSPACE,
    INSERT,
    CAPS_LOCK,
    // Modifier keys
    LEFT_SHIFT,
    RIGHT_SHIFT,
    LEFT_CTRL,
    RIGHT_CTRL,
    LEFT_ALT,
    RIGHT_ALT,
    LEFT_SUPER,    // Windows key / Command key
    RIGHT_SUPER,
    MENU,          // Context menu key
    // Arrow keys
    LEFT_ARROW,
    RIGHT_ARROW,
    UP_ARROW,
    DOWN_ARROW,
    // Numpad
    NUMLOCK,
    NUM_0, NUM_1, NUM_2, NUM_3, NUM_4,
    NUM_5, NUM_6, NUM_7, NUM_8, NUM_9,
    KP_RETURN,
    KP_ADD,
    KP_SUBTRACT,
    KP_MULTIPLY,
    KP_DIVIDE,
    KP_DECIMAL,
    // Legacy aliases for numpad
    MULTIPLY,
    SLASH,
    SUBTRACT,
    PERIOD,
    // Function keys
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    F13, F14, F15, F16, F17, F18, F19, F20,
    // Navigation
    HOME,
    END,
    PAGE_UP,
    PAGE_DOWN,
    // Punctuation and symbols
    MINUS,         // -
    EQUALS,        // =
    LEFT_BRACKET,  // [
    RIGHT_BRACKET, // ]
    BACKSLASH,     // \
    SEMICOLON,     // ;
    APOSTROPHE,    // '
    GRAVE,         // ` (backtick)
    COMMA,         // ,
    PERIOD_KEY,    // .
    SLASH_KEY,     // /
    // Lock keys
    SCROLL_LOCK,
    PAUSE,
    PRINT_SCREEN,
    // Mouse
    LEFT_MOUSE,
    RIGHT_MOUSE,
    MIDDLE_MOUSE,
    MOUSE_SCROLL_UP,
    MOUSE_SCROLL_DOWN,
    MOUSE_4,
    MOUSE_5,
}

// Unified EventType enum
enum EventType : uint
{
    EMPTY_EVENT,
    KEY_PRESSED,
    KEY_RELEASED,
    MOUSE_PRESSED,
    MOUSE_RELEASED,
    MOUSE_MOTION,
    WINDOW_INIT,
    WINDOW_REFRESH,
    QUIT,
    DND,
    DND_INIT,
}
