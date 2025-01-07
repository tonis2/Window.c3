module std::core::env;

module c3w;
import vk;
import std;
import std::os::win32;

struct DarwinWindow {
    uint i;
}

struct Win32Window {
    vk::Hwnd window;
    vk::Hinstance instance;
    Win32_HDC hdc;
}

struct LinuxWindow {
    vk::Display display;
    vk::Connection connection;
    vk::Window window;
}

struct Window {
    DarwinWindow src @if(env::os_is_darwin());
	LinuxWindow src @if(env::LINUX);
    Win32Window src @if(env::WIN32);
    uint width;
    uint height;
    EventMap[EventKey.len] event_map;
}

fn bool Window.is_pressed(self, EventKey key) {
    foreach (item: self.event_map) {
        if (item.key == key) return item.selected;
    };
    return false;
}


struct Event
{
   EventType type;
   EventKey value;
   float mouse_x;
   float mouse_y;
}

struct Params {
    int depth;
    int x;
    int y;
    int width;
    int height;
    int border_width;
}

fault WindowError {
    FAILED_OPENING_WINDOW
}

enum EventType : uint (uint value)
{
    EMPTY_EVENT = 0,
    KEY_PRESSED = 2,
    KEY_RELEASED = 3,
    MOUSE_PRESSED = 4,
    MOUSE_RELEASED = 5,
    MOUSE_MOTION = 6,
    WINDOW_INIT = 12,
    WINDOW_REFRESH = 16,
    QUIT = 32,
    DND = 33,
    DND_INIT = 34,
}

struct EventMap {
    EventKey key;
    bool selected;
}

enum EventKey : uint (uint value)
{
    LEFT_MOUSE = 1,
    MIDDLE_MOUSE = 2,
    RIGHT_MOUSE = 3,
    MOUSE_SCROLL_UP = 4,
    MOUSE_SCROLL_DOWN = 5,
    
    EMPTY_KEY = 0,
    ESCAPE = 9,
    A = 38,
    B = 56,
    C = 54,
    D = 40,
    E = 26,
    F = 41,
    G = 42,
    H = 43,
    I = 31,
    J = 44,
    K = 45,
    L = 46,
    M = 58,
    N = 57,
    O = 32,
    P = 33,
    Q = 24,
    R = 27,
    S = 39,
    T = 28,
    U = 30,
    V = 55,
    W = 25,
    X = 53,
    Y = 29,
    Z = 52,

    RETURN = 36,
    DELETE = 119,   
    NUMLOCK = 77,  
    SLASH = 106,
    MULTIPLY = 63,    
    SUBTRACT = 82,  
    NUM_0 = 87,
    NUM_1 = 88,    
    NUM_2 = 89, 
    NUM_3 = 83,  
    NUM_4 = 84,   
    NUM_5 = 85,    
    NUM_6 = 79, 
    NUM_7 = 80,  
    NUM_8 = 81,   
    NUM_9 = 90,    
    PERIOD = 91,    
    KP_RETURN = 104
}