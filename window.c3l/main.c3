module c3w;
import vk;
import std;

struct DarwinWindow {
    uint i;
}

struct Win32Window {
    vk::Hwnd window;
    vk::Hinstance instance;
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
    struct screen_info {
        uint width;
        uint height;
    }
    MouseButton mouse_click;
}

struct Event
{
   EventType type;
   char value;
   short mouse_x;
   short mouse_y;
   MouseButton mouse_click;
}

struct Params {
    int depth;
    int x;
    int y;
    int width;
    int height;
    int border_width;
}

struct MouseParams {
    char type;
    ushort x;
    ushort y;
    ushort root_x;
    ushort root_y;
}

distinct EventType = inline char;
const EventType EMPTY_EVENT = 0;
const EventType KEY_PRESSED = 2;
const EventType KEY_RELEASED = 3;
const EventType MOUSE_PRESSED = 4;
const EventType MOUSE_RELEASED = 5;
const EventType MOUSE_MOTION = 6;

const EventType WINDOW_INIT = 12;
const EventType WINDOW_REFRESH = 16;
const EventType QUIT = 32;
const EventType DND = 33;
const EventType DND_INIT = 34;

distinct Key = inline char;
const Key EMPTY_KEY = 0;
const Key ESCAPE = 9;
const Key A = 38;
const Key B = 56;
const Key C = 54;
const Key D = 40;
const Key E = 26;
const Key F = 41;
const Key G = 42;
const Key H = 43;
const Key I = 31;
const Key J = 44;
const Key K = 45;
const Key L = 46;
const Key M = 58;
const Key N = 57;
const Key O = 32;
const Key P = 33;
const Key Q = 24;
const Key R = 27;
const Key S = 39;
const Key T = 28;
const Key U = 30;
const Key V = 55;
const Key W = 25;
const Key X = 53;
const Key Y = 29;
const Key Z = 52;

const Key RETURN = 36;
const Key DELETE = 119;
const Key NUMLOCK = 77;
const Key SLASH = 106;
const Key MULTIPLY = 63;
const Key SUBTRACT = 82;
const Key NUM_0 = 87;
const Key NUM_1 = 88;
const Key NUM_2 = 89;
const Key NUM_3 = 83;
const Key NUM_4 = 84;
const Key NUM_5 = 85;
const Key NUM_6 = 79;
const Key NUM_7 = 80;
const Key NUM_8 = 81;
const Key NUM_9 = 90;
const Key PERIOD = 91;
const Key KP_RETURN = 104;

enum MouseButton : char (char value)
{
    NONE = 0,
    LEFT_MOUSE = 1,
    MIDDLE_MOUSE = 2,
    RIGHT_MOUSE = 3,
    MOUSE_SCROLL_UP = 4,
    MOUSE_SCROLL_DOWN = 5,
}