module c3w @if(env::LINUX && $feature(WAYLAND)) @link("wayland-client");
import std::math;
import vk;
import std::io;
import std::core::types;

def GlobalListener = fn void (LinuxWindow* data, void* wl_registry, uint name, char* iface, uint ver);
def RemoveListener = fn void (void* data, void* wl_registry, uint name);
def ShellPing = fn void (LinuxWindow* data, Shell shell, uint serial);

def Registry = void*;
def Proxy = void*;
def Interface = void*;
def Compositor = void*;
def Shell = void*;
def Surface = void*;
def ShellSurface = void*;

struct LinuxWindow {
    vk::Display display;
    vk::Connection connection;
    vk::Window window;
    Compositor compositor;
    Shell shell;
    Surface surface;
}

// struct WLMessage {
//     char* name;
//     char* signature;
//     char* types;
// }

struct RegistryListener {
    GlobalListener global;
    RemoveListener global_remove;
}

struct ShellListener {
    ShellPing ping;
}

struct MouseParams {
    char type;
    ushort x;
    ushort y;
    ushort root_x;
    ushort root_y;
}

const uint WL_DISPLAY_GET_REGISTRY = 1;
const uint WL_REGISTRY_BIND = 0;
const uint WL_MARSHAL_FLAG_DESTROY = 1 << 0;

extern Interface registry_interface @extern("wl_registry_interface");
extern Interface compositor_interface @extern("wl_compositor_interface");
extern Interface surface_interface @extern("wl_surface_interface");
Interface wm_base_interface @export("xdg_wm_base_interface");
Interface xdg_surface_interface @export("xdg_surface_interface");

extern fn vk::Display connect(uint* window) @extern("wl_display_connect");
extern fn void disconnect(vk::Display display) @extern("wl_display_disconnect");
extern fn void* proxy_marshal_flags(Proxy proxy, uint opcode, void* inter, uint version, uint flags, ...) @extern("wl_proxy_marshal_flags");
extern fn int proxy_add_listener(Proxy registry, void* callback, void* data) @extern("wl_proxy_add_listener");

extern fn void wm_base_listener(Shell shell, ShellListener* listener, void* data) @extern("xdg_wm_base_add_listener");
extern fn void proxy_destroy(Proxy proxy) @extern("wl_proxy_destroy");
fn void surface_destroy(Surface surface) => proxy_marshal_flags(surface, 0, null, proxy_get_version(surface), WL_MARSHAL_FLAG_DESTROY);

extern fn uint proxy_get_version(Proxy proxy) @extern("wl_proxy_get_version");
extern fn int dispatch(vk::Display display) @extern("wl_display_dispatch");
extern fn int rountrip(vk::Display display) @extern("wl_display_roundtrip");
fn void surface_commit(Surface surface) => proxy_marshal_flags(surface, 6, null, proxy_get_version(surface), 0);

fn Registry get_registry(vk::Display display) => proxy_marshal_flags(display, WL_DISPLAY_GET_REGISTRY, &registry_interface, 1, 0, null);
fn void* registry_bind(Registry registry, uint name, Interface* inter, uint version, char* interface_name) => proxy_marshal_flags(registry, WL_REGISTRY_BIND, inter, version, 0, name, interface_name, version, null);
fn Surface create_surface(Compositor compositor) => proxy_marshal_flags(compositor, 0, &surface_interface, proxy_get_version(compositor), 0, null);
//fn Surface create_xdg_surface(Shell shell, Surface surface) => proxy_marshal_flags(shell, 2, &xdg_surface_interface, proxy_get_version(shell), 0, null, surface);


fn void removeRegistry(void* data, Registry registry, uint name)
{
    io::printfn("%d", name);
}

fn void shellPing(LinuxWindow* window, Shell shell, uint serial)
{
    io::printfn("shell ping");
    proxy_marshal_flags(shell, 3, null, proxy_get_version(shell), 0, serial);
}

RegistryListener registryListener = {
    &handleRegistry,
    &removeRegistry
};

ShellListener shellListener = {
    &shellPing,
};

fn void handleRegistry(LinuxWindow* window, Registry registry, uint name, char* interface_name, uint version)
{
    String action_name = ((ZString)interface_name).str_view();

    if (action_name == "wl_compositor") {
        window.compositor = proxy_marshal_flags(registry, WL_REGISTRY_BIND, &compositor_interface, version, 0, name, interface_name, version, null);
        window.surface = create_surface(window.compositor);
    }

    if (action_name == "xdg_wm_base") {
        window.shell = proxy_marshal_flags(registry, WL_REGISTRY_BIND, &wm_base_interface, version, 0, name, interface_name, version, null);
        proxy_add_listener(window.shell, &shellListener, window);
    }
}



// Creates new XCB window
fn Window! new(Params params, String name) {
    Window window;

    vk::Display display = connect(null);
    if (display == null) return WindowError.FAILED_OPENING_WINDOW?;

    window.src.display = display;

    Registry registry = get_registry(display);
    if (registry == null) return WindowError.FAILED_OPENING_WINDOW?;
    proxy_add_listener(registry, &registryListener, &window.src);

    dispatch(display);
    rountrip(display);

    assert(window.src.compositor);
    assert(window.src.surface);
    assert(window.src.shell);
    surface_commit(window.src.surface);
    // ShellSurface shell_surface = create_xdg_surface(window.src.shell, window.src.surface);
    // assert(proxy_marshal_flags(window.src.shell, 0, &xdg_surface_interface, 1, 0, null, null, window.src.surface ));

    //assert(shell_surface);

    return window;
}

fn Vec2f Window.getMousePos(self) {
    Vec2f response = {0, 0};
    return response;
}

fn Event Window.getEvent(&self) {  
    Event event_response;
    return event_response;
}

// Free and destroys window instance
fn void Window.free(&self) {
    surface_destroy(self.src.surface);
    disconnect(self.src.display);
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