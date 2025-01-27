module std::core::env;

module c3w;
import vk;
import std;
import std::os::win32;

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

struct EventMap {
    EventKey key;
    bool selected;
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

fault WindowError {
    FAILED_OPENING_WINDOW
}

