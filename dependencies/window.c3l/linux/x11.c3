module c3w @if(env::LINUX && $feature(X11)) @link("X11", "xcb");
import std::math;

import std::io;
import std::core::types;

def Display = void*;
def Connection = void*;
def XCB_Window = void*;
def XCB_setup = void*;

struct LinuxWindow {
    Display display;
    Connection connection;
    XCB_Window window;
    EventMap[EventKey.len] event_map;
    uint width;
    uint height;
}

extern fn Display openDisplay(char* name) @extern("XOpenDisplay");
extern fn Connection xcbConnect(char* name, uint* window) @extern("xcb_connect");
extern fn XCB_setup xcbGetSetup(Connection connection) @extern("xcb_get_setup");
extern fn XScreenIterator* xcbRootsIterator(XCB_setup setup) @extern("xcb_setup_roots_iterator");
extern fn XCB_Window xcbWindowId(XCB_setup setup) @extern("xcb_generate_id");
extern fn XCB_Window xcbMapWindow(Connection con, XCB_Window win) @extern("xcb_map_window");
extern fn XCB_Window xcbFlush(Connection con) @extern("xcb_flush");
extern fn KeyPressEvent* xcbPollEvent(Connection con) @extern("xcb_poll_for_event");
extern fn KeyPressEvent* xcbPollQueuedEvent(Connection con) @extern("xcb_poll_for_queued_event");
extern fn KeyPressEvent* xcbWaitForEvent(Connection con) @extern("xcb_wait_for_event");
extern fn void xcbChangeProperty(Connection con, XcbProp mode, XCB_Window window, uint, uint, uint format, uint size, char* name) @extern("xcb_change_property");
extern fn uint xcbQueryPointer(Connection con, XCB_Window window) @extern("xcb_query_pointer");
extern fn KeyPressEvent* xcbQueryPointerReply(Connection con, uint cookie, void* err) @extern("xcb_query_pointer_reply");
extern fn uint xcbDestroy(Connection con, XCB_Window window) @extern("xcb_destroy_window");
extern fn uint xcbDisconnect(Connection con) @extern("xcb_disconnect");

extern fn uint createWindow(
    Connection    c,
    char          depth,
    XCB_Window        window,
    uint              parent,
    short             x,
    short             y,
    ushort            width,
    ushort            height,
    ushort            border_width,
    ushort            _class,
    uint              visual,
    uint              value_mask,
    void*             value_list
) @extern("xcb_create_window");

enum XcbProp : uint (uint value)
{
    PROP_MODE_REPLACE = 0,
    PROP_MODE_PREPEND = 1,
    PROP_MODE_APPEND = 2,
}

enum XcbEventMask : uint (uint value)
{
    CW_EVENT_MASK = 2048,
    BACK_PIXEL = 2,
    CW_CURSOR = 16384,
    EVENT_MASK_NO_EVENT = 0,
    EVENT_MASK_EXPOSURE = 32768,
    EVENT_MASK_BUTTON_PRESS = 4,
    EVENT_MASK_BUTTON_RELEASE = 8,
    EVENT_MASK_KEY_PRESS = 1,
    EVENT_MASK_KEY_RELEASE = 2,
    EVENT_MASK_POINTER_MOTION = 64,
    EVENT_MASK_POINTER_MOTION_HINT = 128,
    EVENT_MASK_STRUCTURE_NOTIFY = 131072,
    EVENT_MASK_VISIBILITY_CHANGE = 65536,
}

enum XcbPropMode : uint (uint value)
{
    PROP_MODE_REPLACE = 0,
    PROP_MODE_PREPEND = 1,
    PROP_MODE_APPEND = 2,
}

struct XscreenData {
    uint   root;
    uint   default_colormap;
    uint   white_pixel;
    uint   black_pixel;
    uint   current_input_masks;
    ushort width_in_pixels;
    ushort height_in_pixels;
    ushort width_in_millimeters;
    ushort height_in_millimeters;
    ushort min_installed_maps;
    ushort max_installed_maps;
    uint   root_visual;
    char   backing_stores;
    char   save_unders;
    char   root_depth;
    char   allowed_depths_len;
}

struct XScreenIterator {
    inline XscreenData data;
    int         rem;
    int         index;
}

struct KeyPressEvent {
    char type; 
    char value;
    short sequence;
    uint time;      
    uint  root;
    uint  event;
    uint  child;
    short root_x;
    short root_y;
    short event_x;
    short event_y;
    short state;
    char same_screen;
}

struct MouseParams {
    char type;
    ushort x;
    ushort y;
    ushort root_x;
    ushort root_y;
}

// Creates new XCB window
fn Window! new(Params params, String name) {
    Display dpy = openDisplay(null);

    if (!dpy)
    {
        io::printfn("Failed to open display");
        return WindowError.FAILED_OPENING_WINDOW?;
    }

    Connection connection = xcbConnect(null, null);
    XCB_setup setup = xcbGetSetup(connection);
    XScreenIterator* screen_iterator = xcbRootsIterator(setup);

    XCB_Window window = xcbWindowId(connection);

    uint mask = XcbEventMask.BACK_PIXEL.value | XcbEventMask.CW_EVENT_MASK.value;
    uint[] event_masks = {screen_iterator.data.black_pixel,
                          XcbEventMask.EVENT_MASK_EXPOSURE.value | XcbEventMask.EVENT_MASK_KEY_PRESS.value | XcbEventMask.EVENT_MASK_KEY_RELEASE.value |
                          XcbEventMask.EVENT_MASK_BUTTON_PRESS.value | XcbEventMask.EVENT_MASK_BUTTON_RELEASE.value};

    uint cookie = createWindow(
                        connection,
                        0,
                        window,
                        screen_iterator.data.root,
                        (short)params.x, 
                        (short)params.y,
                        (short)params.width,
                        (short)params.height,
                        (short)1.0,
                        1,
                        screen_iterator.data.root_visual,
                        mask,
                        &event_masks[0]
                    );

    xcbMapWindow(connection, window);
    xcbFlush(connection);

    // Change window name
    // XCB_ATOM_WM_NAME, XCB_ATOM_STRING
    xcbChangeProperty(connection, XcbProp.PROP_MODE_REPLACE, window, 39, 31, 8, name.len, name);
    Window response = {
        .src = LinuxWindow {
            .window = window,
            .connection = connection,
            .display = dpy,
            .width = screen_iterator.data.width_in_pixels,
            .height = screen_iterator.data.height_in_pixels
        }
    };

    foreach (index, item: EventKey.values) {
        response.src.event_map[index] = {
           .key = item,
           .selected = false
        };
    }

    return response;
}

fn Vec2f Window.getMousePos(self) {
    void* err;  
    KeyPressEvent* mouse_pos = xcbQueryPointerReply(self.src.connection, xcbQueryPointer(self.src.connection, self.src.window), &err);
    Vec2f response = {mouse_pos.root_x, mouse_pos.root_y};
    free(mouse_pos);
    free(err);

    return response;
}

fn Event Window.getEvent(&self) {
   KeyPressEvent* event = xcbPollEvent(self.src.connection);
   Event event_response;
   defer free(event);
      
   if (event != null) {
        EventType type = @enum_from_value(EventType, value, event.type)!!;
        EventKey value = @enum_from_value(EventKey, value, event.value)!!;
    
        event_response = Event {
            .type = type,
            .value = value,
            .mouse_x = event.event_x,
            .mouse_y = event.event_y,
        };

        switch (type) {
            case KEY_RELEASED:
            case MOUSE_RELEASED: {
                foreach (&item: self.src.event_map) {
                    if (item.key == value) {
                        item.selected = false;
                        break;
                    };
                };
            }
            case KEY_PRESSED:
            case MOUSE_PRESSED: {
                foreach (&item: self.src.event_map) {
                    if (item.key == value) {
                        item.selected = true;
                        break;
                    };
                };
                break;
            }
            default: {};
        }

    }

    return event_response;
}

// Free and destroys window instance
fn void Window.free(self) {
   xcbDestroy(self.src.connection, self.src.window);
   xcbDisconnect(self.src.connection);
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