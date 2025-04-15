module c3w @if(env::WIN32) @link(env::WIN32);
import std::math;
import std::os::win32;
import std::io;

alias HWND = void*;
alias Hinstance = void*;

struct Win32Window {
    void* window;
    Hinstance instance;
    Win32_HDC hdc;
    EventMap[EventKey.len] event_map;
}

extern fn Window createWindow(Params params) @extern("createWindow");
extern fn Event getEvent(Window window) @extern("getEvent");
extern fn MouseParams getMousePos(Window window) @extern("getMousePos");
extern fn void destroy(Window window) @extern("destroy");

fn Window new(Params params, String name) {
    return createWindow(params);
}

fn Event Window.getEvent(self) {
    Event event = getEvent(self);
    if (event.value > 0 && event.value <= 5) {
        event.mouse_click = (MouseButton)event.value;
    }
   
    return event;
}

fn void Window.free(self) {
  destroy(self);
}

enum EventKey : uint (uint value)
{    
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
    SPACE = 65,
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
    KP_RETURN = 104,
    LEFT_ARROW = 113,
    RIGHT_ARROW = 114,
    DOWN_ARROW = 116,
    UP_ARROW = 111
}