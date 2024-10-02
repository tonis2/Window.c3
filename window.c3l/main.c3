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

enum MouseButton : char (char value)
{
    NONE = 0,
    LEFT_MOUSE = 1,
    MIDDLE_MOUSE = 2,
    RIGHT_MOUSE = 3,
    MOUSE_SCROLL_UP = 4,
    MOUSE_SCROLL_DOWN = 5,
}