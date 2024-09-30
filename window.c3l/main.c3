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
    bool left_click;
    bool right_click;
}

struct Event
{
   EventType type;
   char value;
   short mouse_x;
   short mouse_y;
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