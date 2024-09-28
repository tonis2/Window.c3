module xcb;
import std::math;
import std::os::win32;
import vk;
import std::io;

struct Window {
    vk::Display display;
    vk::Connection connection;
    vk::Window window;
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

extern fn Window createWindow(Params params) @extern("createWindow");
extern fn void destroy(Window window) @extern("destroy");
extern fn void changeWindowName(Window window, ZString name) @extern("changeWindowName");
extern fn MouseParams getMousePos(Window window) @extern("getMousePos");
extern fn RawEvent* getEvent(Window window) @extern("getEvent");

// Creates new XCB window
fn Window new(Params params, String name) {
    Window window = createWindow(params);
    changeWindowName(window, (ZString)name);
    return window;
}

fn Event Window.getEvent(&self) {
   RawEvent* event = getEvent(*self);
   Event event_response = Event {.type = 0};

   if (event != null) {
        EventType type = (EventType)event.type;
        switch (type) {
            case MOUSE_MOTION: {}
            case MOUSE_PRESSED: {
                KeyPressEvent* mouse_event = (KeyPressEvent*)event;
  
                event_response = Event{
                    .type = (EventType)event.type, 
                    .value = mouse_event.value,
                    .mouse_x = mouse_event.event_x,
                    .mouse_y = mouse_event.event_y,
                };

                if ((MouseButton)mouse_event.value == LEFT_MOUSE) {
                    self.left_click = true;
                }

                if ((MouseButton)mouse_event.value == RIGHT_MOUSE) {
                    self.right_click = true;
                }
            }
            case MOUSE_RELEASED: {
                KeyPressEvent* mouse_event = (KeyPressEvent*)event;
  
                event_response = Event{
                    .type = (EventType)event.type, 
                    .value = mouse_event.value,
                    .mouse_x = mouse_event.event_x,
                    .mouse_y = mouse_event.event_y,
                };

                if ((MouseButton)mouse_event.value == LEFT_MOUSE) {
                    self.left_click = false;
                }

                if ((MouseButton)mouse_event.value == RIGHT_MOUSE) {
                    self.right_click = false;
                }

                break;
            }
            case KEY_PRESSED:
            case KEY_RELEASED: {
                KeyPressEvent* key_event = (KeyPressEvent*)event;
                event_response = Event{ .type = (EventType)event.type, .value = key_event.value};
                break;
            }
            default: {};
        }
    }

 
    return event_response;
}

// Free and destroys window instance
fn void Window.free(self) {
    destroy(self);
}