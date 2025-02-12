module c3w @if(env::LINUX && $feature(WAYLAND)) @link("wayland-client");
import std::math;
import std::io;
import std::core::types;

def GlobalEvent = fn void (LinuxWindow* data, void* wl_registry, uint name, char* iface, uint ver);
def RemoveEvent = fn void (LinuxWindow* data, void* wl_registry, uint name);
def ShellPing = fn void (LinuxWindow* data, Shell shell, uint serial);
def SeatCapabilitiesEvent = fn void (LinuxWindow* data, void* wl_registry, uint capabilities);
def SeatNameEvent = fn void (LinuxWindow* data, void* wl_registry, char* name);

def KBmapEvent = fn void (LinuxWindow* data, Keyboard kb, uint frmt, int fd, uint sz);
def KBenterEvent = fn void (LinuxWindow* data, Keyboard kb, uint ser, Surface surface, WLArray* keys);
def KBleaveEvent = fn void (LinuxWindow* data, Keyboard kb, uint ser, Surface surface);
def KBkeyEvent = fn void (LinuxWindow* data, Keyboard kb,uint serial, uint type, uint key, uint state);
def KBmodEvent = fn void (LinuxWindow* data, Keyboard kb, uint serial, uint dep, uint lat, uint lock, uint group);
def KBrepEvent = fn void (LinuxWindow* data, Keyboard kb, int rate, int del);

def PointerEnter = fn void (LinuxWindow* data, Pointer pointer, int serial, Surface surface, int x, int y);
def PointerLeave = fn void (LinuxWindow* data, Pointer pointer, int serial, Surface surface);
def PointerMotion = fn void (LinuxWindow* data, Pointer pointer, uint time, int x, int y);
def PointerButton = fn void (LinuxWindow* data, Pointer pointer, int serial, uint time, uint button, uint state);
def PointerAxis = fn void (LinuxWindow* data, Pointer pointer, uint time, uint axis, uint value);
def Noop = fn void ();

def Registry = void*;
def Proxy = void*;
def Compositor = void*;
def Shell = void*;
def Surface = void*;
def SubCompositor = void*;
def Display = void*;
def Seat = void*;
def Keyboard = void*;
def Pointer = void*;

EventMap[EventKey.len] event_map;
Vec2f mouse_pos;

struct LinuxWindow {
    Display display;
    Surface surface;
    Shell shell;
    Seat seat;
    XDG_surface xdg_surface;
    XDG_top_level top_level;
    // EventMap[EventKey.len] event_map;
    // Vec2f mouse_pos;
    bool open;
}

struct WLArray {
	usz size;
	usz alloc;
	void *data;
}

struct WLMessage {
    char* name;
    char* signature;
    char* types;
}

struct RegistryListener {
    GlobalEvent global;
    RemoveEvent global_remove;
}

struct ShellListener {
    ShellPing ping;
}

struct SeatListener {
    SeatCapabilitiesEvent capabilities;
    SeatNameEvent name;
}

struct KeyboardListener {
    KBmapEvent keymap;
    KBenterEvent enter;
    KBleaveEvent leave;
    KBkeyEvent key;
    KBmodEvent modifiers;
    KBrepEvent repeat_info;
}

struct PointerListener {
    PointerEnter enter;
    PointerLeave leave;
    PointerMotion motion;
    PointerButton button;
    PointerAxis axis;
    Noop frame;
    Noop axis_source;
    Noop axis_stop;
    Noop axis_disc;
    Noop axis_value;
}

struct MouseParams {
    char type;
    ushort x;
    ushort y;
    ushort root_x;
    ushort root_y;
}

struct Interface {
	char* name;
	int version;
	int method_count;
	Message* methods;
	int event_count;
	Message* events;
}

const uint WL_DISPLAY_GET_REGISTRY = 1;
const uint WL_REGISTRY_BIND = 0;
const uint WL_MARSHAL_FLAG_DESTROY = 1 << 0;

extern Interface wl_registry_interface @extern("wl_registry_interface");
extern Interface wl_compositor_interface @extern("wl_compositor_interface");
extern Interface wl_surface_interface @extern("wl_surface_interface");
extern Interface wl_shell_interface @extern("wl_shell_interface");
extern Interface wl_output_interface @extern("wl_output_interface");
extern Interface wl_seat_interface @extern("wl_seat_interface");
extern Interface wl_subcompositor_interface @extern("wl_subcompositor_interface");
extern Interface wl_keyboard_interface @extern("wl_keyboard_interface");
extern Interface wl_pointer_interface @extern("wl_pointer_interface");

extern fn Display connect(uint* window) @extern("wl_display_connect");
extern fn void disconnect(Display display) @extern("wl_display_disconnect");
extern fn void subcompositor_surface(Display display) @extern("wl_subcompositor_get_subsurface");
extern fn void* proxy_marshal_flags(Proxy proxy, uint opcode, void* inter, uint version, uint flags, ...) @extern("wl_proxy_marshal_flags");
extern fn int proxy_add_listener(Proxy registry, void* callback, void* data) @extern("wl_proxy_add_listener");
extern fn void proxy_destroy(Proxy proxy) @extern("wl_proxy_destroy");
extern fn uint proxy_get_version(Proxy proxy) @extern("wl_proxy_get_version");
extern fn int dispatch(Display display) @extern("wl_display_dispatch");
extern fn int rountrip(Display display) @extern("wl_display_roundtrip");

fn void surface_commit(Surface surface) => proxy_marshal_flags(surface, 6, null, proxy_get_version(surface), 0);
fn void* registry_bind(Registry registry, Interface* inter, int name, int version) => proxy_marshal_flags(registry, WL_REGISTRY_BIND, inter, version, 0, name, inter.name, version, null);
fn Registry get_registry(Display display) => proxy_marshal_flags(display, WL_DISPLAY_GET_REGISTRY, &wl_registry_interface, 1, 0, null);
fn double fixed_to_double(int fixed) => fixed / 256.0;

enum SeatCapability: uint (uint value) {
	POINTER = 1,
	KEYBOARD = 2,
	TOUCH = 4,
}

fn void removeRegistry(LinuxWindow* window, Registry registry, uint name)
{
    window.open = false;             
}

fn void shellPing(LinuxWindow* window, Shell shell, uint serial)
{
    io::printfn("shell ping");
    // Pong back the ping
    proxy_marshal_flags(shell, 3, null, proxy_get_version(shell), 0, serial);
}

fn void shellSurfaceConfigure(LinuxWindow* window, XDG_surface surface, uint serial)
{
    proxy_marshal_flags(surface, 4, null, proxy_get_version(surface), 0, serial);
}

fn void topSurfaceClose(LinuxWindow* data, XDG_top_level top_level)
{   
    // Window closed
    data.open = false;
}

fn void topSurfaceConfigure(LinuxWindow* data, XDG_top_level top_level, int width, int height, void* states) {}
fn void topSurfaceBounds(LinuxWindow* data, XDG_top_level top_level, int width, int height) {}
fn void topSurfaceCapabilities(LinuxWindow* data, XDG_top_level top_level, void* capabilities) {}

fn void seatCapabilities(LinuxWindow* data, Seat seat, uint capabilities)
{
    if (capabilities & SeatCapability.KEYBOARD.value)
    {
        Keyboard keyboard = proxy_marshal_flags(seat, 1, &wl_keyboard_interface, proxy_get_version(seat), 0, null);
        proxy_add_listener(keyboard, &keyboardListener, data);
    }

    if (capabilities & SeatCapability.POINTER.value)
    {
        Pointer pointer = proxy_marshal_flags(seat, 0, &wl_pointer_interface, proxy_get_version(seat), 0, null);
        proxy_add_listener(pointer, &pointerListener, data);
    }
}

fn void seatName(LinuxWindow* data, Seat seat, char* name)
{
    // io::printfn("seat %s", (ZString)name);
}

fn void kbMap(LinuxWindow* data, Keyboard kb, uint frmt, int fd, uint sz) {}
fn void kbEnter(LinuxWindow* data, Keyboard kb, uint ser, Surface surface, WLArray* keys) {}
fn void kbLeave(LinuxWindow* data, Keyboard kb, uint ser, Surface surface) {}
fn void noop() {}

fn void kbKey(LinuxWindow* data, Keyboard kb, uint serial, uint type, uint key, uint state)
{
    EventKey keyboard_key = @enum_from_value(EventKey, value, key + 8)!!;

    foreach (&item: event_map) {
        if (item.key == keyboard_key) {
            item.selected = (bool)state;
            break;
        };
    };
}

fn void kbMod(LinuxWindow* data, Keyboard kb, uint serial, uint dep, uint lat, uint lock, uint group) {}
fn void kbRep(LinuxWindow* data, Keyboard kb, int rate, int del) {}

fn void pointerEnter(LinuxWindow* data, Pointer pointer, int serial, Surface surface, int x, int y) {}
fn void pointerLeave(LinuxWindow* data, Pointer pointer, int serial, Surface surface) {}

fn void pointerMotion(LinuxWindow* data, Pointer pointer, uint time, int x, int y) {
    mouse_pos = Vec2f{(float)fixed_to_double(x), -(float)fixed_to_double(y)};
}

fn void pointerButton(LinuxWindow* data, Pointer pointer, int serial, uint time, uint button, uint state) {
    //Left mouse button
    if (button == 272) {
        event_map[EventKey.len - 3].selected = (bool)state;
    }

    //Right mouse button
    if (button == 273) {
        event_map[EventKey.len - 2].selected  = (bool)state;
    }
    
    //Middle mouse button
    if (button == 274) {
        event_map[EventKey.len - 1].selected  = (bool)state;
    }
}

fn void pointerAxis(LinuxWindow* data, Pointer pointer, uint time, uint axis, uint value) {}


fn void handleRegistry(LinuxWindow* window, Registry registry, uint name, char* interface_name, uint version)
{
    String action_name = ((ZString)interface_name).str_view();

    if (action_name == "wl_compositor") {
        Compositor compositor = registry_bind(registry, &wl_compositor_interface, name, version);
        window.surface = registry_bind(compositor, &wl_surface_interface, name, version);
    }

    if (action_name == "xdg_wm_base") {
        window.shell = registry_bind(registry, &xdg_wm_base_interface, name, version);
        proxy_add_listener(window.shell, &shellListener, window);
    }

    if (action_name == "wl_seat") {
        window.seat = registry_bind(registry, &wl_seat_interface, name, version);
        proxy_add_listener(window.seat, &seatListener, window);
    }
}

KeyboardListener keyboardListener = {
    &kbMap,
    &kbEnter,
    &kbLeave,
    &kbKey,
    &kbMod,
    &kbRep
};

ShellSurfaceListener shellSurfaceListener = {
    &shellSurfaceConfigure
};

RegistryListener registryListener = {
    &handleRegistry,
    &removeRegistry
};

ShellListener shellListener = {
    &shellPing,
};

TopSurfaceListener topSurfaceListener = {
    &topSurfaceConfigure,
    &topSurfaceClose,
    &topSurfaceBounds,
    &topSurfaceCapabilities
};

SeatListener seatListener = {
    &seatCapabilities,
    &seatName,
};

PointerListener pointerListener = {
    &pointerEnter,
    &pointerLeave,
    &pointerMotion,
    &pointerButton,
    &pointerAxis,
    &noop,
    &noop,
    &noop,
    &noop,
    &noop
};

// Creates new XCB window
fn Window! new(Params params, String name) {
    LinuxWindow window = {
        .open = true,
    };

    Display display = connect(null);
    if (display == null) return WindowError.FAILED_OPENING_WINDOW?;

    window.display = display;

    Registry registry = get_registry(display);
    if (registry == null) return WindowError.FAILED_OPENING_WINDOW?;
    proxy_add_listener(registry, &registryListener, &window);
    rountrip(display);

    assert(window.surface);
    assert(window.shell);
    
    //Get XDG surface
    window.xdg_surface = proxy_marshal_flags(window.shell, 2, &xdg_surface_interface, proxy_get_version(window.shell), 0, null, window.surface);
    assert(window.xdg_surface);
    proxy_add_listener(window.xdg_surface, &shellSurfaceListener, &window);

    window.top_level = proxy_marshal_flags(window.xdg_surface, 1, &xdg_toplevel_interface, proxy_get_version(window.xdg_surface), 0, null);
    proxy_add_listener(window.top_level, &topSurfaceListener, &window);
    assert(window.top_level);
    // set maximized
    // proxy_marshal_flags(top_level, 9, &xdg_toplevel_interface, proxy_get_version(top_level), 0, null);
    // Set title
    proxy_marshal_flags(window.top_level, 1, &xdg_toplevel_interface, proxy_get_version(window.top_level), 0, null, name);
    // // Set id
    proxy_marshal_flags(window.top_level, 2, &xdg_toplevel_interface, proxy_get_version(window.top_level), 0, null, name);
    surface_commit(window.surface);
    rountrip(display);
    surface_commit(window.surface);

    foreach (index, item: EventKey.values) {
        event_map[index] = {
           .key = item,
           .selected = false
        };
    }

    return {
        .src = window,
        .width = params.width,
        .height = params.height,
    };
}

fn Vec2f Window.getMousePos(self) {
    return mouse_pos;
}

fn EventMap[] Window.getEvent(&self) {
    dispatch(self.src.display);
    return &event_map;
}

// Free and destroys window instance
fn void Window.free(&self) {
    // proxy_destroy(self.src.keyboard);
    proxy_marshal_flags(self.src.seat, 3, null, proxy_get_version(self.src.seat), WL_MARSHAL_FLAG_DESTROY);
    proxy_marshal_flags(self.src.surface, 0, null, proxy_get_version(self.src.surface), WL_MARSHAL_FLAG_DESTROY);
    proxy_marshal_flags(self.src.xdg_surface, 0, null, proxy_get_version(self.src.surface), WL_MARSHAL_FLAG_DESTROY);
    proxy_marshal_flags(self.src.top_level, 0, null, proxy_get_version(self.src.surface), WL_MARSHAL_FLAG_DESTROY);
    disconnect(self.src.display);
}
