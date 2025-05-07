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
